import 'package:meta/meta.dart';

/// Someone the user has a financial relationship with.
///
/// A person is just a name and an optional phone number; every amount lives on
/// the debts linked to them, so a person's balance is always derived and can
/// never drift out of sync.
@immutable
class Person {
  const Person({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.note,
    this.archivedAt,
  });

  final String id;
  final String name;

  /// Index into the palette's accent swatches; keeps avatars stable per person.
  final int colorIndex;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String? phone;
  final String? note;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  /// Up to two letters used by the avatar when no image is available.
  String get initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    String firstRune(String word) {
      final int end = word.runes.first > 0xFFFF ? 2 : 1;
      return word.substring(0, end);
    }

    if (parts.length == 1) {
      final String word = parts.first;
      final int first = word.runes.first;
      if (first > 0xFFFF) return word.substring(0, 2);
      return word.length >= 2 ? word.substring(0, 2) : word;
    }
    return '${firstRune(parts.first)}${firstRune(parts[1])}';
  }

  Person copyWith({
    String? name,
    Object? phone = _unset,
    Object? note = _unset,
    int? colorIndex,
    DateTime? updatedAt,
    Object? archivedAt = _unset,
  }) {
    return Person(
      id: id,
      name: name ?? this.name,
      phone: identical(phone, _unset) ? this.phone : phone as String?,
      note: identical(note, _unset) ? this.note : note as String?,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt:
          identical(archivedAt, _unset) ? this.archivedAt : archivedAt as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Person &&
      other.id == id &&
      other.name == name &&
      other.phone == phone &&
      other.note == note &&
      other.colorIndex == colorIndex &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.archivedAt == archivedAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        phone,
        note,
        colorIndex,
        createdAt,
        updatedAt,
        archivedAt,
      );
}

/// Sentinel for "leave this nullable field alone" in `copyWith`.
const Object _unset = Object();
