// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PeopleTable extends People with TableInfo<$PeopleTable, PersonRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeopleTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 160,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($PeopleTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($PeopleTable.$converterupdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> archivedAt =
      GeneratedColumn<int>(
        'archived_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($PeopleTable.$converterarchivedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    note,
    colorIndex,
    createdAt,
    updatedAt,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'people';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      createdAt: $PeopleTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $PeopleTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      archivedAt: $PeopleTable.$converterarchivedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}archived_at'],
        ),
      ),
    );
  }

  @override
  $PeopleTable createAlias(String alias) {
    return $PeopleTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const TimestampConverter();
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const TimestampConverter();
  static TypeConverter<DateTime?, int?> $converterarchivedAt =
      const NullableTimestampConverter();
}

class PersonRow extends DataClass implements Insertable<PersonRow> {
  final String id;
  final String name;
  final String? phone;
  final String? note;
  final int colorIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  const PersonRow({
    required this.id,
    required this.name,
    this.phone,
    this.note,
    required this.colorIndex,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['color_index'] = Variable<int>(colorIndex);
    {
      map['created_at'] = Variable<int>(
        $PeopleTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $PeopleTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<int>(
        $PeopleTable.$converterarchivedAt.toSql(archivedAt),
      );
    }
    return map;
  }

  PeopleCompanion toCompanion(bool nullToAbsent) {
    return PeopleCompanion(
      id: Value(id),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      colorIndex: Value(colorIndex),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
    );
  }

  factory PersonRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      note: serializer.fromJson<String?>(json['note']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'note': serializer.toJson<String?>(note),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
    };
  }

  PersonRow copyWith({
    String? id,
    String? name,
    Value<String?> phone = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? colorIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> archivedAt = const Value.absent(),
  }) => PersonRow(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    note: note.present ? note.value : this.note,
    colorIndex: colorIndex ?? this.colorIndex,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  PersonRow copyWithCompanion(PeopleCompanion data) {
    return PersonRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      note: data.note.present ? data.note.value : this.note,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('note: $note, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

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
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.note == this.note &&
          other.colorIndex == this.colorIndex &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.archivedAt == this.archivedAt);
}

class PeopleCompanion extends UpdateCompanion<PersonRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> note;
  final Value<int> colorIndex;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> archivedAt;
  final Value<int> rowid;
  const PeopleCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.note = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeopleCompanion.insert({
    required String id,
    required String name,
    this.phone = const Value.absent(),
    this.note = const Value.absent(),
    this.colorIndex = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PersonRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? note,
    Expression<int>? colorIndex,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (note != null) 'note': note,
      if (colorIndex != null) 'color_index': colorIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeopleCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? phone,
    Value<String?>? note,
    Value<int>? colorIndex,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? archivedAt,
    Value<int>? rowid,
  }) {
    return PeopleCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $PeopleTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $PeopleTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<int>(
        $PeopleTable.$converterarchivedAt.toSql(archivedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeopleCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('note: $note, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DebtsTable extends Debts with TableInfo<$DebtsTable, DebtRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebtsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people (id) ON DELETE SET NULL',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DebtDirection, String> direction =
      GeneratedColumn<String>(
        'direction',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DebtDirection>($DebtsTable.$converterdirection);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _principalMinorMeta = const VerificationMeta(
    'principalMinor',
  );
  @override
  late final GeneratedColumn<int> principalMinor = GeneratedColumn<int>(
    'principal_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> issuedAt =
      GeneratedColumn<String>(
        'issued_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($DebtsTable.$converterissuedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> dueAt =
      GeneratedColumn<String>(
        'due_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($DebtsTable.$converterdueAt);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<ReminderLead>, String>
  reminderLeads = GeneratedColumn<String>(
    'reminder_leads',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  ).withConverter<List<ReminderLead>>($DebtsTable.$converterreminderLeads);
  @override
  late final GeneratedColumnWithTypeConverter<RecurrenceFrequency, String>
  recurrence = GeneratedColumn<String>(
    'recurrence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<RecurrenceFrequency>($DebtsTable.$converterrecurrence);
  static const VerificationMeta _recurrenceIntervalMeta =
      const VerificationMeta('recurrenceInterval');
  @override
  late final GeneratedColumn<int> recurrenceInterval = GeneratedColumn<int>(
    'recurrence_interval',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String>
  recurrenceEndAt = GeneratedColumn<String>(
    'recurrence_end_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<DateTime?>($DebtsTable.$converterrecurrenceEndAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> closedAt =
      GeneratedColumn<int>(
        'closed_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($DebtsTable.$converterclosedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> archivedAt =
      GeneratedColumn<int>(
        'archived_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($DebtsTable.$converterarchivedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($DebtsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($DebtsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    personId,
    direction,
    title,
    principalMinor,
    currencyCode,
    issuedAt,
    dueAt,
    note,
    reminderLeads,
    recurrence,
    recurrenceInterval,
    recurrenceEndAt,
    closedAt,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DebtRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('principal_minor')) {
      context.handle(
        _principalMinorMeta,
        principalMinor.isAcceptableOrUnknown(
          data['principal_minor']!,
          _principalMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_principalMinorMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('recurrence_interval')) {
      context.handle(
        _recurrenceIntervalMeta,
        recurrenceInterval.isAcceptableOrUnknown(
          data['recurrence_interval']!,
          _recurrenceIntervalMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DebtRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DebtRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      ),
      direction: $DebtsTable.$converterdirection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}direction'],
        )!,
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      principalMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}principal_minor'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      issuedAt: $DebtsTable.$converterissuedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}issued_at'],
        )!,
      ),
      dueAt: $DebtsTable.$converterdueAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}due_at'],
        ),
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      reminderLeads: $DebtsTable.$converterreminderLeads.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}reminder_leads'],
        )!,
      ),
      recurrence: $DebtsTable.$converterrecurrence.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}recurrence'],
        )!,
      ),
      recurrenceInterval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recurrence_interval'],
      )!,
      recurrenceEndAt: $DebtsTable.$converterrecurrenceEndAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}recurrence_end_at'],
        ),
      ),
      closedAt: $DebtsTable.$converterclosedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}closed_at'],
        ),
      ),
      archivedAt: $DebtsTable.$converterarchivedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}archived_at'],
        ),
      ),
      createdAt: $DebtsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $DebtsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $DebtsTable createAlias(String alias) {
    return $DebtsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DebtDirection, String, String> $converterdirection =
      const EnumNameConverter<DebtDirection>(DebtDirection.values);
  static TypeConverter<DateTime, String> $converterissuedAt =
      const DateOnlyConverter();
  static TypeConverter<DateTime?, String?> $converterdueAt =
      const NullableDateOnlyConverter();
  static TypeConverter<List<ReminderLead>, String> $converterreminderLeads =
      const ReminderLeadsConverter();
  static JsonTypeConverter2<RecurrenceFrequency, String, String>
  $converterrecurrence = const EnumNameConverter<RecurrenceFrequency>(
    RecurrenceFrequency.values,
  );
  static TypeConverter<DateTime?, String?> $converterrecurrenceEndAt =
      const NullableDateOnlyConverter();
  static TypeConverter<DateTime?, int?> $converterclosedAt =
      const NullableTimestampConverter();
  static TypeConverter<DateTime?, int?> $converterarchivedAt =
      const NullableTimestampConverter();
  static TypeConverter<DateTime, int> $convertercreatedAt =
      const TimestampConverter();
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const TimestampConverter();
}

class DebtRow extends DataClass implements Insertable<DebtRow> {
  final String id;

