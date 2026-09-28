# Final backup/restore closure — v2

**Date:** 2026-09-26 · **Baseline:** `docs/FINAL-BACKUP-RESTORE-CLOSURE.md` (PARTIAL)
**Verdict: PARTIAL** — see §33. P1 is implemented but not device-measured; SAF, Share,
reinstall, PDF-on-device, leak, clean-run, flakiness, widget coverage and the Android
documentation review remain NOT PROVEN.

## 1. Executive Summary

One P1 fix was executed this phase: the restore's read/decode/checksum/validate path now
runs on a worker isolate that reads the file itself, with an inline fallback so an
unavailable worker can never hang a restore. It is wired, it is covered (all 96 backup
tests pass through it, including the corruption matrix, the 16-point kill matrix and the
round trip, which is what proves the worker and the inline path give identical answers),
and the analyzer is clean.

It is **not** device-measured: the frame run on the phone failed before producing a single
measurement. By the rule in the brief, a change whose effect on the device has not been
measured cannot close a P1 — so P1 is recorded as **implemented, not proven**, and this
phase stays PARTIAL. Everything else on the list (SAF, Share, reinstall, PDF, leak, clean
run, flakiness, widget coverage, Android docs, low-end) was not executed.

## 2. Previous Open Gaps

| Gap | Priority | Status now |
| --- | --- | --- |
| UI blocking (backup hashing + restore decode/checksum/validation) | **P1** | **implemented, device measurement NOT PROVEN** |
| SAF through the system picker | P2 | **NOT PROVEN** |
| Share/Save through the chooser | P2 | **NOT PROVEN** |
| Uninstall → reinstall → restore | P2 | **NOT PROVEN** |
| Six-cycle memory leak run | P2 | **NOT PROVEN** |
| Clean regression (`flutter clean`) + flakiness | P2 | **NOT PROVEN** |
| Widget coverage for the backup screen | P2 | **NOT PROVEN** |
| Performance gate executed on the device | P2 | **NOT PROVEN** |
| PDF rendering verified on a device | P3 | **NOT PROVEN** |
| Android official documentation review | P3 | **NOT PROVEN** |
| Low-end hardware | P2 | **NOT PROVEN** |

## 3. What Was Fixed

`lib/data/backup/backup_worker.dart` (new) + `BackupService.open()` now delegates to it,
with `openInline()` as the reference path and the fallback.

* The worker is handed the **path and the schema version** — nothing large is copied into
  it — and it returns by `Isolate.exit`, which transfers the result instead of copying it.
* The **database is not involved**: the SQLite connection, the transaction and the rest of
  the application stay on the main isolate.
* **It cannot hang**: the isolate is spawned with `onExit` and `onError` wired to the same
  reply port, so a worker that dies without answering still completes the future; a
  `TimeoutException` returns null; and both cases fall back to `openInline()`.
* **It cannot disagree** with the inline path: the worker calls the same
  `BackupFormat.parseEnvelope` and `BackupValidator.validate`. The backup test suites —
  which assert the verdict, the counts and the payload through `open()`/`inspect()` —
  therefore test the worker path on every run.

## 4. Root Causes (this phase)

Decoding, checksumming and validating a multi-megabyte file is ~1.1 s of uninterrupted
synchronous work on the frame thread. Nothing inside it can yield: `jsonDecode`, the
canonicalising hash and the validation loops are each one call. The only way to remove the
freeze without splitting the work by hand is to run it where the frame thread is not — and
the cheap way to do *that* is to hand over the file, not its contents.

## 5. P1 Before/After

