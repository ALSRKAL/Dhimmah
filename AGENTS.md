# AGENTS.md — Binding rules for every agent and developer on this repository

Dhimmah is **local-first**. The SQLite file in the app's documents directory is the
only copy of a real person's debts, money and history. There is no server to ask
and no cloud to re-fetch from. The published app has real users.

**The red line:** no change may ever wipe, corrupt, or strand a user's existing
data, break a backup they already took, or break notifications they already
scheduled.

These rules are binding. If a task seems to require breaking one of them, stop and
raise it with the developer instead of proceeding.

---

## 1. Zero data loss

### 1.1 `destructiveFallback` is forbidden — no exceptions

```dart
// FORBIDDEN, in any form, anywhere in lib/
MigrationStrategy(
  destructiveFallback: ...,
)
```

Drift's fallback drops every table and recreates an empty database. It was
deliberately left out of `AppDatabase.migration` and it must stay out. If a
migration genuinely cannot be written, **that is a conversation with the
developer**, not a fallback.

The CI guard fails the build if the string `destructiveFallback` appears anywhere
under `lib/`.

### 1.2 Changing the schema requires a migration *and* two tests

Touching a table, a column, a primary key, a foreign key, or an enum stored as
text (`textEnum`) requires **all** of:

1. **A real step in `onUpgrade`** (`lib/data/database/app_database.dart`).
   Bump `AppDatabase.currentSchemaVersion` in the same change.

   Write the step **additive and idempotent**:
   - add columns with `withDefault(...)` or `nullable()`, never as required;
   - guard schema objects with `CREATE TABLE IF NOT EXISTS` / `IF NOT EXISTS`
     indexes (see the existing `_ensureIndexes()` helper — drift's plain
     `CREATE INDEX` is not conditional, which is how the version 1 upgrade used to
     die half way through with "no such table");
   - backfill with `INSERT OR IGNORE` so a half-applied upgrade can be re-run;
   - **never** use `createAll()` inside `onUpgrade`;
   - the downgrade case (`from > to`) must keep throwing
     `DatabaseTooNewException` *before* anything is written.

2. **A fixture test in `test/data/migration_test.dart`.**
   Build a real file in the shape of the old version using the existing
   `downgrade(db, version)` helper, open it with the current code, and read every
   row back. A new version needs its own `group`.

   When you extend `downgrade()`, make every removal conditional on
   `version < n` for the version that introduced the object — see §4.1.

3. **A record-level test in `test/data/backward_compatibility_test.dart`.**
   Assert that a real record survives with its amounts intact.

**A test that silently skips proves nothing.** `backward_compatibility_test.dart`
currently skips itself when `build/demo/dhimmah_v2.sqlite` is absent (it calls
`markTestSkipped`). Any new coverage you add there must either generate its own
fixture or fail loudly rather than skip. CI generates the fixture before running
this file — see §4.2.

### 1.3 Files that are part of a user's data — treat as a wire format

| What | Where | Breaking change means |
|---|---|---|
| Backup file format + `schemaVersion` | `lib/domain/services/backup_format.dart` | Old backup files stop restoring |
| Backup JSON keys | `lib/data/backup/backup_codec.dart` | Old/new backups stop round-tripping |
| `SharedPreferences` keys | `lib/core/` storage classes | Settings silently reset |
| Notification `payload` | `lib/core/notifications/notification_composer.dart` | Tapping a notification routes nowhere |

These are serialised formats read and written by **builds that are already on
users' phones**. You cannot change them and then "migrate" — the old app is gone.

Rules:
- **Add** keys. Never rename or remove one without a documented reader that still
  accepts the old spelling.
- When you add a backup field, update the **reader's default** so an old file
  missing the key restores with a sane value, and add the field to the
  round-trip tests.
- `bumpCurrentFormatVersion` / `currentFormatVersion` is asserted by
  `legacy_upgrade_safety_test.dart`. If you bump it, that assertion must change
  **in the same commit**, and the reason belongs in the comment above it.

