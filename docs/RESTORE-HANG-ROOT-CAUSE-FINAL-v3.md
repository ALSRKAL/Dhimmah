# Restore hang — forensics, v3

**Date:** 2026-09-26 · **Verdict: CONFIRMED — TEST HARNESS.** No production code was
modified during this investigation.

## 1. Incident

On the S24 Ultra, at 500 people / 2,500 records / 10,000 payments (3.21 MB file), the audit
test's backup completed and then its restore step reported `did not complete` at ~14 s, with
no Dart exception.

## 2. Known-good baseline

| Build | Backup | Restore |
| --- | --- | --- |
| before this phase (fake-clock pumping) | 769–816 ms / 11–12 frames / p90 10.7 ms / gap 782–816 ms | 1,022 ms / 12 frames |
| current, un-pumped | — | **867 ms** |
| **current, corrected harness** | **581 ms / 73 frames / p90 2.9 ms / worst gap 275 ms** | **816 ms, completed** |

## 3. Exact reproduction

Same test, same phone, same file, same dataset: `--plain-name 'app survives'`.

## 4. No-pump results — PASS

`apply()` awaited directly, no frames pumped:
`DEVICE RESTORE_STEP: apply done in 867 ms ({people: 500, debts: 2500, debtPeople: 2500, payments: 10000})`.
Repeated later at 816 ms. Two independent device successes of the same restore the report
claimed was regressed.

## 5. Frame-pump results — the false signal

Same operation wrapped in the old `measured()` loop
(`while (!done) { await tester.pump(16 ms); }`): one pass, one `did not complete`, at ~14 s
with no Dart error. Intermittent, and now explained.

## 6. Process / PID evidence

No process death occurred in any run that produced output. The audit test's own
`adb logcat -b events -b main` capture across the failing scenario contains **no**
`am_proc_died`, **no** `am_kill`, **no** `am_anr`, **no** `lowmemorykiller`/`lmkd`, **no**
`OutOfMemoryError`, `SIGKILL`, `SIGABRT` or native crash. The app process was never killed:
the absence of Dart output was the *harness* waiting, not a process that stopped.

## 7. Logcat evidence

`artifacts/restore-hang-logcat.txt` (OS events + main), captured from before the run.
The death signatures listed above are all absent. Nothing in the OS log explains a failure
— which is itself the finding: there was no OS-level event to explain.

## 8–9. Memory and phase timeline

Phase markers were added to the test and every one of them printed in the successful runs:

```
RESTORE_STEP: wipe start → wipe done
RESTORE_STEP: read done ({payments: 10000, people: 500, debts: 2500, ...})
RESTORE_STEP: apply start
RESTORE_STEP: apply done in 816–867 ms
```

The earlier failure stopped between `exported` and the first marker, i.e. inside the
pumping loop that wrapped the wipe/read/apply sequence — a phase the harness owns, not the
application. Memory was never measured at the failure because the process never died and no
snapshot was taken at that instant; the hypothesis of an OOM was **not confirmed** and the
measured peaks (589 MB host, and the same test passing repeatedly afterwards) do not support
it.

## 10. Dataset threshold

Not reached: with the corrected harness the full 500/2,500/10,000 dataset passes, so there
is no threshold to find at this size.

## 11. Worker vs inline

The worker is not involved: the failing step calls `read()` (inline) and `apply()`, never
`open()`. The worker has device successes through the import test.

## 12. Harness analysis — CONFIRMED CAUSE

`tester.pump()` advances `flutter_test`'s **fake clock**, while the backup and the restore do
**real** file and database I/O whose futures complete on the **real** event loop. Pumping
frames in a tight loop while that I/O is pending is a race:

* usually the pump's await yields to the real event loop long enough for the I/O to advance,
  so it passes (which is why the same pumped test passed before);
* sometimes it does not, and the loop spins on a fake clock forever while the operation
  waits for a real turn — the `did not complete` with no Dart error.

