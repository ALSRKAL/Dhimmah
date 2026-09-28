import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

/// The `.dhimmah` backup format.
///
/// A backup is the whole state of the app in one file: every table, the
/// relationships between them, the settings that are not tied to the device, and
/// the metadata needed to know what the file is and whether it arrived intact.
/// It is deliberately *not* the same thing as an export — an export is for
/// reading, a backup is for coming back to.
///
/// Three properties this file exists to guarantee:
///
/// * **A file says what it is.** `format` and `formatVersion` mean a CSV, a
///   screenshot or another app's JSON is refused rather than half-imported.
/// * **A file can be checked.** `checksum` is a SHA-256 over the canonical
///   payload, so a truncated download or a flipped byte is caught before it
///   reaches the database. It is integrity, *not* confidentiality: a backup is
///   not encrypted, and `encryption` says so in the file itself.
/// * **The same data always produces the same bytes.** Keys are written in a
///   fixed order and lists are sorted by id, so two backups of the same state
///   are byte-identical — which is what makes "has anything changed since the
///   last backup?" answerable without trusting a flag.
abstract final class BackupFormat {
  const BackupFormat._();

  /// The marker every Dhimmah backup carries.
  static const String identifier = 'dhimmah-backup';

  /// The envelope's own shape. Bumped only if the wrapper changes.
  static const int currentFormatVersion = 1;

  /// The tables a backup carries, in the order they must be restored: parents
  /// before children, so a single transaction can insert them straight through.
  static const List<String> tables = <String>[
    'people',
    'debts',
    'debtPeople',
    'payments',
    'obligations',
    'obligationOccurrences',
    'reminders',
    'monthlySummaries',
    'activity',
  ];

  /// The file extension, including the dot.
  static const String extension = '.dhimmah';

  /// What the user is told about the file's privacy, in the file itself.
  ///
  /// A backup is not encrypted: anyone who can open the file can read the
  /// ledger. Saying so here — and in the screen that creates it — is the honest
  /// alternative to a half-built encryption feature whose forgotten password
  /// would lose the data it was meant to protect.
  static const String encryption = 'none';

  /// The most activity entries a backup carries.
  ///
  /// The activity feed is a log, and a log grows without limit; at ten thousand
  /// records it is the largest table by far and the least valuable to restore.
  /// The cap is stated in the file's metadata rather than applied silently.
  static const int activityLimit = 5000;

  /// Builds the payload (everything the checksum covers) from already-serialised
  /// rows.
  ///
  /// The order of [tables] is fixed and every list is sorted by `id`, so the
  /// same state produces the same JSON on any device, in any locale, on any
  /// run — which is what lets a test compare two backups byte for byte.
  static Map<String, Object?> payload({
    required int schemaVersion,
    required Map<String, List<Map<String, Object?>>> tables,
    required Map<String, Object?> settings,
    required Map<String, int> counts,
    Map<String, Object?> truncated = const <String, Object?>{},
  }) {
    // Keys are written in sorted order at both levels, and every row already has
    // its own keys sorted. That is what makes the payload *canonical as built*:
    // the bytes of this map are the bytes the reader hashes, so a writer can
    // encode it once instead of canonicalising a copy of the whole ledger first.
    // The invariant is asserted by test (`payload` encoded == `payload`
    // canonicalised), because it is the one thing the short path depends on.
    return <String, Object?>{
      'counts': _sortedMap(counts.cast<String, Object?>()),
      'data': <String, Object?>{
        for (final String table in _alphabetical(BackupFormat.tables))
          table: _sortedRows(tables[table] ?? const <Map<String, Object?>>[]),
        'settings': _sortedMap(settings),
      },
      'schemaVersion': schemaVersion,
      if (truncated.isNotEmpty) 'truncated': _sortedMap(truncated),
    };
  }

  /// Wraps [payload] in the envelope, with the checksum that covers it.
  ///
  /// This is the reference path: with no [checksum] given it canonicalises the
  /// payload and hashes it, which is what a reader does when it checks a file. A
  /// writer that has already reduced its payload to canonical bytes passes the
  /// digest of *those bytes* (see [canonical]) so the ledger is not encoded a
  /// second time.
  static Map<String, Object?> envelope({
    required Map<String, Object?> payload,
    required String appVersion,
    required DateTime createdAt,
    required String kind,
    String? checksum,
  }) {
    return <String, Object?>{
      'format': identifier,
      'formatVersion': currentFormatVersion,
      'encryption': encryption,
      'appVersion': appVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'kind': kind,
      'checksum': checksum ?? checksumOf(payload),
      'payload': payload,
    };
  }

