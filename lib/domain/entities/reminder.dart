import 'package:meta/meta.dart';

import '../enums/obligation_enums.dart';

/// A standalone reminder the user creates directly.
///
/// Reminders attached to a debt or an obligation are generated from that
/// record's own lead times; this entity is for the "just remind me" case, and it
/// can also point at a debt so a reminder shows up on that record's timeline.
@immutable
class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.dueAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.relatedType = RelatedEntityType.none,
    this.relatedId,
    this.notificationId,
    this.completedAt,
  });

  final String id;
  final String title;
  final String? note;

  /// The day the reminder is about. Notification delivery time comes from the
  /// user's notification-time setting, so a reminder stays a date rather than an
  /// instant.
  final DateTime dueAt;

  final RelatedEntityType relatedType;
  final String? relatedId;

  final ReminderStatus status;

  /// Identifier of the scheduled OS notification, so it can be cancelled or
  /// replaced. Null when nothing was scheduled (reminders switched off).
  final int? notificationId;

  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => status == ReminderStatus.completed;

  bool get isOpen => !isCompleted && status != ReminderStatus.dismissed;

  Reminder copyWith({
    String? title,
    Object? note = _unset,
    DateTime? dueAt,
    RelatedEntityType? relatedType,
    Object? relatedId = _unset,
    ReminderStatus? status,
    Object? notificationId = _unset,
    Object? completedAt = _unset,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      note: identical(note, _unset) ? this.note : note as String?,
      dueAt: dueAt ?? this.dueAt,
      relatedType: relatedType ?? this.relatedType,
      relatedId: identical(relatedId, _unset) ? this.relatedId : relatedId as String?,
      status: status ?? this.status,
      notificationId: identical(notificationId, _unset)
          ? this.notificationId
          : notificationId as int?,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.title == title &&
      other.note == note &&
      other.dueAt == dueAt &&
      other.relatedType == relatedType &&
      other.relatedId == relatedId &&
      other.status == status &&
      other.notificationId == notificationId &&
      other.completedAt == completedAt &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        note,
        dueAt,
        relatedType,
        relatedId,
        status,
        notificationId,
        completedAt,
        createdAt,
        updatedAt,
      );
}

const Object _unset = Object();
