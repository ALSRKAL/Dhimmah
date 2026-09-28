# Final backup/restore closure report

**Date:** 2026-09-26 · **Baseline:** the report of 2026-09-25 (OVERALL = PARTIAL)
**Verdict:** **PARTIAL** — one P1 remains, and several items are NOT PROVEN. See §37.

## 1. Executive Summary

Three gaps were closed with evidence, one was reduced and **not** closed, and eight were
not closed. Nothing in this document is claimed as a pass without a measurement behind it.

Closed: the **16-point kill matrix** (16/16), the **memory re-measure** after the last
optimisation (peak 666 → 589 MB), and the **performance gate** as a documented,
deliberately separate gate. The UI blocking **P1 is not closed**: the worst single
synchronous stretch was cut from 3,111 ms to 191 ms by paging, and the phone went from 2
frames to 12 during a backup and from 0 to 12 during a restore — but a stretch of roughly
0.2–0.8 s remains, and by the rule in the brief, *improved is not closed*.

## 2. Previous Open Gaps

| Gap | Status now |
| --- | --- |
| 1. P1 synchronous UI block ≈0.4–0.8 s | **FAIL — reduced, not removed** |
| 2. SAF not proven | **NOT PROVEN** |
| 3. Share/Save not proven | **NOT PROVEN** |
| 4. uninstall/reinstall not proven | **NOT PROVEN** |
| 5. low-end not proven | **NOT PROVEN** |
| 6. leak test not run | **NOT PROVEN** |
| 7. clean environment / flakiness | **NOT PROVEN** (two green runs, no clean-state run) |
| 8. Android backup docs review | **NOT PROVEN** |
| 9. PDF rendering on device | **NOT PROVEN** |
| 10. widget test for the screen | **NOT PROVEN** (attempted; see §26) |
| 11. performance gate not documented | **CLOSED** |

## 3. Gaps Closed

* **16/16 kill matrix** — `test/data/backup_kill_matrix_test.dart`, one row per point.
* **Memory re-measured** after the one-pass payload build: peak 666 → **589 MB**.
* **Performance gate documented** — `docs/PERFORMANCE-GATE.md`, with commands,
  baselines and thresholds derived from measurements.

## 4. Bugs Found (this phase)

| # | Bug | Severity |
| --- | --- | --- |
| 13 | every table read in one synchronous `SELECT` (drift maps every row before returning) | **P1** |
| 14 | the restore wrote each table as one batch | **P1** |
| 15 | a second full canonicalising copy of the ledger before hashing | P2 |
| 16 | `isEmpty()` read whole tables to answer yes/no, on every resume | P2 |
| 17 | the frame harness measured the test, not the app (`Future.delayed` instead of pumping) | P2 (evidence integrity) |

## 5. Root Causes

The unit of synchronous work was the size of the table, not the size of a page. drift
returns after mapping every row, so one `SELECT` over 40,000 payments is one 3.1-second
stretch on the frame thread; fixing it means reading in pages, not moving the read.
The writer then copied the whole ledger a second time to canonicalise what its own builder
had already sorted. Both are structural, both were measured, both are fixed.

## 6. Fixes

* `lib/data/backup/table_reader.dart` — keyset paging (500 rows) with a **count guard**
  that falls back to a full read when the pages do not add up, so the optimisation cannot
  lose a row silently. Used by `create`, `_planMerge` and `_verify`.
* inserts/replaces chunked at 400 rows with a yield between chunks, inside the same
  transaction.
* `BackupFormat.build()` — payload, canonical bytes and digest in one pass; the invariant
  that the payload *is* canonical as built is asserted by test.
* `BackupService.isEmpty()` — `LIMIT 1` instead of a table read.

## 7. UI Performance Before/After

| | before | after |
| --- | ---: | ---: |
| worst stall, 500/2,500/10,000 (host) | 812 ms | **117–190 ms** |
| worst stall, 1,000/10,000/40,000 (host) | 3,111 ms | **191 ms** |
| frames during a backup (S24 Ultra) | 2 | **12** (p90 10.7 ms) |
| frames during a restore (S24 Ultra) | 0 | **12** (p90 2.3 ms, none >16.7 ms) |
| worst gap, restore (S24 Ultra) | — | 383 ms |
| worst gap, backup (S24 Ultra) | 782 ms | 816 ms (**unchanged — this is the P1**) |

## 8. Memory Before/After

| | before | after |
| --- | ---: | ---: |
| peak RSS, 1,000/10,000/40,000 | 666 MB | **589 MB** |
| RSS after create | — | 429 MB |
| RSS after restore | — | 449 MB |