  /// The whole snapshot in one pass: the payload, its canonical bytes, and the
  /// digest of those bytes.
  ///
  /// [payload] already writes every key sorted and every list ordered, so what it
  /// returns *is* canonical — and canonicalising it again (which [canonical]
  /// does, for a payload whose origin is unknown) would copy the entire ledger a
  /// second time. On the phone that copy was most of the longest remaining stall
  /// in a backup of a large ledger, and it is pure waste: nothing is being
  /// checked that [payload] did not already guarantee.
  ///
  /// The equivalence of this path with the reference one — [payload] plus
  /// [canonical] — is asserted by test, including the digest, because a writer
  /// whose bytes and whose stated checksum came from two different code paths is
  /// exactly how a format rots.
  static CanonicalPayload build({
    required int schemaVersion,
    required Map<String, List<Map<String, Object?>>> tables,
    required Map<String, Object?> settings,
    required Map<String, int> counts,
    Map<String, Object?> truncated = const <String, Object?>{},
  }) {
    final Map<String, Object?> built = payload(
      schemaVersion: schemaVersion,
      tables: tables,
      settings: settings,
      counts: counts,
      truncated: truncated,
    );
    final String text = jsonEncode(built);
    return CanonicalPayload(
      payload: built,
      text: text,
      digest: 'sha256:${crypto.sha256.convert(utf8.encode(text))}',
    );
  }

  /// A payload reduced to its canonical bytes, with the digest of those bytes.
  ///
  /// The two are produced together because a writer needs both and must not
  /// compute them separately: canonicalising a ten-thousand-row ledger and
  /// encoding it is a measurable part of taking a snapshot, and doing it twice
  /// buys nothing.
  static CanonicalPayload canonical(Map<String, Object?> payload) {
    final Map<String, Object?> sorted =
        _canonicalize(payload)! as Map<String, Object?>;
    final String text = jsonEncode(sorted);
    return CanonicalPayload(
      payload: sorted,
      text: text,
      digest: 'sha256:${crypto.sha256.convert(utf8.encode(text))}',
    );
  }

  /// Builds the envelope's text around payload bytes that are already canonical.
  ///
  /// The result carries the same payload as [encode] of the envelope built by
  /// [envelope], with the same digest, and in the canonical key order rather
  /// than the order the payload map happens to be built in — so the two differ
  /// in the *order* of the payload's keys and in nothing else. An object's key
  /// order is not part of what it says, and this layer never treats it as
  /// though it were: the reader decodes, and the checksum covers the canonical
  /// form on both sides. `test/data/backup_hardening_test.dart` asserts the
  /// decoded equality and the digest, rather than a byte equality that was
  /// never true and does not need to be.
  static String wrap({
    required String payloadJson,
    required String checksum,
    required String appVersion,
    required DateTime createdAt,
    required String kind,
  }) {
    // The key order is the order `envelope` writes, and the payload's own bytes
    // are spliced in unchanged rather than re-encoded.
    return '{"format":"$identifier",'
        '"formatVersion":$currentFormatVersion,'
        '"encryption":"$encryption",'
        '"appVersion":${jsonEncode(appVersion)},'
        '"createdAt":${jsonEncode(createdAt.toUtc().toIso8601String())},'
        '"kind":${jsonEncode(kind)},'
        '"checksum":${jsonEncode(checksum)},'
        '"payload":$payloadJson}';
  }

  /// The canonical bytes of a backup: what gets written, hashed and compared.
  ///
  /// Compact, not pretty-printed. An indented file is roughly twice the size and
  /// takes roughly twice as long to write and to validate, and the readability
  /// it buys is already provided by the restore preview, which shows what is in
  /// the file in the user's own language. Size and time here are the difference
  /// between a backup a phone takes unnoticed and one it cannot finish.
  static String encode(Map<String, Object?> envelope) => jsonEncode(envelope);

  /// SHA-256 over the canonical JSON of [payload].
  ///
  /// Canonical means keys sorted at every level and no insignificant
  /// whitespace, so the digest depends on the data and nothing else. Two
  /// different byte sequences that decode to the same payload produce the same
  /// digest, which is what makes the check meaningful after a file has been
  /// through a share sheet, a cloud drive or a copy.
  static String checksumOf(Map<String, Object?> payload) {
    final String canonical = jsonEncode(_canonicalize(payload));
    return 'sha256:${crypto.sha256.convert(utf8.encode(canonical))}';
  }

