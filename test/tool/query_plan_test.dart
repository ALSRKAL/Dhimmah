import 'package:dhimmah/data/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

/// What SQLite actually does with the app's hot queries.
void main() {
  // Seeding a ledger at scale takes longer than the default budget.
  test('query plans', timeout: const Timeout(Duration(minutes: 3)), () async {
    final AppDatabase db = AppDatabase.memory();
    // Force the schema, then ask the planner.
    await db.customSelect('SELECT 1').get();

    // EXPLAIN only plans, it never runs, so literals stand in for the bound
    // parameters without changing the plan. The app's own queries are built by
    // drift's query builder and bind every value.
    Future<void> plan(String label, String sql) async {
      final List<QueryRow> rows =
          await db.customSelect('EXPLAIN QUERY PLAN $sql').get();
      // ignore: avoid_print
      print('--- $label');
      for (final QueryRow row in rows) {
        // ignore: avoid_print
        print('    ${row.data['detail']}');
      }
    }

    // One person's records, in the shape the person page asks for them: the
    // link table decides who is on a record, so the plan has to be read from
    // the join over `debt_people` rather than from the mirror column.
    await plan(
      'debts for one person',
      'SELECT * FROM debts WHERE id IN '
          "(SELECT debt_id FROM debt_people WHERE person_id = 'p1')",
    );
    await plan(
      'participants of one debt',
      "SELECT person_id FROM debt_people WHERE debt_id = 'd1_1' "
          'ORDER BY position ASC',
    );
    await plan(
      'every participant, in order',
      'SELECT debt_id, person_id FROM debt_people ORDER BY position ASC',
    );
    await plan('payments for one debt',
        "SELECT * FROM payments WHERE debt_id = 'd1_1'");
    await plan('payment totals by debt',
        'SELECT debt_id, SUM(amount_minor), COUNT(id), MAX(paid_at) '
        'FROM payments GROUP BY debt_id');
    await plan('occurrences for one obligation',
        "SELECT * FROM obligation_occurrences WHERE obligation_id = 'o1'");
    await plan('all occurrences by due',
        'SELECT * FROM obligation_occurrences ORDER BY due_at');
    await plan('activity for an entity',
        "SELECT * FROM activity_entries WHERE entity_type = 'debt' "
        "AND entity_id = 'd1_1' ORDER BY occurred_at DESC");
    await plan('recent activity',
        'SELECT * FROM activity_entries ORDER BY occurred_at DESC LIMIT 12');
    await plan('people by name', "SELECT * FROM people WHERE name LIKE '%a%'");
    await plan('all payments', 'SELECT * FROM payments');
    await plan('payments in a date range',
        "SELECT * FROM payments WHERE paid_at >= '2026-01-01' "
        "AND paid_at <= '2026-12-31'");
    await plan('obligation by id', "SELECT * FROM obligations WHERE id = 'o1'");
    await plan('debts by due date',
        'SELECT * FROM debts WHERE due_at IS NOT NULL ORDER BY due_at');

    // What the schema actually has.
    final List<QueryRow> indexes = await db
        .customSelect(
          'SELECT name, tbl_name FROM sqlite_master '
          "WHERE type = 'index' AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    // ignore: avoid_print
    print('--- indexes (${indexes.length})');
    for (final QueryRow row in indexes) {
      // ignore: avoid_print
      print('    ${row.data['tbl_name']}.${row.data['name']}');
    }

    await db.close();
  });
}