### 1.4 These identifiers are already baked into users' phones

Changing any of these is a silent, unrecoverable break for people who never open
an app update:

| Constant | Value / location | What breaks if it changes |
|---|---|---|
| `applicationId` | `com.dhimmah.dhimmah` (`android/app/build.gradle`) | The update installs as a **different app**; the old data stays behind, unreachable |
| Notification id derivation | `_identity()` + `_hash()` in `notification_composer.dart` | Already-armed alarms can never be cancelled by their new id → **duplicate and orphaned notifications** |

`_identity()` is currently:

```dart
'${intent.payload}|${intent.kind.name}|${intent.when.toIso8601String()}'
```

hashed to a 31-bit FNV-1a. **Every one of those three parts is load-bearing.**

- `payload` — see §1.3.
- `kind.name` — renaming a `NotificationKind` changes every id.
- `when.toIso8601String()` — **any change to how the reminder moment is computed
  changes every id.** This includes timezone handling, the clock provider, DST
  arithmetic, and the lead-time maths. Do not "clean up" the time zone code
  without proving `notification_planner_test.dart` ids are unchanged.

The existing tests pin *stability across passes*
(`notification_planner_test.dart` — "the same reminder gets the same id across
planning passes"). They do **not** pin the literal id value, so a change to
`_identity` would still pass. Treat `_identity` as frozen; if you believe it must
change, stop and raise it.

### 1.5 Removing data on purpose

User-initiated deletes are fine. Verify the intended scope before touching any of:

- `AppDatabase.clearAllData()` — the "delete all data" action.
- `BackupRestoreService` — wipes every row before restoring (by design; verify it
  runs inside a transaction that also holds the restore, or a crash mid-restore
  leaves an empty ledger).
- Backup rotation in `backup_service.dart` — must never delete a file the app did
  not create within its own retention window. `backup_hardening_test.dart` pins
  this ("manual snapshots are never deleted by the app").

---

## 2. Git safety — destructive commands are forbidden without explicit permission

These destroy work that exists nowhere else. **Do not run them** when there are
uncommitted or uncommitted-but-untracked changes, and never without the
developer's explicit go-ahead in the current conversation:

```
git checkout --
git restore
git reset --hard
git reset <commit>          # rewrites published history
git clean -fd / -x
git stash                  # hides work the developer may not know about
git rebase / git push --force
git branch -D
```

Before any commit:

- `git status` and `git diff` — stage **only** the files you intended to change;
- never `git add -A` / `git add .` unless the task is explicitly "commit
  everything";
- never commit a secret (`android/key.properties` is ignored — keep it that way);
- `git log --oneline -10` — match the existing message style.

If you believe a destructive command is required, **stop and ask.** "The tests are
failing and I need to reset" is not permission.

---

## 3. Pre-commit gates — all must be green

Run these in order. A red gate is not "mostly fine".

### 3.1 Static analysis — zero issues

```bash
dart analyze --fatal-infos --fatal-warnings lib test integration_test
```

> `flutter analyze` crashes on a non-ASCII working path (it has on this
> repository's Arabic path). In CI the checkout path is ASCII, so the workflow
> uses `flutter analyze`; locally use the `dart analyze` form above.

### 3.2 Zero data-loss gate — run first, on its own

```bash
flutter test test/data/migration_test.dart \
  test/data/backward_compatibility_test.dart \
  test/data/legacy_upgrade_safety_test.dart \
  test/data/backup_round_trip_test.dart \
  test/data/backup_hardening_test.dart \
  test/data/backup_kill_matrix_test.dart
```

**`migration_test.dart` is not optional.** It is the only file that actually
executes `onUpgrade`. `legacy_upgrade_safety_test.dart` builds a *current* v5
in-memory database and never runs a migration — its name is misleading, and it
will not catch a broken upgrade.

Confirm the count: a silently skipped test prints `~N: All tests skipped`. Treat a
skip in this gate as a **failure**, not a pass.

### 3.3 Full suite

```bash
flutter test
```

The suite is currently **983 passing / 10 skipped**. Record the real number; do
not quote this one from memory if you have just changed something.

### 3.4 After anything touching notifications

```bash
flutter test test/core/notifications/ test/domain/notification_planner_test.dart \
  test/data/notification_lifecycle_test.dart test/data/reminder_plan_test.dart \
  test/widget/notification_routes_test.dart
```

---

## 4. Audit findings — what is fixed and what is still open

### 4.1 FIXED — `downgrade()` built version 3/4 files that no phone ever had

`downgrade()` used to drop `debt_people` **unconditionally**. A real version 3 or
4 file has that table; the fixture did not. Because `from < 3` is false at those
versions the upgrade never recreated it, so the fixture reached `user_version = 5`
without the link table — and the version 4 assertions (settings and language only)
passed anyway.

The removals are now conditional on the version that introduced the object, and a
`group` covers version 3 and version 4 files keeping their link rows and the
index on the link table. **Keep the conditionals** when you add a version:
`drop` belongs to `version < n`, never to the function body.

### 4.2 OPEN — `backward_compatibility_test.dart` skips on a clean checkout

It needs `build/demo/dhimmah_v2.sqlite`, produced by
`test/tool/seed_demo_data_test.dart`. Without it the whole file reports
`All tests skipped` and the gate is a no-op. The CI workflow seeds the fixture
first and fails the gate on any skip — **any new gate you add must do the same**,
or verify its fixtures exist.

### 4.3 OPEN — `migration_test.dart` seeds a small fixture

It seeds three people, two debts, one payment and settings. It does **not**
exercise `payments`, `obligations`, `obligation_occurrences`, `reminders`,
`activity_entries` or `monthly_summaries` across a version bump. Those tables have
never changed shape, which is why this is survivable — but a future change to any
of them must add coverage here first.

### 4.4 OPEN — `_identity()` is only pinned for stability, not for value

`notification_planner_test.dart` proves an id repeats across planning passes. It
does not assert the literal id, so reformatting `_identity()` would pass every
test while stranding every alarm already armed on a user's phone. The CI guard
asserts the shipped form of the function as a string — keep that check in step
with the code (§1.4).

### 4.5 Checked and sound — the restore is atomic

`BackupRestoreService.apply` puts the wipe, the inserts, the replaces, the settings
and the verification inside **one** `_db.transaction(...)`, and takes a safety
snapshot before it. A failure anywhere rolls the whole restore back rather than
leaving an empty ledger. `backup_kill_matrix_test.dart` kills the process at 13
points across a restore, including "inside the database transaction" and "just
before the commit". Do not move any write out of that block without adding a kill
point beside it.

---

## 5. Quick reference — the files that matter

| Concern | File |
|---|---|
| Schema, `schemaVersion`, `onUpgrade` | `lib/data/database/app_database.dart` |
| Table definitions | `lib/data/database/tables.dart` |
| Backup wire format | `lib/domain/services/backup_format.dart` |
| Backup read/write | `lib/data/backup/backup_codec.dart`, `table_reader.dart` |
| Restore path | `lib/data/services/backup_restore_service.dart` |
| Notification id + payload | `lib/core/notifications/notification_composer.dart` |
| Channels, scheduling | `lib/core/notifications/notification_gateway.dart`, `notification_service.dart` |
| `applicationId`, signing | `android/app/build.gradle`, `android/key.properties` (ignored) |
| Manifest permissions | `android/app/src/main/AndroidManifest.xml` |

`SCHEDULE_EXACT_ALARM` is **deliberately absent** from the manifest and must stay
absent — it is restricted by Play Store policy for alarm-clock-style apps and this
is not one. The app uses `inexactAllowWhileIdle` on purpose. The CI guard fails if
it appears.