  /// Parses a file's text.
  ///
  /// Throws a [BackupFormatException] with a reason the UI can act on — never a
  /// raw cast error — so a wrong file, a truncated file and a file from a newer
  /// app are told apart.
  static ParsedBackup parse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const BackupFormatException(BackupProblem.notJson);
    }
    return parseEnvelope(decoded);
  }

  /// Whether text that was read back off the disk is the file that was meant to
  /// be written, and if not, what is wrong with it.
  ///
  /// Returns null when it is. The check is deliberately in three layers, because
  /// each one catches something the others cannot:
  ///
  /// * it must parse, and its own payload must hash to the checksum stored
  ///   *inside it* — so a truncated or altered file is caught on its own terms;
  /// * that checksum must be the one the caller set out to write — so a valid
  ///   file that is not the new snapshot is not mistaken for one;
  /// * the row counts must be the counts that were read from the ledger — so the
  ///   payload is known to carry the records, not merely to be self-consistent.
  ///
  /// A `write` that returned without throwing proves none of this. Being a pure
  /// function on text is what lets every one of those failures be tested
  /// directly, instead of only through a filesystem that would have to be made to
  /// misbehave.
  static BackupProblem? checkReadBack(
    String text, {
    required String expectedDigest,
    required Map<String, int> expectedCounts,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return BackupProblem.notJson;
    }
    final ParsedBackup readBack;
    try {
      readBack = parseEnvelope(decoded);
    } on BackupFormatException catch (error) {
      return error.problem;
    }
    final String? onDisk =
        decoded is Map<String, Object?> ? decoded['checksum'] as String? : null;
    if (onDisk == null || onDisk != expectedDigest) {
      return BackupProblem.checksumMismatch;
    }
    for (final MapEntry<String, int> entry in expectedCounts.entries) {
      if (readBack.counts[entry.key] != entry.value) {
        return BackupProblem.unreadablePayload;
      }
    }
    return null;
  }

  /// The same checks, on an envelope already decoded.
  ///
  /// Used by a writer that still holds the map it just wrote: re-reading and
  /// re-parsing a five-megabyte file to learn what it already knows is work a
  /// save does not need to do.
  static ParsedBackup parseEnvelope(Object? decoded, {bool verifyChecksum = true}) {
    if (decoded is! Map<String, Object?>) {
      throw const BackupFormatException(BackupProblem.notAnObject);
    }

    if (decoded['format'] != identifier) {
      throw const BackupFormatException(BackupProblem.notADhimmahBackup);
    }
    final Object? formatVersion = decoded['formatVersion'];
    if (formatVersion is! int || formatVersion < 1) {
      throw const BackupFormatException(BackupProblem.unreadableEnvelope);
    }
    if (formatVersion > currentFormatVersion) {
      throw BackupFormatException(
        BackupProblem.formatTooNew,
        found: formatVersion,
        supported: currentFormatVersion,
      );
    }

    final Object? payload = decoded['payload'];
    if (payload is! Map<String, Object?>) {
      throw const BackupFormatException(BackupProblem.unreadableEnvelope);
    }
    final Object? schemaVersion = payload['schemaVersion'];
    if (schemaVersion is! int || schemaVersion < 1) {
      throw const BackupFormatException(BackupProblem.unreadablePayload);
    }

    final Object? recorded = decoded['checksum'];
    if (verifyChecksum && recorded is String) {
      final String actual = checksumOf(payload);
      if (recorded != actual) {
        throw const BackupFormatException(BackupProblem.checksumMismatch);
      }
    }

    final Object? data = payload['data'];
    if (data is! Map<String, Object?>) {
      throw const BackupFormatException(BackupProblem.unreadablePayload);
    }

    return ParsedBackup(
      formatVersion: formatVersion,
      schemaVersion: schemaVersion,
      appVersion: decoded['appVersion'] is String
          ? decoded['appVersion']! as String
          : '',
      createdAt: DateTime.tryParse('${decoded['createdAt']}')?.toLocal(),
      kind: decoded['kind'] is String ? decoded['kind']! as String : 'unknown',
      encrypted: decoded['encryption'] != null && decoded['encryption'] != 'none',
      hasChecksum: recorded is String,
      counts: _countsOf(payload['counts']),
      truncated: _mapOf(payload['truncated']),
      data: data,
      settings: data['settings'] is Map<String, Object?>
          ? data['settings']! as Map<String, Object?>
          : const <String, Object?>{},
    );
  }

  static Map<String, int> _countsOf(Object? value) {
    if (value is! Map<String, Object?>) return const <String, int>{};
    return <String, int>{
      for (final MapEntry<String, Object?> entry in value.entries)
        if (entry.value is int) entry.key: entry.value! as int,
    };
  }

  static Map<String, Object?> _mapOf(Object? value) =>
      value is Map<String, Object?> ? value : const <String, Object?>{};

  /// The same names, in the order a canonical JSON object would write them.
  static List<String> _alphabetical(List<String> names) =>
      (List<String>.of(names)..sort());

  /// Rows of one table, sorted by id so the file is deterministic.
  static List<Map<String, Object?>> _sortedRows(
    List<Map<String, Object?>> rows,
  ) {
    final List<Map<String, Object?>> out = <Map<String, Object?>>[
      for (final Map<String, Object?> row in rows) _sortedMap(row),
    ];
    out.sort((Map<String, Object?> a, Map<String, Object?> b) {
      final int byId = '${a['id']}'.compareTo('${b['id']}');
      if (byId != 0) return byId;
      // Two rows can share an id-space only across tables, but a stable
      // tie-break costs nothing and keeps the file byte-identical.
      return jsonEncode(a).compareTo(jsonEncode(b));
    });
    return out;
  }

  static Map<String, Object?> _sortedMap(Map<String, Object?> value) {
    final List<String> keys = value.keys.toList()..sort();
    return <String, Object?>{
      for (final String key in keys) key: _canonicalize(value[key]),
    };
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final List<String> keys = <String>[
        for (final Object? key in value.keys) '$key',
      ]..sort();
      return <String, Object?>{
        for (final String key in keys)
          key: _canonicalize(
            value.containsKey(key) ? value[key] : value[key.toString()],
          ),
      };
    }
    if (value is List) {
      return <Object?>[for (final Object? item in value) _canonicalize(item)];
    }
    return value;
  }
}

