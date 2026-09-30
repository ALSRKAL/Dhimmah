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

  // MARK: - Choosing

  private func presentFolderPicker(_ result: @escaping FlutterResult) {
    // One choice at a time, as on Android: a second picker would take the
    // first one's place, and the first caller would wait for ever.
    if pickerDelegate != nil {
      result(FlutterError(code: "io_error", message: "a folder choice is already open", details: nil))
      return
    }
    let presenter = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap({ $0.windows })
      .first(where: { $0.isKeyWindow })?
      .rootViewController
    guard let presenter else {
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