| | value | status |
| --- | ---: | --- |
| worst stall, read path, 40k payments (host) | 3,111 ms → **191 ms** | measured |
| frames during a backup, S24 Ultra | 2 → **12** (p90 10.7 ms) | measured (before this phase's change) |
| frames during a restore, S24 Ultra | 0 → **12** (p90 2.3 ms) | measured (before this phase's change) |
| worst gap, backup, S24 Ultra | 782 → **816 ms** | measured — **unchanged; this is the P1** |
| worker isolate for open/decode/checksum/validate | inline 1.1 s → **(391 ms transfer measured earlier, not re-measured here)** | **NOT PROVEN on device** |

The worker's own cost was measured before it was written (391 ms to decode 3.2 MB and
transfer the payload, against ~1.1 s inline). What has *not* been measured is its effect on
the phone: the run failed at build/install and produced no frames.

## 6. Memory Before/After

| | before | after |
| --- | ---: | ---: |
| peak RSS, 1,000/10,000/40,000 | 666 MB | **589 MB** |

The worker adds a second isolate during a restore. An isolate has its own heap, so a
device-side peak for the restore path would be expected to *rise* by roughly the size of
one payload; that has not been measured, and is recorded as an open question rather than a
number.

## 7. Leak Test — **NOT PROVEN**

Not run. Six cycles, memory recorded after each, is the required procedure.

## 8. Kill Matrix — **16/16 PASS**

`test/data/backup_kill_matrix_test.dart`, re-run green after the worker change. Every row
asserts the database fingerprint unchanged (or the whole committed state after the commit),
the file set, and the absence of abandoned temporaries.

## 9–11. SAF / Share / Uninstall-Reinstall — **NOT PROVEN**

None of the three was executed. The brief's prohibitions are respected: `adb` was not used
as a substitute for the picker, and an empty-database import is not counted as a reinstall.

## 12–17. Financial Integrity / Multi-Person / Notifications / Search / Reports / PDF

Financial integrity, multi-person (one record / 1,500 / three links), notifications (no
duplicates, stale cancelled), search and reports are **PASS**, unchanged and still covered
by green tests. PDF rendering on a device is **NOT PROVEN**.

## 18. Android Documentation — **NOT PROVEN**

Not reviewed. `allowBackup=false`, `fullBackupContent=false` and `dataExtractionRules` are
unchanged and unreviewed this phase.

## 19–20. Security / Encryption — **PASS (unchanged)**

No secret leaves the device; the lock and biometric flags are excluded from the file and
asserted device-only; the app asks for no storage permission; no hand-assembled SQL exists
in the backup path (drift's parameterised expressions throughout, including the new
`TableReader`). The encryption decision (none, disclosed in the file, on the restore screen
and in Settings) is documented in `docs/BACKUP-ENCRYPTION.md` and unchanged.

## 21. Low-End — **NOT PROVEN — real low-end hardware unavailable**

No such device was available. No emulator figure is offered as a substitute.

## 22. Widget Coverage — **NOT PROVEN**

Attempted in the previous phase and removed after it failed; the root cause was identified
as the screen's provider chain throwing in a widget environment (the `appVersionProvider`
reads a platform plugin that has no implementation in `flutter test`). The fix is one more
override in the test; it was not implemented in this phase. The screen therefore still has
no automated coverage, and this is recorded as an open gap rather than a deleted problem.

## 23. Performance Gate — **documented, execution NOT PROVEN**

`docs/PERFORMANCE-GATE.md` exists with commands, baselines and thresholds. The gate was not
executed end-to-end after the worker change.

## 24. Clean Regression — **NOT PROVEN**

No `flutter clean` run this phase. The suites were run repeatedly and green.

## 25. Flakiness — **NOT PROVEN**

No repeat-after-clean run and no parallel run. No flaky test has been observed, which is not
the same as flakiness being ruled out.

## 26. Bugs Found

| # | Bug | Severity |
| --- | --- | --- |
| 18 | the restore's whole preparation was one uninterruptible synchronous stretch | **P1** |

(No new defect was found in the application code during this phase. Three test-side
expectation errors were found and fixed while building the kill matrix in the previous
phase.)

## 27. Fixes

`backup_worker.dart` and the `open`/`openInline` split, described in §3.

## 28. Tests

| | |
| --- | ---: |
| Backup suites, after the worker change | **96 passed, 0 failed** |
| Analyzer (`lib test integration_test test_driver`) | **No issues found!** |
| New tests this phase | none (the worker is covered by the existing suites, which exercise `open`/`inspect`) |

## 29. Real Device Evidence

Unchanged from the previous report (S24 Ultra, Android 16, debug): backup 769 ms / 12
frames / p90 10.7 ms / worst gap 816 ms; restore 1,022 ms / 12 frames / p90 2.3 ms; kill
recovery 7/7; import from outside the app verified by counts. **No device run was completed
this phase**, so no figure in this report describes the worker path on hardware.

