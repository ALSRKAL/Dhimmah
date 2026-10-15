# CLAUDE.md

**Read and follow [`AGENTS.md`](./AGENTS.md) before doing anything in this
repository.**

`AGENTS.md` is the single source of truth for the binding rules. It is not a
summary that can drift; read it in full, including the "Known gaps" section,
before touching `lib/`, `test/`, the database, the backup format, the
notification id scheme, or the Android build.

The short version, so the shape of it is obvious before you open the file:

- Dhimmah is local-first and published with real users. The SQLite file on a
  person's phone is the **only** copy of their data.
- **Zero data loss** is the red line: never `destructiveFallback`, never a
  schema change without a real `onUpgrade` step plus a fixture test in
  `test/data/migration_test.dart`, never a change to `applicationId`, the
  backup format, the notification `payload`, or `_identity()`.
- **Git:** no destructive commands (`reset --hard`, `restore`, `clean`, `stash`,
  forced push…) without the developer's explicit permission.
- **Before any commit:** `dart analyze --fatal-infos --fatal-warnings` clean, the
  zero data-loss gate green, and the full suite green.

Two traps worth knowing before you trust a green run:

1. `legacy_upgrade_safety_test.dart` never runs a migration — it builds a current
   v5 in-memory database. `migration_test.dart` is the file that actually
   executes `onUpgrade`.
2. `backward_compatibility_test.dart` skips itself when its fixture is missing and
   prints `All tests skipped`. A skip in the data-loss gate is a failure, not a
   pass. CI seeds the fixture first.