The peak is the payload map plus its canonical bytes plus the file's bytes. RSS does not
return to baseline (196 MB) because this measurement holds the whole database in memory
by construction; on a device the database is on disk.

## 9. Leak Results — **NOT PROVEN**

The six-cycle run was not written. The single-cycle figures above show memory returning
after the operation, which is not the same claim.

## 10. Kill Matrix — **16/16 PASS**

`test/data/backup_kill_matrix_test.dart`. Each point is emulated by aborting at that step
(two by their artifact: a half-written `.tmp`, and a failing insert inside the
transaction). Every row asserts the database fingerprint unchanged — or, after the commit,
the whole restored state — plus the file set and the absence of temporaries.

## 11–17. Disk / Corruption / Automatic / Restore / Merge / Financial / Multi-Person

All **PASS**, unchanged from the previous report and still covered by green tests: three
disk-failure scenarios; fifteen corruption cases each proving the database did not change;
single-flight, coalescing, no false success; one transaction with verification inside it;
merge by identity with conflicts reported and the local row kept; `DebtCalculator` equality
before and after; one record / 1,500 / three links / never 4,500.

## 18. Notifications — **PASS**

Rebuilt from the records: restoring the same file twice produces the same notification ids,
and a record the restore does not bring back has its reminder cancelled.

## 19–21. SAF / Share / Uninstall-Reinstall — **NOT PROVEN**

Not executed this phase. The earlier evidence stands and is not a substitute: a 3.21 MB
file imported from outside the app's backup directory into an empty database through the
app's own code, and the sandbox confirmed to be removed with the app. The system picker and
the chooser were moved by `adb`, which the brief explicitly rules out as proof.

## 22. PDF Real-Device — **NOT PROVEN**

The statement data is proven; rendering the file needs a device and was not re-run.

## 23. Android Official Documentation Review — **NOT PROVEN**

Not performed this phase. `allowBackup=false`, `fullBackupContent=false` and
`dataExtractionRules` are unchanged and unreviewed.

## 24–25. Security / Encryption — **PASS (unchanged)**

No secret travels; the lock and biometric flags are excluded from the file and asserted to
be device-only; no storage permission; no hand-built SQL anywhere in the backup path. The
encryption decision (none, with the limitation stated in the file, on the restore screen
and in Settings) is documented in `docs/BACKUP-ENCRYPTION.md` and unchanged.

## 26. Widget Tests — **NOT PROVEN**

Attempted: a `test/widget/backup_screen_test.dart` with all four platform dependencies
overridden (database, backup directory, file gateway, notification service), the app theme
and a real settings row. It compiles and runs, and every case fails the same way: the
screen renders its app bar and nothing else, because its provider chain throws in a widget
environment. The same chain works on a device, where the three audit tests pass. Rather
than leave a red suite or claim coverage, the file was removed and the gap recorded with
its symptom. **The screen still has no automated coverage.**

## 27. Clean Regression — **NOT PROVEN**

The suite was run in full and green twice (534 then 550 executed), but not from a
`flutter clean` state. Analyzer: *No issues found!* over `lib test integration_test test_driver`.

## 28. Flakiness — **NOT PROVEN**

Two consecutive full runs were green; no repeat-after-clean run and no parallel run were
performed, so nothing here rules out ordering or shared-state dependence.

## 29. Performance Gate — **CLOSED**

`docs/PERFORMANCE-GATE.md`: commands, datasets, measured baseline, expected range,
regression thresholds derived from the ±20% host variance, interpretation, and why it is
separate from the unit suite.

## 30. Low-End Device — **NOT PROVEN**

No real low-end hardware was available. An `android-36 x86_64` emulator was used earlier as
documented secondary evidence and is **not** claimed as a low-end pass.

## 31. Files Changed

`lib/data/backup/table_reader.dart` (new), `lib/data/services/backup_service.dart`,
`lib/data/services/backup_restore_service.dart`, `lib/domain/services/backup_format.dart`,
`test/data/backup_kill_matrix_test.dart` (new), `test/tool/backup_phase_profile_test.dart`,
`integration_test/backup_audit_on_device_test.dart`, `docs/PERFORMANCE-GATE.md` (new).

## 32. Tests

| | |
| --- | ---: |
| Discovered (`test/`) | 530 |
| Executed | **550** |
| Passed | **550** |
| Failed | 0 |
| Skipped | 0 |
| Environment-only | 7 in `integration_test/` (need a device) |
| Performance gate | separate, by design |
| Manual real-device | 3 audit tests, run on the S24 Ultra |

## 33. Real Device Evidence