/// A payload's canonical bytes, with the digest that covers them.
///
/// Held together because they are always wanted together, and because computing
/// one without the other means encoding the whole ledger twice.
class CanonicalPayload {
  const CanonicalPayload({
    required this.payload,
    required this.text,
    required this.digest,
  });

  /// The payload itself, canonical. Kept here so a writer can build its envelope
  /// from the map it already has rather than decoding the bytes again.
  final Map<String, Object?> payload;

  /// The canonical JSON. This is what goes in the file, byte for byte.
  final String text;

  /// `sha256:<hex>` over [text] — the same digest [BackupFormat.checksumOf]
  /// returns for the same payload.
  final String digest;
}

/// A backup that parsed and whose checksum matched.
class ParsedBackup {
  const ParsedBackup({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.kind,
    required this.encrypted,
    required this.hasChecksum,
    required this.counts,
    required this.truncated,
    required this.data,
    required this.settings,
  });

  final int formatVersion;

  /// The app's database schema version when the file was written. An older one
  /// is migrated on the way in; a newer one is refused.
  final int schemaVersion;

  final String appVersion;
  final DateTime? createdAt;
  final String kind;
  final bool encrypted;

  /// False for a file written before checksums existed; accepted, and reported.
  final bool hasChecksum;

  /// How many rows of each table the file says it holds.
  final Map<String, int> counts;

  /// Tables the writer shortened, and by how much — never silent.
  final Map<String, Object?> truncated;

  final Map<String, Object?> data;
  final Map<String, Object?> settings;

  /// The rows of one table.
  List<Map<String, Object?>> rows(String table) {
    final Object? value = data[table];
    if (value is! List) return const <Map<String, Object?>>[];
    return <Map<String, Object?>>[
      for (final Object? row in value)
        if (row is Map<String, Object?>) row,
    ];
  }

  /// How many rows of each table are actually present, whatever the metadata
  /// claims.
  Map<String, int> get actualCounts => <String, int>{
        for (final String table in BackupFormat.tables) table: rows(table).length,
      };

  /// True when the file's own counts and the rows it carries disagree.
  bool get countsMismatch {
    for (final String table in BackupFormat.tables) {
      if (counts[table] != null && counts[table] != rows(table).length) {
        return true;
      }
    }
    return false;
  }

  String get summary =>
      'dhimmah-backup v$formatVersion · schema $schemaVersion · '
      '${counts.isEmpty ? actualCounts : counts}';
}

/// Why a file could not be read as a backup.
enum BackupProblem {
  notJson,
  notAnObject,
  notADhimmahBackup,
  unreadableEnvelope,
  unreadablePayload,
  checksumMismatch,
  formatTooNew,
  encrypted,
}

/// A refused file, with the reason named.
class BackupFormatException implements Exception {
  const BackupFormatException(this.problem, {this.found, this.supported});

  final BackupProblem problem;
  final int? found;
  final int? supported;

  @override
  String toString() => 'BackupFormatException(${problem.name}'
      '${found == null ? '' : ', found: $found'}'
      '${supported == null ? '' : ', supported: $supported'})';
}