## 30. Remaining Risks

| # | Risk | Severity |
| --- | --- | --- |
| 1 | the worker path's effect on device frames, memory and restore latency is unmeasured | **P1 (unproven)** |
| 2 | the backup path still hashes inline; its worst gap (816 ms) is unchanged | **P1** |
| 3 | SAF, Share/Save, uninstall/reinstall unproven | P2 |
| 4 | leak, clean run, flakiness, widget coverage, low-end unproven | P2 |
| 5 | the worker adds a second isolate heap during a restore (expected, unmeasured) | P2 |
| 6 | no conflict-resolution UI (deliberate) | P3 |
| 7 | backups are not encrypted (documented) | P3 |

## 31. Rejected Changes

* **Moving the backup's encode/hash to a worker**: the payload map would have to be copied
  into the isolate, which costs about what the work costs; the measured win was in the
  read path, and the read path is what was changed.
* **Offset paging** in `TableReader`: relies on an ordering SQL does not guarantee; keyset
  paging with a count guard is deterministic and self-checking.
* **Raw SQL reads** to bypass drift's row mapping: removes the stall but duplicates column
  knowledge in the path that must never drift.
* **Streaming format and file compression**: no measured need.

## 32. Final Acceptance Matrix

| Area | Status | Evidence |
| --- | --- | --- |
| Backup integrity | **PASS** | atomic write, checksum, collision-safe names |
| Restore integrity | **PASS** | one transaction, verification inside, rollback proven |
| Automatic backup | **PASS** | single-flight, coalescing, no false success |
| UI blocking | **FAIL** | read stall 3,111→191 ms; backup worst gap unchanged at 816 ms |
| **P1** | **FAIL** | worker implemented, device effect **NOT PROVEN** |
| Memory | **PASS** | 666 → 589 MB peak |
| Memory leak | **NOT PROVEN** | six-cycle run not performed |
| Kill 16/16 | **PASS** | `backup_kill_matrix_test.dart`, re-run green |
| Disk failure | **PASS** | three scenarios |
| Corruption | **PASS** | 15 cases, database unchanged |
| Duplicates | **PASS** | 3 restores, 3 merges |
| Merge | **PASS** | identity, conflicts reported |
| Financial integrity | **PASS** | `DebtCalculator` equality |
| Multi-person | **PASS** | one record / 1,500 / three links |
| Notifications | **PASS** | no duplicates, stale cancelled |
| Search | **PASS** | Arabic, English, phone, participants |
| Reports | **PASS** | built from restored records |
| PDF real device | **NOT PROVEN** | not run |
| SAF | **NOT PROVEN** | not run |
| Share | **NOT PROVEN** | not run |
| Uninstall/Reinstall | **NOT PROVEN** | not run |
| Android official review | **NOT PROVEN** | not run |
| Security | **PASS** | no secrets leave; no hand-built SQL |
| Encryption decision | **PASS** | documented and disclosed |
| Low-end | **NOT PROVEN** | no hardware |
| Widget coverage | **NOT PROVEN** | attempted, root cause known, not fixed |
| Performance gate | **NOT PROVEN** | documented, not executed after the change |
| Clean run | **NOT PROVEN** | no `flutter clean` run |
| Flakiness | **NOT PROVEN** | no repeat-after-clean or parallel run |
| Full regression | **PASS (partial)** | 96 backup tests green + analyzer clean; full suite not re-run after the change |
| **Overall** | **PARTIAL** | — |

## 33. Final Verdict

**PARTIAL.**

The P1 fix was executed rather than proposed: the restore's preparation now runs off the
frame thread, and the change is verified where it can be — the same verdicts, the same
payloads, all 96 backup tests green through the new path, analyzer clean. What is missing is
the measurement that would let it be called closed: a device run. Without those frames, and
with SAF, Share, reinstall, PDF-on-device, the leak run, a clean regression, flakiness,
widget coverage and the Android documentation review all untested, `CLOSED` is not
available and `BLOCKED` does not apply — nothing threatens data integrity.

The next three things, in order: run the audit test on the phone to get frames for the
worker path (and the 40k dataset); add the `appVersionProvider` override and reinstate the
widget test; then the SAF and share flows, and the uninstall/reinstall journey through the
system picker.