  /// The person the user named first, kept as one value.
  ///
  /// [DebtPeople] is the authority on who a debt is with, and this column is a
  /// projection of it: the participant at position 0, or NULL for a record that
  /// names nobody. It survives because it is what payments, notifications, the
  /// statement and the activity feed have always read, and because its foreign
  /// key is what unlinks a debt when the person behind it is deleted. It is
  /// written in exactly one place — the same write that stores the links — and
  /// `debts_dao` refuses to let the two disagree.
  final String? personId;
  final DebtDirection direction;
  final String title;
  final int principalMinor;
  final String currencyCode;
  final DateTime issuedAt;
  final DateTime? dueAt;
  final String? note;
  final List<ReminderLead> reminderLeads;
  final RecurrenceFrequency recurrence;
  final int recurrenceInterval;
  final DateTime? recurrenceEndAt;
  final DateTime? closedAt;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DebtRow({
    required this.id,
    this.personId,
    required this.direction,
    required this.title,
    required this.principalMinor,
    required this.currencyCode,
    required this.issuedAt,
    this.dueAt,
    this.note,
    required this.reminderLeads,
    required this.recurrence,
    required this.recurrenceInterval,
    this.recurrenceEndAt,
    this.closedAt,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || personId != null) {
      map['person_id'] = Variable<String>(personId);
    }
    {
      map['direction'] = Variable<String>(
        $DebtsTable.$converterdirection.toSql(direction),
      );
    }
    map['title'] = Variable<String>(title);
    map['principal_minor'] = Variable<int>(principalMinor);
    map['currency_code'] = Variable<String>(currencyCode);
    {
      map['issued_at'] = Variable<String>(
        $DebtsTable.$converterissuedAt.toSql(issuedAt),
      );
    }
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<String>(
        $DebtsTable.$converterdueAt.toSql(dueAt),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    {
      map['reminder_leads'] = Variable<String>(
        $DebtsTable.$converterreminderLeads.toSql(reminderLeads),
      );
    }
    {
      map['recurrence'] = Variable<String>(
        $DebtsTable.$converterrecurrence.toSql(recurrence),
      );
    }
    map['recurrence_interval'] = Variable<int>(recurrenceInterval);
    if (!nullToAbsent || recurrenceEndAt != null) {
      map['recurrence_end_at'] = Variable<String>(
        $DebtsTable.$converterrecurrenceEndAt.toSql(recurrenceEndAt),
      );
    }
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<int>(
        $DebtsTable.$converterclosedAt.toSql(closedAt),
      );
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<int>(
        $DebtsTable.$converterarchivedAt.toSql(archivedAt),
      );
    }
    {
      map['created_at'] = Variable<int>(
        $DebtsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $DebtsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  DebtsCompanion toCompanion(bool nullToAbsent) {
    return DebtsCompanion(
      id: Value(id),
      personId: personId == null && nullToAbsent
          ? const Value.absent()
          : Value(personId),
      direction: Value(direction),
      title: Value(title),
      principalMinor: Value(principalMinor),
      currencyCode: Value(currencyCode),
      issuedAt: Value(issuedAt),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      reminderLeads: Value(reminderLeads),
      recurrence: Value(recurrence),
      recurrenceInterval: Value(recurrenceInterval),
      recurrenceEndAt: recurrenceEndAt == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceEndAt),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DebtRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DebtRow(
      id: serializer.fromJson<String>(json['id']),
      personId: serializer.fromJson<String?>(json['personId']),
      direction: $DebtsTable.$converterdirection.fromJson(
        serializer.fromJson<String>(json['direction']),
      ),
      title: serializer.fromJson<String>(json['title']),
      principalMinor: serializer.fromJson<int>(json['principalMinor']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      issuedAt: serializer.fromJson<DateTime>(json['issuedAt']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      note: serializer.fromJson<String?>(json['note']),
      reminderLeads: serializer.fromJson<List<ReminderLead>>(
        json['reminderLeads'],
      ),
      recurrence: $DebtsTable.$converterrecurrence.fromJson(
        serializer.fromJson<String>(json['recurrence']),
      ),
      recurrenceInterval: serializer.fromJson<int>(json['recurrenceInterval']),
      recurrenceEndAt: serializer.fromJson<DateTime?>(json['recurrenceEndAt']),
      closedAt: serializer.fromJson<DateTime?>(json['closedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'personId': serializer.toJson<String?>(personId),
      'direction': serializer.toJson<String>(
        $DebtsTable.$converterdirection.toJson(direction),
      ),
      'title': serializer.toJson<String>(title),
      'principalMinor': serializer.toJson<int>(principalMinor),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'issuedAt': serializer.toJson<DateTime>(issuedAt),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'note': serializer.toJson<String?>(note),
      'reminderLeads': serializer.toJson<List<ReminderLead>>(reminderLeads),
      'recurrence': serializer.toJson<String>(
        $DebtsTable.$converterrecurrence.toJson(recurrence),
      ),
      'recurrenceInterval': serializer.toJson<int>(recurrenceInterval),
      'recurrenceEndAt': serializer.toJson<DateTime?>(recurrenceEndAt),
      'closedAt': serializer.toJson<DateTime?>(closedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DebtRow copyWith({
    String? id,
    Value<String?> personId = const Value.absent(),
    DebtDirection? direction,
    String? title,
    int? principalMinor,
    String? currencyCode,
    DateTime? issuedAt,
    Value<DateTime?> dueAt = const Value.absent(),
    Value<String?> note = const Value.absent(),
    List<ReminderLead>? reminderLeads,
    RecurrenceFrequency? recurrence,
    int? recurrenceInterval,
    Value<DateTime?> recurrenceEndAt = const Value.absent(),
    Value<DateTime?> closedAt = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DebtRow(
    id: id ?? this.id,
    personId: personId.present ? personId.value : this.personId,
    direction: direction ?? this.direction,
    title: title ?? this.title,
    principalMinor: principalMinor ?? this.principalMinor,
    currencyCode: currencyCode ?? this.currencyCode,
    issuedAt: issuedAt ?? this.issuedAt,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    note: note.present ? note.value : this.note,
    reminderLeads: reminderLeads ?? this.reminderLeads,
    recurrence: recurrence ?? this.recurrence,
    recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
    recurrenceEndAt: recurrenceEndAt.present
        ? recurrenceEndAt.value
        : this.recurrenceEndAt,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DebtRow copyWithCompanion(DebtsCompanion data) {
    return DebtRow(
      id: data.id.present ? data.id.value : this.id,
      personId: data.personId.present ? data.personId.value : this.personId,
      direction: data.direction.present ? data.direction.value : this.direction,
      title: data.title.present ? data.title.value : this.title,
      principalMinor: data.principalMinor.present
          ? data.principalMinor.value
          : this.principalMinor,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      issuedAt: data.issuedAt.present ? data.issuedAt.value : this.issuedAt,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      note: data.note.present ? data.note.value : this.note,
      reminderLeads: data.reminderLeads.present
          ? data.reminderLeads.value
          : this.reminderLeads,
      recurrence: data.recurrence.present
          ? data.recurrence.value
          : this.recurrence,
      recurrenceInterval: data.recurrenceInterval.present
          ? data.recurrenceInterval.value
          : this.recurrenceInterval,
      recurrenceEndAt: data.recurrenceEndAt.present
          ? data.recurrenceEndAt.value
          : this.recurrenceEndAt,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DebtRow(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('direction: $direction, ')
          ..write('title: $title, ')
          ..write('principalMinor: $principalMinor, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('issuedAt: $issuedAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('note: $note, ')
          ..write('reminderLeads: $reminderLeads, ')
          ..write('recurrence: $recurrence, ')
          ..write('recurrenceInterval: $recurrenceInterval, ')
          ..write('recurrenceEndAt: $recurrenceEndAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    personId,
    direction,
    title,
    principalMinor,
    currencyCode,
    issuedAt,
    dueAt,
    note,
    reminderLeads,
    recurrence,
    recurrenceInterval,
    recurrenceEndAt,
    closedAt,
    archivedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DebtRow &&
          other.id == this.id &&
          other.personId == this.personId &&
          other.direction == this.direction &&
          other.title == this.title &&
          other.principalMinor == this.principalMinor &&
          other.currencyCode == this.currencyCode &&
          other.issuedAt == this.issuedAt &&
          other.dueAt == this.dueAt &&
          other.note == this.note &&
          other.reminderLeads == this.reminderLeads &&
          other.recurrence == this.recurrence &&
          other.recurrenceInterval == this.recurrenceInterval &&
          other.recurrenceEndAt == this.recurrenceEndAt &&
          other.closedAt == this.closedAt &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DebtsCompanion extends UpdateCompanion<DebtRow> {
  final Value<String> id;
  final Value<String?> personId;
  final Value<DebtDirection> direction;
  final Value<String> title;
  final Value<int> principalMinor;
  final Value<String> currencyCode;
  final Value<DateTime> issuedAt;
  final Value<DateTime?> dueAt;
  final Value<String?> note;
  final Value<List<ReminderLead>> reminderLeads;
  final Value<RecurrenceFrequency> recurrence;
  final Value<int> recurrenceInterval;
  final Value<DateTime?> recurrenceEndAt;
  final Value<DateTime?> closedAt;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DebtsCompanion({
    this.id = const Value.absent(),
    this.personId = const Value.absent(),
    this.direction = const Value.absent(),
    this.title = const Value.absent(),
    this.principalMinor = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.issuedAt = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.note = const Value.absent(),
    this.reminderLeads = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.recurrenceInterval = const Value.absent(),
    this.recurrenceEndAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DebtsCompanion.insert({
    required String id,
    this.personId = const Value.absent(),
    required DebtDirection direction,
    this.title = const Value.absent(),
    required int principalMinor,
    required String currencyCode,
    required DateTime issuedAt,
    this.dueAt = const Value.absent(),
    this.note = const Value.absent(),
    this.reminderLeads = const Value.absent(),
    required RecurrenceFrequency recurrence,
    this.recurrenceInterval = const Value.absent(),
    this.recurrenceEndAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       direction = Value(direction),
       principalMinor = Value(principalMinor),
       currencyCode = Value(currencyCode),
       issuedAt = Value(issuedAt),
       recurrence = Value(recurrence),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DebtRow> custom({
    Expression<String>? id,
    Expression<String>? personId,
    Expression<String>? direction,
    Expression<String>? title,
    Expression<int>? principalMinor,
    Expression<String>? currencyCode,
    Expression<String>? issuedAt,
    Expression<String>? dueAt,
    Expression<String>? note,
    Expression<String>? reminderLeads,
    Expression<String>? recurrence,
    Expression<int>? recurrenceInterval,
    Expression<String>? recurrenceEndAt,
    Expression<int>? closedAt,
    Expression<int>? archivedAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personId != null) 'person_id': personId,
      if (direction != null) 'direction': direction,
      if (title != null) 'title': title,
      if (principalMinor != null) 'principal_minor': principalMinor,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (issuedAt != null) 'issued_at': issuedAt,
      if (dueAt != null) 'due_at': dueAt,
      if (note != null) 'note': note,
      if (reminderLeads != null) 'reminder_leads': reminderLeads,
      if (recurrence != null) 'recurrence': recurrence,
      if (recurrenceInterval != null) 'recurrence_interval': recurrenceInterval,
      if (recurrenceEndAt != null) 'recurrence_end_at': recurrenceEndAt,
      if (closedAt != null) 'closed_at': closedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DebtsCompanion copyWith({
    Value<String>? id,
    Value<String?>? personId,
    Value<DebtDirection>? direction,
    Value<String>? title,
    Value<int>? principalMinor,
    Value<String>? currencyCode,
    Value<DateTime>? issuedAt,
    Value<DateTime?>? dueAt,
    Value<String?>? note,
    Value<List<ReminderLead>>? reminderLeads,
    Value<RecurrenceFrequency>? recurrence,
    Value<int>? recurrenceInterval,
    Value<DateTime?>? recurrenceEndAt,
    Value<DateTime?>? closedAt,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DebtsCompanion(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      direction: direction ?? this.direction,
      title: title ?? this.title,
      principalMinor: principalMinor ?? this.principalMinor,
      currencyCode: currencyCode ?? this.currencyCode,
      issuedAt: issuedAt ?? this.issuedAt,
      dueAt: dueAt ?? this.dueAt,
      note: note ?? this.note,
      reminderLeads: reminderLeads ?? this.reminderLeads,
      recurrence: recurrence ?? this.recurrence,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceEndAt: recurrenceEndAt ?? this.recurrenceEndAt,
      closedAt: closedAt ?? this.closedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(
        $DebtsTable.$converterdirection.toSql(direction.value),
      );
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (principalMinor.present) {
      map['principal_minor'] = Variable<int>(principalMinor.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (issuedAt.present) {
      map['issued_at'] = Variable<String>(
        $DebtsTable.$converterissuedAt.toSql(issuedAt.value),
      );
    }
    if (dueAt.present) {
      map['due_at'] = Variable<String>(
        $DebtsTable.$converterdueAt.toSql(dueAt.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (reminderLeads.present) {
      map['reminder_leads'] = Variable<String>(
        $DebtsTable.$converterreminderLeads.toSql(reminderLeads.value),
      );
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(
        $DebtsTable.$converterrecurrence.toSql(recurrence.value),
      );
    }
    if (recurrenceInterval.present) {
      map['recurrence_interval'] = Variable<int>(recurrenceInterval.value);
    }
    if (recurrenceEndAt.present) {
      map['recurrence_end_at'] = Variable<String>(
        $DebtsTable.$converterrecurrenceEndAt.toSql(recurrenceEndAt.value),
      );
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<int>(
        $DebtsTable.$converterclosedAt.toSql(closedAt.value),
      );
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<int>(
        $DebtsTable.$converterarchivedAt.toSql(archivedAt.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $DebtsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $DebtsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DebtsCompanion(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('direction: $direction, ')
          ..write('title: $title, ')
          ..write('principalMinor: $principalMinor, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('issuedAt: $issuedAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('note: $note, ')
          ..write('reminderLeads: $reminderLeads, ')
          ..write('recurrence: $recurrence, ')
          ..write('recurrenceInterval: $recurrenceInterval, ')
          ..write('recurrenceEndAt: $recurrenceEndAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DebtPeopleTable extends DebtPeople
    with TableInfo<$DebtPeopleTable, DebtPersonRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebtPeopleTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _debtIdMeta = const VerificationMeta('debtId');
  @override
  late final GeneratedColumn<String> debtId = GeneratedColumn<String>(
    'debt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES debts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($DebtPeopleTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [debtId, personId, position, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debt_people';
  @override
  VerificationContext validateIntegrity(
    Insertable<DebtPersonRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('debt_id')) {
      context.handle(
        _debtIdMeta,
        debtId.isAcceptableOrUnknown(data['debt_id']!, _debtIdMeta),
      );
    } else if (isInserting) {
      context.missing(_debtIdMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {debtId, personId};
  @override
  DebtPersonRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DebtPersonRow(
      debtId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}debt_id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      createdAt: $DebtPeopleTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $DebtPeopleTable createAlias(String alias) {
    return $DebtPeopleTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const TimestampConverter();
}

class DebtPersonRow extends DataClass implements Insertable<DebtPersonRow> {
  final String debtId;
  final String personId;
  final int position;
  final DateTime createdAt;
  const DebtPersonRow({
    required this.debtId,
    required this.personId,
    required this.position,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['debt_id'] = Variable<String>(debtId);
    map['person_id'] = Variable<String>(personId);
    map['position'] = Variable<int>(position);
    {
      map['created_at'] = Variable<int>(
        $DebtPeopleTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  DebtPeopleCompanion toCompanion(bool nullToAbsent) {
    return DebtPeopleCompanion(
      debtId: Value(debtId),
      personId: Value(personId),
      position: Value(position),
      createdAt: Value(createdAt),
    );
  }

  factory DebtPersonRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DebtPersonRow(
      debtId: serializer.fromJson<String>(json['debtId']),
      personId: serializer.fromJson<String>(json['personId']),
      position: serializer.fromJson<int>(json['position']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'debtId': serializer.toJson<String>(debtId),
      'personId': serializer.toJson<String>(personId),
      'position': serializer.toJson<int>(position),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DebtPersonRow copyWith({
    String? debtId,
    String? personId,
    int? position,
    DateTime? createdAt,
  }) => DebtPersonRow(
    debtId: debtId ?? this.debtId,
    personId: personId ?? this.personId,
    position: position ?? this.position,
    createdAt: createdAt ?? this.createdAt,
  );
  DebtPersonRow copyWithCompanion(DebtPeopleCompanion data) {
    return DebtPersonRow(
      debtId: data.debtId.present ? data.debtId.value : this.debtId,
      personId: data.personId.present ? data.personId.value : this.personId,
      position: data.position.present ? data.position.value : this.position,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DebtPersonRow(')
          ..write('debtId: $debtId, ')
          ..write('personId: $personId, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(debtId, personId, position, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DebtPersonRow &&
          other.debtId == this.debtId &&
          other.personId == this.personId &&
          other.position == this.position &&
          other.createdAt == this.createdAt);
}

class DebtPeopleCompanion extends UpdateCompanion<DebtPersonRow> {
  final Value<String> debtId;
  final Value<String> personId;
  final Value<int> position;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DebtPeopleCompanion({
    this.debtId = const Value.absent(),
    this.personId = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DebtPeopleCompanion.insert({
    required String debtId,
    required String personId,
    this.position = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : debtId = Value(debtId),
       personId = Value(personId),
       createdAt = Value(createdAt);
  static Insertable<DebtPersonRow> custom({
    Expression<String>? debtId,
    Expression<String>? personId,
    Expression<int>? position,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (debtId != null) 'debt_id': debtId,
      if (personId != null) 'person_id': personId,
      if (position != null) 'position': position,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DebtPeopleCompanion copyWith({
    Value<String>? debtId,
    Value<String>? personId,
    Value<int>? position,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return DebtPeopleCompanion(
      debtId: debtId ?? this.debtId,
      personId: personId ?? this.personId,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (debtId.present) {
      map['debt_id'] = Variable<String>(debtId.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $DebtPeopleTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DebtPeopleCompanion(')
          ..write('debtId: $debtId, ')
          ..write('personId: $personId, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PaymentsTable extends Payments
    with TableInfo<$PaymentsTable, PaymentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _debtIdMeta = const VerificationMeta('debtId');
  @override
  late final GeneratedColumn<String> debtId = GeneratedColumn<String>(
    'debt_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES debts (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _obligationIdMeta = const VerificationMeta(
    'obligationId',
  );
  @override
  late final GeneratedColumn<String> obligationId = GeneratedColumn<String>(
    'obligation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurrenceIdMeta = const VerificationMeta(
    'occurrenceId',
  );
  @override
  late final GeneratedColumn<String> occurrenceId = GeneratedColumn<String>(
    'occurrence_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> paidAt =
      GeneratedColumn<String>(
        'paid_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($PaymentsTable.$converterpaidAt);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($PaymentsTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    debtId,
    obligationId,
    occurrenceId,
    personId,
    amountMinor,
    currencyCode,
    paidAt,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<PaymentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('debt_id')) {
      context.handle(
        _debtIdMeta,
        debtId.isAcceptableOrUnknown(data['debt_id']!, _debtIdMeta),
      );
    }
    if (data.containsKey('obligation_id')) {
      context.handle(
        _obligationIdMeta,
        obligationId.isAcceptableOrUnknown(
          data['obligation_id']!,
          _obligationIdMeta,
        ),
      );
    }
    if (data.containsKey('occurrence_id')) {
      context.handle(
        _occurrenceIdMeta,
        occurrenceId.isAcceptableOrUnknown(
          data['occurrence_id']!,
          _occurrenceIdMeta,
        ),
      );
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PaymentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaymentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      debtId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}debt_id'],
      ),
      obligationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}obligation_id'],
      ),
      occurrenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurrence_id'],
      ),
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      ),
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      paidAt: $PaymentsTable.$converterpaidAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}paid_at'],
        )!,
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: $PaymentsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $PaymentsTable createAlias(String alias) {
    return $PaymentsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterpaidAt =
      const DateOnlyConverter();
  static TypeConverter<DateTime, int> $convertercreatedAt =
      const TimestampConverter();
}

class PaymentRow extends DataClass implements Insertable<PaymentRow> {
  final String id;
  final String? debtId;
  final String? obligationId;
  final String? occurrenceId;
  final String? personId;
  final int amountMinor;
  final String currencyCode;
  final DateTime paidAt;
  final String? note;
  final DateTime createdAt;
  const PaymentRow({
    required this.id,
    this.debtId,
    this.obligationId,
    this.occurrenceId,
    this.personId,
    required this.amountMinor,
    required this.currencyCode,
    required this.paidAt,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || debtId != null) {
      map['debt_id'] = Variable<String>(debtId);
    }
    if (!nullToAbsent || obligationId != null) {
      map['obligation_id'] = Variable<String>(obligationId);
    }
    if (!nullToAbsent || occurrenceId != null) {
      map['occurrence_id'] = Variable<String>(occurrenceId);
    }
    if (!nullToAbsent || personId != null) {
      map['person_id'] = Variable<String>(personId);
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency_code'] = Variable<String>(currencyCode);
    {
      map['paid_at'] = Variable<String>(
        $PaymentsTable.$converterpaidAt.toSql(paidAt),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    {
      map['created_at'] = Variable<int>(
        $PaymentsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  PaymentsCompanion toCompanion(bool nullToAbsent) {
    return PaymentsCompanion(
      id: Value(id),
      debtId: debtId == null && nullToAbsent
          ? const Value.absent()
          : Value(debtId),
      obligationId: obligationId == null && nullToAbsent
          ? const Value.absent()
          : Value(obligationId),
      occurrenceId: occurrenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(occurrenceId),
      personId: personId == null && nullToAbsent
          ? const Value.absent()
          : Value(personId),
      amountMinor: Value(amountMinor),
      currencyCode: Value(currencyCode),
      paidAt: Value(paidAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory PaymentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaymentRow(
      id: serializer.fromJson<String>(json['id']),
      debtId: serializer.fromJson<String?>(json['debtId']),
      obligationId: serializer.fromJson<String?>(json['obligationId']),
      occurrenceId: serializer.fromJson<String?>(json['occurrenceId']),
      personId: serializer.fromJson<String?>(json['personId']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      paidAt: serializer.fromJson<DateTime>(json['paidAt']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'debtId': serializer.toJson<String?>(debtId),
      'obligationId': serializer.toJson<String?>(obligationId),
      'occurrenceId': serializer.toJson<String?>(occurrenceId),
      'personId': serializer.toJson<String?>(personId),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'paidAt': serializer.toJson<DateTime>(paidAt),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PaymentRow copyWith({
    String? id,
    Value<String?> debtId = const Value.absent(),
    Value<String?> obligationId = const Value.absent(),
    Value<String?> occurrenceId = const Value.absent(),
    Value<String?> personId = const Value.absent(),
    int? amountMinor,
    String? currencyCode,
    DateTime? paidAt,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
  }) => PaymentRow(
    id: id ?? this.id,
    debtId: debtId.present ? debtId.value : this.debtId,
    obligationId: obligationId.present ? obligationId.value : this.obligationId,
    occurrenceId: occurrenceId.present ? occurrenceId.value : this.occurrenceId,
    personId: personId.present ? personId.value : this.personId,
    amountMinor: amountMinor ?? this.amountMinor,
    currencyCode: currencyCode ?? this.currencyCode,
    paidAt: paidAt ?? this.paidAt,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  PaymentRow copyWithCompanion(PaymentsCompanion data) {
    return PaymentRow(
      id: data.id.present ? data.id.value : this.id,
      debtId: data.debtId.present ? data.debtId.value : this.debtId,
      obligationId: data.obligationId.present
          ? data.obligationId.value
          : this.obligationId,
      occurrenceId: data.occurrenceId.present
          ? data.occurrenceId.value
          : this.occurrenceId,
      personId: data.personId.present ? data.personId.value : this.personId,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaymentRow(')
          ..write('id: $id, ')
          ..write('debtId: $debtId, ')
          ..write('obligationId: $obligationId, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('personId: $personId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('paidAt: $paidAt, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    debtId,
    obligationId,
    occurrenceId,
    personId,
    amountMinor,
    currencyCode,
    paidAt,
    note,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaymentRow &&
          other.id == this.id &&
          other.debtId == this.debtId &&
          other.obligationId == this.obligationId &&
          other.occurrenceId == this.occurrenceId &&
          other.personId == this.personId &&
          other.amountMinor == this.amountMinor &&
          other.currencyCode == this.currencyCode &&
          other.paidAt == this.paidAt &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class PaymentsCompanion extends UpdateCompanion<PaymentRow> {
  final Value<String> id;
  final Value<String?> debtId;
  final Value<String?> obligationId;
  final Value<String?> occurrenceId;
  final Value<String?> personId;
  final Value<int> amountMinor;
  final Value<String> currencyCode;
  final Value<DateTime> paidAt;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PaymentsCompanion({
    this.id = const Value.absent(),
    this.debtId = const Value.absent(),
    this.obligationId = const Value.absent(),
    this.occurrenceId = const Value.absent(),
    this.personId = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaymentsCompanion.insert({
    required String id,
    this.debtId = const Value.absent(),
    this.obligationId = const Value.absent(),
    this.occurrenceId = const Value.absent(),
    this.personId = const Value.absent(),
    required int amountMinor,
    required String currencyCode,
    required DateTime paidAt,
    this.note = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       amountMinor = Value(amountMinor),
       currencyCode = Value(currencyCode),
       paidAt = Value(paidAt),
       createdAt = Value(createdAt);
  static Insertable<PaymentRow> custom({
    Expression<String>? id,
    Expression<String>? debtId,
    Expression<String>? obligationId,
    Expression<String>? occurrenceId,
    Expression<String>? personId,
    Expression<int>? amountMinor,
    Expression<String>? currencyCode,
    Expression<String>? paidAt,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (debtId != null) 'debt_id': debtId,
      if (obligationId != null) 'obligation_id': obligationId,
      if (occurrenceId != null) 'occurrence_id': occurrenceId,
      if (personId != null) 'person_id': personId,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (paidAt != null) 'paid_at': paidAt,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaymentsCompanion copyWith({
    Value<String>? id,
    Value<String?>? debtId,
    Value<String?>? obligationId,
    Value<String?>? occurrenceId,
    Value<String?>? personId,
    Value<int>? amountMinor,
    Value<String>? currencyCode,
    Value<DateTime>? paidAt,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PaymentsCompanion(
      id: id ?? this.id,
      debtId: debtId ?? this.debtId,
      obligationId: obligationId ?? this.obligationId,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      personId: personId ?? this.personId,
      amountMinor: amountMinor ?? this.amountMinor,
      currencyCode: currencyCode ?? this.currencyCode,
      paidAt: paidAt ?? this.paidAt,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (debtId.present) {
      map['debt_id'] = Variable<String>(debtId.value);
    }
    if (obligationId.present) {
      map['obligation_id'] = Variable<String>(obligationId.value);
    }
    if (occurrenceId.present) {
      map['occurrence_id'] = Variable<String>(occurrenceId.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (paidAt.present) {
      map['paid_at'] = Variable<String>(
        $PaymentsTable.$converterpaidAt.toSql(paidAt.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $PaymentsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentsCompanion(')
          ..write('id: $id, ')
          ..write('debtId: $debtId, ')
          ..write('obligationId: $obligationId, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('personId: $personId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('paidAt: $paidAt, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ObligationsTable extends Obligations
    with TableInfo<$ObligationsTable, ObligationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ObligationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 160,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ObligationCategory, String>
  category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ObligationCategory>($ObligationsTable.$convertercategory);
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RecurrenceFrequency, String>
  frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<RecurrenceFrequency>($ObligationsTable.$converterfrequency);
  static const VerificationMeta _intervalCountMeta = const VerificationMeta(
    'intervalCount',
  );
  @override
  late final GeneratedColumn<int> intervalCount = GeneratedColumn<int>(
    'interval_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _dayOfMonthMeta = const VerificationMeta(
    'dayOfMonth',
  );
  @override
  late final GeneratedColumn<int> dayOfMonth = GeneratedColumn<int>(
    'day_of_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> startAt =
      GeneratedColumn<String>(
        'start_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ObligationsTable.$converterstartAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> nextDueAt =
      GeneratedColumn<String>(
        'next_due_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ObligationsTable.$converternextDueAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> endAt =
      GeneratedColumn<String>(
        'end_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($ObligationsTable.$converterendAt);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<ReminderLead>, String>
  reminderLeads =
      GeneratedColumn<String>(
        'reminder_leads',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      ).withConverter<List<ReminderLead>>(
        $ObligationsTable.$converterreminderLeads,
      );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> archivedAt =
      GeneratedColumn<int>(
        'archived_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($ObligationsTable.$converterarchivedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ObligationsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ObligationsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    category,
    amountMinor,
    currencyCode,
    frequency,
    intervalCount,
    dayOfMonth,
    startAt,
    nextDueAt,
    endAt,
    note,
    reminderLeads,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'obligations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ObligationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('interval_count')) {
      context.handle(
        _intervalCountMeta,
        intervalCount.isAcceptableOrUnknown(
          data['interval_count']!,
          _intervalCountMeta,
        ),
      );
    }
    if (data.containsKey('day_of_month')) {
      context.handle(
        _dayOfMonthMeta,
        dayOfMonth.isAcceptableOrUnknown(
          data['day_of_month']!,
          _dayOfMonthMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ObligationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ObligationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: $ObligationsTable.$convertercategory.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}category'],
        )!,
      ),
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      frequency: $ObligationsTable.$converterfrequency.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}frequency'],
        )!,
      ),
      intervalCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_count'],
      )!,
      dayOfMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_month'],
      ),
      startAt: $ObligationsTable.$converterstartAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}start_at'],
        )!,
      ),
      nextDueAt: $ObligationsTable.$converternextDueAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}next_due_at'],
        )!,
      ),
      endAt: $ObligationsTable.$converterendAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}end_at'],
        ),
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      reminderLeads: $ObligationsTable.$converterreminderLeads.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}reminder_leads'],
        )!,
      ),
      archivedAt: $ObligationsTable.$converterarchivedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}archived_at'],
        ),
      ),
      createdAt: $ObligationsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $ObligationsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $ObligationsTable createAlias(String alias) {
    return $ObligationsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ObligationCategory, String, String>
  $convertercategory = const EnumNameConverter<ObligationCategory>(
    ObligationCategory.values,
  );
  static JsonTypeConverter2<RecurrenceFrequency, String, String>
  $converterfrequency = const EnumNameConverter<RecurrenceFrequency>(
    RecurrenceFrequency.values,
  );
  static TypeConverter<DateTime, String> $converterstartAt =
      const DateOnlyConverter();
  static TypeConverter<DateTime, String> $converternextDueAt =
      const DateOnlyConverter();
  static TypeConverter<DateTime?, String?> $converterendAt =
      const NullableDateOnlyConverter();
  static TypeConverter<List<ReminderLead>, String> $converterreminderLeads =
      const ReminderLeadsConverter();
  static TypeConverter<DateTime?, int?> $converterarchivedAt =
      const NullableTimestampConverter();
  static TypeConverter<DateTime, int> $convertercreatedAt =
      const TimestampConverter();
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const TimestampConverter();
}

class ObligationRow extends DataClass implements Insertable<ObligationRow> {
  final String id;
  final String name;
  final ObligationCategory category;
  final int amountMinor;
  final String currencyCode;
  final RecurrenceFrequency frequency;
  final int intervalCount;
  final int? dayOfMonth;
  final DateTime startAt;
  final DateTime nextDueAt;
  final DateTime? endAt;
  final String? note;
  final List<ReminderLead> reminderLeads;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ObligationRow({
    required this.id,
    required this.name,
    required this.category,
    required this.amountMinor,
    required this.currencyCode,
    required this.frequency,
    required this.intervalCount,
    this.dayOfMonth,
    required this.startAt,
    required this.nextDueAt,
    this.endAt,
    this.note,
    required this.reminderLeads,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    {
      map['category'] = Variable<String>(
        $ObligationsTable.$convertercategory.toSql(category),
      );
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency_code'] = Variable<String>(currencyCode);
    {
      map['frequency'] = Variable<String>(
        $ObligationsTable.$converterfrequency.toSql(frequency),
      );
    }
    map['interval_count'] = Variable<int>(intervalCount);
    if (!nullToAbsent || dayOfMonth != null) {
      map['day_of_month'] = Variable<int>(dayOfMonth);
    }
    {
      map['start_at'] = Variable<String>(
        $ObligationsTable.$converterstartAt.toSql(startAt),
      );
    }
    {
      map['next_due_at'] = Variable<String>(
        $ObligationsTable.$converternextDueAt.toSql(nextDueAt),
      );
    }
    if (!nullToAbsent || endAt != null) {
      map['end_at'] = Variable<String>(
        $ObligationsTable.$converterendAt.toSql(endAt),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    {
      map['reminder_leads'] = Variable<String>(
        $ObligationsTable.$converterreminderLeads.toSql(reminderLeads),
      );
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<int>(
        $ObligationsTable.$converterarchivedAt.toSql(archivedAt),
      );
    }
    {
      map['created_at'] = Variable<int>(
        $ObligationsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $ObligationsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  ObligationsCompanion toCompanion(bool nullToAbsent) {
    return ObligationsCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      amountMinor: Value(amountMinor),
      currencyCode: Value(currencyCode),
      frequency: Value(frequency),
      intervalCount: Value(intervalCount),
      dayOfMonth: dayOfMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfMonth),
      startAt: Value(startAt),
      nextDueAt: Value(nextDueAt),
      endAt: endAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      reminderLeads: Value(reminderLeads),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ObligationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ObligationRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: $ObligationsTable.$convertercategory.fromJson(
        serializer.fromJson<String>(json['category']),
      ),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      frequency: $ObligationsTable.$converterfrequency.fromJson(
        serializer.fromJson<String>(json['frequency']),
      ),
      intervalCount: serializer.fromJson<int>(json['intervalCount']),
      dayOfMonth: serializer.fromJson<int?>(json['dayOfMonth']),
      startAt: serializer.fromJson<DateTime>(json['startAt']),
      nextDueAt: serializer.fromJson<DateTime>(json['nextDueAt']),
      endAt: serializer.fromJson<DateTime?>(json['endAt']),
      note: serializer.fromJson<String?>(json['note']),
      reminderLeads: serializer.fromJson<List<ReminderLead>>(
        json['reminderLeads'],
      ),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(
        $ObligationsTable.$convertercategory.toJson(category),
      ),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'frequency': serializer.toJson<String>(
        $ObligationsTable.$converterfrequency.toJson(frequency),
      ),
      'intervalCount': serializer.toJson<int>(intervalCount),
      'dayOfMonth': serializer.toJson<int?>(dayOfMonth),
      'startAt': serializer.toJson<DateTime>(startAt),
      'nextDueAt': serializer.toJson<DateTime>(nextDueAt),
      'endAt': serializer.toJson<DateTime?>(endAt),
      'note': serializer.toJson<String?>(note),
      'reminderLeads': serializer.toJson<List<ReminderLead>>(reminderLeads),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ObligationRow copyWith({
    String? id,
    String? name,
    ObligationCategory? category,
    int? amountMinor,
    String? currencyCode,
    RecurrenceFrequency? frequency,
    int? intervalCount,
    Value<int?> dayOfMonth = const Value.absent(),
    DateTime? startAt,
    DateTime? nextDueAt,
    Value<DateTime?> endAt = const Value.absent(),
    Value<String?> note = const Value.absent(),
    List<ReminderLead>? reminderLeads,
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ObligationRow(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    amountMinor: amountMinor ?? this.amountMinor,
    currencyCode: currencyCode ?? this.currencyCode,
    frequency: frequency ?? this.frequency,
    intervalCount: intervalCount ?? this.intervalCount,
    dayOfMonth: dayOfMonth.present ? dayOfMonth.value : this.dayOfMonth,
    startAt: startAt ?? this.startAt,
    nextDueAt: nextDueAt ?? this.nextDueAt,
    endAt: endAt.present ? endAt.value : this.endAt,
    note: note.present ? note.value : this.note,
    reminderLeads: reminderLeads ?? this.reminderLeads,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ObligationRow copyWithCompanion(ObligationsCompanion data) {
    return ObligationRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      intervalCount: data.intervalCount.present
          ? data.intervalCount.value
          : this.intervalCount,
      dayOfMonth: data.dayOfMonth.present
          ? data.dayOfMonth.value
          : this.dayOfMonth,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      nextDueAt: data.nextDueAt.present ? data.nextDueAt.value : this.nextDueAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      note: data.note.present ? data.note.value : this.note,
      reminderLeads: data.reminderLeads.present
          ? data.reminderLeads.value
          : this.reminderLeads,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ObligationRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('frequency: $frequency, ')
          ..write('intervalCount: $intervalCount, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('startAt: $startAt, ')
          ..write('nextDueAt: $nextDueAt, ')
          ..write('endAt: $endAt, ')
          ..write('note: $note, ')
          ..write('reminderLeads: $reminderLeads, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    amountMinor,
    currencyCode,
    frequency,
    intervalCount,
    dayOfMonth,
    startAt,
    nextDueAt,
    endAt,
    note,
    reminderLeads,
    archivedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ObligationRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.amountMinor == this.amountMinor &&
          other.currencyCode == this.currencyCode &&
          other.frequency == this.frequency &&
          other.intervalCount == this.intervalCount &&
          other.dayOfMonth == this.dayOfMonth &&
          other.startAt == this.startAt &&
          other.nextDueAt == this.nextDueAt &&
          other.endAt == this.endAt &&
          other.note == this.note &&
          other.reminderLeads == this.reminderLeads &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ObligationsCompanion extends UpdateCompanion<ObligationRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<ObligationCategory> category;
  final Value<int> amountMinor;
  final Value<String> currencyCode;
  final Value<RecurrenceFrequency> frequency;
  final Value<int> intervalCount;
  final Value<int?> dayOfMonth;
  final Value<DateTime> startAt;
  final Value<DateTime> nextDueAt;
  final Value<DateTime?> endAt;
  final Value<String?> note;
  final Value<List<ReminderLead>> reminderLeads;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ObligationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.frequency = const Value.absent(),
    this.intervalCount = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.startAt = const Value.absent(),
    this.nextDueAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.note = const Value.absent(),
    this.reminderLeads = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ObligationsCompanion.insert({
    required String id,
    required String name,
    required ObligationCategory category,
    required int amountMinor,
    required String currencyCode,
    required RecurrenceFrequency frequency,
    this.intervalCount = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    required DateTime startAt,
    required DateTime nextDueAt,
    this.endAt = const Value.absent(),
    this.note = const Value.absent(),
    this.reminderLeads = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       category = Value(category),
       amountMinor = Value(amountMinor),
       currencyCode = Value(currencyCode),
       frequency = Value(frequency),
       startAt = Value(startAt),
       nextDueAt = Value(nextDueAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ObligationRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<int>? amountMinor,
    Expression<String>? currencyCode,
    Expression<String>? frequency,
    Expression<int>? intervalCount,
    Expression<int>? dayOfMonth,
    Expression<String>? startAt,
    Expression<String>? nextDueAt,
    Expression<String>? endAt,
    Expression<String>? note,
    Expression<String>? reminderLeads,
    Expression<int>? archivedAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (frequency != null) 'frequency': frequency,
      if (intervalCount != null) 'interval_count': intervalCount,
      if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      if (startAt != null) 'start_at': startAt,
      if (nextDueAt != null) 'next_due_at': nextDueAt,
      if (endAt != null) 'end_at': endAt,
      if (note != null) 'note': note,
      if (reminderLeads != null) 'reminder_leads': reminderLeads,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ObligationsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<ObligationCategory>? category,
    Value<int>? amountMinor,
    Value<String>? currencyCode,
    Value<RecurrenceFrequency>? frequency,
    Value<int>? intervalCount,
    Value<int?>? dayOfMonth,
    Value<DateTime>? startAt,
    Value<DateTime>? nextDueAt,
    Value<DateTime?>? endAt,
    Value<String?>? note,
    Value<List<ReminderLead>>? reminderLeads,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ObligationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      amountMinor: amountMinor ?? this.amountMinor,
      currencyCode: currencyCode ?? this.currencyCode,
      frequency: frequency ?? this.frequency,
      intervalCount: intervalCount ?? this.intervalCount,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      startAt: startAt ?? this.startAt,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      endAt: endAt ?? this.endAt,
      note: note ?? this.note,
      reminderLeads: reminderLeads ?? this.reminderLeads,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(
        $ObligationsTable.$convertercategory.toSql(category.value),
      );
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(
        $ObligationsTable.$converterfrequency.toSql(frequency.value),
      );
    }
    if (intervalCount.present) {
      map['interval_count'] = Variable<int>(intervalCount.value);
    }
    if (dayOfMonth.present) {
      map['day_of_month'] = Variable<int>(dayOfMonth.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<String>(
        $ObligationsTable.$converterstartAt.toSql(startAt.value),
      );
    }
    if (nextDueAt.present) {
      map['next_due_at'] = Variable<String>(
        $ObligationsTable.$converternextDueAt.toSql(nextDueAt.value),
      );
    }
    if (endAt.present) {
      map['end_at'] = Variable<String>(
        $ObligationsTable.$converterendAt.toSql(endAt.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (reminderLeads.present) {
      map['reminder_leads'] = Variable<String>(
        $ObligationsTable.$converterreminderLeads.toSql(reminderLeads.value),
      );
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<int>(
        $ObligationsTable.$converterarchivedAt.toSql(archivedAt.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $ObligationsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $ObligationsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ObligationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('frequency: $frequency, ')
          ..write('intervalCount: $intervalCount, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('startAt: $startAt, ')
          ..write('nextDueAt: $nextDueAt, ')
          ..write('endAt: $endAt, ')
          ..write('note: $note, ')
          ..write('reminderLeads: $reminderLeads, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ObligationOccurrencesTable extends ObligationOccurrences
    with TableInfo<$ObligationOccurrencesTable, ObligationOccurrenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ObligationOccurrencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _obligationIdMeta = const VerificationMeta(
    'obligationId',
  );
  @override
  late final GeneratedColumn<String> obligationId = GeneratedColumn<String>(
    'obligation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES obligations (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _periodKeyMeta = const VerificationMeta(
    'periodKey',
  );
  @override
  late final GeneratedColumn<String> periodKey = GeneratedColumn<String>(
    'period_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> dueAt =
      GeneratedColumn<String>(
        'due_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ObligationOccurrencesTable.$converterdueAt);
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ObligationStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ObligationStatus>(
        $ObligationOccurrencesTable.$converterstatus,
      );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> paidAt =
      GeneratedColumn<String>(
        'paid_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($ObligationOccurrencesTable.$converterpaidAt);
  static const VerificationMeta _paymentIdMeta = const VerificationMeta(
    'paymentId',
  );
  @override
  late final GeneratedColumn<String> paymentId = GeneratedColumn<String>(
    'payment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>(
        $ObligationOccurrencesTable.$convertercreatedAt,
      );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>(
        $ObligationOccurrencesTable.$converterupdatedAt,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    obligationId,
    periodKey,
    dueAt,
    amountMinor,
    status,
    paidAt,
    paymentId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'obligation_occurrences';
  @override
  VerificationContext validateIntegrity(
    Insertable<ObligationOccurrenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('obligation_id')) {
      context.handle(
        _obligationIdMeta,
        obligationId.isAcceptableOrUnknown(
          data['obligation_id']!,
          _obligationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_obligationIdMeta);
    }
    if (data.containsKey('period_key')) {
      context.handle(
        _periodKeyMeta,
        periodKey.isAcceptableOrUnknown(data['period_key']!, _periodKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_periodKeyMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('payment_id')) {
      context.handle(
        _paymentIdMeta,
        paymentId.isAcceptableOrUnknown(data['payment_id']!, _paymentIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ObligationOccurrenceRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ObligationOccurrenceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      obligationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}obligation_id'],
      )!,
      periodKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_key'],
      )!,
      dueAt: $ObligationOccurrencesTable.$converterdueAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}due_at'],
        )!,
      ),
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      status: $ObligationOccurrencesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      paidAt: $ObligationOccurrencesTable.$converterpaidAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}paid_at'],
        ),
      ),
      paymentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_id'],
      ),
      createdAt: $ObligationOccurrencesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $ObligationOccurrencesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $ObligationOccurrencesTable createAlias(String alias) {
    return $ObligationOccurrencesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterdueAt =
      const DateOnlyConverter();
  static JsonTypeConverter2<ObligationStatus, String, String> $converterstatus =
      const EnumNameConverter<ObligationStatus>(ObligationStatus.values);
  static TypeConverter<DateTime?, String?> $converterpaidAt =
      const NullableDateOnlyConverter();
  static TypeConverter<DateTime, int> $convertercreatedAt =
      const TimestampConverter();
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const TimestampConverter();
}

class ObligationOccurrenceRow extends DataClass
    implements Insertable<ObligationOccurrenceRow> {
  final String id;
  final String obligationId;
  final String periodKey;
  final DateTime dueAt;
  final int amountMinor;
  final ObligationStatus status;
  final DateTime? paidAt;
  final String? paymentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ObligationOccurrenceRow({
    required this.id,
    required this.obligationId,
    required this.periodKey,
    required this.dueAt,
    required this.amountMinor,
    required this.status,
    this.paidAt,
    this.paymentId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['obligation_id'] = Variable<String>(obligationId);
    map['period_key'] = Variable<String>(periodKey);
    {
      map['due_at'] = Variable<String>(
        $ObligationOccurrencesTable.$converterdueAt.toSql(dueAt),
      );
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    {
      map['status'] = Variable<String>(
        $ObligationOccurrencesTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || paidAt != null) {
      map['paid_at'] = Variable<String>(
        $ObligationOccurrencesTable.$converterpaidAt.toSql(paidAt),
      );
    }
    if (!nullToAbsent || paymentId != null) {
      map['payment_id'] = Variable<String>(paymentId);
    }
    {
      map['created_at'] = Variable<int>(
        $ObligationOccurrencesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $ObligationOccurrencesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  ObligationOccurrencesCompanion toCompanion(bool nullToAbsent) {
    return ObligationOccurrencesCompanion(
      id: Value(id),
      obligationId: Value(obligationId),
      periodKey: Value(periodKey),
      dueAt: Value(dueAt),
      amountMinor: Value(amountMinor),
      status: Value(status),
      paidAt: paidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(paidAt),
      paymentId: paymentId == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ObligationOccurrenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ObligationOccurrenceRow(
      id: serializer.fromJson<String>(json['id']),
      obligationId: serializer.fromJson<String>(json['obligationId']),
      periodKey: serializer.fromJson<String>(json['periodKey']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      status: $ObligationOccurrencesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      paidAt: serializer.fromJson<DateTime?>(json['paidAt']),
      paymentId: serializer.fromJson<String?>(json['paymentId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'obligationId': serializer.toJson<String>(obligationId),
      'periodKey': serializer.toJson<String>(periodKey),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'status': serializer.toJson<String>(
        $ObligationOccurrencesTable.$converterstatus.toJson(status),
      ),
      'paidAt': serializer.toJson<DateTime?>(paidAt),
      'paymentId': serializer.toJson<String?>(paymentId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ObligationOccurrenceRow copyWith({
    String? id,
    String? obligationId,
    String? periodKey,
    DateTime? dueAt,
    int? amountMinor,
    ObligationStatus? status,
    Value<DateTime?> paidAt = const Value.absent(),
    Value<String?> paymentId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ObligationOccurrenceRow(
    id: id ?? this.id,
    obligationId: obligationId ?? this.obligationId,
    periodKey: periodKey ?? this.periodKey,
    dueAt: dueAt ?? this.dueAt,
    amountMinor: amountMinor ?? this.amountMinor,
    status: status ?? this.status,
    paidAt: paidAt.present ? paidAt.value : this.paidAt,
    paymentId: paymentId.present ? paymentId.value : this.paymentId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ObligationOccurrenceRow copyWithCompanion(
    ObligationOccurrencesCompanion data,
  ) {
    return ObligationOccurrenceRow(
      id: data.id.present ? data.id.value : this.id,
      obligationId: data.obligationId.present
          ? data.obligationId.value
          : this.obligationId,
      periodKey: data.periodKey.present ? data.periodKey.value : this.periodKey,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      status: data.status.present ? data.status.value : this.status,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
      paymentId: data.paymentId.present ? data.paymentId.value : this.paymentId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ObligationOccurrenceRow(')
          ..write('id: $id, ')
          ..write('obligationId: $obligationId, ')
          ..write('periodKey: $periodKey, ')
          ..write('dueAt: $dueAt, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('status: $status, ')
          ..write('paidAt: $paidAt, ')
          ..write('paymentId: $paymentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    obligationId,
    periodKey,
    dueAt,
    amountMinor,
    status,
    paidAt,
    paymentId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ObligationOccurrenceRow &&
          other.id == this.id &&
          other.obligationId == this.obligationId &&
          other.periodKey == this.periodKey &&
          other.dueAt == this.dueAt &&
          other.amountMinor == this.amountMinor &&
          other.status == this.status &&
          other.paidAt == this.paidAt &&
          other.paymentId == this.paymentId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ObligationOccurrencesCompanion
    extends UpdateCompanion<ObligationOccurrenceRow> {
  final Value<String> id;
  final Value<String> obligationId;
  final Value<String> periodKey;
  final Value<DateTime> dueAt;
  final Value<int> amountMinor;
  final Value<ObligationStatus> status;
  final Value<DateTime?> paidAt;
  final Value<String?> paymentId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ObligationOccurrencesCompanion({
    this.id = const Value.absent(),
    this.obligationId = const Value.absent(),
    this.periodKey = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.status = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.paymentId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ObligationOccurrencesCompanion.insert({
    required String id,
    required String obligationId,
    required String periodKey,
    required DateTime dueAt,
    required int amountMinor,
    required ObligationStatus status,
    this.paidAt = const Value.absent(),
    this.paymentId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       obligationId = Value(obligationId),
       periodKey = Value(periodKey),
       dueAt = Value(dueAt),
       amountMinor = Value(amountMinor),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ObligationOccurrenceRow> custom({
    Expression<String>? id,
    Expression<String>? obligationId,
    Expression<String>? periodKey,
    Expression<String>? dueAt,
    Expression<int>? amountMinor,
    Expression<String>? status,
    Expression<String>? paidAt,
    Expression<String>? paymentId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (obligationId != null) 'obligation_id': obligationId,
      if (periodKey != null) 'period_key': periodKey,
      if (dueAt != null) 'due_at': dueAt,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (status != null) 'status': status,
      if (paidAt != null) 'paid_at': paidAt,
      if (paymentId != null) 'payment_id': paymentId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ObligationOccurrencesCompanion copyWith({
    Value<String>? id,
    Value<String>? obligationId,
    Value<String>? periodKey,
    Value<DateTime>? dueAt,
    Value<int>? amountMinor,
    Value<ObligationStatus>? status,
    Value<DateTime?>? paidAt,
    Value<String?>? paymentId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ObligationOccurrencesCompanion(
      id: id ?? this.id,
      obligationId: obligationId ?? this.obligationId,
      periodKey: periodKey ?? this.periodKey,
      dueAt: dueAt ?? this.dueAt,
      amountMinor: amountMinor ?? this.amountMinor,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      paymentId: paymentId ?? this.paymentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (obligationId.present) {
      map['obligation_id'] = Variable<String>(obligationId.value);
    }
    if (periodKey.present) {
      map['period_key'] = Variable<String>(periodKey.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<String>(
        $ObligationOccurrencesTable.$converterdueAt.toSql(dueAt.value),
      );
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $ObligationOccurrencesTable.$converterstatus.toSql(status.value),
      );
    }
    if (paidAt.present) {
      map['paid_at'] = Variable<String>(
        $ObligationOccurrencesTable.$converterpaidAt.toSql(paidAt.value),
      );
    }
    if (paymentId.present) {
      map['payment_id'] = Variable<String>(paymentId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $ObligationOccurrencesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $ObligationOccurrencesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ObligationOccurrencesCompanion(')
          ..write('id: $id, ')
          ..write('obligationId: $obligationId, ')
          ..write('periodKey: $periodKey, ')
          ..write('dueAt: $dueAt, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('status: $status, ')
          ..write('paidAt: $paidAt, ')
          ..write('paymentId: $paymentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, ReminderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> dueAt =
      GeneratedColumn<String>(
        'due_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($RemindersTable.$converterdueAt);
  @override
  late final GeneratedColumnWithTypeConverter<RelatedEntityType, String>
  relatedType = GeneratedColumn<String>(
    'related_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<RelatedEntityType>($RemindersTable.$converterrelatedType);
  static const VerificationMeta _relatedIdMeta = const VerificationMeta(
    'relatedId',
  );
  @override
  late final GeneratedColumn<String> relatedId = GeneratedColumn<String>(
    'related_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReminderStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ReminderStatus>($RemindersTable.$converterstatus);
  static const VerificationMeta _notificationIdMeta = const VerificationMeta(
    'notificationId',
  );
  @override
  late final GeneratedColumn<int> notificationId = GeneratedColumn<int>(
    'notification_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> completedAt =
      GeneratedColumn<int>(
        'completed_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($RemindersTable.$convertercompletedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($RemindersTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($RemindersTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
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
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('related_id')) {
      context.handle(
        _relatedIdMeta,
        relatedId.isAcceptableOrUnknown(data['related_id']!, _relatedIdMeta),
      );
    }
    if (data.containsKey('notification_id')) {
      context.handle(
        _notificationIdMeta,
        notificationId.isAcceptableOrUnknown(
          data['notification_id']!,
          _notificationIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      dueAt: $RemindersTable.$converterdueAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}due_at'],
        )!,
      ),
      relatedType: $RemindersTable.$converterrelatedType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}related_type'],
        )!,
      ),
      relatedId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}related_id'],
      ),
      status: $RemindersTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      notificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_id'],
      ),
      completedAt: $RemindersTable.$convertercompletedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}completed_at'],
        ),
      ),
      createdAt: $RemindersTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $RemindersTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterdueAt =
      const DateOnlyConverter();
  static JsonTypeConverter2<RelatedEntityType, String, String>
  $converterrelatedType = const EnumNameConverter<RelatedEntityType>(
    RelatedEntityType.values,
  );
  static JsonTypeConverter2<ReminderStatus, String, String> $converterstatus =
      const EnumNameConverter<ReminderStatus>(ReminderStatus.values);
  static TypeConverter<DateTime?, int?> $convertercompletedAt =
      const NullableTimestampConverter();
  static TypeConverter<DateTime, int> $convertercreatedAt =
      const TimestampConverter();
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const TimestampConverter();
}

class ReminderRow extends DataClass implements Insertable<ReminderRow> {
  final String id;
  final String title;
  final String? note;
  final DateTime dueAt;
  final RelatedEntityType relatedType;
  final String? relatedId;
  final ReminderStatus status;

  /// Vestigial. The app does not store the platform's notification id: the
  /// records are the source of truth and the pending set is the platform's own
  /// record of what it is holding, compared on every reconciliation. The column
  /// is never written, and dropping it would cost a migration for nothing.
  final int? notificationId;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ReminderRow({
    required this.id,
    required this.title,
    this.note,
    required this.dueAt,
    required this.relatedType,
    this.relatedId,
    required this.status,
    this.notificationId,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    {
      map['due_at'] = Variable<String>(
        $RemindersTable.$converterdueAt.toSql(dueAt),
      );
    }
    {
      map['related_type'] = Variable<String>(
        $RemindersTable.$converterrelatedType.toSql(relatedType),
      );
    }
    if (!nullToAbsent || relatedId != null) {
      map['related_id'] = Variable<String>(relatedId);
    }
    {
      map['status'] = Variable<String>(
        $RemindersTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || notificationId != null) {
      map['notification_id'] = Variable<int>(notificationId);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(
        $RemindersTable.$convertercompletedAt.toSql(completedAt),
      );
    }
    {
      map['created_at'] = Variable<int>(
        $RemindersTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $RemindersTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      title: Value(title),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      dueAt: Value(dueAt),
      relatedType: Value(relatedType),
      relatedId: relatedId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedId),
      status: Value(status),
      notificationId: notificationId == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationId),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReminderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      note: serializer.fromJson<String?>(json['note']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      relatedType: $RemindersTable.$converterrelatedType.fromJson(
        serializer.fromJson<String>(json['relatedType']),
      ),
      relatedId: serializer.fromJson<String?>(json['relatedId']),
      status: $RemindersTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      notificationId: serializer.fromJson<int?>(json['notificationId']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'note': serializer.toJson<String?>(note),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'relatedType': serializer.toJson<String>(
        $RemindersTable.$converterrelatedType.toJson(relatedType),
      ),
      'relatedId': serializer.toJson<String?>(relatedId),
      'status': serializer.toJson<String>(
        $RemindersTable.$converterstatus.toJson(status),
      ),
      'notificationId': serializer.toJson<int?>(notificationId),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReminderRow copyWith({
    String? id,
    String? title,
    Value<String?> note = const Value.absent(),
    DateTime? dueAt,
    RelatedEntityType? relatedType,
    Value<String?> relatedId = const Value.absent(),
    ReminderStatus? status,
    Value<int?> notificationId = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ReminderRow(
    id: id ?? this.id,
    title: title ?? this.title,
    note: note.present ? note.value : this.note,
    dueAt: dueAt ?? this.dueAt,
    relatedType: relatedType ?? this.relatedType,
    relatedId: relatedId.present ? relatedId.value : this.relatedId,
    status: status ?? this.status,
    notificationId: notificationId.present
        ? notificationId.value
        : this.notificationId,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReminderRow copyWithCompanion(RemindersCompanion data) {
    return ReminderRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      note: data.note.present ? data.note.value : this.note,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      relatedType: data.relatedType.present
          ? data.relatedType.value
          : this.relatedType,
      relatedId: data.relatedId.present ? data.relatedId.value : this.relatedId,
      status: data.status.present ? data.status.value : this.status,
      notificationId: data.notificationId.present
          ? data.notificationId.value
          : this.notificationId,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('dueAt: $dueAt, ')
          ..write('relatedType: $relatedType, ')
          ..write('relatedId: $relatedId, ')
          ..write('status: $status, ')
          ..write('notificationId: $notificationId, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

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
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.note == this.note &&
          other.dueAt == this.dueAt &&
          other.relatedType == this.relatedType &&
          other.relatedId == this.relatedId &&
          other.status == this.status &&
          other.notificationId == this.notificationId &&
          other.completedAt == this.completedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RemindersCompanion extends UpdateCompanion<ReminderRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> note;
  final Value<DateTime> dueAt;
  final Value<RelatedEntityType> relatedType;
  final Value<String?> relatedId;
  final Value<ReminderStatus> status;
  final Value<int?> notificationId;
  final Value<DateTime?> completedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.relatedType = const Value.absent(),
    this.relatedId = const Value.absent(),
    this.status = const Value.absent(),
    this.notificationId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String id,
    required String title,
    this.note = const Value.absent(),
    required DateTime dueAt,
    required RelatedEntityType relatedType,
    this.relatedId = const Value.absent(),
    required ReminderStatus status,
    this.notificationId = const Value.absent(),
    this.completedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       dueAt = Value(dueAt),
       relatedType = Value(relatedType),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ReminderRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? note,
    Expression<String>? dueAt,
    Expression<String>? relatedType,
    Expression<String>? relatedId,
    Expression<String>? status,
    Expression<int>? notificationId,
    Expression<int>? completedAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (note != null) 'note': note,
      if (dueAt != null) 'due_at': dueAt,
      if (relatedType != null) 'related_type': relatedType,
      if (relatedId != null) 'related_id': relatedId,
      if (status != null) 'status': status,
      if (notificationId != null) 'notification_id': notificationId,
      if (completedAt != null) 'completed_at': completedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? note,
    Value<DateTime>? dueAt,
    Value<RelatedEntityType>? relatedType,
    Value<String?>? relatedId,
    Value<ReminderStatus>? status,
    Value<int?>? notificationId,
    Value<DateTime?>? completedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      dueAt: dueAt ?? this.dueAt,
      relatedType: relatedType ?? this.relatedType,
      relatedId: relatedId ?? this.relatedId,
      status: status ?? this.status,
      notificationId: notificationId ?? this.notificationId,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<String>(
        $RemindersTable.$converterdueAt.toSql(dueAt.value),
      );
    }
    if (relatedType.present) {
      map['related_type'] = Variable<String>(
        $RemindersTable.$converterrelatedType.toSql(relatedType.value),
      );
    }
    if (relatedId.present) {
      map['related_id'] = Variable<String>(relatedId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $RemindersTable.$converterstatus.toSql(status.value),
      );
    }
    if (notificationId.present) {
      map['notification_id'] = Variable<int>(notificationId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(
        $RemindersTable.$convertercompletedAt.toSql(completedAt.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $RemindersTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $RemindersTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('dueAt: $dueAt, ')
          ..write('relatedType: $relatedType, ')
          ..write('relatedId: $relatedId, ')
          ..write('status: $status, ')
          ..write('notificationId: $notificationId, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActivityEntriesTable extends ActivityEntries
    with TableInfo<$ActivityEntriesTable, ActivityEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ActivityType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ActivityType>($ActivityEntriesTable.$convertertype);
  @override
  late final GeneratedColumnWithTypeConverter<RelatedEntityType, String>
  entityType =
      GeneratedColumn<String>(
        'entity_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RelatedEntityType>(
        $ActivityEntriesTable.$converterentityType,
      );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> occurredAt =
      GeneratedColumn<int>(
        'occurred_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ActivityEntriesTable.$converteroccurredAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    entityType,
    entityId,
    title,
    amountMinor,
    currencyCode,
    detail,
    occurredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: $ActivityEntriesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      entityType: $ActivityEntriesTable.$converterentityType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}entity_type'],
        )!,
      ),
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      ),
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      ),
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      occurredAt: $ActivityEntriesTable.$converteroccurredAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}occurred_at'],
        )!,
      ),
    );
  }

  @override
  $ActivityEntriesTable createAlias(String alias) {
    return $ActivityEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ActivityType, String, String> $convertertype =
      const EnumNameConverter<ActivityType>(ActivityType.values);
  static JsonTypeConverter2<RelatedEntityType, String, String>
  $converterentityType = const EnumNameConverter<RelatedEntityType>(
    RelatedEntityType.values,
  );
  static TypeConverter<DateTime, int> $converteroccurredAt =
      const TimestampConverter();
}

class ActivityEntryRow extends DataClass
    implements Insertable<ActivityEntryRow> {
  final String id;
  final ActivityType type;
  final RelatedEntityType entityType;
  final String? entityId;
  final String title;
  final int? amountMinor;
  final String? currencyCode;
  final String? detail;
  final DateTime occurredAt;
  const ActivityEntryRow({
    required this.id,
    required this.type,
    required this.entityType,
    this.entityId,
    required this.title,
    this.amountMinor,
    this.currencyCode,
    this.detail,
    required this.occurredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['type'] = Variable<String>(
        $ActivityEntriesTable.$convertertype.toSql(type),
      );
    }
    {
      map['entity_type'] = Variable<String>(
        $ActivityEntriesTable.$converterentityType.toSql(entityType),
      );
    }
    if (!nullToAbsent || entityId != null) {
      map['entity_id'] = Variable<String>(entityId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || amountMinor != null) {
      map['amount_minor'] = Variable<int>(amountMinor);
    }
    if (!nullToAbsent || currencyCode != null) {
      map['currency_code'] = Variable<String>(currencyCode);
    }
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    {
      map['occurred_at'] = Variable<int>(
        $ActivityEntriesTable.$converteroccurredAt.toSql(occurredAt),
      );
    }
    return map;
  }

  ActivityEntriesCompanion toCompanion(bool nullToAbsent) {
    return ActivityEntriesCompanion(
      id: Value(id),
      type: Value(type),
      entityType: Value(entityType),
      entityId: entityId == null && nullToAbsent
          ? const Value.absent()
          : Value(entityId),
      title: Value(title),
      amountMinor: amountMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(amountMinor),
      currencyCode: currencyCode == null && nullToAbsent
          ? const Value.absent()
          : Value(currencyCode),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      occurredAt: Value(occurredAt),
    );
  }

  factory ActivityEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityEntryRow(
      id: serializer.fromJson<String>(json['id']),
      type: $ActivityEntriesTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      entityType: $ActivityEntriesTable.$converterentityType.fromJson(
        serializer.fromJson<String>(json['entityType']),
      ),
      entityId: serializer.fromJson<String?>(json['entityId']),
      title: serializer.fromJson<String>(json['title']),
      amountMinor: serializer.fromJson<int?>(json['amountMinor']),
      currencyCode: serializer.fromJson<String?>(json['currencyCode']),
      detail: serializer.fromJson<String?>(json['detail']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(
        $ActivityEntriesTable.$convertertype.toJson(type),
      ),
      'entityType': serializer.toJson<String>(
        $ActivityEntriesTable.$converterentityType.toJson(entityType),
      ),
      'entityId': serializer.toJson<String?>(entityId),
      'title': serializer.toJson<String>(title),
      'amountMinor': serializer.toJson<int?>(amountMinor),
      'currencyCode': serializer.toJson<String?>(currencyCode),
      'detail': serializer.toJson<String?>(detail),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
    };
  }

  ActivityEntryRow copyWith({
    String? id,
    ActivityType? type,
    RelatedEntityType? entityType,
    Value<String?> entityId = const Value.absent(),
    String? title,
    Value<int?> amountMinor = const Value.absent(),
    Value<String?> currencyCode = const Value.absent(),
    Value<String?> detail = const Value.absent(),
    DateTime? occurredAt,
  }) => ActivityEntryRow(
    id: id ?? this.id,
    type: type ?? this.type,
    entityType: entityType ?? this.entityType,
    entityId: entityId.present ? entityId.value : this.entityId,
    title: title ?? this.title,
    amountMinor: amountMinor.present ? amountMinor.value : this.amountMinor,
    currencyCode: currencyCode.present ? currencyCode.value : this.currencyCode,
    detail: detail.present ? detail.value : this.detail,
    occurredAt: occurredAt ?? this.occurredAt,
  );
  ActivityEntryRow copyWithCompanion(ActivityEntriesCompanion data) {
    return ActivityEntryRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      title: data.title.present ? data.title.value : this.title,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      detail: data.detail.present ? data.detail.value : this.detail,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityEntryRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('title: $title, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('detail: $detail, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    entityType,
    entityId,
    title,
    amountMinor,
    currencyCode,
    detail,
    occurredAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityEntryRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.title == this.title &&
          other.amountMinor == this.amountMinor &&
          other.currencyCode == this.currencyCode &&
          other.detail == this.detail &&
          other.occurredAt == this.occurredAt);
}

class ActivityEntriesCompanion extends UpdateCompanion<ActivityEntryRow> {
  final Value<String> id;
  final Value<ActivityType> type;
  final Value<RelatedEntityType> entityType;
  final Value<String?> entityId;
  final Value<String> title;
  final Value<int?> amountMinor;
  final Value<String?> currencyCode;
  final Value<String?> detail;
  final Value<DateTime> occurredAt;
  final Value<int> rowid;
  const ActivityEntriesCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.title = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.detail = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivityEntriesCompanion.insert({
    required String id,
    required ActivityType type,
    required RelatedEntityType entityType,
    this.entityId = const Value.absent(),
    this.title = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.detail = const Value.absent(),
    required DateTime occurredAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       entityType = Value(entityType),
       occurredAt = Value(occurredAt);
  static Insertable<ActivityEntryRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? title,
    Expression<int>? amountMinor,
    Expression<String>? currencyCode,
    Expression<String>? detail,
    Expression<int>? occurredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (title != null) 'title': title,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (detail != null) 'detail': detail,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivityEntriesCompanion copyWith({
    Value<String>? id,
    Value<ActivityType>? type,
    Value<RelatedEntityType>? entityType,
    Value<String?>? entityId,
    Value<String>? title,
    Value<int?>? amountMinor,
    Value<String?>? currencyCode,
    Value<String?>? detail,
    Value<DateTime>? occurredAt,
    Value<int>? rowid,
  }) {
    return ActivityEntriesCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      title: title ?? this.title,
      amountMinor: amountMinor ?? this.amountMinor,
      currencyCode: currencyCode ?? this.currencyCode,
      detail: detail ?? this.detail,
      occurredAt: occurredAt ?? this.occurredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $ActivityEntriesTable.$convertertype.toSql(type.value),
      );
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(
        $ActivityEntriesTable.$converterentityType.toSql(entityType.value),
      );
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(
        $ActivityEntriesTable.$converteroccurredAt.toSql(occurredAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityEntriesCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('title: $title, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('detail: $detail, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MonthlySummariesTable extends MonthlySummaries
    with TableInfo<$MonthlySummariesTable, MonthlySummaryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MonthlySummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<int> month = GeneratedColumn<int>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _newDebtMinorMeta = const VerificationMeta(
    'newDebtMinor',
  );
  @override
  late final GeneratedColumn<int> newDebtMinor = GeneratedColumn<int>(
    'new_debt_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _settledMinorMeta = const VerificationMeta(
    'settledMinor',
  );
  @override
  late final GeneratedColumn<int> settledMinor = GeneratedColumn<int>(
    'settled_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _receivedMinorMeta = const VerificationMeta(
    'receivedMinor',
  );
  @override
  late final GeneratedColumn<int> receivedMinor = GeneratedColumn<int>(
    'received_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _paidOutMinorMeta = const VerificationMeta(
    'paidOutMinor',
  );
  @override
  late final GeneratedColumn<int> paidOutMinor = GeneratedColumn<int>(
    'paid_out_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _obligationsMinorMeta = const VerificationMeta(
    'obligationsMinor',
  );
  @override
  late final GeneratedColumn<int> obligationsMinor = GeneratedColumn<int>(
    'obligations_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _overdueMinorMeta = const VerificationMeta(
    'overdueMinor',
  );
  @override
  late final GeneratedColumn<int> overdueMinor = GeneratedColumn<int>(
    'overdue_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _peopleCountMeta = const VerificationMeta(
    'peopleCount',
  );
  @override
  late final GeneratedColumn<int> peopleCount = GeneratedColumn<int>(
    'people_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _closedDebtsMeta = const VerificationMeta(
    'closedDebts',
  );
  @override
  late final GeneratedColumn<int> closedDebts = GeneratedColumn<int>(
    'closed_debts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _activeDebtsMeta = const VerificationMeta(
    'activeDebts',
  );
  @override
  late final GeneratedColumn<int> activeDebts = GeneratedColumn<int>(
    'active_debts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> generatedAt =
      GeneratedColumn<int>(
        'generated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($MonthlySummariesTable.$convertergeneratedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    year,
    month,
    currencyCode,
    newDebtMinor,
    settledMinor,
    receivedMinor,
    paidOutMinor,
    obligationsMinor,
    overdueMinor,
    peopleCount,
    closedDebts,
    activeDebts,
    generatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'monthly_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MonthlySummaryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('new_debt_minor')) {
      context.handle(
        _newDebtMinorMeta,
        newDebtMinor.isAcceptableOrUnknown(
          data['new_debt_minor']!,
          _newDebtMinorMeta,
        ),
      );
    }
    if (data.containsKey('settled_minor')) {
      context.handle(
        _settledMinorMeta,
        settledMinor.isAcceptableOrUnknown(
          data['settled_minor']!,
          _settledMinorMeta,
        ),
      );
    }
    if (data.containsKey('received_minor')) {
      context.handle(
        _receivedMinorMeta,
        receivedMinor.isAcceptableOrUnknown(
          data['received_minor']!,
          _receivedMinorMeta,
        ),
      );
    }
    if (data.containsKey('paid_out_minor')) {
      context.handle(
        _paidOutMinorMeta,
        paidOutMinor.isAcceptableOrUnknown(
          data['paid_out_minor']!,
          _paidOutMinorMeta,
        ),
      );
    }
    if (data.containsKey('obligations_minor')) {
      context.handle(
        _obligationsMinorMeta,
        obligationsMinor.isAcceptableOrUnknown(
          data['obligations_minor']!,
          _obligationsMinorMeta,
        ),
      );
    }
    if (data.containsKey('overdue_minor')) {
      context.handle(
        _overdueMinorMeta,
        overdueMinor.isAcceptableOrUnknown(
          data['overdue_minor']!,
          _overdueMinorMeta,
        ),
      );
    }
    if (data.containsKey('people_count')) {
      context.handle(
        _peopleCountMeta,
        peopleCount.isAcceptableOrUnknown(
          data['people_count']!,
          _peopleCountMeta,
        ),
      );
    }
    if (data.containsKey('closed_debts')) {
      context.handle(
        _closedDebtsMeta,
        closedDebts.isAcceptableOrUnknown(
          data['closed_debts']!,
          _closedDebtsMeta,
        ),
      );
    }
    if (data.containsKey('active_debts')) {
      context.handle(
        _activeDebtsMeta,
        activeDebts.isAcceptableOrUnknown(
          data['active_debts']!,
          _activeDebtsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MonthlySummaryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MonthlySummaryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      newDebtMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}new_debt_minor'],
      )!,
      settledMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}settled_minor'],
      )!,
      receivedMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}received_minor'],
      )!,
      paidOutMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid_out_minor'],
      )!,
      obligationsMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}obligations_minor'],
      )!,
      overdueMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overdue_minor'],
      )!,
      peopleCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}people_count'],
      )!,
      closedDebts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}closed_debts'],
      )!,
      activeDebts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_debts'],
      )!,
      generatedAt: $MonthlySummariesTable.$convertergeneratedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}generated_at'],
        )!,
      ),
    );
  }

  @override
  $MonthlySummariesTable createAlias(String alias) {
    return $MonthlySummariesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertergeneratedAt =
      const TimestampConverter();
}

class MonthlySummaryRow extends DataClass
    implements Insertable<MonthlySummaryRow> {
  final String id;
  final int year;
  final int month;
  final String currencyCode;
  final int newDebtMinor;
  final int settledMinor;
  final int receivedMinor;
  final int paidOutMinor;
  final int obligationsMinor;
  final int overdueMinor;
  final int peopleCount;
  final int closedDebts;
  final int activeDebts;
  final DateTime generatedAt;
  const MonthlySummaryRow({
    required this.id,
    required this.year,
    required this.month,
    required this.currencyCode,
    required this.newDebtMinor,
    required this.settledMinor,
    required this.receivedMinor,
    required this.paidOutMinor,
    required this.obligationsMinor,
    required this.overdueMinor,
    required this.peopleCount,
    required this.closedDebts,
    required this.activeDebts,
    required this.generatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['year'] = Variable<int>(year);
    map['month'] = Variable<int>(month);
    map['currency_code'] = Variable<String>(currencyCode);
    map['new_debt_minor'] = Variable<int>(newDebtMinor);
    map['settled_minor'] = Variable<int>(settledMinor);
    map['received_minor'] = Variable<int>(receivedMinor);
    map['paid_out_minor'] = Variable<int>(paidOutMinor);
    map['obligations_minor'] = Variable<int>(obligationsMinor);
    map['overdue_minor'] = Variable<int>(overdueMinor);
    map['people_count'] = Variable<int>(peopleCount);
    map['closed_debts'] = Variable<int>(closedDebts);
    map['active_debts'] = Variable<int>(activeDebts);
    {
      map['generated_at'] = Variable<int>(
        $MonthlySummariesTable.$convertergeneratedAt.toSql(generatedAt),
      );
    }
    return map;
  }

  MonthlySummariesCompanion toCompanion(bool nullToAbsent) {
    return MonthlySummariesCompanion(
      id: Value(id),
      year: Value(year),
      month: Value(month),
      currencyCode: Value(currencyCode),
      newDebtMinor: Value(newDebtMinor),
      settledMinor: Value(settledMinor),
      receivedMinor: Value(receivedMinor),
      paidOutMinor: Value(paidOutMinor),
      obligationsMinor: Value(obligationsMinor),
      overdueMinor: Value(overdueMinor),
      peopleCount: Value(peopleCount),
      closedDebts: Value(closedDebts),
      activeDebts: Value(activeDebts),
      generatedAt: Value(generatedAt),
    );
  }

  factory MonthlySummaryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MonthlySummaryRow(
      id: serializer.fromJson<String>(json['id']),
      year: serializer.fromJson<int>(json['year']),
      month: serializer.fromJson<int>(json['month']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      newDebtMinor: serializer.fromJson<int>(json['newDebtMinor']),
      settledMinor: serializer.fromJson<int>(json['settledMinor']),
      receivedMinor: serializer.fromJson<int>(json['receivedMinor']),
      paidOutMinor: serializer.fromJson<int>(json['paidOutMinor']),
      obligationsMinor: serializer.fromJson<int>(json['obligationsMinor']),
      overdueMinor: serializer.fromJson<int>(json['overdueMinor']),
      peopleCount: serializer.fromJson<int>(json['peopleCount']),
      closedDebts: serializer.fromJson<int>(json['closedDebts']),
      activeDebts: serializer.fromJson<int>(json['activeDebts']),
      generatedAt: serializer.fromJson<DateTime>(json['generatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'year': serializer.toJson<int>(year),
      'month': serializer.toJson<int>(month),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'newDebtMinor': serializer.toJson<int>(newDebtMinor),
      'settledMinor': serializer.toJson<int>(settledMinor),
      'receivedMinor': serializer.toJson<int>(receivedMinor),
      'paidOutMinor': serializer.toJson<int>(paidOutMinor),
      'obligationsMinor': serializer.toJson<int>(obligationsMinor),
      'overdueMinor': serializer.toJson<int>(overdueMinor),
      'peopleCount': serializer.toJson<int>(peopleCount),
      'closedDebts': serializer.toJson<int>(closedDebts),
      'activeDebts': serializer.toJson<int>(activeDebts),
      'generatedAt': serializer.toJson<DateTime>(generatedAt),
    };
  }

  MonthlySummaryRow copyWith({
    String? id,
    int? year,
    int? month,
    String? currencyCode,
    int? newDebtMinor,
    int? settledMinor,
    int? receivedMinor,
    int? paidOutMinor,
    int? obligationsMinor,
    int? overdueMinor,
    int? peopleCount,
    int? closedDebts,
    int? activeDebts,
    DateTime? generatedAt,
  }) => MonthlySummaryRow(
    id: id ?? this.id,
    year: year ?? this.year,
    month: month ?? this.month,
    currencyCode: currencyCode ?? this.currencyCode,
    newDebtMinor: newDebtMinor ?? this.newDebtMinor,
    settledMinor: settledMinor ?? this.settledMinor,
    receivedMinor: receivedMinor ?? this.receivedMinor,
    paidOutMinor: paidOutMinor ?? this.paidOutMinor,
    obligationsMinor: obligationsMinor ?? this.obligationsMinor,
    overdueMinor: overdueMinor ?? this.overdueMinor,
    peopleCount: peopleCount ?? this.peopleCount,
    closedDebts: closedDebts ?? this.closedDebts,
    activeDebts: activeDebts ?? this.activeDebts,
    generatedAt: generatedAt ?? this.generatedAt,
  );
  MonthlySummaryRow copyWithCompanion(MonthlySummariesCompanion data) {
    return MonthlySummaryRow(
      id: data.id.present ? data.id.value : this.id,
      year: data.year.present ? data.year.value : this.year,
      month: data.month.present ? data.month.value : this.month,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      newDebtMinor: data.newDebtMinor.present
          ? data.newDebtMinor.value
          : this.newDebtMinor,
      settledMinor: data.settledMinor.present
          ? data.settledMinor.value
          : this.settledMinor,
      receivedMinor: data.receivedMinor.present
          ? data.receivedMinor.value
          : this.receivedMinor,
      paidOutMinor: data.paidOutMinor.present
          ? data.paidOutMinor.value
          : this.paidOutMinor,
      obligationsMinor: data.obligationsMinor.present
          ? data.obligationsMinor.value
          : this.obligationsMinor,
      overdueMinor: data.overdueMinor.present
          ? data.overdueMinor.value
          : this.overdueMinor,
      peopleCount: data.peopleCount.present
          ? data.peopleCount.value
          : this.peopleCount,
      closedDebts: data.closedDebts.present
          ? data.closedDebts.value
          : this.closedDebts,
      activeDebts: data.activeDebts.present
          ? data.activeDebts.value
          : this.activeDebts,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MonthlySummaryRow(')
          ..write('id: $id, ')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('newDebtMinor: $newDebtMinor, ')
          ..write('settledMinor: $settledMinor, ')
          ..write('receivedMinor: $receivedMinor, ')
          ..write('paidOutMinor: $paidOutMinor, ')
          ..write('obligationsMinor: $obligationsMinor, ')
          ..write('overdueMinor: $overdueMinor, ')
          ..write('peopleCount: $peopleCount, ')
          ..write('closedDebts: $closedDebts, ')
          ..write('activeDebts: $activeDebts, ')
          ..write('generatedAt: $generatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    year,
    month,
    currencyCode,
    newDebtMinor,
    settledMinor,
    receivedMinor,
    paidOutMinor,
    obligationsMinor,
    overdueMinor,
    peopleCount,
    closedDebts,
    activeDebts,
    generatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthlySummaryRow &&
          other.id == this.id &&
          other.year == this.year &&
          other.month == this.month &&
          other.currencyCode == this.currencyCode &&
          other.newDebtMinor == this.newDebtMinor &&
          other.settledMinor == this.settledMinor &&
          other.receivedMinor == this.receivedMinor &&
          other.paidOutMinor == this.paidOutMinor &&
          other.obligationsMinor == this.obligationsMinor &&
          other.overdueMinor == this.overdueMinor &&
          other.peopleCount == this.peopleCount &&
          other.closedDebts == this.closedDebts &&
          other.activeDebts == this.activeDebts &&
          other.generatedAt == this.generatedAt);
}

class MonthlySummariesCompanion extends UpdateCompanion<MonthlySummaryRow> {
  final Value<String> id;
  final Value<int> year;
  final Value<int> month;
  final Value<String> currencyCode;
  final Value<int> newDebtMinor;
  final Value<int> settledMinor;
  final Value<int> receivedMinor;
  final Value<int> paidOutMinor;
  final Value<int> obligationsMinor;
  final Value<int> overdueMinor;
  final Value<int> peopleCount;
  final Value<int> closedDebts;
  final Value<int> activeDebts;
  final Value<DateTime> generatedAt;
  final Value<int> rowid;
  const MonthlySummariesCompanion({
    this.id = const Value.absent(),
    this.year = const Value.absent(),
    this.month = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.newDebtMinor = const Value.absent(),
    this.settledMinor = const Value.absent(),
    this.receivedMinor = const Value.absent(),
    this.paidOutMinor = const Value.absent(),
    this.obligationsMinor = const Value.absent(),
    this.overdueMinor = const Value.absent(),
    this.peopleCount = const Value.absent(),
    this.closedDebts = const Value.absent(),
    this.activeDebts = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MonthlySummariesCompanion.insert({
    required String id,
    required int year,
    required int month,
    required String currencyCode,
    this.newDebtMinor = const Value.absent(),
    this.settledMinor = const Value.absent(),
    this.receivedMinor = const Value.absent(),
    this.paidOutMinor = const Value.absent(),
    this.obligationsMinor = const Value.absent(),
    this.overdueMinor = const Value.absent(),
    this.peopleCount = const Value.absent(),
    this.closedDebts = const Value.absent(),
    this.activeDebts = const Value.absent(),
    required DateTime generatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       year = Value(year),
       month = Value(month),
       currencyCode = Value(currencyCode),
       generatedAt = Value(generatedAt);
  static Insertable<MonthlySummaryRow> custom({
    Expression<String>? id,
    Expression<int>? year,
    Expression<int>? month,
    Expression<String>? currencyCode,
    Expression<int>? newDebtMinor,
    Expression<int>? settledMinor,
    Expression<int>? receivedMinor,
    Expression<int>? paidOutMinor,
    Expression<int>? obligationsMinor,
    Expression<int>? overdueMinor,
    Expression<int>? peopleCount,
    Expression<int>? closedDebts,
    Expression<int>? activeDebts,
    Expression<int>? generatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (year != null) 'year': year,
      if (month != null) 'month': month,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (newDebtMinor != null) 'new_debt_minor': newDebtMinor,
      if (settledMinor != null) 'settled_minor': settledMinor,
      if (receivedMinor != null) 'received_minor': receivedMinor,
      if (paidOutMinor != null) 'paid_out_minor': paidOutMinor,
      if (obligationsMinor != null) 'obligations_minor': obligationsMinor,
      if (overdueMinor != null) 'overdue_minor': overdueMinor,
      if (peopleCount != null) 'people_count': peopleCount,
      if (closedDebts != null) 'closed_debts': closedDebts,
      if (activeDebts != null) 'active_debts': activeDebts,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MonthlySummariesCompanion copyWith({
    Value<String>? id,
    Value<int>? year,
    Value<int>? month,
    Value<String>? currencyCode,
    Value<int>? newDebtMinor,
    Value<int>? settledMinor,
    Value<int>? receivedMinor,
    Value<int>? paidOutMinor,
    Value<int>? obligationsMinor,
    Value<int>? overdueMinor,
    Value<int>? peopleCount,
    Value<int>? closedDebts,
    Value<int>? activeDebts,
    Value<DateTime>? generatedAt,
    Value<int>? rowid,
  }) {
    return MonthlySummariesCompanion(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      currencyCode: currencyCode ?? this.currencyCode,
      newDebtMinor: newDebtMinor ?? this.newDebtMinor,
      settledMinor: settledMinor ?? this.settledMinor,
      receivedMinor: receivedMinor ?? this.receivedMinor,
      paidOutMinor: paidOutMinor ?? this.paidOutMinor,
      obligationsMinor: obligationsMinor ?? this.obligationsMinor,
      overdueMinor: overdueMinor ?? this.overdueMinor,
      peopleCount: peopleCount ?? this.peopleCount,
      closedDebts: closedDebts ?? this.closedDebts,
      activeDebts: activeDebts ?? this.activeDebts,
      generatedAt: generatedAt ?? this.generatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (month.present) {
      map['month'] = Variable<int>(month.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (newDebtMinor.present) {
      map['new_debt_minor'] = Variable<int>(newDebtMinor.value);
    }
    if (settledMinor.present) {
      map['settled_minor'] = Variable<int>(settledMinor.value);
    }
    if (receivedMinor.present) {
      map['received_minor'] = Variable<int>(receivedMinor.value);
    }
    if (paidOutMinor.present) {
      map['paid_out_minor'] = Variable<int>(paidOutMinor.value);
    }
    if (obligationsMinor.present) {
      map['obligations_minor'] = Variable<int>(obligationsMinor.value);
    }
    if (overdueMinor.present) {
      map['overdue_minor'] = Variable<int>(overdueMinor.value);
    }
    if (peopleCount.present) {
      map['people_count'] = Variable<int>(peopleCount.value);
    }
    if (closedDebts.present) {
      map['closed_debts'] = Variable<int>(closedDebts.value);
    }
    if (activeDebts.present) {
      map['active_debts'] = Variable<int>(activeDebts.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<int>(
        $MonthlySummariesTable.$convertergeneratedAt.toSql(generatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MonthlySummariesCompanion(')
          ..write('id: $id, ')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('newDebtMinor: $newDebtMinor, ')
          ..write('settledMinor: $settledMinor, ')
          ..write('receivedMinor: $receivedMinor, ')
          ..write('paidOutMinor: $paidOutMinor, ')
          ..write('obligationsMinor: $obligationsMinor, ')
          ..write('overdueMinor: $overdueMinor, ')
          ..write('peopleCount: $peopleCount, ')
          ..write('closedDebts: $closedDebts, ')
          ..write('activeDebts: $activeDebts, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AppLanguage, String> language =
      GeneratedColumn<String>(
        'language',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AppLanguage>($SettingsTable.$converterlanguage);
  @override
  late final GeneratedColumnWithTypeConverter<AppThemeMode, String> themeMode =
      GeneratedColumn<String>(
        'theme_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AppThemeMode>($SettingsTable.$converterthemeMode);
  @override
  late final GeneratedColumnWithTypeConverter<NumeralsStyle, String> numerals =
      GeneratedColumn<String>(
        'numerals',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<NumeralsStyle>($SettingsTable.$converternumerals);
  static const VerificationMeta _defaultCurrencyCodeMeta =
      const VerificationMeta('defaultCurrencyCode');
  @override
  late final GeneratedColumn<String> defaultCurrencyCode =
      GeneratedColumn<String>(
        'default_currency_code',
        aliasedName,
        false,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 3,
          maxTextLength: 3,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _notificationsEnabledMeta =
      const VerificationMeta('notificationsEnabled');
  @override
  late final GeneratedColumn<bool> notificationsEnabled = GeneratedColumn<bool>(
    'notifications_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notifications_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notificationHourMeta = const VerificationMeta(
    'notificationHour',
  );
  @override
  late final GeneratedColumn<int> notificationHour = GeneratedColumn<int>(
    'notification_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(20),
  );
  static const VerificationMeta _notificationMinuteMeta =
      const VerificationMeta('notificationMinute');
  @override
  late final GeneratedColumn<int> notificationMinute = GeneratedColumn<int>(
    'notification_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<ReminderLead>, String>
  defaultReminderLeads =
      GeneratedColumn<String>(
        'default_reminder_leads',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('1'),
      ).withConverter<List<ReminderLead>>(
        $SettingsTable.$converterdefaultReminderLeads,
      );
  static const VerificationMeta _monthEndSummaryEnabledMeta =
      const VerificationMeta('monthEndSummaryEnabled');
  @override
  late final GeneratedColumn<bool> monthEndSummaryEnabled =
      GeneratedColumn<bool>(
        'month_end_summary_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("month_end_summary_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  @override
  late final GeneratedColumnWithTypeConverter<MonthEndDay, String> monthEndDay =
      GeneratedColumn<String>(
        'month_end_day',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MonthEndDay>($SettingsTable.$convertermonthEndDay);
  static const VerificationMeta _monthEndHourMeta = const VerificationMeta(
    'monthEndHour',
  );
  @override
  late final GeneratedColumn<int> monthEndHour = GeneratedColumn<int>(
    'month_end_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(20),
  );
  static const VerificationMeta _monthEndMinuteMeta = const VerificationMeta(
    'monthEndMinute',
  );
  @override
  late final GeneratedColumn<int> monthEndMinute = GeneratedColumn<int>(
    'month_end_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dueSoonWindowDaysMeta = const VerificationMeta(
    'dueSoonWindowDays',
  );
  @override
  late final GeneratedColumn<int> dueSoonWindowDays = GeneratedColumn<int>(
    'due_soon_window_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(7),
  );
  static const VerificationMeta _lockEnabledMeta = const VerificationMeta(
    'lockEnabled',
  );
  @override
  late final GeneratedColumn<bool> lockEnabled = GeneratedColumn<bool>(
    'lock_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("lock_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _biometricEnabledMeta = const VerificationMeta(
    'biometricEnabled',
  );
  @override
  late final GeneratedColumn<bool> biometricEnabled = GeneratedColumn<bool>(
    'biometric_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("biometric_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _onboardingCompletedMeta =
      const VerificationMeta('onboardingCompleted');
  @override
  late final GeneratedColumn<bool> onboardingCompleted = GeneratedColumn<bool>(
    'onboarding_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("onboarding_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _backupAutoEnabledMeta = const VerificationMeta(
    'backupAutoEnabled',
  );
  @override
  late final GeneratedColumn<bool> backupAutoEnabled = GeneratedColumn<bool>(
    'backup_auto_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("backup_auto_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String>
  lastSummarySentOn = GeneratedColumn<String>(
    'last_summary_sent_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<DateTime?>($SettingsTable.$converterlastSummarySentOn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastExportedAt =
      GeneratedColumn<int>(
        'last_exported_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($SettingsTable.$converterlastExportedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    language,
    themeMode,
    numerals,
    defaultCurrencyCode,
    notificationsEnabled,
    notificationHour,
    notificationMinute,
    defaultReminderLeads,
    monthEndSummaryEnabled,
    monthEndDay,
    monthEndHour,
    monthEndMinute,
    dueSoonWindowDays,
    lockEnabled,
    biometricEnabled,
    onboardingCompleted,
    backupAutoEnabled,
    lastSummarySentOn,
    lastExportedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('default_currency_code')) {
      context.handle(
        _defaultCurrencyCodeMeta,
        defaultCurrencyCode.isAcceptableOrUnknown(
          data['default_currency_code']!,
          _defaultCurrencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultCurrencyCodeMeta);
    }
    if (data.containsKey('notifications_enabled')) {
      context.handle(
        _notificationsEnabledMeta,
        notificationsEnabled.isAcceptableOrUnknown(
          data['notifications_enabled']!,
          _notificationsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('notification_hour')) {
      context.handle(
        _notificationHourMeta,
        notificationHour.isAcceptableOrUnknown(
          data['notification_hour']!,
          _notificationHourMeta,
        ),
      );
    }
    if (data.containsKey('notification_minute')) {
      context.handle(
        _notificationMinuteMeta,
        notificationMinute.isAcceptableOrUnknown(
          data['notification_minute']!,
          _notificationMinuteMeta,
        ),
      );
    }
    if (data.containsKey('month_end_summary_enabled')) {
      context.handle(
        _monthEndSummaryEnabledMeta,
        monthEndSummaryEnabled.isAcceptableOrUnknown(
          data['month_end_summary_enabled']!,
          _monthEndSummaryEnabledMeta,
        ),
      );
    }
    if (data.containsKey('month_end_hour')) {
      context.handle(
        _monthEndHourMeta,
        monthEndHour.isAcceptableOrUnknown(
          data['month_end_hour']!,
          _monthEndHourMeta,
        ),
      );
    }
    if (data.containsKey('month_end_minute')) {
      context.handle(
        _monthEndMinuteMeta,
        monthEndMinute.isAcceptableOrUnknown(
          data['month_end_minute']!,
          _monthEndMinuteMeta,
        ),
      );
    }
    if (data.containsKey('due_soon_window_days')) {
      context.handle(
        _dueSoonWindowDaysMeta,
        dueSoonWindowDays.isAcceptableOrUnknown(
          data['due_soon_window_days']!,
          _dueSoonWindowDaysMeta,
        ),
      );
    }
    if (data.containsKey('lock_enabled')) {
      context.handle(
        _lockEnabledMeta,
        lockEnabled.isAcceptableOrUnknown(
          data['lock_enabled']!,
          _lockEnabledMeta,
        ),
      );
    }
    if (data.containsKey('biometric_enabled')) {
      context.handle(
        _biometricEnabledMeta,
        biometricEnabled.isAcceptableOrUnknown(
          data['biometric_enabled']!,
          _biometricEnabledMeta,
        ),
      );
    }
    if (data.containsKey('onboarding_completed')) {
      context.handle(
        _onboardingCompletedMeta,
        onboardingCompleted.isAcceptableOrUnknown(
          data['onboarding_completed']!,
          _onboardingCompletedMeta,
        ),
      );
    }
    if (data.containsKey('backup_auto_enabled')) {
      context.handle(
        _backupAutoEnabledMeta,
        backupAutoEnabled.isAcceptableOrUnknown(
          data['backup_auto_enabled']!,
          _backupAutoEnabledMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      language: $SettingsTable.$converterlanguage.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}language'],
        )!,
      ),
      themeMode: $SettingsTable.$converterthemeMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}theme_mode'],
        )!,
      ),
      numerals: $SettingsTable.$converternumerals.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}numerals'],
        )!,
      ),
      defaultCurrencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_currency_code'],
      )!,
      notificationsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notifications_enabled'],
      )!,
      notificationHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_hour'],
      )!,
      notificationMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_minute'],
      )!,
      defaultReminderLeads: $SettingsTable.$converterdefaultReminderLeads
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}default_reminder_leads'],
            )!,
          ),
      monthEndSummaryEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}month_end_summary_enabled'],
      )!,
      monthEndDay: $SettingsTable.$convertermonthEndDay.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}month_end_day'],
        )!,
      ),
      monthEndHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month_end_hour'],
      )!,
      monthEndMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month_end_minute'],
      )!,
      dueSoonWindowDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_soon_window_days'],
      )!,
      lockEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}lock_enabled'],
      )!,
      biometricEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}biometric_enabled'],
      )!,
      onboardingCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}onboarding_completed'],
      )!,
      backupAutoEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}backup_auto_enabled'],
      )!,
      lastSummarySentOn: $SettingsTable.$converterlastSummarySentOn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}last_summary_sent_on'],
        ),
      ),
      lastExportedAt: $SettingsTable.$converterlastExportedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_exported_at'],
        ),
      ),
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AppLanguage, String, String> $converterlanguage =
      const EnumNameConverter<AppLanguage>(AppLanguage.values);
  static JsonTypeConverter2<AppThemeMode, String, String> $converterthemeMode =
      const EnumNameConverter<AppThemeMode>(AppThemeMode.values);
  static JsonTypeConverter2<NumeralsStyle, String, String> $converternumerals =
      const EnumNameConverter<NumeralsStyle>(NumeralsStyle.values);
  static TypeConverter<List<ReminderLead>, String>
  $converterdefaultReminderLeads = const ReminderLeadsConverter();
  static JsonTypeConverter2<MonthEndDay, String, String> $convertermonthEndDay =
      const EnumNameConverter<MonthEndDay>(MonthEndDay.values);
  static TypeConverter<DateTime?, String?> $converterlastSummarySentOn =
      const NullableDateOnlyConverter();
  static TypeConverter<DateTime?, int?> $converterlastExportedAt =
      const NullableTimestampConverter();
}

class Setting extends DataClass implements Insertable<Setting> {
  final int id;
  final AppLanguage language;
  final AppThemeMode themeMode;
  final NumeralsStyle numerals;
  final String defaultCurrencyCode;
  final bool notificationsEnabled;
  final int notificationHour;
  final int notificationMinute;
  final List<ReminderLead> defaultReminderLeads;
  final bool monthEndSummaryEnabled;
  final MonthEndDay monthEndDay;
  final int monthEndHour;
  final int monthEndMinute;
  final int dueSoonWindowDays;
  final bool lockEnabled;
  final bool biometricEnabled;
  final bool onboardingCompleted;

  /// Whether the app keeps its own snapshots up to date.
  ///
  /// On by default: the point of a safety net is that it is already there the
  /// first time it is needed. Turning it off leaves the manual buttons working.
  final bool backupAutoEnabled;
  final DateTime? lastSummarySentOn;
  final DateTime? lastExportedAt;
  const Setting({
    required this.id,
    required this.language,
    required this.themeMode,
    required this.numerals,
    required this.defaultCurrencyCode,
    required this.notificationsEnabled,
    required this.notificationHour,
    required this.notificationMinute,
    required this.defaultReminderLeads,
    required this.monthEndSummaryEnabled,
    required this.monthEndDay,
    required this.monthEndHour,
    required this.monthEndMinute,
    required this.dueSoonWindowDays,
    required this.lockEnabled,
    required this.biometricEnabled,
    required this.onboardingCompleted,
    required this.backupAutoEnabled,
    this.lastSummarySentOn,
    this.lastExportedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['language'] = Variable<String>(
        $SettingsTable.$converterlanguage.toSql(language),
      );
    }
    {
      map['theme_mode'] = Variable<String>(
        $SettingsTable.$converterthemeMode.toSql(themeMode),
      );
    }
    {
      map['numerals'] = Variable<String>(
        $SettingsTable.$converternumerals.toSql(numerals),
      );
    }
    map['default_currency_code'] = Variable<String>(defaultCurrencyCode);
    map['notifications_enabled'] = Variable<bool>(notificationsEnabled);
    map['notification_hour'] = Variable<int>(notificationHour);
    map['notification_minute'] = Variable<int>(notificationMinute);
    {
      map['default_reminder_leads'] = Variable<String>(
        $SettingsTable.$converterdefaultReminderLeads.toSql(
          defaultReminderLeads,
        ),
      );
    }
    map['month_end_summary_enabled'] = Variable<bool>(monthEndSummaryEnabled);
    {
      map['month_end_day'] = Variable<String>(
        $SettingsTable.$convertermonthEndDay.toSql(monthEndDay),
      );
    }
    map['month_end_hour'] = Variable<int>(monthEndHour);
    map['month_end_minute'] = Variable<int>(monthEndMinute);
    map['due_soon_window_days'] = Variable<int>(dueSoonWindowDays);
    map['lock_enabled'] = Variable<bool>(lockEnabled);
    map['biometric_enabled'] = Variable<bool>(biometricEnabled);
    map['onboarding_completed'] = Variable<bool>(onboardingCompleted);
    map['backup_auto_enabled'] = Variable<bool>(backupAutoEnabled);
    if (!nullToAbsent || lastSummarySentOn != null) {
      map['last_summary_sent_on'] = Variable<String>(
        $SettingsTable.$converterlastSummarySentOn.toSql(lastSummarySentOn),
      );
    }
    if (!nullToAbsent || lastExportedAt != null) {
      map['last_exported_at'] = Variable<int>(
        $SettingsTable.$converterlastExportedAt.toSql(lastExportedAt),
      );
    }
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      language: Value(language),
      themeMode: Value(themeMode),
      numerals: Value(numerals),
      defaultCurrencyCode: Value(defaultCurrencyCode),
      notificationsEnabled: Value(notificationsEnabled),
      notificationHour: Value(notificationHour),
      notificationMinute: Value(notificationMinute),
      defaultReminderLeads: Value(defaultReminderLeads),
      monthEndSummaryEnabled: Value(monthEndSummaryEnabled),
      monthEndDay: Value(monthEndDay),
      monthEndHour: Value(monthEndHour),
      monthEndMinute: Value(monthEndMinute),
      dueSoonWindowDays: Value(dueSoonWindowDays),
      lockEnabled: Value(lockEnabled),
      biometricEnabled: Value(biometricEnabled),
      onboardingCompleted: Value(onboardingCompleted),
      backupAutoEnabled: Value(backupAutoEnabled),
      lastSummarySentOn: lastSummarySentOn == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSummarySentOn),
      lastExportedAt: lastExportedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastExportedAt),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      id: serializer.fromJson<int>(json['id']),
      language: $SettingsTable.$converterlanguage.fromJson(
        serializer.fromJson<String>(json['language']),
      ),
      themeMode: $SettingsTable.$converterthemeMode.fromJson(
        serializer.fromJson<String>(json['themeMode']),
      ),
      numerals: $SettingsTable.$converternumerals.fromJson(
        serializer.fromJson<String>(json['numerals']),
      ),
      defaultCurrencyCode: serializer.fromJson<String>(
        json['defaultCurrencyCode'],
      ),
      notificationsEnabled: serializer.fromJson<bool>(
        json['notificationsEnabled'],
      ),
      notificationHour: serializer.fromJson<int>(json['notificationHour']),
      notificationMinute: serializer.fromJson<int>(json['notificationMinute']),
      defaultReminderLeads: serializer.fromJson<List<ReminderLead>>(
        json['defaultReminderLeads'],
      ),
      monthEndSummaryEnabled: serializer.fromJson<bool>(
        json['monthEndSummaryEnabled'],
      ),
      monthEndDay: $SettingsTable.$convertermonthEndDay.fromJson(
        serializer.fromJson<String>(json['monthEndDay']),
      ),
      monthEndHour: serializer.fromJson<int>(json['monthEndHour']),
      monthEndMinute: serializer.fromJson<int>(json['monthEndMinute']),
      dueSoonWindowDays: serializer.fromJson<int>(json['dueSoonWindowDays']),
      lockEnabled: serializer.fromJson<bool>(json['lockEnabled']),
      biometricEnabled: serializer.fromJson<bool>(json['biometricEnabled']),
      onboardingCompleted: serializer.fromJson<bool>(
        json['onboardingCompleted'],
      ),
      backupAutoEnabled: serializer.fromJson<bool>(json['backupAutoEnabled']),
      lastSummarySentOn: serializer.fromJson<DateTime?>(
        json['lastSummarySentOn'],
      ),
      lastExportedAt: serializer.fromJson<DateTime?>(json['lastExportedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'language': serializer.toJson<String>(
        $SettingsTable.$converterlanguage.toJson(language),
      ),
      'themeMode': serializer.toJson<String>(
        $SettingsTable.$converterthemeMode.toJson(themeMode),
      ),
      'numerals': serializer.toJson<String>(
        $SettingsTable.$converternumerals.toJson(numerals),
      ),
      'defaultCurrencyCode': serializer.toJson<String>(defaultCurrencyCode),
      'notificationsEnabled': serializer.toJson<bool>(notificationsEnabled),
      'notificationHour': serializer.toJson<int>(notificationHour),
      'notificationMinute': serializer.toJson<int>(notificationMinute),
      'defaultReminderLeads': serializer.toJson<List<ReminderLead>>(
        defaultReminderLeads,
      ),
      'monthEndSummaryEnabled': serializer.toJson<bool>(monthEndSummaryEnabled),
      'monthEndDay': serializer.toJson<String>(
        $SettingsTable.$convertermonthEndDay.toJson(monthEndDay),
      ),
      'monthEndHour': serializer.toJson<int>(monthEndHour),
      'monthEndMinute': serializer.toJson<int>(monthEndMinute),
      'dueSoonWindowDays': serializer.toJson<int>(dueSoonWindowDays),
      'lockEnabled': serializer.toJson<bool>(lockEnabled),
      'biometricEnabled': serializer.toJson<bool>(biometricEnabled),
      'onboardingCompleted': serializer.toJson<bool>(onboardingCompleted),
      'backupAutoEnabled': serializer.toJson<bool>(backupAutoEnabled),
      'lastSummarySentOn': serializer.toJson<DateTime?>(lastSummarySentOn),
      'lastExportedAt': serializer.toJson<DateTime?>(lastExportedAt),
    };
  }

  Setting copyWith({
    int? id,
    AppLanguage? language,
    AppThemeMode? themeMode,
    NumeralsStyle? numerals,
    String? defaultCurrencyCode,
    bool? notificationsEnabled,
    int? notificationHour,
    int? notificationMinute,
    List<ReminderLead>? defaultReminderLeads,
    bool? monthEndSummaryEnabled,
    MonthEndDay? monthEndDay,
    int? monthEndHour,
    int? monthEndMinute,
    int? dueSoonWindowDays,
    bool? lockEnabled,
    bool? biometricEnabled,
    bool? onboardingCompleted,
    bool? backupAutoEnabled,
    Value<DateTime?> lastSummarySentOn = const Value.absent(),
    Value<DateTime?> lastExportedAt = const Value.absent(),
  }) => Setting(
    id: id ?? this.id,
    language: language ?? this.language,
    themeMode: themeMode ?? this.themeMode,
    numerals: numerals ?? this.numerals,
    defaultCurrencyCode: defaultCurrencyCode ?? this.defaultCurrencyCode,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    notificationHour: notificationHour ?? this.notificationHour,
    notificationMinute: notificationMinute ?? this.notificationMinute,
    defaultReminderLeads: defaultReminderLeads ?? this.defaultReminderLeads,
    monthEndSummaryEnabled:
        monthEndSummaryEnabled ?? this.monthEndSummaryEnabled,
    monthEndDay: monthEndDay ?? this.monthEndDay,
    monthEndHour: monthEndHour ?? this.monthEndHour,
    monthEndMinute: monthEndMinute ?? this.monthEndMinute,
    dueSoonWindowDays: dueSoonWindowDays ?? this.dueSoonWindowDays,
    lockEnabled: lockEnabled ?? this.lockEnabled,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    backupAutoEnabled: backupAutoEnabled ?? this.backupAutoEnabled,
    lastSummarySentOn: lastSummarySentOn.present
        ? lastSummarySentOn.value
        : this.lastSummarySentOn,
    lastExportedAt: lastExportedAt.present
        ? lastExportedAt.value
        : this.lastExportedAt,
  );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      id: data.id.present ? data.id.value : this.id,
      language: data.language.present ? data.language.value : this.language,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      numerals: data.numerals.present ? data.numerals.value : this.numerals,
      defaultCurrencyCode: data.defaultCurrencyCode.present
          ? data.defaultCurrencyCode.value
          : this.defaultCurrencyCode,
      notificationsEnabled: data.notificationsEnabled.present
          ? data.notificationsEnabled.value
          : this.notificationsEnabled,
      notificationHour: data.notificationHour.present
          ? data.notificationHour.value
          : this.notificationHour,
      notificationMinute: data.notificationMinute.present
          ? data.notificationMinute.value
          : this.notificationMinute,
      defaultReminderLeads: data.defaultReminderLeads.present
          ? data.defaultReminderLeads.value
          : this.defaultReminderLeads,
      monthEndSummaryEnabled: data.monthEndSummaryEnabled.present
          ? data.monthEndSummaryEnabled.value
          : this.monthEndSummaryEnabled,
      monthEndDay: data.monthEndDay.present
          ? data.monthEndDay.value
          : this.monthEndDay,
      monthEndHour: data.monthEndHour.present
          ? data.monthEndHour.value
          : this.monthEndHour,
      monthEndMinute: data.monthEndMinute.present
          ? data.monthEndMinute.value
          : this.monthEndMinute,
      dueSoonWindowDays: data.dueSoonWindowDays.present
          ? data.dueSoonWindowDays.value
          : this.dueSoonWindowDays,
      lockEnabled: data.lockEnabled.present
          ? data.lockEnabled.value
          : this.lockEnabled,
      biometricEnabled: data.biometricEnabled.present
          ? data.biometricEnabled.value
          : this.biometricEnabled,
      onboardingCompleted: data.onboardingCompleted.present
          ? data.onboardingCompleted.value
          : this.onboardingCompleted,
      backupAutoEnabled: data.backupAutoEnabled.present
          ? data.backupAutoEnabled.value
          : this.backupAutoEnabled,
      lastSummarySentOn: data.lastSummarySentOn.present
          ? data.lastSummarySentOn.value
          : this.lastSummarySentOn,
      lastExportedAt: data.lastExportedAt.present
          ? data.lastExportedAt.value
          : this.lastExportedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('id: $id, ')
          ..write('language: $language, ')
          ..write('themeMode: $themeMode, ')
          ..write('numerals: $numerals, ')
          ..write('defaultCurrencyCode: $defaultCurrencyCode, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('notificationHour: $notificationHour, ')
          ..write('notificationMinute: $notificationMinute, ')
          ..write('defaultReminderLeads: $defaultReminderLeads, ')
          ..write('monthEndSummaryEnabled: $monthEndSummaryEnabled, ')
          ..write('monthEndDay: $monthEndDay, ')
          ..write('monthEndHour: $monthEndHour, ')
          ..write('monthEndMinute: $monthEndMinute, ')
          ..write('dueSoonWindowDays: $dueSoonWindowDays, ')
          ..write('lockEnabled: $lockEnabled, ')
          ..write('biometricEnabled: $biometricEnabled, ')
          ..write('onboardingCompleted: $onboardingCompleted, ')
          ..write('backupAutoEnabled: $backupAutoEnabled, ')
          ..write('lastSummarySentOn: $lastSummarySentOn, ')
          ..write('lastExportedAt: $lastExportedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    language,
    themeMode,
    numerals,
    defaultCurrencyCode,
    notificationsEnabled,
    notificationHour,
    notificationMinute,
    defaultReminderLeads,
    monthEndSummaryEnabled,
    monthEndDay,
    monthEndHour,
    monthEndMinute,
    dueSoonWindowDays,
    lockEnabled,
    biometricEnabled,
    onboardingCompleted,
    backupAutoEnabled,
    lastSummarySentOn,
    lastExportedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.id == this.id &&
          other.language == this.language &&
          other.themeMode == this.themeMode &&
          other.numerals == this.numerals &&
          other.defaultCurrencyCode == this.defaultCurrencyCode &&
          other.notificationsEnabled == this.notificationsEnabled &&
          other.notificationHour == this.notificationHour &&
          other.notificationMinute == this.notificationMinute &&
          other.defaultReminderLeads == this.defaultReminderLeads &&
          other.monthEndSummaryEnabled == this.monthEndSummaryEnabled &&
          other.monthEndDay == this.monthEndDay &&
          other.monthEndHour == this.monthEndHour &&
          other.monthEndMinute == this.monthEndMinute &&
          other.dueSoonWindowDays == this.dueSoonWindowDays &&
          other.lockEnabled == this.lockEnabled &&
          other.biometricEnabled == this.biometricEnabled &&
          other.onboardingCompleted == this.onboardingCompleted &&
          other.backupAutoEnabled == this.backupAutoEnabled &&
          other.lastSummarySentOn == this.lastSummarySentOn &&
          other.lastExportedAt == this.lastExportedAt);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<int> id;
  final Value<AppLanguage> language;
  final Value<AppThemeMode> themeMode;
  final Value<NumeralsStyle> numerals;
  final Value<String> defaultCurrencyCode;
  final Value<bool> notificationsEnabled;
  final Value<int> notificationHour;
  final Value<int> notificationMinute;
  final Value<List<ReminderLead>> defaultReminderLeads;
  final Value<bool> monthEndSummaryEnabled;
  final Value<MonthEndDay> monthEndDay;
  final Value<int> monthEndHour;
  final Value<int> monthEndMinute;
  final Value<int> dueSoonWindowDays;
  final Value<bool> lockEnabled;
  final Value<bool> biometricEnabled;
  final Value<bool> onboardingCompleted;
  final Value<bool> backupAutoEnabled;
  final Value<DateTime?> lastSummarySentOn;
  final Value<DateTime?> lastExportedAt;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.language = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.numerals = const Value.absent(),
    this.defaultCurrencyCode = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.notificationHour = const Value.absent(),
    this.notificationMinute = const Value.absent(),
    this.defaultReminderLeads = const Value.absent(),
    this.monthEndSummaryEnabled = const Value.absent(),
    this.monthEndDay = const Value.absent(),
    this.monthEndHour = const Value.absent(),
    this.monthEndMinute = const Value.absent(),
    this.dueSoonWindowDays = const Value.absent(),
    this.lockEnabled = const Value.absent(),
    this.biometricEnabled = const Value.absent(),
    this.onboardingCompleted = const Value.absent(),
    this.backupAutoEnabled = const Value.absent(),
    this.lastSummarySentOn = const Value.absent(),
    this.lastExportedAt = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    required AppLanguage language,
    required AppThemeMode themeMode,
    required NumeralsStyle numerals,
    required String defaultCurrencyCode,
    this.notificationsEnabled = const Value.absent(),
    this.notificationHour = const Value.absent(),
    this.notificationMinute = const Value.absent(),
    this.defaultReminderLeads = const Value.absent(),
    this.monthEndSummaryEnabled = const Value.absent(),
    required MonthEndDay monthEndDay,
    this.monthEndHour = const Value.absent(),
    this.monthEndMinute = const Value.absent(),
    this.dueSoonWindowDays = const Value.absent(),
    this.lockEnabled = const Value.absent(),
    this.biometricEnabled = const Value.absent(),
    this.onboardingCompleted = const Value.absent(),
    this.backupAutoEnabled = const Value.absent(),
    this.lastSummarySentOn = const Value.absent(),
    this.lastExportedAt = const Value.absent(),
  }) : language = Value(language),
       themeMode = Value(themeMode),
       numerals = Value(numerals),
       defaultCurrencyCode = Value(defaultCurrencyCode),
       monthEndDay = Value(monthEndDay);
  static Insertable<Setting> custom({
    Expression<int>? id,
    Expression<String>? language,
    Expression<String>? themeMode,
    Expression<String>? numerals,
    Expression<String>? defaultCurrencyCode,
    Expression<bool>? notificationsEnabled,
    Expression<int>? notificationHour,
    Expression<int>? notificationMinute,
    Expression<String>? defaultReminderLeads,
    Expression<bool>? monthEndSummaryEnabled,
    Expression<String>? monthEndDay,
    Expression<int>? monthEndHour,
    Expression<int>? monthEndMinute,
    Expression<int>? dueSoonWindowDays,
    Expression<bool>? lockEnabled,
    Expression<bool>? biometricEnabled,
    Expression<bool>? onboardingCompleted,
    Expression<bool>? backupAutoEnabled,
    Expression<String>? lastSummarySentOn,
    Expression<int>? lastExportedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (language != null) 'language': language,
      if (themeMode != null) 'theme_mode': themeMode,
      if (numerals != null) 'numerals': numerals,
      if (defaultCurrencyCode != null)
        'default_currency_code': defaultCurrencyCode,
      if (notificationsEnabled != null)
        'notifications_enabled': notificationsEnabled,
      if (notificationHour != null) 'notification_hour': notificationHour,
      if (notificationMinute != null) 'notification_minute': notificationMinute,
      if (defaultReminderLeads != null)
        'default_reminder_leads': defaultReminderLeads,
      if (monthEndSummaryEnabled != null)
        'month_end_summary_enabled': monthEndSummaryEnabled,
      if (monthEndDay != null) 'month_end_day': monthEndDay,
      if (monthEndHour != null) 'month_end_hour': monthEndHour,
      if (monthEndMinute != null) 'month_end_minute': monthEndMinute,
      if (dueSoonWindowDays != null) 'due_soon_window_days': dueSoonWindowDays,
      if (lockEnabled != null) 'lock_enabled': lockEnabled,
      if (biometricEnabled != null) 'biometric_enabled': biometricEnabled,
      if (onboardingCompleted != null)
        'onboarding_completed': onboardingCompleted,
      if (backupAutoEnabled != null) 'backup_auto_enabled': backupAutoEnabled,
      if (lastSummarySentOn != null) 'last_summary_sent_on': lastSummarySentOn,
      if (lastExportedAt != null) 'last_exported_at': lastExportedAt,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<AppLanguage>? language,
    Value<AppThemeMode>? themeMode,
    Value<NumeralsStyle>? numerals,
    Value<String>? defaultCurrencyCode,
    Value<bool>? notificationsEnabled,
    Value<int>? notificationHour,
    Value<int>? notificationMinute,
    Value<List<ReminderLead>>? defaultReminderLeads,
    Value<bool>? monthEndSummaryEnabled,
    Value<MonthEndDay>? monthEndDay,
    Value<int>? monthEndHour,
    Value<int>? monthEndMinute,
    Value<int>? dueSoonWindowDays,
    Value<bool>? lockEnabled,
    Value<bool>? biometricEnabled,
    Value<bool>? onboardingCompleted,
    Value<bool>? backupAutoEnabled,
    Value<DateTime?>? lastSummarySentOn,
    Value<DateTime?>? lastExportedAt,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      numerals: numerals ?? this.numerals,
      defaultCurrencyCode: defaultCurrencyCode ?? this.defaultCurrencyCode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
      defaultReminderLeads: defaultReminderLeads ?? this.defaultReminderLeads,
      monthEndSummaryEnabled:
          monthEndSummaryEnabled ?? this.monthEndSummaryEnabled,
      monthEndDay: monthEndDay ?? this.monthEndDay,
      monthEndHour: monthEndHour ?? this.monthEndHour,
      monthEndMinute: monthEndMinute ?? this.monthEndMinute,
      dueSoonWindowDays: dueSoonWindowDays ?? this.dueSoonWindowDays,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      backupAutoEnabled: backupAutoEnabled ?? this.backupAutoEnabled,
      lastSummarySentOn: lastSummarySentOn ?? this.lastSummarySentOn,
      lastExportedAt: lastExportedAt ?? this.lastExportedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(
        $SettingsTable.$converterlanguage.toSql(language.value),
      );
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(
        $SettingsTable.$converterthemeMode.toSql(themeMode.value),
      );
    }
    if (numerals.present) {
      map['numerals'] = Variable<String>(
        $SettingsTable.$converternumerals.toSql(numerals.value),
      );
    }
    if (defaultCurrencyCode.present) {
      map['default_currency_code'] = Variable<String>(
        defaultCurrencyCode.value,
      );
    }
    if (notificationsEnabled.present) {
      map['notifications_enabled'] = Variable<bool>(notificationsEnabled.value);
    }
    if (notificationHour.present) {
      map['notification_hour'] = Variable<int>(notificationHour.value);
    }
    if (notificationMinute.present) {
      map['notification_minute'] = Variable<int>(notificationMinute.value);
    }
    if (defaultReminderLeads.present) {
      map['default_reminder_leads'] = Variable<String>(
        $SettingsTable.$converterdefaultReminderLeads.toSql(
          defaultReminderLeads.value,
        ),
      );
    }
    if (monthEndSummaryEnabled.present) {
      map['month_end_summary_enabled'] = Variable<bool>(
        monthEndSummaryEnabled.value,
      );
    }
    if (monthEndDay.present) {
      map['month_end_day'] = Variable<String>(
        $SettingsTable.$convertermonthEndDay.toSql(monthEndDay.value),
      );
    }
    if (monthEndHour.present) {
      map['month_end_hour'] = Variable<int>(monthEndHour.value);
    }
    if (monthEndMinute.present) {
      map['month_end_minute'] = Variable<int>(monthEndMinute.value);
    }
    if (dueSoonWindowDays.present) {
      map['due_soon_window_days'] = Variable<int>(dueSoonWindowDays.value);
    }
    if (lockEnabled.present) {
      map['lock_enabled'] = Variable<bool>(lockEnabled.value);
    }
    if (biometricEnabled.present) {
      map['biometric_enabled'] = Variable<bool>(biometricEnabled.value);
    }
    if (onboardingCompleted.present) {
      map['onboarding_completed'] = Variable<bool>(onboardingCompleted.value);
    }
    if (backupAutoEnabled.present) {
      map['backup_auto_enabled'] = Variable<bool>(backupAutoEnabled.value);
    }
    if (lastSummarySentOn.present) {
      map['last_summary_sent_on'] = Variable<String>(
        $SettingsTable.$converterlastSummarySentOn.toSql(
          lastSummarySentOn.value,
        ),
      );
    }
    if (lastExportedAt.present) {
      map['last_exported_at'] = Variable<int>(
        $SettingsTable.$converterlastExportedAt.toSql(lastExportedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('language: $language, ')
          ..write('themeMode: $themeMode, ')
          ..write('numerals: $numerals, ')
          ..write('defaultCurrencyCode: $defaultCurrencyCode, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('notificationHour: $notificationHour, ')
          ..write('notificationMinute: $notificationMinute, ')
          ..write('defaultReminderLeads: $defaultReminderLeads, ')
          ..write('monthEndSummaryEnabled: $monthEndSummaryEnabled, ')
          ..write('monthEndDay: $monthEndDay, ')
          ..write('monthEndHour: $monthEndHour, ')
          ..write('monthEndMinute: $monthEndMinute, ')
          ..write('dueSoonWindowDays: $dueSoonWindowDays, ')
          ..write('lockEnabled: $lockEnabled, ')
          ..write('biometricEnabled: $biometricEnabled, ')
          ..write('onboardingCompleted: $onboardingCompleted, ')
          ..write('backupAutoEnabled: $backupAutoEnabled, ')
          ..write('lastSummarySentOn: $lastSummarySentOn, ')
          ..write('lastExportedAt: $lastExportedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PeopleTable people = $PeopleTable(this);
  late final $DebtsTable debts = $DebtsTable(this);
  late final $DebtPeopleTable debtPeople = $DebtPeopleTable(this);
  late final $PaymentsTable payments = $PaymentsTable(this);
  late final $ObligationsTable obligations = $ObligationsTable(this);
  late final $ObligationOccurrencesTable obligationOccurrences =
      $ObligationOccurrencesTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $ActivityEntriesTable activityEntries = $ActivityEntriesTable(
    this,
  );
  late final $MonthlySummariesTable monthlySummaries = $MonthlySummariesTable(
    this,
  );
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index idxDebtsPerson = Index(
    'idx_debts_person',
    'CREATE INDEX idx_debts_person ON debts (person_id)',
  );
  late final Index idxDebtsDue = Index(
    'idx_debts_due',
    'CREATE INDEX idx_debts_due ON debts (due_at)',
  );
  late final Index idxDebtsArchived = Index(
    'idx_debts_archived',
    'CREATE INDEX idx_debts_archived ON debts (archived_at)',
  );
  late final Index idxDebtPeoplePerson = Index(
    'idx_debt_people_person',
    'CREATE INDEX idx_debt_people_person ON debt_people (person_id)',
  );
  late final Index idxPaymentsDebt = Index(
    'idx_payments_debt',
    'CREATE INDEX idx_payments_debt ON payments (debt_id)',
  );
  late final Index idxPaymentsPerson = Index(
    'idx_payments_person',
    'CREATE INDEX idx_payments_person ON payments (person_id)',
  );
  late final Index idxPaymentsPaidAt = Index(
    'idx_payments_paid_at',
    'CREATE INDEX idx_payments_paid_at ON payments (paid_at)',
  );
  late final Index idxPaymentsOccurrence = Index(
    'idx_payments_occurrence',
    'CREATE INDEX idx_payments_occurrence ON payments (occurrence_id)',
  );
  late final Index idxObligationsNextDue = Index(
    'idx_obligations_next_due',
    'CREATE INDEX idx_obligations_next_due ON obligations (next_due_at)',
  );
  late final Index idxObligationsArchived = Index(
    'idx_obligations_archived',
    'CREATE INDEX idx_obligations_archived ON obligations (archived_at)',
  );
  late final Index idxOccurrencesObligation = Index(
    'idx_occurrences_obligation',
    'CREATE INDEX idx_occurrences_obligation ON obligation_occurrences (obligation_id)',
  );
  late final Index idxOccurrencesDue = Index(
    'idx_occurrences_due',
    'CREATE INDEX idx_occurrences_due ON obligation_occurrences (due_at)',
  );
  late final Index idxOccurrencesStatus = Index(
    'idx_occurrences_status',
    'CREATE INDEX idx_occurrences_status ON obligation_occurrences (status)',
  );
  late final Index idxRemindersDue = Index(
    'idx_reminders_due',
    'CREATE INDEX idx_reminders_due ON reminders (due_at)',
  );
  late final Index idxRemindersStatus = Index(
    'idx_reminders_status',
    'CREATE INDEX idx_reminders_status ON reminders (status)',
  );
  late final Index idxActivityEntity = Index(
    'idx_activity_entity',
    'CREATE INDEX idx_activity_entity ON activity_entries (entity_type, entity_id)',
  );
  late final Index idxActivityOccurred = Index(
    'idx_activity_occurred',
    'CREATE INDEX idx_activity_occurred ON activity_entries (occurred_at)',
  );
  late final PeopleDao peopleDao = PeopleDao(this as AppDatabase);
  late final DebtsDao debtsDao = DebtsDao(this as AppDatabase);
  late final ObligationsDao obligationsDao = ObligationsDao(
    this as AppDatabase,
  );
  late final RemindersDao remindersDao = RemindersDao(this as AppDatabase);
  late final ActivityDao activityDao = ActivityDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    people,
    debts,
    debtPeople,
    payments,
    obligations,
    obligationOccurrences,
    reminders,
    activityEntries,
    monthlySummaries,
    settings,
    idxDebtsPerson,
    idxDebtsDue,
    idxDebtsArchived,
    idxDebtPeoplePerson,
    idxPaymentsDebt,
    idxPaymentsPerson,
    idxPaymentsPaidAt,
    idxPaymentsOccurrence,
    idxObligationsNextDue,
    idxObligationsArchived,
    idxOccurrencesObligation,
    idxOccurrencesDue,
    idxOccurrencesStatus,
    idxRemindersDue,
    idxRemindersStatus,
    idxActivityEntity,
    idxActivityOccurred,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'people',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('debts', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'debts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('debt_people', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'people',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('debt_people', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'debts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('payments', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'people',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('payments', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'obligations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('obligation_occurrences', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$PeopleTableCreateCompanionBuilder =
    PeopleCompanion Function({
      required String id,
      required String name,
      Value<String?> phone,
      Value<String?> note,
      Value<int> colorIndex,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });
typedef $$PeopleTableUpdateCompanionBuilder =
    PeopleCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> phone,
      Value<String?> note,
      Value<int> colorIndex,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });

final class $$PeopleTableReferences
    extends BaseReferences<_$AppDatabase, $PeopleTable, PersonRow> {
  $$PeopleTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DebtsTable, List<DebtRow>> _debtsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.debts,
    aliasName: 'people__id__debts__person_id',
  );

  $$DebtsTableProcessedTableManager get debtsRefs {
    final manager = $$DebtsTableTableManager(
      $_db,
      $_db.debts,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_debtsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DebtPeopleTable, List<DebtPersonRow>>
  _debtPeopleRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.debtPeople,
    aliasName: 'people__id__debt_people__person_id',
  );

  $$DebtPeopleTableProcessedTableManager get debtPeopleRefs {
    final manager = $$DebtPeopleTableTableManager(
      $_db,
      $_db.debtPeople,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_debtPeopleRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PaymentsTable, List<PaymentRow>>
  _paymentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.payments,
    aliasName: 'people__id__payments__person_id',
  );

  $$PaymentsTableProcessedTableManager get paymentsRefs {
    final manager = $$PaymentsTableTableManager(
      $_db,
      $_db.payments,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_paymentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PeopleTableFilterComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get archivedAt =>
      $composableBuilder(
        column: $table.archivedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> debtsRefs(
    Expression<bool> Function($$DebtsTableFilterComposer f) f,
  ) {
    final $$DebtsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.debts,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtsTableFilterComposer(
            $db: $db,
            $table: $db.debts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> debtPeopleRefs(
    Expression<bool> Function($$DebtPeopleTableFilterComposer f) f,
  ) {
    final $$DebtPeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.debtPeople,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtPeopleTableFilterComposer(
            $db: $db,
            $table: $db.debtPeople,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> paymentsRefs(
    Expression<bool> Function($$PaymentsTableFilterComposer f) f,
  ) {
    final $$PaymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableFilterComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeopleTableOrderingComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeopleTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get archivedAt =>
      $composableBuilder(
        column: $table.archivedAt,
        builder: (column) => column,
      );

  Expression<T> debtsRefs<T extends Object>(
    Expression<T> Function($$DebtsTableAnnotationComposer a) f,
  ) {
    final $$DebtsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.debts,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtsTableAnnotationComposer(
            $db: $db,
            $table: $db.debts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> debtPeopleRefs<T extends Object>(
    Expression<T> Function($$DebtPeopleTableAnnotationComposer a) f,
  ) {
    final $$DebtPeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.debtPeople,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtPeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.debtPeople,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> paymentsRefs<T extends Object>(
    Expression<T> Function($$PaymentsTableAnnotationComposer a) f,
  ) {
    final $$PaymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeopleTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeopleTable,
          PersonRow,
          $$PeopleTableFilterComposer,
          $$PeopleTableOrderingComposer,
          $$PeopleTableAnnotationComposer,
          $$PeopleTableCreateCompanionBuilder,
          $$PeopleTableUpdateCompanionBuilder,
          (PersonRow, $$PeopleTableReferences),
          PersonRow,
          PrefetchHooks Function({
            bool debtsRefs,
            bool debtPeopleRefs,
            bool paymentsRefs,
          })
        > {
  $$PeopleTableTableManager(_$AppDatabase db, $PeopleTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeopleTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeopleTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeopleTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeopleCompanion(
                id: id,
                name: name,
                phone: phone,
                note: note,
                colorIndex: colorIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeopleCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                note: note,
                colorIndex: colorIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PeopleTable, PersonRow>(table),
                  $$PeopleTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                debtsRefs = false,
                debtPeopleRefs = false,
                paymentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (debtsRefs) db.debts,
                    if (debtPeopleRefs) db.debtPeople,
                    if (paymentsRefs) db.payments,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (debtsRefs)
                        await $_getPrefetchedData<
                          PersonRow,
                          $PeopleTable,
                          DebtRow
                        >(
                          currentTable: table,
                          referencedTable: $$PeopleTableReferences
                              ._debtsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeopleTableReferences(db, table, p0).debtsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.personId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (debtPeopleRefs)
                        await $_getPrefetchedData<
                          PersonRow,
                          $PeopleTable,
                          DebtPersonRow
                        >(
                          currentTable: table,
                          referencedTable: $$PeopleTableReferences
                              ._debtPeopleRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeopleTableReferences(
                                db,
                                table,
                                p0,
                              ).debtPeopleRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.personId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (paymentsRefs)
                        await $_getPrefetchedData<
                          PersonRow,
                          $PeopleTable,
                          PaymentRow
                        >(
                          currentTable: table,
                          referencedTable: $$PeopleTableReferences
                              ._paymentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeopleTableReferences(
                                db,
                                table,
                                p0,
                              ).paymentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.personId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PeopleTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeopleTable,
      PersonRow,
      $$PeopleTableFilterComposer,
      $$PeopleTableOrderingComposer,
      $$PeopleTableAnnotationComposer,
      $$PeopleTableCreateCompanionBuilder,
      $$PeopleTableUpdateCompanionBuilder,
      (PersonRow, $$PeopleTableReferences),
      PersonRow,
      PrefetchHooks Function({
        bool debtsRefs,
        bool debtPeopleRefs,
        bool paymentsRefs,
      })
    >;
typedef $$DebtsTableCreateCompanionBuilder =
    DebtsCompanion Function({
      required String id,
      Value<String?> personId,
      required DebtDirection direction,
      Value<String> title,
      required int principalMinor,
      required String currencyCode,
      required DateTime issuedAt,
      Value<DateTime?> dueAt,
      Value<String?> note,
      Value<List<ReminderLead>> reminderLeads,
      required RecurrenceFrequency recurrence,
      Value<int> recurrenceInterval,
      Value<DateTime?> recurrenceEndAt,
      Value<DateTime?> closedAt,
      Value<DateTime?> archivedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DebtsTableUpdateCompanionBuilder =
    DebtsCompanion Function({
      Value<String> id,
      Value<String?> personId,
      Value<DebtDirection> direction,
      Value<String> title,
      Value<int> principalMinor,
      Value<String> currencyCode,
      Value<DateTime> issuedAt,
      Value<DateTime?> dueAt,
      Value<String?> note,
      Value<List<ReminderLead>> reminderLeads,
      Value<RecurrenceFrequency> recurrence,
      Value<int> recurrenceInterval,
      Value<DateTime?> recurrenceEndAt,
      Value<DateTime?> closedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$DebtsTableReferences
    extends BaseReferences<_$AppDatabase, $DebtsTable, DebtRow> {
  $$DebtsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PeopleTable _personIdTable(_$AppDatabase db) =>
      db.people.createAlias('debts__person_id__people__id');

  $$PeopleTableProcessedTableManager? get personId {
    final $_column = $_itemColumn<String>('person_id');
    if ($_column == null) return null;
    final manager = $$PeopleTableTableManager(
      $_db,
      $_db.people,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$DebtPeopleTable, List<DebtPersonRow>>
  _debtPeopleRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.debtPeople,
    aliasName: 'debts__id__debt_people__debt_id',
  );

  $$DebtPeopleTableProcessedTableManager get debtPeopleRefs {
    final manager = $$DebtPeopleTableTableManager(
      $_db,
      $_db.debtPeople,
    ).filter((f) => f.debtId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_debtPeopleRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PaymentsTable, List<PaymentRow>>
  _paymentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.payments,
    aliasName: 'debts__id__payments__debt_id',
  );

  $$PaymentsTableProcessedTableManager get paymentsRefs {
    final manager = $$PaymentsTableTableManager(
      $_db,
      $_db.payments,
    ).filter((f) => f.debtId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_paymentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DebtsTableFilterComposer extends Composer<_$AppDatabase, $DebtsTable> {
  $$DebtsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DebtDirection, DebtDirection, String>
  get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get principalMinor => $composableBuilder(
    column: $table.principalMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get issuedAt =>
      $composableBuilder(
        column: $table.issuedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get dueAt =>
      $composableBuilder(
        column: $table.dueAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<ReminderLead>, List<ReminderLead>, String>
  get reminderLeads => $composableBuilder(
    column: $table.reminderLeads,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<
    RecurrenceFrequency,
    RecurrenceFrequency,
    String
  >
  get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get recurrenceInterval => $composableBuilder(
    column: $table.recurrenceInterval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String>
  get recurrenceEndAt => $composableBuilder(
    column: $table.recurrenceEndAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get closedAt =>
      $composableBuilder(
        column: $table.closedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get archivedAt =>
      $composableBuilder(
        column: $table.archivedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$PeopleTableFilterComposer get personId {
    final $$PeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableFilterComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> debtPeopleRefs(
    Expression<bool> Function($$DebtPeopleTableFilterComposer f) f,
  ) {
    final $$DebtPeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.debtPeople,
      getReferencedColumn: (t) => t.debtId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtPeopleTableFilterComposer(
            $db: $db,
            $table: $db.debtPeople,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> paymentsRefs(
    Expression<bool> Function($$PaymentsTableFilterComposer f) f,
  ) {
    final $$PaymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.debtId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableFilterComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DebtsTableOrderingComposer
    extends Composer<_$AppDatabase, $DebtsTable> {
  $$DebtsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get principalMinor => $composableBuilder(
    column: $table.principalMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get issuedAt => $composableBuilder(
    column: $table.issuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderLeads => $composableBuilder(
    column: $table.reminderLeads,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recurrenceInterval => $composableBuilder(
    column: $table.recurrenceInterval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceEndAt => $composableBuilder(
    column: $table.recurrenceEndAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PeopleTableOrderingComposer get personId {
    final $$PeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableOrderingComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DebtsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DebtsTable> {
  $$DebtsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DebtDirection, String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get principalMinor => $composableBuilder(
    column: $table.principalMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, String> get issuedAt =>
      $composableBuilder(column: $table.issuedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<ReminderLead>, String>
  get reminderLeads => $composableBuilder(
    column: $table.reminderLeads,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<RecurrenceFrequency, String>
  get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recurrenceInterval => $composableBuilder(
    column: $table.recurrenceInterval,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, String> get recurrenceEndAt =>
      $composableBuilder(
        column: $table.recurrenceEndAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get archivedAt =>
      $composableBuilder(
        column: $table.archivedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PeopleTableAnnotationComposer get personId {
    final $$PeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> debtPeopleRefs<T extends Object>(
    Expression<T> Function($$DebtPeopleTableAnnotationComposer a) f,
  ) {
    final $$DebtPeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.debtPeople,
      getReferencedColumn: (t) => t.debtId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtPeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.debtPeople,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> paymentsRefs<T extends Object>(
    Expression<T> Function($$PaymentsTableAnnotationComposer a) f,
  ) {
    final $$PaymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.debtId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DebtsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DebtsTable,
          DebtRow,
          $$DebtsTableFilterComposer,
          $$DebtsTableOrderingComposer,
          $$DebtsTableAnnotationComposer,
          $$DebtsTableCreateCompanionBuilder,
          $$DebtsTableUpdateCompanionBuilder,
          (DebtRow, $$DebtsTableReferences),
          DebtRow,
          PrefetchHooks Function({
            bool personId,
            bool debtPeopleRefs,
            bool paymentsRefs,
          })
        > {
  $$DebtsTableTableManager(_$AppDatabase db, $DebtsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebtsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebtsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DebtsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> personId = const Value.absent(),
                Value<DebtDirection> direction = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> principalMinor = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<DateTime> issuedAt = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<List<ReminderLead>> reminderLeads = const Value.absent(),
                Value<RecurrenceFrequency> recurrence = const Value.absent(),
                Value<int> recurrenceInterval = const Value.absent(),
                Value<DateTime?> recurrenceEndAt = const Value.absent(),
                Value<DateTime?> closedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebtsCompanion(
                id: id,
                personId: personId,
                direction: direction,
                title: title,
                principalMinor: principalMinor,
                currencyCode: currencyCode,
                issuedAt: issuedAt,
                dueAt: dueAt,
                note: note,
                reminderLeads: reminderLeads,
                recurrence: recurrence,
                recurrenceInterval: recurrenceInterval,
                recurrenceEndAt: recurrenceEndAt,
                closedAt: closedAt,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> personId = const Value.absent(),
                required DebtDirection direction,
                Value<String> title = const Value.absent(),
                required int principalMinor,
                required String currencyCode,
                required DateTime issuedAt,
                Value<DateTime?> dueAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<List<ReminderLead>> reminderLeads = const Value.absent(),
                required RecurrenceFrequency recurrence,
                Value<int> recurrenceInterval = const Value.absent(),
                Value<DateTime?> recurrenceEndAt = const Value.absent(),
                Value<DateTime?> closedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DebtsCompanion.insert(
                id: id,
                personId: personId,
                direction: direction,
                title: title,
                principalMinor: principalMinor,
                currencyCode: currencyCode,
                issuedAt: issuedAt,
                dueAt: dueAt,
                note: note,
                reminderLeads: reminderLeads,
                recurrence: recurrence,
                recurrenceInterval: recurrenceInterval,
                recurrenceEndAt: recurrenceEndAt,
                closedAt: closedAt,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DebtsTable, DebtRow>(table),
                  $$DebtsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                personId = false,
                debtPeopleRefs = false,
                paymentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (debtPeopleRefs) db.debtPeople,
                    if (paymentsRefs) db.payments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (personId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.personId,
                                    referencedTable: $$DebtsTableReferences
                                        ._personIdTable(db),
                                    referencedColumn: $$DebtsTableReferences
                                        ._personIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (debtPeopleRefs)
                        await $_getPrefetchedData<
                          DebtRow,
                          $DebtsTable,
                          DebtPersonRow
                        >(
                          currentTable: table,
                          referencedTable: $$DebtsTableReferences
                              ._debtPeopleRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DebtsTableReferences(
                                db,
                                table,
                                p0,
                              ).debtPeopleRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.debtId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (paymentsRefs)
                        await $_getPrefetchedData<
                          DebtRow,
                          $DebtsTable,
                          PaymentRow
                        >(
                          currentTable: table,
                          referencedTable: $$DebtsTableReferences
                              ._paymentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DebtsTableReferences(
                                db,
                                table,
                                p0,
                              ).paymentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.debtId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DebtsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DebtsTable,
      DebtRow,
      $$DebtsTableFilterComposer,
      $$DebtsTableOrderingComposer,
      $$DebtsTableAnnotationComposer,
      $$DebtsTableCreateCompanionBuilder,
      $$DebtsTableUpdateCompanionBuilder,
      (DebtRow, $$DebtsTableReferences),
      DebtRow,
      PrefetchHooks Function({
        bool personId,
        bool debtPeopleRefs,
        bool paymentsRefs,
      })
    >;
typedef $$DebtPeopleTableCreateCompanionBuilder =
    DebtPeopleCompanion Function({
      required String debtId,
      required String personId,
      Value<int> position,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$DebtPeopleTableUpdateCompanionBuilder =
    DebtPeopleCompanion Function({
      Value<String> debtId,
      Value<String> personId,
      Value<int> position,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$DebtPeopleTableReferences
    extends BaseReferences<_$AppDatabase, $DebtPeopleTable, DebtPersonRow> {
  $$DebtPeopleTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DebtsTable _debtIdTable(_$AppDatabase db) =>
      db.debts.createAlias('debt_people__debt_id__debts__id');

  $$DebtsTableProcessedTableManager get debtId {
    final $_column = $_itemColumn<String>('debt_id')!;

    final manager = $$DebtsTableTableManager(
      $_db,
      $_db.debts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_debtIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PeopleTable _personIdTable(_$AppDatabase db) =>
      db.people.createAlias('debt_people__person_id__people__id');

  $$PeopleTableProcessedTableManager get personId {
    final $_column = $_itemColumn<String>('person_id')!;

    final manager = $$PeopleTableTableManager(
      $_db,
      $_db.people,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DebtPeopleTableFilterComposer
    extends Composer<_$AppDatabase, $DebtPeopleTable> {
  $$DebtPeopleTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$DebtsTableFilterComposer get debtId {
    final $$DebtsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.debtId,
      referencedTable: $db.debts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtsTableFilterComposer(
            $db: $db,
            $table: $db.debts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableFilterComposer get personId {
    final $$PeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableFilterComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DebtPeopleTableOrderingComposer
    extends Composer<_$AppDatabase, $DebtPeopleTable> {
  $$DebtPeopleTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DebtsTableOrderingComposer get debtId {
    final $$DebtsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.debtId,
      referencedTable: $db.debts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtsTableOrderingComposer(
            $db: $db,
            $table: $db.debts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableOrderingComposer get personId {
    final $$PeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableOrderingComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DebtPeopleTableAnnotationComposer
    extends Composer<_$AppDatabase, $DebtPeopleTable> {
  $$DebtPeopleTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$DebtsTableAnnotationComposer get debtId {
    final $$DebtsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.debtId,
      referencedTable: $db.debts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtsTableAnnotationComposer(
            $db: $db,
            $table: $db.debts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableAnnotationComposer get personId {
    final $$PeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DebtPeopleTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DebtPeopleTable,
          DebtPersonRow,
          $$DebtPeopleTableFilterComposer,
          $$DebtPeopleTableOrderingComposer,
          $$DebtPeopleTableAnnotationComposer,
          $$DebtPeopleTableCreateCompanionBuilder,
          $$DebtPeopleTableUpdateCompanionBuilder,
          (DebtPersonRow, $$DebtPeopleTableReferences),
          DebtPersonRow,
          PrefetchHooks Function({bool debtId, bool personId})
        > {
  $$DebtPeopleTableTableManager(_$AppDatabase db, $DebtPeopleTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebtPeopleTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebtPeopleTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DebtPeopleTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> debtId = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebtPeopleCompanion(
                debtId: debtId,
                personId: personId,
                position: position,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String debtId,
                required String personId,
                Value<int> position = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => DebtPeopleCompanion.insert(
                debtId: debtId,
                personId: personId,
                position: position,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DebtPeopleTable, DebtPersonRow>(table),
                  $$DebtPeopleTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({debtId = false, personId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (debtId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.debtId,
                                referencedTable: $$DebtPeopleTableReferences
                                    ._debtIdTable(db),
                                referencedColumn: $$DebtPeopleTableReferences
                                    ._debtIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (personId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.personId,
                                referencedTable: $$DebtPeopleTableReferences
                                    ._personIdTable(db),
                                referencedColumn: $$DebtPeopleTableReferences
                                    ._personIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DebtPeopleTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DebtPeopleTable,
      DebtPersonRow,
      $$DebtPeopleTableFilterComposer,
      $$DebtPeopleTableOrderingComposer,
      $$DebtPeopleTableAnnotationComposer,
      $$DebtPeopleTableCreateCompanionBuilder,
      $$DebtPeopleTableUpdateCompanionBuilder,
      (DebtPersonRow, $$DebtPeopleTableReferences),
      DebtPersonRow,
      PrefetchHooks Function({bool debtId, bool personId})
    >;
typedef $$PaymentsTableCreateCompanionBuilder =
    PaymentsCompanion Function({
      required String id,
      Value<String?> debtId,
      Value<String?> obligationId,
      Value<String?> occurrenceId,
      Value<String?> personId,
      required int amountMinor,
      required String currencyCode,
      required DateTime paidAt,
      Value<String?> note,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PaymentsTableUpdateCompanionBuilder =
    PaymentsCompanion Function({
      Value<String> id,
      Value<String?> debtId,
      Value<String?> obligationId,
      Value<String?> occurrenceId,
      Value<String?> personId,
      Value<int> amountMinor,
      Value<String> currencyCode,
      Value<DateTime> paidAt,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$PaymentsTableReferences
    extends BaseReferences<_$AppDatabase, $PaymentsTable, PaymentRow> {
  $$PaymentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DebtsTable _debtIdTable(_$AppDatabase db) =>
      db.debts.createAlias('payments__debt_id__debts__id');

  $$DebtsTableProcessedTableManager? get debtId {
    final $_column = $_itemColumn<String>('debt_id');
    if ($_column == null) return null;
    final manager = $$DebtsTableTableManager(
      $_db,
      $_db.debts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_debtIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PeopleTable _personIdTable(_$AppDatabase db) =>
      db.people.createAlias('payments__person_id__people__id');

  $$PeopleTableProcessedTableManager? get personId {
    final $_column = $_itemColumn<String>('person_id');
    if ($_column == null) return null;
    final manager = $$PeopleTableTableManager(
      $_db,
      $_db.people,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get obligationId => $composableBuilder(
    column: $table.obligationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get paidAt =>
      $composableBuilder(
        column: $table.paidAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$DebtsTableFilterComposer get debtId {
    final $$DebtsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.debtId,
      referencedTable: $db.debts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtsTableFilterComposer(
            $db: $db,
            $table: $db.debts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableFilterComposer get personId {
    final $$PeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableFilterComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get obligationId => $composableBuilder(
    column: $table.obligationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DebtsTableOrderingComposer get debtId {
    final $$DebtsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.debtId,
      referencedTable: $db.debts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtsTableOrderingComposer(
            $db: $db,
            $table: $db.debts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableOrderingComposer get personId {
    final $$PeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableOrderingComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get obligationId => $composableBuilder(
    column: $table.obligationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, String> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$DebtsTableAnnotationComposer get debtId {
    final $$DebtsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.debtId,
      referencedTable: $db.debts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtsTableAnnotationComposer(
            $db: $db,
            $table: $db.debts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableAnnotationComposer get personId {
    final $$PeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PaymentsTable,
          PaymentRow,
          $$PaymentsTableFilterComposer,
          $$PaymentsTableOrderingComposer,
          $$PaymentsTableAnnotationComposer,
          $$PaymentsTableCreateCompanionBuilder,
          $$PaymentsTableUpdateCompanionBuilder,
          (PaymentRow, $$PaymentsTableReferences),
          PaymentRow,
          PrefetchHooks Function({bool debtId, bool personId})
        > {
  $$PaymentsTableTableManager(_$AppDatabase db, $PaymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> debtId = const Value.absent(),
                Value<String?> obligationId = const Value.absent(),
                Value<String?> occurrenceId = const Value.absent(),
                Value<String?> personId = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<DateTime> paidAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion(
                id: id,
                debtId: debtId,
                obligationId: obligationId,
                occurrenceId: occurrenceId,
                personId: personId,
                amountMinor: amountMinor,
                currencyCode: currencyCode,
                paidAt: paidAt,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> debtId = const Value.absent(),
                Value<String?> obligationId = const Value.absent(),
                Value<String?> occurrenceId = const Value.absent(),
                Value<String?> personId = const Value.absent(),
                required int amountMinor,
                required String currencyCode,
                required DateTime paidAt,
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion.insert(
                id: id,
                debtId: debtId,
                obligationId: obligationId,
                occurrenceId: occurrenceId,
                personId: personId,
                amountMinor: amountMinor,
                currencyCode: currencyCode,
                paidAt: paidAt,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PaymentsTable, PaymentRow>(table),
                  $$PaymentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({debtId = false, personId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (debtId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.debtId,
                                referencedTable: $$PaymentsTableReferences
                                    ._debtIdTable(db),
                                referencedColumn: $$PaymentsTableReferences
                                    ._debtIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (personId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.personId,
                                referencedTable: $$PaymentsTableReferences
                                    ._personIdTable(db),
                                referencedColumn: $$PaymentsTableReferences
                                    ._personIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PaymentsTable,
      PaymentRow,
      $$PaymentsTableFilterComposer,
      $$PaymentsTableOrderingComposer,
      $$PaymentsTableAnnotationComposer,
      $$PaymentsTableCreateCompanionBuilder,
      $$PaymentsTableUpdateCompanionBuilder,
      (PaymentRow, $$PaymentsTableReferences),
      PaymentRow,
      PrefetchHooks Function({bool debtId, bool personId})
    >;
typedef $$ObligationsTableCreateCompanionBuilder =
    ObligationsCompanion Function({
      required String id,
      required String name,
      required ObligationCategory category,
      required int amountMinor,
      required String currencyCode,
      required RecurrenceFrequency frequency,
      Value<int> intervalCount,
      Value<int?> dayOfMonth,
      required DateTime startAt,
      required DateTime nextDueAt,
      Value<DateTime?> endAt,
      Value<String?> note,
      Value<List<ReminderLead>> reminderLeads,
      Value<DateTime?> archivedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ObligationsTableUpdateCompanionBuilder =
    ObligationsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<ObligationCategory> category,
      Value<int> amountMinor,
      Value<String> currencyCode,
      Value<RecurrenceFrequency> frequency,
      Value<int> intervalCount,
      Value<int?> dayOfMonth,
      Value<DateTime> startAt,
      Value<DateTime> nextDueAt,
      Value<DateTime?> endAt,
      Value<String?> note,
      Value<List<ReminderLead>> reminderLeads,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ObligationsTableReferences
    extends BaseReferences<_$AppDatabase, $ObligationsTable, ObligationRow> {
  $$ObligationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $ObligationOccurrencesTable,
    List<ObligationOccurrenceRow>
  >
  _obligationOccurrencesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.obligationOccurrences,
        aliasName: 'obligations__id__obligation_occurrences__obligation_id',
      );

  $$ObligationOccurrencesTableProcessedTableManager
  get obligationOccurrencesRefs {
    final manager = $$ObligationOccurrencesTableTableManager(
      $_db,
      $_db.obligationOccurrences,
    ).filter((f) => f.obligationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _obligationOccurrencesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ObligationsTableFilterComposer
    extends Composer<_$AppDatabase, $ObligationsTable> {
  $$ObligationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ObligationCategory, ObligationCategory, String>
  get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    RecurrenceFrequency,
    RecurrenceFrequency,
    String
  >
  get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get intervalCount => $composableBuilder(
    column: $table.intervalCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get startAt =>
      $composableBuilder(
        column: $table.startAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get nextDueAt =>
      $composableBuilder(
        column: $table.nextDueAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get endAt =>
      $composableBuilder(
        column: $table.endAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<ReminderLead>, List<ReminderLead>, String>
  get reminderLeads => $composableBuilder(
    column: $table.reminderLeads,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get archivedAt =>
      $composableBuilder(
        column: $table.archivedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> obligationOccurrencesRefs(
    Expression<bool> Function($$ObligationOccurrencesTableFilterComposer f) f,
  ) {
    final $$ObligationOccurrencesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.obligationOccurrences,
          getReferencedColumn: (t) => t.obligationId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ObligationOccurrencesTableFilterComposer(
                $db: $db,
                $table: $db.obligationOccurrences,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ObligationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ObligationsTable> {
  $$ObligationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalCount => $composableBuilder(
    column: $table.intervalCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextDueAt => $composableBuilder(
    column: $table.nextDueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderLeads => $composableBuilder(
    column: $table.reminderLeads,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ObligationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ObligationsTable> {
  $$ObligationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ObligationCategory, String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<RecurrenceFrequency, String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<int> get intervalCount => $composableBuilder(
    column: $table.intervalCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, String> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get nextDueAt =>
      $composableBuilder(column: $table.nextDueAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<ReminderLead>, String>
  get reminderLeads => $composableBuilder(
    column: $table.reminderLeads,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, int> get archivedAt =>
      $composableBuilder(
        column: $table.archivedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> obligationOccurrencesRefs<T extends Object>(
    Expression<T> Function($$ObligationOccurrencesTableAnnotationComposer a) f,
  ) {
    final $$ObligationOccurrencesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.obligationOccurrences,
          getReferencedColumn: (t) => t.obligationId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ObligationOccurrencesTableAnnotationComposer(
                $db: $db,
                $table: $db.obligationOccurrences,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ObligationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ObligationsTable,
          ObligationRow,
          $$ObligationsTableFilterComposer,
          $$ObligationsTableOrderingComposer,
          $$ObligationsTableAnnotationComposer,
          $$ObligationsTableCreateCompanionBuilder,
          $$ObligationsTableUpdateCompanionBuilder,
          (ObligationRow, $$ObligationsTableReferences),
          ObligationRow,
          PrefetchHooks Function({bool obligationOccurrencesRefs})
        > {
  $$ObligationsTableTableManager(_$AppDatabase db, $ObligationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ObligationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ObligationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ObligationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<ObligationCategory> category = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<RecurrenceFrequency> frequency = const Value.absent(),
                Value<int> intervalCount = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                Value<DateTime> startAt = const Value.absent(),
                Value<DateTime> nextDueAt = const Value.absent(),
                Value<DateTime?> endAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<List<ReminderLead>> reminderLeads = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ObligationsCompanion(
                id: id,
                name: name,
                category: category,
                amountMinor: amountMinor,
                currencyCode: currencyCode,
                frequency: frequency,
                intervalCount: intervalCount,
                dayOfMonth: dayOfMonth,
                startAt: startAt,
                nextDueAt: nextDueAt,
                endAt: endAt,
                note: note,
                reminderLeads: reminderLeads,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required ObligationCategory category,
                required int amountMinor,
                required String currencyCode,
                required RecurrenceFrequency frequency,
                Value<int> intervalCount = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                required DateTime startAt,
                required DateTime nextDueAt,
                Value<DateTime?> endAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<List<ReminderLead>> reminderLeads = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ObligationsCompanion.insert(
                id: id,
                name: name,
                category: category,
                amountMinor: amountMinor,
                currencyCode: currencyCode,
                frequency: frequency,
                intervalCount: intervalCount,
                dayOfMonth: dayOfMonth,
                startAt: startAt,
                nextDueAt: nextDueAt,
                endAt: endAt,
                note: note,
                reminderLeads: reminderLeads,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ObligationsTable, ObligationRow>(table),
                  $$ObligationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({obligationOccurrencesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (obligationOccurrencesRefs) db.obligationOccurrences,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (obligationOccurrencesRefs)
                    await $_getPrefetchedData<
                      ObligationRow,
                      $ObligationsTable,
                      ObligationOccurrenceRow
                    >(
                      currentTable: table,
                      referencedTable: $$ObligationsTableReferences
                          ._obligationOccurrencesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ObligationsTableReferences(
                            db,
                            table,
                            p0,
                          ).obligationOccurrencesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.obligationId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ObligationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ObligationsTable,
      ObligationRow,
      $$ObligationsTableFilterComposer,
      $$ObligationsTableOrderingComposer,
      $$ObligationsTableAnnotationComposer,
      $$ObligationsTableCreateCompanionBuilder,
      $$ObligationsTableUpdateCompanionBuilder,
      (ObligationRow, $$ObligationsTableReferences),
      ObligationRow,
      PrefetchHooks Function({bool obligationOccurrencesRefs})
    >;
typedef $$ObligationOccurrencesTableCreateCompanionBuilder =
    ObligationOccurrencesCompanion Function({
      required String id,
      required String obligationId,
      required String periodKey,
      required DateTime dueAt,
      required int amountMinor,
      required ObligationStatus status,
      Value<DateTime?> paidAt,
      Value<String?> paymentId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ObligationOccurrencesTableUpdateCompanionBuilder =
    ObligationOccurrencesCompanion Function({
      Value<String> id,
      Value<String> obligationId,
      Value<String> periodKey,
      Value<DateTime> dueAt,
      Value<int> amountMinor,
      Value<ObligationStatus> status,
      Value<DateTime?> paidAt,
      Value<String?> paymentId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ObligationOccurrencesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ObligationOccurrencesTable,
          ObligationOccurrenceRow
        > {
  $$ObligationOccurrencesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ObligationsTable _obligationIdTable(_$AppDatabase db) => db
      .obligations
      .createAlias('obligation_occurrences__obligation_id__obligations__id');

  $$ObligationsTableProcessedTableManager get obligationId {
    final $_column = $_itemColumn<String>('obligation_id')!;

    final manager = $$ObligationsTableTableManager(
      $_db,
      $_db.obligations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_obligationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ObligationOccurrencesTableFilterComposer
    extends Composer<_$AppDatabase, $ObligationOccurrencesTable> {
  $$ObligationOccurrencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get dueAt =>
      $composableBuilder(
        column: $table.dueAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ObligationStatus, ObligationStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get paidAt =>
      $composableBuilder(
        column: $table.paidAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get paymentId => $composableBuilder(
    column: $table.paymentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$ObligationsTableFilterComposer get obligationId {
    final $$ObligationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.obligationId,
      referencedTable: $db.obligations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ObligationsTableFilterComposer(
            $db: $db,
            $table: $db.obligations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ObligationOccurrencesTableOrderingComposer
    extends Composer<_$AppDatabase, $ObligationOccurrencesTable> {
  $$ObligationOccurrencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentId => $composableBuilder(
    column: $table.paymentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ObligationsTableOrderingComposer get obligationId {
    final $$ObligationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.obligationId,
      referencedTable: $db.obligations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ObligationsTableOrderingComposer(
            $db: $db,
            $table: $db.obligations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ObligationOccurrencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ObligationOccurrencesTable> {
  $$ObligationOccurrencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get periodKey =>
      $composableBuilder(column: $table.periodKey, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ObligationStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);

  GeneratedColumn<String> get paymentId =>
      $composableBuilder(column: $table.paymentId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ObligationsTableAnnotationComposer get obligationId {
    final $$ObligationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.obligationId,
      referencedTable: $db.obligations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ObligationsTableAnnotationComposer(
            $db: $db,
            $table: $db.obligations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ObligationOccurrencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ObligationOccurrencesTable,
          ObligationOccurrenceRow,
          $$ObligationOccurrencesTableFilterComposer,
          $$ObligationOccurrencesTableOrderingComposer,
          $$ObligationOccurrencesTableAnnotationComposer,
          $$ObligationOccurrencesTableCreateCompanionBuilder,
          $$ObligationOccurrencesTableUpdateCompanionBuilder,
          (ObligationOccurrenceRow, $$ObligationOccurrencesTableReferences),
          ObligationOccurrenceRow,
          PrefetchHooks Function({bool obligationId})
        > {
  $$ObligationOccurrencesTableTableManager(
    _$AppDatabase db,
    $ObligationOccurrencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ObligationOccurrencesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ObligationOccurrencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ObligationOccurrencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> obligationId = const Value.absent(),
                Value<String> periodKey = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<ObligationStatus> status = const Value.absent(),
                Value<DateTime?> paidAt = const Value.absent(),
                Value<String?> paymentId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ObligationOccurrencesCompanion(
                id: id,
                obligationId: obligationId,
                periodKey: periodKey,
                dueAt: dueAt,
                amountMinor: amountMinor,
                status: status,
                paidAt: paidAt,
                paymentId: paymentId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String obligationId,
                required String periodKey,
                required DateTime dueAt,
                required int amountMinor,
                required ObligationStatus status,
                Value<DateTime?> paidAt = const Value.absent(),
                Value<String?> paymentId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ObligationOccurrencesCompanion.insert(
                id: id,
                obligationId: obligationId,
                periodKey: periodKey,
                dueAt: dueAt,
                amountMinor: amountMinor,
                status: status,
                paidAt: paidAt,
                paymentId: paymentId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ObligationOccurrencesTable,
                    ObligationOccurrenceRow
                  >(table),
                  $$ObligationOccurrencesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({obligationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (obligationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.obligationId,
                                referencedTable:
                                    $$ObligationOccurrencesTableReferences
                                        ._obligationIdTable(db),
                                referencedColumn:
                                    $$ObligationOccurrencesTableReferences
                                        ._obligationIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ObligationOccurrencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ObligationOccurrencesTable,
      ObligationOccurrenceRow,
      $$ObligationOccurrencesTableFilterComposer,
      $$ObligationOccurrencesTableOrderingComposer,
      $$ObligationOccurrencesTableAnnotationComposer,
      $$ObligationOccurrencesTableCreateCompanionBuilder,
      $$ObligationOccurrencesTableUpdateCompanionBuilder,
      (ObligationOccurrenceRow, $$ObligationOccurrencesTableReferences),
      ObligationOccurrenceRow,
      PrefetchHooks Function({bool obligationId})
    >;
typedef $$RemindersTableCreateCompanionBuilder =
    RemindersCompanion Function({
      required String id,
      required String title,
      Value<String?> note,
      required DateTime dueAt,
      required RelatedEntityType relatedType,
      Value<String?> relatedId,
      required ReminderStatus status,
      Value<int?> notificationId,
      Value<DateTime?> completedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$RemindersTableUpdateCompanionBuilder =
    RemindersCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> note,
      Value<DateTime> dueAt,
      Value<RelatedEntityType> relatedType,
      Value<String?> relatedId,
      Value<ReminderStatus> status,
      Value<int?> notificationId,
      Value<DateTime?> completedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get dueAt =>
      $composableBuilder(
        column: $table.dueAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<RelatedEntityType, RelatedEntityType, String>
  get relatedType => $composableBuilder(
    column: $table.relatedType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get relatedId => $composableBuilder(
    column: $table.relatedId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ReminderStatus, ReminderStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get completedAt =>
      $composableBuilder(
        column: $table.completedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relatedType => $composableBuilder(
    column: $table.relatedType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relatedId => $composableBuilder(
    column: $table.relatedId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RelatedEntityType, String> get relatedType =>
      $composableBuilder(
        column: $table.relatedType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get relatedId =>
      $composableBuilder(column: $table.relatedId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReminderStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, int> get completedAt =>
      $composableBuilder(
        column: $table.completedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          ReminderRow,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (
            ReminderRow,
            BaseReferences<_$AppDatabase, $RemindersTable, ReminderRow>,
          ),
          ReminderRow,
          PrefetchHooks Function()
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<RelatedEntityType> relatedType = const Value.absent(),
                Value<String?> relatedId = const Value.absent(),
                Value<ReminderStatus> status = const Value.absent(),
                Value<int?> notificationId = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                title: title,
                note: note,
                dueAt: dueAt,
                relatedType: relatedType,
                relatedId: relatedId,
                status: status,
                notificationId: notificationId,
                completedAt: completedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> note = const Value.absent(),
                required DateTime dueAt,
                required RelatedEntityType relatedType,
                Value<String?> relatedId = const Value.absent(),
                required ReminderStatus status,
                Value<int?> notificationId = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                title: title,
                note: note,
                dueAt: dueAt,
                relatedType: relatedType,
                relatedId: relatedId,
                status: status,
                notificationId: notificationId,
                completedAt: completedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemindersTable, ReminderRow>(table),
                  BaseReferences<_$AppDatabase, $RemindersTable, ReminderRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      ReminderRow,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (
        ReminderRow,
        BaseReferences<_$AppDatabase, $RemindersTable, ReminderRow>,
      ),
      ReminderRow,
      PrefetchHooks Function()
    >;
typedef $$ActivityEntriesTableCreateCompanionBuilder =
    ActivityEntriesCompanion Function({
      required String id,
      required ActivityType type,
      required RelatedEntityType entityType,
      Value<String?> entityId,
      Value<String> title,
      Value<int?> amountMinor,
      Value<String?> currencyCode,
      Value<String?> detail,
      required DateTime occurredAt,
      Value<int> rowid,
    });
typedef $$ActivityEntriesTableUpdateCompanionBuilder =
    ActivityEntriesCompanion Function({
      Value<String> id,
      Value<ActivityType> type,
      Value<RelatedEntityType> entityType,
      Value<String?> entityId,
      Value<String> title,
      Value<int?> amountMinor,
      Value<String?> currencyCode,
      Value<String?> detail,
      Value<DateTime> occurredAt,
      Value<int> rowid,
    });

class $$ActivityEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ActivityEntriesTable> {
  $$ActivityEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ActivityType, ActivityType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<RelatedEntityType, RelatedEntityType, String>
  get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get occurredAt =>
      $composableBuilder(
        column: $table.occurredAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$ActivityEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivityEntriesTable> {
  $$ActivityEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivityEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivityEntriesTable> {
  $$ActivityEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ActivityType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RelatedEntityType, String> get entityType =>
      $composableBuilder(
        column: $table.entityType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get occurredAt =>
      $composableBuilder(
        column: $table.occurredAt,
        builder: (column) => column,
      );
}

class $$ActivityEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivityEntriesTable,
          ActivityEntryRow,
          $$ActivityEntriesTableFilterComposer,
          $$ActivityEntriesTableOrderingComposer,
          $$ActivityEntriesTableAnnotationComposer,
          $$ActivityEntriesTableCreateCompanionBuilder,
          $$ActivityEntriesTableUpdateCompanionBuilder,
          (
            ActivityEntryRow,
            BaseReferences<
              _$AppDatabase,
              $ActivityEntriesTable,
              ActivityEntryRow
            >,
          ),
          ActivityEntryRow,
          PrefetchHooks Function()
        > {
  $$ActivityEntriesTableTableManager(
    _$AppDatabase db,
    $ActivityEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivityEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivityEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivityEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<ActivityType> type = const Value.absent(),
                Value<RelatedEntityType> entityType = const Value.absent(),
                Value<String?> entityId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> amountMinor = const Value.absent(),
                Value<String?> currencyCode = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivityEntriesCompanion(
                id: id,
                type: type,
                entityType: entityType,
                entityId: entityId,
                title: title,
                amountMinor: amountMinor,
                currencyCode: currencyCode,
                detail: detail,
                occurredAt: occurredAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required ActivityType type,
                required RelatedEntityType entityType,
                Value<String?> entityId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> amountMinor = const Value.absent(),
                Value<String?> currencyCode = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                required DateTime occurredAt,
                Value<int> rowid = const Value.absent(),
              }) => ActivityEntriesCompanion.insert(
                id: id,
                type: type,
                entityType: entityType,
                entityId: entityId,
                title: title,
                amountMinor: amountMinor,
                currencyCode: currencyCode,
                detail: detail,
                occurredAt: occurredAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ActivityEntriesTable, ActivityEntryRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ActivityEntriesTable,
                    ActivityEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivityEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivityEntriesTable,
      ActivityEntryRow,
      $$ActivityEntriesTableFilterComposer,
      $$ActivityEntriesTableOrderingComposer,
      $$ActivityEntriesTableAnnotationComposer,
      $$ActivityEntriesTableCreateCompanionBuilder,
      $$ActivityEntriesTableUpdateCompanionBuilder,
      (
        ActivityEntryRow,
        BaseReferences<_$AppDatabase, $ActivityEntriesTable, ActivityEntryRow>,
      ),
      ActivityEntryRow,
      PrefetchHooks Function()
    >;
typedef $$MonthlySummariesTableCreateCompanionBuilder =
    MonthlySummariesCompanion Function({
      required String id,
      required int year,
      required int month,
      required String currencyCode,
      Value<int> newDebtMinor,
      Value<int> settledMinor,
      Value<int> receivedMinor,
      Value<int> paidOutMinor,
      Value<int> obligationsMinor,
      Value<int> overdueMinor,
      Value<int> peopleCount,
      Value<int> closedDebts,
      Value<int> activeDebts,
      required DateTime generatedAt,
      Value<int> rowid,
    });
typedef $$MonthlySummariesTableUpdateCompanionBuilder =
    MonthlySummariesCompanion Function({
      Value<String> id,
      Value<int> year,
      Value<int> month,
      Value<String> currencyCode,
      Value<int> newDebtMinor,
      Value<int> settledMinor,
      Value<int> receivedMinor,
      Value<int> paidOutMinor,
      Value<int> obligationsMinor,
      Value<int> overdueMinor,
      Value<int> peopleCount,
      Value<int> closedDebts,
      Value<int> activeDebts,
      Value<DateTime> generatedAt,
      Value<int> rowid,
    });

class $$MonthlySummariesTableFilterComposer
    extends Composer<_$AppDatabase, $MonthlySummariesTable> {
  $$MonthlySummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get newDebtMinor => $composableBuilder(
    column: $table.newDebtMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get settledMinor => $composableBuilder(
    column: $table.settledMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receivedMinor => $composableBuilder(
    column: $table.receivedMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paidOutMinor => $composableBuilder(
    column: $table.paidOutMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get obligationsMinor => $composableBuilder(
    column: $table.obligationsMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overdueMinor => $composableBuilder(
    column: $table.overdueMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get peopleCount => $composableBuilder(
    column: $table.peopleCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get closedDebts => $composableBuilder(
    column: $table.closedDebts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activeDebts => $composableBuilder(
    column: $table.activeDebts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get generatedAt =>
      $composableBuilder(
        column: $table.generatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$MonthlySummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $MonthlySummariesTable> {
  $$MonthlySummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get newDebtMinor => $composableBuilder(
    column: $table.newDebtMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get settledMinor => $composableBuilder(
    column: $table.settledMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receivedMinor => $composableBuilder(
    column: $table.receivedMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paidOutMinor => $composableBuilder(
    column: $table.paidOutMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get obligationsMinor => $composableBuilder(
    column: $table.obligationsMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overdueMinor => $composableBuilder(
    column: $table.overdueMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get peopleCount => $composableBuilder(
    column: $table.peopleCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get closedDebts => $composableBuilder(
    column: $table.closedDebts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activeDebts => $composableBuilder(
    column: $table.activeDebts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MonthlySummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MonthlySummariesTable> {
  $$MonthlySummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get newDebtMinor => $composableBuilder(
    column: $table.newDebtMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get settledMinor => $composableBuilder(
    column: $table.settledMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get receivedMinor => $composableBuilder(
    column: $table.receivedMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paidOutMinor => $composableBuilder(
    column: $table.paidOutMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get obligationsMinor => $composableBuilder(
    column: $table.obligationsMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get overdueMinor => $composableBuilder(
    column: $table.overdueMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get peopleCount => $composableBuilder(
    column: $table.peopleCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get closedDebts => $composableBuilder(
    column: $table.closedDebts,
    builder: (column) => column,
  );

  GeneratedColumn<int> get activeDebts => $composableBuilder(
    column: $table.activeDebts,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get generatedAt =>
      $composableBuilder(
        column: $table.generatedAt,
        builder: (column) => column,
      );
}

class $$MonthlySummariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MonthlySummariesTable,
          MonthlySummaryRow,
          $$MonthlySummariesTableFilterComposer,
          $$MonthlySummariesTableOrderingComposer,
          $$MonthlySummariesTableAnnotationComposer,
          $$MonthlySummariesTableCreateCompanionBuilder,
          $$MonthlySummariesTableUpdateCompanionBuilder,
          (
            MonthlySummaryRow,
            BaseReferences<
              _$AppDatabase,
              $MonthlySummariesTable,
              MonthlySummaryRow
            >,
          ),
          MonthlySummaryRow,
          PrefetchHooks Function()
        > {
  $$MonthlySummariesTableTableManager(
    _$AppDatabase db,
    $MonthlySummariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MonthlySummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MonthlySummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MonthlySummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<int> month = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<int> newDebtMinor = const Value.absent(),
                Value<int> settledMinor = const Value.absent(),
                Value<int> receivedMinor = const Value.absent(),
                Value<int> paidOutMinor = const Value.absent(),
                Value<int> obligationsMinor = const Value.absent(),
                Value<int> overdueMinor = const Value.absent(),
                Value<int> peopleCount = const Value.absent(),
                Value<int> closedDebts = const Value.absent(),
                Value<int> activeDebts = const Value.absent(),
                Value<DateTime> generatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MonthlySummariesCompanion(
                id: id,
                year: year,
                month: month,
                currencyCode: currencyCode,
                newDebtMinor: newDebtMinor,
                settledMinor: settledMinor,
                receivedMinor: receivedMinor,
                paidOutMinor: paidOutMinor,
                obligationsMinor: obligationsMinor,
                overdueMinor: overdueMinor,
                peopleCount: peopleCount,
                closedDebts: closedDebts,
                activeDebts: activeDebts,
                generatedAt: generatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int year,
                required int month,
                required String currencyCode,
                Value<int> newDebtMinor = const Value.absent(),
                Value<int> settledMinor = const Value.absent(),
                Value<int> receivedMinor = const Value.absent(),
                Value<int> paidOutMinor = const Value.absent(),
                Value<int> obligationsMinor = const Value.absent(),
                Value<int> overdueMinor = const Value.absent(),
                Value<int> peopleCount = const Value.absent(),
                Value<int> closedDebts = const Value.absent(),
                Value<int> activeDebts = const Value.absent(),
                required DateTime generatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MonthlySummariesCompanion.insert(
                id: id,
                year: year,
                month: month,
                currencyCode: currencyCode,
                newDebtMinor: newDebtMinor,
                settledMinor: settledMinor,
                receivedMinor: receivedMinor,
                paidOutMinor: paidOutMinor,
                obligationsMinor: obligationsMinor,
                overdueMinor: overdueMinor,
                peopleCount: peopleCount,
                closedDebts: closedDebts,
                activeDebts: activeDebts,
                generatedAt: generatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MonthlySummariesTable, MonthlySummaryRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MonthlySummariesTable,
                    MonthlySummaryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MonthlySummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MonthlySummariesTable,
      MonthlySummaryRow,
      $$MonthlySummariesTableFilterComposer,
      $$MonthlySummariesTableOrderingComposer,
      $$MonthlySummariesTableAnnotationComposer,
      $$MonthlySummariesTableCreateCompanionBuilder,
      $$MonthlySummariesTableUpdateCompanionBuilder,
      (
        MonthlySummaryRow,
        BaseReferences<
          _$AppDatabase,
          $MonthlySummariesTable,
          MonthlySummaryRow
        >,
      ),
      MonthlySummaryRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      required AppLanguage language,
      required AppThemeMode themeMode,
      required NumeralsStyle numerals,
      required String defaultCurrencyCode,
      Value<bool> notificationsEnabled,
      Value<int> notificationHour,
      Value<int> notificationMinute,
      Value<List<ReminderLead>> defaultReminderLeads,
      Value<bool> monthEndSummaryEnabled,
      required MonthEndDay monthEndDay,
      Value<int> monthEndHour,
      Value<int> monthEndMinute,
      Value<int> dueSoonWindowDays,
      Value<bool> lockEnabled,
      Value<bool> biometricEnabled,
      Value<bool> onboardingCompleted,
      Value<bool> backupAutoEnabled,
      Value<DateTime?> lastSummarySentOn,
      Value<DateTime?> lastExportedAt,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      Value<AppLanguage> language,
      Value<AppThemeMode> themeMode,
      Value<NumeralsStyle> numerals,
      Value<String> defaultCurrencyCode,
      Value<bool> notificationsEnabled,
      Value<int> notificationHour,
      Value<int> notificationMinute,
      Value<List<ReminderLead>> defaultReminderLeads,
      Value<bool> monthEndSummaryEnabled,
      Value<MonthEndDay> monthEndDay,
      Value<int> monthEndHour,
      Value<int> monthEndMinute,
      Value<int> dueSoonWindowDays,
      Value<bool> lockEnabled,
      Value<bool> biometricEnabled,
      Value<bool> onboardingCompleted,
      Value<bool> backupAutoEnabled,
      Value<DateTime?> lastSummarySentOn,
      Value<DateTime?> lastExportedAt,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AppLanguage, AppLanguage, String>
  get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<AppThemeMode, AppThemeMode, String>
  get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<NumeralsStyle, NumeralsStyle, String>
  get numerals => $composableBuilder(
    column: $table.numerals,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get defaultCurrencyCode => $composableBuilder(
    column: $table.defaultCurrencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationHour => $composableBuilder(
    column: $table.notificationHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationMinute => $composableBuilder(
    column: $table.notificationMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<ReminderLead>, List<ReminderLead>, String>
  get defaultReminderLeads => $composableBuilder(
    column: $table.defaultReminderLeads,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get monthEndSummaryEnabled => $composableBuilder(
    column: $table.monthEndSummaryEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MonthEndDay, MonthEndDay, String>
  get monthEndDay => $composableBuilder(
    column: $table.monthEndDay,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get monthEndHour => $composableBuilder(
    column: $table.monthEndHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthEndMinute => $composableBuilder(
    column: $table.monthEndMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueSoonWindowDays => $composableBuilder(
    column: $table.dueSoonWindowDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lockEnabled => $composableBuilder(
    column: $table.lockEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get biometricEnabled => $composableBuilder(
    column: $table.biometricEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get backupAutoEnabled => $composableBuilder(
    column: $table.backupAutoEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String>
  get lastSummarySentOn => $composableBuilder(
    column: $table.lastSummarySentOn,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastExportedAt =>
      $composableBuilder(
        column: $table.lastExportedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get numerals => $composableBuilder(
    column: $table.numerals,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultCurrencyCode => $composableBuilder(
    column: $table.defaultCurrencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationHour => $composableBuilder(
    column: $table.notificationHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationMinute => $composableBuilder(
    column: $table.notificationMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultReminderLeads => $composableBuilder(
    column: $table.defaultReminderLeads,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get monthEndSummaryEnabled => $composableBuilder(
    column: $table.monthEndSummaryEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monthEndDay => $composableBuilder(
    column: $table.monthEndDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthEndHour => $composableBuilder(
    column: $table.monthEndHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthEndMinute => $composableBuilder(
    column: $table.monthEndMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueSoonWindowDays => $composableBuilder(
    column: $table.dueSoonWindowDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lockEnabled => $composableBuilder(
    column: $table.lockEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get biometricEnabled => $composableBuilder(
    column: $table.biometricEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get backupAutoEnabled => $composableBuilder(
    column: $table.backupAutoEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSummarySentOn => $composableBuilder(
    column: $table.lastSummarySentOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastExportedAt => $composableBuilder(
    column: $table.lastExportedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AppLanguage, String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AppThemeMode, String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumnWithTypeConverter<NumeralsStyle, String> get numerals =>
      $composableBuilder(column: $table.numerals, builder: (column) => column);

  GeneratedColumn<String> get defaultCurrencyCode => $composableBuilder(
    column: $table.defaultCurrencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationHour => $composableBuilder(
    column: $table.notificationHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationMinute => $composableBuilder(
    column: $table.notificationMinute,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<ReminderLead>, String>
  get defaultReminderLeads => $composableBuilder(
    column: $table.defaultReminderLeads,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get monthEndSummaryEnabled => $composableBuilder(
    column: $table.monthEndSummaryEnabled,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MonthEndDay, String> get monthEndDay =>
      $composableBuilder(
        column: $table.monthEndDay,
        builder: (column) => column,
      );

  GeneratedColumn<int> get monthEndHour => $composableBuilder(
    column: $table.monthEndHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get monthEndMinute => $composableBuilder(
    column: $table.monthEndMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueSoonWindowDays => $composableBuilder(
    column: $table.dueSoonWindowDays,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get lockEnabled => $composableBuilder(
    column: $table.lockEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get biometricEnabled => $composableBuilder(
    column: $table.biometricEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get backupAutoEnabled => $composableBuilder(
    column: $table.backupAutoEnabled,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, String> get lastSummarySentOn =>
      $composableBuilder(
        column: $table.lastSummarySentOn,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastExportedAt =>
      $composableBuilder(
        column: $table.lastExportedAt,
        builder: (column) => column,
      );
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<AppLanguage> language = const Value.absent(),
                Value<AppThemeMode> themeMode = const Value.absent(),
                Value<NumeralsStyle> numerals = const Value.absent(),
                Value<String> defaultCurrencyCode = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<int> notificationHour = const Value.absent(),
                Value<int> notificationMinute = const Value.absent(),
                Value<List<ReminderLead>> defaultReminderLeads =
                    const Value.absent(),
                Value<bool> monthEndSummaryEnabled = const Value.absent(),
                Value<MonthEndDay> monthEndDay = const Value.absent(),
                Value<int> monthEndHour = const Value.absent(),
                Value<int> monthEndMinute = const Value.absent(),
                Value<int> dueSoonWindowDays = const Value.absent(),
                Value<bool> lockEnabled = const Value.absent(),
                Value<bool> biometricEnabled = const Value.absent(),
                Value<bool> onboardingCompleted = const Value.absent(),
                Value<bool> backupAutoEnabled = const Value.absent(),
                Value<DateTime?> lastSummarySentOn = const Value.absent(),
                Value<DateTime?> lastExportedAt = const Value.absent(),
              }) => SettingsCompanion(
                id: id,
                language: language,
                themeMode: themeMode,
                numerals: numerals,
                defaultCurrencyCode: defaultCurrencyCode,
                notificationsEnabled: notificationsEnabled,
                notificationHour: notificationHour,
                notificationMinute: notificationMinute,
                defaultReminderLeads: defaultReminderLeads,
                monthEndSummaryEnabled: monthEndSummaryEnabled,
                monthEndDay: monthEndDay,
                monthEndHour: monthEndHour,
                monthEndMinute: monthEndMinute,
                dueSoonWindowDays: dueSoonWindowDays,
                lockEnabled: lockEnabled,
                biometricEnabled: biometricEnabled,
                onboardingCompleted: onboardingCompleted,
                backupAutoEnabled: backupAutoEnabled,
                lastSummarySentOn: lastSummarySentOn,
                lastExportedAt: lastExportedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required AppLanguage language,
                required AppThemeMode themeMode,
                required NumeralsStyle numerals,
                required String defaultCurrencyCode,
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<int> notificationHour = const Value.absent(),
                Value<int> notificationMinute = const Value.absent(),
                Value<List<ReminderLead>> defaultReminderLeads =
                    const Value.absent(),
                Value<bool> monthEndSummaryEnabled = const Value.absent(),
                required MonthEndDay monthEndDay,
                Value<int> monthEndHour = const Value.absent(),
                Value<int> monthEndMinute = const Value.absent(),
                Value<int> dueSoonWindowDays = const Value.absent(),
                Value<bool> lockEnabled = const Value.absent(),
                Value<bool> biometricEnabled = const Value.absent(),
                Value<bool> onboardingCompleted = const Value.absent(),
                Value<bool> backupAutoEnabled = const Value.absent(),
                Value<DateTime?> lastSummarySentOn = const Value.absent(),
                Value<DateTime?> lastExportedAt = const Value.absent(),
              }) => SettingsCompanion.insert(
                id: id,
                language: language,
                themeMode: themeMode,
                numerals: numerals,
                defaultCurrencyCode: defaultCurrencyCode,
                notificationsEnabled: notificationsEnabled,
                notificationHour: notificationHour,
                notificationMinute: notificationMinute,
                defaultReminderLeads: defaultReminderLeads,
                monthEndSummaryEnabled: monthEndSummaryEnabled,
                monthEndDay: monthEndDay,
                monthEndHour: monthEndHour,
                monthEndMinute: monthEndMinute,
                dueSoonWindowDays: dueSoonWindowDays,
                lockEnabled: lockEnabled,
                biometricEnabled: biometricEnabled,
                onboardingCompleted: onboardingCompleted,
                backupAutoEnabled: backupAutoEnabled,
                lastSummarySentOn: lastSummarySentOn,
                lastExportedAt: lastExportedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db, _db.people);
  $$DebtsTableTableManager get debts =>
      $$DebtsTableTableManager(_db, _db.debts);
  $$DebtPeopleTableTableManager get debtPeople =>
      $$DebtPeopleTableTableManager(_db, _db.debtPeople);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db, _db.payments);
  $$ObligationsTableTableManager get obligations =>
      $$ObligationsTableTableManager(_db, _db.obligations);
  $$ObligationOccurrencesTableTableManager get obligationOccurrences =>
      $$ObligationOccurrencesTableTableManager(_db, _db.obligationOccurrences);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$ActivityEntriesTableTableManager get activityEntries =>
      $$ActivityEntriesTableTableManager(_db, _db.activityEntries);
  $$MonthlySummariesTableTableManager get monthlySummaries =>
      $$MonthlySummariesTableTableManager(_db, _db.monthlySummaries);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
