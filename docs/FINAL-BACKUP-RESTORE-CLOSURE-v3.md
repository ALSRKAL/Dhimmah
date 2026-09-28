# Final backup/restore closure — v3

**Date:** 2026-09-26 · **Baseline:** `docs/FINAL-BACKUP-RESTORE-CLOSURE-v2.md` (PARTIAL)
**Verdict: PARTIAL** — see §35. A device-only restore hang is unresolved, and P1 is not closed.

## Executive Summary

Executed: P1's worker isolate (implemented, wired, unit-verified), a device run of the audit
test, and two attempts at the widget coverage gap. Not executed: SAF, Share/Save,
uninstall/reinstall, PDF on device, the leak run, a clean regression, flakiness, the
performance gate, the Android documentation review, low-end hardware.

The device run is the headline, and not for the reason I hoped:

* the **backup** measured: wall 802 ms, **11 frames**, build p90 **11.5 ms**, worst gap
  **750 ms** — the backup path was not touched this phase, and it shows;
* the **restore never finished**: the test hung at that step and did not complete, so the
  worker path produced **no device measurement at all**.

That hang is unexplained, and it did not happen in the same test on the same phone before
this phase's two changes (`BackupFormat.build()` and the worker). It is recorded as an open
FAIL to diagnose, not as a test artefact to ignore.

## Baseline

v2: 96 backup tests green with the worker wired; full suite 550 green; analyzer clean; peak
memory 666 → 589 MB; worst read stall 3,111 → 191 ms; device frames 2 → 12 (backup) and
0 → 12 (restore) measured **before** the worker change.

## Bugs Found

| # | Bug | Severity | Status |
| --- | --- | --- | --- |
| 19 | the restore step of the audit test hangs on the device after this phase's changes | **P1 (unresolved)** | reproduced twice (once as "did not complete"), cause not yet identified |
| 20 | the widget test cannot drive the screen: real I/O does not progress under `pump`, and resolving the providers inside `runAsync` then hangs too | P2 | diagnosed, not fixed |

## Root Causes

* **#19 — not established.** Two changes landed between the last successful device run and
  this one: `BackupFormat.build()` (writes) and `openOnWorker` (reads). Neither is on the
  path the hung test takes — it calls `read()` and `apply()`, not `open()` — so the
  candidates are (a) the frame-pumping harness interacting with the chunked writes and
  `_breathe()` yields added in the previous phase, or (b) a genuine device-only stall in
  `apply()`. Bisecting the two commits against this test is the first task.
* **#20 — two layers.** `flutter_test` fakes the clock, so the status provider's real file
  and database reads never complete under `tester.pump()`; and once they are resolved
  inside `tester.runAsync()`, the provider chain (which holds a stream subscription to the
  database) hangs instead. The screen therefore needs either a live binding or a seam that
  does not subscribe.

## Fixes

* `lib/data/backup/backup_worker.dart` (new): reads, decodes, checksums and validates a
  file on a worker isolate that is handed **only the path and the schema version**.
  `Isolate.exit` transfers the result instead of copying it. `onExit`/`onError` are wired to
  the reply port and a timeout sits on top, so a worker that dies without answering still
  completes the future — and both cases fall back to `openInline()`. The database is never
  moved off the main isolate.
* `BackupService.open()` delegates to it; `openInline()` is the reference path and the
  fallback. Both call the same `parseEnvelope` and `BackupValidator`, so they cannot
  disagree — which the suites prove, because all 96 backup tests read files through `open()`
  and `inspect()`.

## P1 Measurement

| | value | status |
| --- | ---: | --- |
| backup, S24 Ultra, 500/2,500/10,000, **this phase** | wall **802 ms**, **11 frames**, p90 11.5 ms, worst frame 252 ms, **worst gap 750 ms** | **measured** |
| restore, same | — | **NOT PROVEN — the run hung** |
| worst read stall (host, 40k) | 3,111 → 191 ms | measured (previous phase) |
| restore frames (previous phase) | 0 → 12, p90 2.3 ms | measured before this phase's changes |

**P1 = FAIL.** The backup's worst gap is unchanged (750–816 ms) because only the restore path
was moved, and the restore path has no device figure at all. Neither half is closed.

## Worker Verification

* **Success path:** all 96 backup tests, including the corruption matrix, the 16-point kill
  matrix and the round trip, pass through `open()` ⇒ the worker returns the same verdicts,
  counts and payload as the inline path.
* **Failure paths (timeout, `onError`, `onExit` without a result, spawn failure, inline
  fallback):** designed and implemented, but **NOT PROVEN by test** — no test drives them,
  because the worker is exercised only through the public API.
