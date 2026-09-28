import '../../core/money/currency.dart';
import '../entities/activity_entry.dart';
import '../entities/app_settings.dart';
import '../entities/debt.dart';
import '../entities/monthly_summary.dart';
import '../entities/obligation.dart';
import '../entities/payment.dart';
import '../entities/person.dart';
import '../entities/reminder.dart';
import '../enums/obligation_enums.dart';

/// Storage contracts for the domain layer.
///
/// The UI and the services depend only on these; the SQLite implementation lives
/// behind them. Every `watch*` member returns a stream that re-emits whenever the
/// underlying rows change, which is what makes the whole app update live without
/// any manual refresh.
abstract interface class PersonRepository {
  Stream<List<Person>> watchAll();

  Future<List<Person>> getAll();

  Future<Person?> getById(String id);

  Future<Person?> findByName(String name);

  Stream<Person?> watchById(String id);

  Future<void> save(Person person);

  Future<void> setArchived(String id, {required bool archived});

  Future<void> delete(String id);

  Future<int> countActive();
}

abstract interface class DebtRepository {
  Stream<List<Debt>> watchAll();

  Future<List<Debt>> getAll();

  Future<Debt?> getById(String id);

  Stream<Debt?> watchById(String id);

  Stream<List<Debt>> watchForPerson(String personId);

  Future<List<Debt>> forPerson(String personId);

  Future<void> save(Debt debt);

  /// Replaces who a record is with, leaving every other field alone.
  Future<void> setParticipants(String debtId, List<String> personIds);

  Future<void> setArchived(String id, {required bool archived});

  /// Stamps or clears the moment the balance reached zero.
  Future<void> setClosed(String id, DateTime? closedAt);

  Future<void> reassignPerson(String fromPersonId, String? toPersonId);

  Future<void> delete(String id);
}

abstract interface class PaymentRepository {
  Stream<List<Payment>> watchAll();

  Future<List<Payment>> getAll();

  Future<Payment?> getById(String id);

  Stream<List<Payment>> watchForDebt(String debtId);

  Future<List<Payment>> forDebt(String debtId);


  Stream<List<Payment>> watchForPerson(String personId);

  Future<void> save(Payment payment);

  Future<void> delete(String id);

  Future<void> deleteForDebt(String debtId);
}

abstract interface class ObligationRepository {
  Stream<List<Obligation>> watchAll();

  Future<List<Obligation>> getAll();

  Future<Obligation?> getById(String id);

  Stream<Obligation?> watchById(String id);

  Future<void> save(Obligation obligation);

  Future<void> setArchived(String id, {required bool archived});

  Future<void> delete(String id);

  Stream<List<ObligationOccurrence>> watchOccurrences();

  /// Every occurrence in one read, for the read models and the reports.
  Future<List<ObligationOccurrence>> allOccurrences();

  Stream<List<ObligationOccurrence>> watchOccurrencesFor(String obligationId);

  Future<List<ObligationOccurrence>> occurrencesFor(String obligationId);

  Future<ObligationOccurrence?> occurrenceById(String id);

  Future<void> saveOccurrence(ObligationOccurrence occurrence);

  Future<void> saveOccurrences(List<ObligationOccurrence> occurrences);

  Future<void> deleteOccurrence(String id);

  Future<void> deleteOccurrencesFor(String obligationId);

  /// Period keys already materialised for an obligation.
  Future<Set<String>> existingPeriodKeys(String obligationId);
}

abstract interface class ReminderRepository {
  Stream<List<Reminder>> watchAll();

  Future<List<Reminder>> getAll();

  Future<List<Reminder>> getOpen();

  Future<Reminder?> getById(String id);

  Stream<Reminder?> watchById(String id);

  Future<void> save(Reminder reminder);

  Future<void> setStatus(
    String id,
    ReminderStatus status, {
    DateTime? completedAt,
  });

  Future<void> delete(String id);
}

abstract interface class ActivityRepository {
  Stream<List<ActivityEntry>> watchRecent({int limit});

  Stream<List<ActivityEntry>> watchForEntity(RelatedEntityType type, String id);

  Stream<List<ActivityEntry>> watchForEntities(
    RelatedEntityType type,
    List<String> ids,
  );

  Stream<List<ActivityEntry>> watchRange(DateTime from, DateTime to);

  Future<List<ActivityEntry>> recent({int limit});

  Future<List<ActivityEntry>> forEntity(RelatedEntityType type, String id);

  Future<void> add(ActivityEntry entry);

  Future<void> addAll(List<ActivityEntry> entries);

  Future<void> deleteForEntity(RelatedEntityType type, String id);

  Future<void> deleteAll();
}

abstract interface class MonthlySummaryRepository {
  Future<MonthlySummary?> get(int year, int month, AppCurrency currency);

  Stream<MonthlySummary?> watch(int year, int month, AppCurrency currency);

  Future<void> save(MonthlySummary summary);

  Future<void> deleteForMonth(int year, int month);
}

abstract interface class SettingsRepository {
  /// Emits the current settings and every later change.
  Stream<AppSettings> watch();

  Future<AppSettings> get();

  Future<void> save(AppSettings settings);

  /// Read-modify-write helper. Serialised by the database, so concurrent
  /// toggles from different screens cannot lose each other's changes.
  Future<AppSettings> update(AppSettings Function(AppSettings current) transform);
}
