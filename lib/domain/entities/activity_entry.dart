import 'package:meta/meta.dart';

import '../../core/money/currency.dart';
import '../enums/activity_enums.dart';
import '../enums/obligation_enums.dart';

/// One line in the "recent activity" feed.
///
/// The entry keeps a *snapshot* of the text and amount rather than pointing only
/// at a live row, so the feed still reads correctly after a debt is deleted or
/// renamed.
@immutable
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.type,
    required this.entityType,
    required this.title,
    required this.occurredAt,
    this.entityId,
    this.amountMinor,
    this.currency,
    this.detail,
  });

  final String id;
  final ActivityType type;
  final RelatedEntityType entityType;

  /// Denormalised label shown in the feed, e.g. a person's name.
  final String title;

  final String? entityId;

  /// Signed amount for money events. Null for structural events such as
  /// "person created".
  final int? amountMinor;

  final AppCurrency? currency;

  /// Free-form extra context, stored as JSON.
  final String? detail;

  final DateTime occurredAt;

  bool get hasAmount => amountMinor != null && currency != null;

  @override
  bool operator ==(Object other) =>
      other is ActivityEntry &&
      other.id == id &&
      other.type == type &&
      other.entityType == entityType &&
      other.title == title &&
      other.entityId == entityId &&
      other.amountMinor == amountMinor &&
      other.currency == currency &&
      other.detail == detail &&
      other.occurredAt == occurredAt;

  @override
  int get hashCode => Object.hash(
        id,
        type,
        entityType,
        title,
        entityId,
        amountMinor,
        currency,
        detail,
        occurredAt,
      );
}