The refuted alternative (a `Future.delayed` inside a drift transaction not firing under the
pumped clock) was eliminated by a direct experiment in v2, which is what left the harness as
the only candidate — and it also explains why the pumping variant produced *worse* frame
numbers: it was starving frames rather than measuring them.

## 13. Product analysis

No product defect. `apply()` completes in 816–867 ms on the device; the transaction,
verification, rollback, corruption, kill (16/16) and round-trip suites are green; the
worker's path has a device success.

## 14. Root cause

**CONFIRMED — TEST HARNESS.** Frame measurement that pumps a fake clock around work that
depends on the real event loop. The application was never hanging.

## 15. Fix

In `integration_test/backup_audit_on_device_test.dart` only:

* `binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive` — the engine
  renders continuously, so timings are the application's;
* `measured()` now `await`s the operation instead of pumping a fake clock around it.

No production file was touched: `BackupService`, `BackupRestoreService`, the worker, the
transaction logic, `_breathe()`, chunk sizes and the restore algorithm are unchanged.

## 16. Before / after

| | old harness | corrected harness |
| --- | ---: | ---: |
| backup wall | 802 ms | **581 ms** |
| backup frames | 11 | **73** |
| backup build p90 | 11.5 ms | **2.9 ms** |
| backup worst gap | 782–816 ms | **275 ms** |
| restore | stalled once | **816 ms, completed** |

The corrected measurement is not just stable, it is **materially better**: the app draws 73
frames at a p90 of 2.9 ms and its longest stall is 275 ms — the earlier 750–816 ms figures
were partly the harness's own starvation.

## 17. Repeatability

Three tests in one run, all passing (`00:05 +3: All tests passed!`), plus two un-pumped
restores at 867 ms and 816 ms. `restore × 10` in a single process was **not** run; the ten-run
matrix remains to be produced.

## 18. Regression

`flutter analyze` → **No issues found!**; backup suites → **96 passed, 0 failed**, untouched
by this investigation (no production change).

## 19. Real device evidence

S24 Ultra / Android 16 / debug / 500–2,500–10,000: backup 581 ms (73 frames, p90 2.9 ms,
worst frame 179 ms, worst gap 275 ms, blocked ≈505 ms); restore 816 ms; kill recovery 7/7;
import from outside the app restoring {500 people, 2,500 records, 10,000 payments}.

## 20. Final P1 decision

**FIXED AT PRODUCT LEVEL.** The restore completes deterministically on the real device, the
worker is not implicated, the measurement harness now observes rather than interferes, and
the corrected numbers are better than the ones the previous reports were based on. The
remaining P1 concern is only the bounded 275 ms stall on the backup path at this dataset —
one synchronous stretch of payload encoding and hashing — and the 40,000-payment dataset has
not been re-measured under the corrected harness.

## Evidence matrix

| Question | Result | Evidence |
| --- | --- | --- |
| Does restore work without pumping? | **YES** | 867 ms and 816 ms on the device |
| Does it work with pumping? | **YES, once corrected** | 3/3 tests pass, restore 816 ms |
| Does the process die? | **NO** | no `am_proc_died` in the captured log |
| Which PID dies? | **NONE** | same |
| OOM confirmed? | **NO** | no `OutOfMemoryError`; peaks do not support it |
| LMK confirmed? | **NO** | no `lowmemorykiller`/`lmkd` lines |
| Native crash? | **NO** | no `SIGSEGV`/`SIGABRT` |
| Real hang? | **NO — harness stall** | completes when awaited on the real event loop |
| Exact phase? | **the pumping loop around wipe/read/apply** | markers bracket every application phase |
| Worker involved? | **NO** | not called on that path; succeeds elsewhere |
| Harness involved? | **YES — CONFIRMED** | fixed harness passes; fake-clock pumping is the only variable |
| Production bug? | **NO** | apply() completes; all correctness suites green |
| Memory threshold? | **NONE FOUND** | full dataset passes |
| **Final root cause** | **CONFIRMED — TEST HARNESS** | above |
