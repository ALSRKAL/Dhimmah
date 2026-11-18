import Flutter
import UniformTypeIdentifiers
import UIKit

/// Saving backups into a folder the user owns, on iOS.
///
/// The Android side of this channel is `ACTION_OPEN_DOCUMENT_TREE` and the
/// Storage Access Framework. iOS has no tree URI; the equivalent is a
/// **security-scoped bookmark**: the user picks a folder through
/// `UIDocumentPickerViewController`, the app turns the URL it is handed into a
/// bookmark, and every later access resolves that bookmark and brackets its work
/// with `startAccessingSecurityScopedResource` /
/// `stopAccessingSecurityScopedResource`. Without the bracketing, the first read
/// works and the next one does not, which is exactly the kind of bug that only
/// shows up after a restart.
///
/// The bookmark is the folder's *identifier*: an opaque base64 blob that only
/// iOS can resolve. Nothing above the platform layer knows that, which is the
/// point — the Dart domain sees `BackupLocation` and nothing else.
///
/// The same four facts as Android, and the same refusal to guess:
///
/// * the provider (Files, iCloud Drive, a third-party provider) is the authority
///   on names and sizes;
/// * a folder that cannot be written to is reported, not worked around;
/// * a file is never written empty;
/// * nothing here asks for a storage permission the user did not grant by
///   choosing the folder.
///
/// NOTE: this file has not been compiled. The machine this was written on has no
/// Xcode, so it is code review only — see `docs/EXTERNAL-BACKUP-FOLDER.md`,
/// which records it as unverified rather than as proven.
@objc class BackupFolderChannel: NSObject {
  static let methodName = "dhimmah/backup_file"
  static let folderName = "Dhimmah Backups"

  private let queue = DispatchQueue(label: "dhimmah.backup-folder", qos: .userInitiated)

  /// The open picker's delegate, held until it answers. The picker keeps only a
  /// weak reference to its delegate, so one that nothing else held was gone
  /// before the user chose, and the choice never reached Dart.
  private var pickerDelegate: FolderPickerDelegate?

  /// The open export picker's delegate, held for the same reason.
  private var exportDelegate: ExportPickerDelegate?

  /// Where a document waits between `createDocument` and `write`.
  ///
  /// The channel's Dart caller asks where to save first, then hands over the
  /// bytes. iOS has no empty-document step like Android's SAF, so the file waits
  /// here, named as the app suggested, and `write` exports it with
  /// `UIDocumentPickerViewController(forExporting:)` once it holds the bytes.
  private static let stagingFolderName = "dhimmah-save"