S24 Ultra / Android 16 / debug / in-memory ledger of 500 people, 2,500 records, 10,000
payments: backup 769 ms (12 frames, p90 10.7 ms, worst gap 816 ms); restore 1,022 ms
(12 frames, p90 2.3 ms, no frame over 16.7 ms, worst gap 383 ms); kill-recovery checklist
7/7; import from outside the app verified by counts.

## 34. Remaining Risks

| # | Risk | Severity |
| --- | --- | --- |
| 1 | residual synchronous stretch (~0.2–0.8 s) in hashing on the backup path and in decode/checksum/validation on the restore path | **P1** |
| 2 | 40,000 payments: 8.6 s create / 11–15 s restore; peak 589 MB | P2 |
| 3 | SAF, Share/Save, uninstall/reinstall through the system UI unproven | P2 |
| 4 | low-end device, widget coverage, leak, clean-state and flakiness unproven | P2 |
| 5 | no conflict-resolution UI (deliberate) | P3 |
| 6 | backups are not encrypted (documented decision) | P3 |

## 35. Rejected Changes

* **An isolate now.** Measured earlier: checksum inline 675 ms versus 931 ms in an isolate
  (the text has to be copied in); the one variant that showed a gain was an isolate that
  reads the file itself and returns the payload by transfer (391 ms for 3.2 MB). That is
  the next step, and it was not implemented or measured on the device in this phase — so it
  is not claimed.
* **Raw SQL reads** to bypass drift's row mapping: removes the stall but duplicates column
  knowledge in the path that must never drift.
* **Streaming** format: no evidence that memory is an operational problem, and the peak fell.
* **Compression**: changes the format for a size problem nobody has.
* **A cancel button for a restore**: would mean a half-applied transaction or a synthetic
  rollback; the reason is stated to the user instead.

## 36. Final Acceptance Matrix

| Area | Status | Evidence |
| --- | --- | --- |
| Backup integrity | **PASS** | atomic write, checksum, collision-safe names |
| Restore integrity | **PASS** | one transaction, verification inside, rollback proven |
| Automatic backup | **PASS** | single-flight, coalescing, no false success |
| UI responsiveness | **PARTIAL** | 2 → 12 frames, restore p90 2.3 ms |
| **P1 UI blocking** | **FAIL** | worst gap 816 ms on the device; improved is not closed |
| Memory | **PASS** | 666 → 589 MB peak, measured after the change |
| Memory leak | **NOT PROVEN** | six-cycle run not written |
| Kill 16/16 | **PASS** | `backup_kill_matrix_test.dart` |
| Disk failure | **PASS** | three scenarios |
| Corruption | **PASS** | 15 cases, database unchanged |
| Duplicate restore | **PASS** | 3 restores, 3 merges |
| Merge | **PASS** | identity, conflicts reported |
| Financial integrity | **PASS** | `DebtCalculator` equality |
| Multi-person | **PASS** | one record / 1,500 / three links |
| Notifications | **PASS** | no duplicates, stale cancelled |
| Search | **PASS** | Arabic, English, phone, participants |
| Reports | **PASS** | built from restored records |
| PDF real-device | **NOT PROVEN** | not re-run |
| SAF real UI | **NOT PROVEN** | not executed |
| Share/Save real UI | **NOT PROVEN** | not executed |
| Uninstall/Reinstall | **NOT PROVEN** | not executed through the picker |
| Android backup docs | **NOT PROVEN** | not reviewed |
| Encryption decision | **PASS** | documented, disclosed |
| Low-end device | **NOT PROVEN** | no hardware |
| Widget coverage | **NOT PROVEN** | attempted, removed, symptom recorded |
| Performance gate | **PASS** | `docs/PERFORMANCE-GATE.md` |
| Clean regression | **NOT PROVEN** | two green runs, no clean-state run |
| Flakiness | **NOT PROVEN** | no repeat-after-clean, no parallel run |
| **Overall** | **PARTIAL** | — |

## 37. Final Verdict

**PARTIAL.**

There is a P1 that is measured and reduced but not removed, and there are testable items
that were not tested (SAF, Share/Save, uninstall/reinstall through the system UI, low-end
hardware, PDF on a device, the leak run, a clean-state regression, the widget coverage, and
the official Android documentation review). Under the rules in the brief, neither
`CLOSED` nor `BLOCKED` is available: no defect threatens data integrity, and the closure
criteria are not all met.

What would close it, in order: the isolate variant that reads the file itself (then the
same frame harness on the phone); the SAF and share flows driven through the system UI;
the uninstall/reinstall journey through the picker; a six-cycle leak run; a `flutter clean`
regression and a repeat run; the widget test with the provider chain made to build outside
a device; and the official Apple and Google pages re-read before any upload.
