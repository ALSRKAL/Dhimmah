/// The rules a debt's participants must satisfy.
///
/// Kept in the domain beside [AmountRules], and for the same reason: a rule the
/// form enforces and the service does not is a rule a second caller can break.
/// A record with nobody on it and no description is unreadable a week later —
/// the ledger row can say neither who nor what — so the write is refused rather
/// than stored.
abstract final class ParticipantRules {
  const ParticipantRules._();

  /// How many people a single record may name.
  ///
  /// Not a product limit but a guard: every list that shows participants is a
  /// list, and a record with a hundred names on it is a mistyped import rather
  /// than a debt. The ledger, the statement and the notification all interpolate
  /// the names, so the ceiling also keeps a notification title readable.
  static const int maxParticipants = 50;

  /// Whether [personIds] is a set a record may be saved with.
  ///
  /// Empty is not allowed: since people can now be shared between records, a
  /// blank participant list means the user removed everyone, not that they
  /// deliberately recorded a nameless debt.
  static bool isValid(List<String> personIds) =>
      personIds.isNotEmpty &&
      personIds.length <= maxParticipants &&
      personIds.toSet().length == personIds.length;

  /// Removes blanks and repeats while keeping the user's order.
  ///
  /// Used at every boundary — the form, a driver, a restored backup — so the
  /// list stored is the list shown, and a person picked twice is one link.
  static List<String> normalise(Iterable<String> personIds) {
    final List<String> out = <String>[];
    final Set<String> seen = <String>{};
    for (final String id in personIds) {
      if (id.trim().isEmpty) continue;
      if (!seen.add(id)) continue;
      out.add(id);
    }
    return List<String>.unmodifiable(out);
  }
}

/// Thrown when a write is asked to store a debt with no one on it.
class MissingParticipantsException implements Exception {
  const MissingParticipantsException();

  @override
  String toString() =>
      'MissingParticipantsException(a debt must name at least one person)';
}