  /// Answers the channel on [messenger].
  ///
  /// Takes the messenger rather than a plugin registrar: this is a method
  /// channel, not a plugin, and under the scene lifecycle the app delegate
  /// creates it in `didInitializeImplicitFlutterEngine` with the engine's
  /// messenger, as Flutter's UIScene migration guide describes. The handler
  /// closure holds the instance, and the messenger holds the handler.
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: methodName, binaryMessenger: messenger)
    let instance = BackupFolderChannel()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // The picker has to run on the main thread and answer later, so it is
    // handled before the worker queue.
    if call.method == "chooseFolder" {
      DispatchQueue.main.async { self.presentFolderPicker(result) }
      return
    }
    // The work runs off the main thread; its answer goes back on it, which is
    // where a channel's replies belong.
    let reply: FlutterResult = { value in
      DispatchQueue.main.async { result(value) }
    }
    queue.async {
      do {
        let arguments = call.arguments as? [String: Any]
        let uri = arguments?["uri"] as? String
        switch call.method {
        case "createFolder":
          let name = arguments?["name"] as? String ?? Self.folderName
          reply(try self.withAccess(to: uri) { folder in
            self.describe(try self.createFolder(in: folder, named: name))
          })
        case "writeDocument":
          let name = arguments?["name"] as? String ?? "backup.dhimmah"
          let bytes = arguments?["bytes"] as? FlutterStandardTypedData
          reply(try self.withAccess(to: uri) { folder in
            try self.write(bytes?.data ?? Data(), into: folder, named: name)
          })
        case "readDocument":
          let data = try self.withAccess(to: uri) { document in
            try Data(contentsOf: document)
          }
          reply(FlutterStandardTypedData(bytes: data))
        case "listDocuments":
          reply(try self.withAccess(to: uri) { folder in
            try self.list(in: folder)
          })
        case "deleteDocument":
          try self.withAccess(to: uri) { document in
            try FileManager.default.removeItem(at: document)
          }
          reply(["deleted": true])
        case "verifyWritable":
          try self.withAccess(to: uri) { folder in
            try self.verifyWritable(folder)
          }
          reply(["writable": true])
        case "describeFolder":
          reply(try self.withAccess(to: uri) { folder in
            self.describe(folder)
          })
        case "releaseFolder":
          // A bookmark has nothing to hand back; forgetting it is enough.
          reply(["released": true])
        // The same four calls Android's `DocumentSaveChannel` uses. They share
        // this channel because they are the same feature (a document the user
        // saves), and the same names so the Dart side cannot tell the platforms
        // apart — which is the point of the channel.
        case "createDocument":
          let name = arguments?["name"] as? String ?? "backup.dhimmah"
          let url = try self.makeStagingFile(named: name)
          self.purgeStaging()
          reply(self.describeStaging(url))
        case "write":
          let url = try self.stagingFile(from: uri)
          let bytes = (arguments?["bytes"] as? FlutterStandardTypedData)?.data ?? Data()
          if bytes.isEmpty {
            throw FolderError(code: "empty_bytes", message: "refusing to write an empty document")
          }
          // The bytes are on disk before the user is asked where they should
          // go; the export picker hands the file to the provider itself.
          try bytes.write(to: url, options: [.atomic])
          DispatchQueue.main.async {
            self.presentExport(url, count: bytes.count, result: result)
          }
        case "read":
          let url = try self.stagingFile(from: uri)
          reply(FlutterStandardTypedData(bytes: try Data(contentsOf: url)))
        case "metadata":
          reply(self.describeStaging(try self.stagingFile(from: uri)))
        default:
          reply(FlutterMethodNotImplemented)
        }
      } catch let error as FolderError {
        reply(FlutterError(code: error.code, message: error.message, details: nil))
      } catch {
        reply(FlutterError(code: "io_error", message: error.localizedDescription, details: nil))
      }
    }
  }

  // MARK: - Saving one document

  /// The folder a document waits in before it is exported.
  private func stagingFolder() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(Self.stagingFolderName, isDirectory: true)
  }

  /// Creates the empty file `createDocument` describes to Dart.
  ///
  /// Nothing is shown yet: iOS's export picker needs the finished file, and the
  /// bytes arrive on the next call. The name is the app's suggestion; the
  /// provider is free to change it when the user saves.
  private func makeStagingFile(named name: String) throws -> URL {
    let folder = stagingFolder()
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let safeName = name.replacingOccurrences(of: "/", with: "_")
    let url = folder.appendingPathComponent(safeName)
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
    guard FileManager.default.createFile(atPath: url.path, contents: Data()) else {
      throw FolderError(code: "io_error", message: "the document could not be prepared")
    }
    return url
  }

  /// The staging file an opaque identifier names.
  ///
  /// The identifier is `staging:` plus the path in base64: opaque to Dart, and
  /// deliberately **not** a bookmark, because this file is in the app's own
  /// temporary directory and needs no security-scoped access. The path is
  /// checked against the staging folder, so a value from Dart cannot name a
  /// file anywhere else.
  private func stagingFile(from raw: String?) throws -> URL {
    let prefix = "staging:"
    guard let raw, raw.hasPrefix(prefix),
          let data = Data(base64Encoded: String(raw.dropFirst(prefix.count))),
          let path = String(data: data, encoding: .utf8) else {
      throw FolderError(code: "bad_uri", message: "no document was named")
    }
    let url = URL(fileURLWithPath: path).standardizedFileURL
    let folder = stagingFolder().standardizedFileURL
    guard url.path.hasPrefix(folder.path + "/") else {
      throw FolderError(code: "bad_uri", message: "the document is not in this app's staging folder")
    }
    return url
  }

  private func identifier(for url: URL) -> String {
    "staging:" + Data(url.path.utf8).base64EncodedString()
  }

  /// What Dart is told about the document.
  private func describeStaging(_ url: URL) -> [String: Any] {
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
    return [
      "uri": identifier(for: url),
      "displayName": url.lastPathComponent,
      "size": size,
    ]
  }

  /// Removes documents left behind by an earlier save.
  ///
  /// A staged file is deleted by the system with the temporary directory, but a
  /// run of saves should not accumulate until then. An hour is far longer than
  /// the two calls a save makes, and far shorter than a session.
  private func purgeStaging() {
    let folder = stagingFolder()
    guard let entries = try? FileManager.default.contentsOfDirectory(
      at: folder,
      includingPropertiesForKeys: [.contentModificationDateKey]
    ) else { return }
    let cutoff = Date().addingTimeInterval(-3600)
    for entry in entries {
      let modified = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate ?? .distantPast
      if modified < cutoff {
        try? FileManager.default.removeItem(at: entry)
      }
    }
  }

  /// Asks the user where the finished document should go.
  ///
  /// `UIDocumentPickerViewController(forExporting:)` copies the staging file
  /// into the provider the user chooses. iOS does not tell an app where an
  /// exported copy went — that is the point of the picker — so the success
  /// answer is the byte count the app wrote, and verification afterwards reads
  /// the staged copy. Nothing is claimed about a destination the app cannot see.
  private func presentExport(
    _ url: URL,
    count: Int,
    result: @escaping FlutterResult
  ) {
    if exportDelegate != nil {
      result(FlutterError(code: "io_error", message: "a save is already open", details: nil))
      return
    }
    guard let presenter = currentPresenter() else {
      result(FlutterError(code: "io_error", message: "could not open the save dialog", details: nil))
      return
    }
    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      // The export flow Apple added in iOS 14: the app hands over a finished
      // file and the provider copies it to wherever the user points.
      picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    } else {
      // iOS 13's only export initialiser. Same delegate, same answer.
      picker = UIDocumentPickerViewController(url: url, in: .exportToService)
    }
    picker.allowsMultipleSelection = false
    let delegate = ExportPickerDelegate { [weak self] exported in
      self?.exportDelegate = nil
      if exported {
        result(count)
      } else {
        // Backing out is an answer, not a crash: Dart reports that nothing was
        // saved rather than claiming a copy exists.
        result(FlutterError(code: "cancelled", message: "the save was cancelled", details: nil))
      }
    }
    picker.delegate = delegate
    exportDelegate = delegate
    presenter.present(picker, animated: true)
  }

  /// The view controller a picker can be presented from.
  private func currentPresenter() -> UIViewController? {
    UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap({ $0.windows })
      .first(where: { $0.isKeyWindow })?
      .rootViewController
  }

  // MARK: - Choosing

  private func presentFolderPicker(_ result: @escaping FlutterResult) {
    // One choice at a time, as on Android: a second picker would take the
    // first one's place, and the first caller would wait for ever.
    if pickerDelegate != nil {
      result(FlutterError(code: "io_error", message: "a folder choice is already open", details: nil))
      return
    }
    guard let presenter = currentPresenter() else {
      // Nothing on screen to present from: answered, rather than left waiting.
      result(FlutterError(code: "io_error", message: "could not open the folder picker", details: nil))
      return
    }
    let types = [UTType.folder]
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
    picker.allowsMultipleSelection = false
    let delegate = FolderPickerDelegate { [weak self] bookmark, name, persisted in
      self?.pickerDelegate = nil
      if let bookmark {
        result(["uri": bookmark, "displayName": name, "persisted": persisted])
      } else {
        result(nil)
      }
    }
    picker.delegate = delegate
    pickerDelegate = delegate
    presenter.present(picker, animated: true)
  }

  // MARK: - Security-scoped access

  /// Turns a bookmark back into a URL.
  private func resolveBookmark(_ raw: String?) throws -> URL {
    guard let raw, let data = Data(base64Encoded: raw) else {
      throw FolderError(code: "bad_uri", message: "no folder was named")
    }
    var stale = false
    return try URL(
      resolvingBookmarkData: data,
      options: [],
      relativeTo: nil,
      bookmarkDataIsStale: &stale
    )
  }

  /// Resolves a bookmark and runs [body] with access to it open.
  ///
  /// Every `startAccessingSecurityScopedResource` is paired with its `stop`.
  /// Access used to be started on every call and never stopped; the system
  /// counts those, and access that is only ever opened is a leak.
  private func withAccess<T>(to raw: String?, _ body: (URL) throws -> T) throws -> T {
    let url = try resolveBookmark(raw)
    guard url.startAccessingSecurityScopedResource() else {
      // The user, or the provider, took the access back.
      throw FolderError(code: "forbidden", message: "access to the folder was revoked")
    }
    defer { url.stopAccessingSecurityScopedResource() }
    return try body(url)
  }

  private func createFolder(in parent: URL, named name: String) throws -> URL {
    let target = parent.appendingPathComponent(name, isDirectory: true)
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory),
       isDirectory.boolValue {
      return target
    }
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
    return target
  }

  /// Writes the document, replacing one of the same name.
  ///
  /// A backup's name is how the user tells its copies apart, so writing the same
  /// name replaces the old file rather than leaving `backup (1).dhimmah` beside
  /// it. An empty payload is refused outright.
  private func write(_ data: Data, into folder: URL, named name: String) throws -> [String: Any] {
    if data.isEmpty {
      throw FolderError(code: "empty_bytes", message: "refusing to write an empty document")
    }
    let target = folder.appendingPathComponent(name)
    // Asked before the write: asked after, it was always true.
    let replacedExisting = FileManager.default.fileExists(atPath: target.path)
    try data.write(to: target, options: [.atomic])
    return [
      "uri": try bookmarkData(for: target),
      "displayName": target.lastPathComponent,
      "size": data.count,
      "bytes": data.count,
      "replacedExisting": replacedExisting,
    ]
  }

  private func list(in folder: URL) throws -> [[String: Any]] {
    let items = try FileManager.default.contentsOfDirectory(
      at: folder, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
    )
    return try items.map { url in
      let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
      return [
        "uri": try bookmarkData(for: url),
        "displayName": url.lastPathComponent,
        "size": values.fileSize ?? 0,
        "lastModified": Int((values.contentModificationDate ?? .distantPast).timeIntervalSince1970 * 1000),
      ]
    }
  }

  /// Writes a probe file, reads it back and takes it away, because a folder that
  /// lists fine can still refuse writes.
  private func verifyWritable(_ folder: URL) throws {
    let payload = Data("dhimmah".utf8)
    let probe = folder.appendingPathComponent(".dhimmah-write-test")
    try payload.write(to: probe, options: [.atomic])
    let readBack = try Data(contentsOf: probe)
    try? FileManager.default.removeItem(at: probe)
    if readBack != payload {
      throw FolderError(code: "io_error", message: "the probe file did not read back")
    }
  }

  private func bookmarkData(for url: URL) throws -> String {
    let data = try url.bookmarkData()
    return data.base64EncodedString()
  }

  /// What the provider says about the folder.
  private func describe(_ url: URL) -> [String: Any] {
    [
      "uri": (try? bookmarkData(for: url)) ?? "",
      "displayName": url.lastPathComponent,
      "persisted": true,
    ]
  }
}

/// One error shape for the channel, matching the Android side's codes.
struct FolderError: Error {
  let code: String
  let message: String?
}

/// Holds the picker's answer until it arrives.
final class FolderPickerDelegate: NSObject, UIDocumentPickerDelegate {
  private let onFinish: (String?, String, Bool) -> Void

  init(onFinish: @escaping (String?, String, Bool) -> Void) {
    self.onFinish = onFinish
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else {
      onFinish(nil, "", true)
      return
    }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let bookmark = try url.bookmarkData().base64EncodedString()
      onFinish(bookmark, url.lastPathComponent, true)
    } catch {
      onFinish(nil, url.lastPathComponent, false)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    onFinish(nil, "", true)
  }
}

/// Holds the export picker's answer until it arrives.
///
/// For an export, iOS calls `didPickDocumentsAt` with the documents it was
/// given, not the destination the user chose — the provider owns the copy from
/// then on. So the only question this delegate can answer is "did the save
/// happen", and that is all it reports.
final class ExportPickerDelegate: NSObject, UIDocumentPickerDelegate {
  private let onFinish: (Bool) -> Void

  init(onFinish: @escaping (Bool) -> Void) {
    self.onFinish = onFinish
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    onFinish(true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    onFinish(false)
  }
}
