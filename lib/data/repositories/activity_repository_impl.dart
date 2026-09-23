import '../../core/money/currency.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/entities/activity_entry.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/enums/activity_enums.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../domain/repositories/repositories.dart';
import '../database/app_database.dart';
import '../mappers/db_mappers.dart';

/// SQLite-backed activity feed.
class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<ActivityEntry>> watchRecent({int limit = 30}) =>
      _db.activityDao.watchRecent(limit: limit).map(_toEntities);

  @override
  Stream<List<ActivityEntry>> watchForEntity(
    RelatedEntityType type,
    String id,
  ) =>
      _db.activityDao.watchForEntity(type, id).map(_toEntities);

  @override
  Stream<List<ActivityEntry>> watchForEntities(
    RelatedEntityType type,
    List<String> ids,
  ) =>
      _db.activityDao.watchForEntities(type, ids).map(_toEntities);

  @override
  Stream<List<ActivityEntry>> watchRange(DateTime from, DateTime to) =>
      _db.activityDao.watchRange(from, to).map(_toEntities);

  @override
  Future<List<ActivityEntry>> recent({int limit = 30}) async =>
      _toEntities(await _db.activityDao.getRecent(limit: limit));

  @override
  Future<List<ActivityEntry>> forEntity(RelatedEntityType type, String id) async {
    return _toEntities(
      await _db.activityDao.watchForEntity(type, id).first,
    );
  }

  @override
  Future<void> add(ActivityEntry entry) =>
      _db.activityDao.insert(entry.toRow());

  @override
  Future<void> addAll(List<ActivityEntry> entries) => _db.activityDao.insertAll(
        entries.map((ActivityEntry e) => e.toRow()).toList(),
      );

  @override
  Future<void> deleteForEntity(RelatedEntityType type, String id) =>
      _db.activityDao.deleteForEntity(type, id);

  @override
  Future<void> deleteAll() => _db.activityDao.deleteAll();

  static List<ActivityEntry> _toEntities(List<ActivityEntryRow> rows) =>
      rows.map((ActivityEntryRow row) => row.toEntity()).toList(growable: false);
}

/// SQLite-backed monthly summary cache.
class MonthlySummaryRepositoryImpl implements MonthlySummaryRepository {
  MonthlySummaryRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<MonthlySummary?> get(int year, int month, AppCurrency currency) async {
    final MonthlySummaryRow? row =
        await _db.activityDao.getSummary(year, month, currency.code);
    return row?.toEntity();
  }

  @override
  Stream<MonthlySummary?> watch(int year, int month, AppCurrency currency) =>
      _db.activityDao
          .watchSummary(year, month, currency.code)
          .map((MonthlySummaryRow? row) => row?.toEntity());

  @override
  Future<void> save(MonthlySummary summary) {
    return _db.activityDao.upsertSummary(
      MonthlySummaryRow(
        id: '${summary.year}-${summary.month.toString().padLeft(2, '0')}'
            '-${summary.currency.code}',
        year: summary.year,
        month: summary.month,
        currencyCode: summary.currency.code,
        newDebtMinor: summary.newDebtMinor,
        settledMinor: summary.settledMinor,
        receivedMinor: summary.receivedMinor,
        paidOutMinor: summary.paidOutMinor,
        obligationsMinor: summary.obligationsMinor,
        overdueMinor: summary.overdueMinor,
        peopleCount: summary.peopleCount,
        closedDebts: summary.closedDebts,
        activeDebts: summary.activeDebts,
        generatedAt: summary.generatedAt,
      ),
    );
  }

  @override
  Future<void> deleteForMonth(int year, int month) =>
      _db.activityDao.deleteSummaryForMonth(year, month);
}

/// Builds an activity entry.
ActivityEntry newActivityEntry({
  required ActivityType type,
  required RelatedEntityType entityType,
  required String title,
  String? entityId,
  int? amountMinor,
  AppCurrency? currency,
  String? detail,
  DateTime? occurredAt,
}) {
  return ActivityEntry(
    id: newId(),
    type: type,
    entityType: entityType,
    title: title,
    entityId: entityId,
    amountMinor: amountMinor,
    currency: currency,
    detail: detail,
    occurredAt: occurredAt ?? DateTime.now(),
  );
}

/// The window an activity entry falls in, used by the reports screen.
({DateTime start, DateTime end}) monthWindow(int year, int month) {
  final DateTime start = DateTime(year, month);
  return (start: start, end: endOfMonth(start));
}
