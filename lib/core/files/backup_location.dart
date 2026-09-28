/// Where the user keeps this app's portable backups.
///
/// One concept for every platform, and the only thing the domain is allowed to
/// know about it: an opaque identifier, the name the user would recognise, and
/// when it was last proven to work. What the identifier *is* — a `content://`
/// tree URI on Android, a security-scoped bookmark on iOS — stays behind the
/// storage layer, because a path that is meaningful on one platform is a
/// coincidence on another.
class BackupLocation {
  const BackupLocation({
    required this.identifier,
    required this.displayName,
    required this.platform,
    required this.verifiedAt,
    this.isPersisted = true,
  });

  /// Opaque. Never parsed, never turned into a path, never shown to the user.
  final String identifier;

  /// What the provider calls this folder — normally `Dhimmah Backups`.
  final String displayName;

  final BackupPlatform platform;

  /// The last time the folder was proven readable and writable.
  ///
  /// A folder that was verified yesterday and never touched since is still
  /// reported with yesterday's date: the app does not claim a check it has not
  /// just done.
  final DateTime? verifiedAt;

  /// Whether the platform granted *standing* access, as opposed to a grant that
  /// dies with this process. On Android this is a persisted URI permission; a
  /// folder without one works now and stops working at the next launch, which
  /// the app says rather than discovering later.
  final bool isPersisted;

  BackupLocation withVerified(DateTime when) => BackupLocation(
        identifier: identifier,
        displayName: displayName,
        platform: platform,
        verifiedAt: when,
        isPersisted: isPersisted,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'identifier': identifier,
        'displayName': displayName,
        'platform': platform.name,
        'verifiedAt': verifiedAt?.millisecondsSinceEpoch,
        'isPersisted': isPersisted,
      };

  static BackupLocation? fromJson(Map<Object?, Object?>? json) {
    if (json == null) return null;
    final Object? identifier = json['identifier'];
    final Object? displayName = json['displayName'];
    if (identifier is! String || identifier.isEmpty) return null;
    if (displayName is! String) return null;
    final Object? platform = json['platform'];
    final Object? verifiedAt = json['verifiedAt'];
    final Object? persisted = json['isPersisted'];
    return BackupLocation(
      identifier: identifier,
      displayName: displayName,
      platform: BackupPlatform.values
          .where((BackupPlatform p) => p.name == platform)
          .firstOrNull ??
          BackupPlatform.android,
      verifiedAt: verifiedAt is int
          ? DateTime.fromMillisecondsSinceEpoch(verifiedAt)
          : null,
      isPersisted: persisted is bool ? persisted : true,
    );
  }
}

enum BackupPlatform { android, ios }

/// Everything the folder can be, in words the interface can show.
///
/// `NOT_CONFIGURED` and `CONFIGURED` are facts about the *setting*; the rest are
/// facts about the *folder right now*. Collapsing them into a boolean would make
/// "no folder chosen" and "the folder was revoked" look like the same thing, and
/// they need opposite answers from the user.
enum BackupLocationStatus {
  /// No folder has ever been chosen.
  notConfigured,

  /// A folder is remembered but has not been checked yet.
  configured,

  /// A check is running.
  verifying,

  /// Readable, writable, and holding valid backups.
  available,

  /// The provider answered, but the folder could not be used.
  unavailable,

  /// The standing grant was taken back by the user or the provider.
  permissionRevoked,

  /// The folder can be read but not written.
  readOnly,

  /// Something went wrong that is none of the above.
  error,
}

/// The result of checking a folder, as evidence rather than as a boolean.
class BackupLocationHealth {
  const BackupLocationHealth({
    required this.status,
    required this.checkedAt,
    this.detail,
    this.validBackups = 0,
    this.invalidFiles = 0,
    this.otherFiles = 0,
    this.newestBackupAt,
  });

  const BackupLocationHealth.notConfigured()
      : this(status: BackupLocationStatus.notConfigured, checkedAt: null);

  final BackupLocationStatus status;
  final DateTime? checkedAt;

  /// A short, user-presentable reason, when the status is not a good one.
  final String? detail;

  /// What the folder actually holds, counted during the check.
  final int validBackups;
  final int invalidFiles;
  final int otherFiles;

  /// When the newest usable copy in the folder was made, read from the file's
  /// own envelope rather than from its modification time — the same reason
  /// validity is decided by content. A file that was copied or restored has a
  /// modification time that says when it was copied, and the question being
  /// answered is when the data was captured.
  ///
  /// Carried so the app can say when the data last reached a file *anywhere*:
  /// the app's own snapshots are not the whole answer on a device that has just
  /// been restored, where the folder holds the only copy there is.
  final DateTime? newestBackupAt;

  bool get isUsable => status == BackupLocationStatus.available;
}

/// One `.dhimmah` file in the user's folder, as the folder describes it.
class ExternalBackupFile {
  const ExternalBackupFile({
    required this.identifier,
    required this.displayName,
    required this.sizeBytes,
    required this.modifiedAt,
    this.validity = ExternalFileValidity.unchecked,
    this.kind,
    this.createdAt,
  });

  /// Opaque document handle; the only way back to the file is through the
  /// repository that produced it.
  final String identifier;
  final String displayName;
  final int sizeBytes;
  final DateTime? modifiedAt;

  /// Set by the reconciliation pass, which reads the content rather than
  /// trusting the name.
  final ExternalFileValidity validity;

  /// Parsed out of the file's own envelope when it is valid.
  final String? kind;
  final DateTime? createdAt;

  ExternalBackupFile withValidity(ExternalFileValidity validity) =>
      ExternalBackupFile(
        identifier: identifier,
        displayName: displayName,
        sizeBytes: sizeBytes,
        modifiedAt: modifiedAt,
        validity: validity,
        kind: kind,
        createdAt: createdAt,
      );

  bool get isValid => validity == ExternalFileValidity.valid;
}

/// What a file in the folder turned out to be, once its content was read.
enum ExternalFileValidity {
  /// Not looked at yet.
  unchecked,

  /// A real Dhimmah backup: envelope, checksum, structure all hold.
  valid,

  /// Named like a backup, not one — or one this build cannot read.
  invalid,

  /// Something else entirely, which the app leaves alone and does not offer.
  unrelated,
}

/// What happened when the user was asked to choose a folder.
class ChosenFolder {
  const ChosenFolder({
    required this.location,
    required this.disposition,
    this.subfolderCreated = false,
  });

  /// The folder to remember.
  final BackupLocation location;

  /// How the folder came to be `Dhimmah Backups`, or whether it could not be.
  final FolderDisposition disposition;

  final bool subfolderCreated;
}

/// How [ChosenFolder] came about.
enum FolderDisposition {
  /// The user picked a parent and the app made `Dhimmah Backups` inside it.
  subfolderCreated,

  /// The user picked a folder that is already called `Dhimmah Backups`.
  alreadyNamed,

  /// The provider would not create a folder, so using what was picked needs the
  /// user's explicit agreement. The app never adopts a folder silently.
  needsConfirmation,
}