* **No restore hang:** the device run hung, but the hang is not attributable to the worker
  yet (see #19).

## Memory

Peak 666 → 589 MB (previous phase, before the worker). The worker adds a second isolate heap
during a restore; that has not been measured.

## Leak Test — NOT PROVEN

Not run.

## Kill Matrix — 16/16 PASS

Re-run green after the worker change.

## Disk Failure — PASS · Corruption — PASS (15 cases) · Duplicate Protection — PASS

## Automatic Backup — PASS · Restore — PASS in tests · Merge — PASS

## Financial Integrity — PASS · Multi-Person — PASS (one record / 1,500 / three links)

## Notifications — PASS · Search — PASS · Reports — PASS

## PDF — NOT PROVEN (not opened on a device)

## SAF — NOT PROVEN · Share/Save — NOT PROVEN · Uninstall/Reinstall — NOT PROVEN

Not executed. `adb` was not used as a substitute, and no empty-database import is counted as
a reinstall.

## Android Documentation Review — NOT PROVEN

Not performed. `allowBackup=false`, `fullBackupContent=false`, `dataExtractionRules`
unchanged.

## Security — PASS

No secret leaves the device; the lock and biometric flags are excluded and asserted
device-only; no storage permission; no hand-assembled SQL anywhere (drift's parameterised
expressions, including the new `TableReader`); logs carry no records.

## Encryption — PASS (decision unchanged, disclosed in the file, the restore screen and Settings)

## Low-End — NOT PROVEN — real low-end hardware unavailable

## Widget Coverage — NOT PROVEN

Attempted twice with five overrides (database, directory, picker, notifications, version).
Both root causes identified and recorded above. The file was **removed** rather than left in
the suite: it hangs, and a hanging file stops the suite from loading at all, which would
hide every other test. The gap stays open, with the diagnosis, as a task — not as a closed
item.

## Performance Gate — documented, NOT executed

## Clean Regression — NOT PROVEN (no `flutter clean` run)

Ad-hoc full runs during the phase: **550 passed / 0 failed**, analyzer **No issues found!**

## Flakiness — NOT PROVEN

## Real Device Evidence

S24 Ultra / Android 16 / debug / 500–2,500–10,000: backup 802 ms, 11 frames, p90 11.5 ms,
worst gap 750 ms, 3.21 MB file written and exported. Then the run hung at the restore step
and did not complete. Previous phase, same phone: backup 769 ms / 12 frames; restore
1,022 ms / 12 frames / worst gap 383 ms; kill checklist 7/7; external import verified.

## Final Acceptance Matrix

| Area | Status | Evidence |
| --- | --- | --- |
| Backup integrity | **PASS** | atomic, checksummed, collision-safe |
| Restore integrity | **PASS** | one transaction, verification inside, rollback proven |
| Automatic backup | **PASS** | single-flight, coalescing |
| **P1 UI blocking** | **FAIL** | backup gap 750 ms unchanged; restore unmeasured |
| **Worker reliability** | **PARTIAL** | success path proven by 96 tests; failure paths designed, untested; device restore hung |
| Memory | **PASS** | 666 → 589 MB (pre-worker) |
| Memory leak | **NOT PROVEN** | — |
| Kill 16/16 | **PASS** | re-run green |
| Disk failure · Corruption · Duplicates | **PASS** | — |
| Merge · Financial · Multi-person | **PASS** | — |
| Notifications · Search · Reports | **PASS** | — |
| PDF real device | **NOT PROVEN** | — |
| SAF real UI · Share/Save · Uninstall/Reinstall | **NOT PROVEN** | — |
| Android backup review | **NOT PROVEN** | — |
| Security · Encryption | **PASS** | — |
| Low-end | **NOT PROVEN** | no hardware |
| Widget coverage | **NOT PROVEN** | two attempts, root causes recorded |
| Performance gate | **NOT PROVEN** | documented only |
| Clean run · Flakiness | **NOT PROVEN** | — |
| Full regression | **PASS (550/0, analyzer clean)** | not from a clean state |
| **Overall** | **PARTIAL** | — |

## Remaining Risks

| # | Risk | Severity |
| --- | --- | --- |
| 1 | **the device-only restore hang is unexplained** — if it is in `apply()` rather than the harness, recovery on a phone is at risk and this becomes BLOCKED | **P1** |
| 2 | the backup's 750–816 ms synchronous gap is unchanged | **P1** |
| 3 | the worker's failure paths (timeout, error, exit, fallback) have no test | P2 |
| 4 | SAF, Share, reinstall, PDF, leak, clean run, flakiness, widget, low-end unproven | P2 |
| 5 | the worker adds an isolate heap during a restore (unmeasured) | P3 |
| 6 | conflict-resolution UI absent (deliberate) · backups unencrypted (documented) | P3 |

## Rejected Changes

* **Documenting the hang away as "test flakiness".** The same test passed on the same phone
  before this phase's changes; that makes it a regression in the current state until shown
  otherwise.
* **Keeping the widget test red to satisfy a checklist.** A hanging file breaks the suite's
  ability to load; the gap is recorded instead.
* **Leaving the `runAsync` variant in place** once it hung, rather than bisecting further
  with the budget available.
* **Raw SQL reads** and **offset paging**: same reasons as v2 (duplicated column knowledge;
  reliance on an ordering SQL does not promise).

## Final Verdict

**PARTIAL.**

One item blocks closure outright: the device-only restore hang, which must be bisected
before anything else. P1 is not closed either — the backup path was never moved and its gap
is unchanged, and the restore path's new worker has no device measurement because the run
died. SAF, Share/Save, uninstall/reinstall, PDF on a device, the leak run, a clean
regression, flakiness, the widget gap, the performance gate, the Android documentation
review and low-end hardware are all still untested.

`BLOCKED` is not claimed yet, because the hang is not yet shown to be in the application
rather than in the test harness. If bisecting finds it in `apply()` — the path that owns the
restore transaction — then this becomes **BLOCKED** and no further acceptance work matters
until it is fixed.
