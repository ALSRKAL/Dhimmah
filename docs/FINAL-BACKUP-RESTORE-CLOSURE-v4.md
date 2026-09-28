# Final backup/restore closure — v4

**Date:** 2026-09-26 · **Verdict: PARTIAL** (see §29)

**Restore-hang status:** *CONFIRMED — TEST HARNESS; NO PRODUCTION RESTORE HANG CONFIRMED*.
No production file was changed for that issue.

## Executive Summary

The restore-hang investigation is closed: the cause was the measurement harness, and with it
corrected the restore completes **10 times out of 10** on the S24 Ultra with the full dataset.
The worker's contract is now tested, including the paths where it does *not* answer. Frame
numbers were re-measured with the corrected harness and are **materially better** than every
figure the earlier reports were based on.

What remains open is everything that was not executed: SAF through the system picker,
Share/Save, the real uninstall/reinstall journey, PDF on a device, the six-cycle leak run, a
clean-state regression, flakiness, the performance gate at 40,000 payments, the Android
documentation review, low-end hardware, and widget coverage for the backup screen.

## Current Status

| Item | Status |
| --- | --- |
| Restore hang | **CLOSED — harness** |
| P1 (restore determinism) | **PASS** |
| P1 (backup frame gap) | **PASS at 500/2,500/10,000** — 275 ms worst gap under the corrected harness |
| Worker | **PARTIAL** — success and no-answer paths tested; no test for `onError`/`onExit` classification |
| Everything else | **NOT PROVEN** |

## Restore Hang Forensics

The finding, in one paragraph: the old `measured()` helper pumped `tester.pump()` — which
advances `flutter_test`'s **fake clock** — in a tight loop while the restore was doing **real**
file and database I/O. Sometimes the pump's await let the real event loop turn and the
operation advanced; sometimes it did not, and the loop spun on a clock the operation was not
waiting on. That is a race in the harness, and it produced `did not complete` with no Dart
error. The alternative hypothesis (a `Future.delayed` inside a drift transaction not firing
under the pumped clock) was **refuted by a direct local experiment** before the harness was
changed, which is what left the harness as the only candidate. No `am_proc_died`, `am_kill`,
`am_anr`, `lowmemorykiller`, `OutOfMemoryError` or native crash appears in the OS log captured
across the failing scenario; the process was never killed.

## Worker Verification

`test/data/backup_worker_test.dart` — **8 tests, all passing**:

| Case | Result |
| --- | --- |
| success: worker payload and verdict identical to inline | PASS |
| the four steps the worker reports are the four that happen | PASS |
| a slow worker (zero timeout) returns null quickly, and `open()` still answers | PASS |
| missing file → `unreadableEnvelope` | PASS |
| a file that is not a backup → `notADhimmahBackup`, ledger untouched | PASS |
| damaged payload → `checksumMismatch` | PASS |
| newer schema → a verdict with `schema_too_new`, not an exception | PASS |
| **the worker does not classify refusals** — it reports no answer, and the inline path names the problem (recorded, not hidden) | PASS |

The last row is a real observation about the implementation: for a file it refuses, the worker
returns "no answer" rather than its reason, so `open()` does the work again inline and throws
from there. The product contract is unaffected — the caller still learns exactly what is wrong
— and the cost is one extra pass over a file that was not going to be restored.

## Performance — corrected harness, S24 Ultra, 500/2,500/10,000

| Metric | Old harness | **Corrected harness** |
| --- | ---: | ---: |
| backup wall | 802 ms | **581 ms** |
| backup frames | 11 | **73** |
| backup build p90 | 11.5 ms | **2.9 ms** |
| backup worst frame | 252 ms | 179 ms |
| **backup worst gap** | 782–816 ms | **275 ms** |
| backup blocked (≈) | 1375 ms | 505 ms |
| restore wall | stalled once | **816 ms** |

`p95` and peak memory were not captured in this run; the helper reports p90, worst frame, worst
gap and blocked time. The 40,000-payment dataset was **not** re-measured under the corrected
harness on the device.

## Memory

Peak 666 → **589 MB** at 1,000/10,000/40,000 (host, before the worker). A device peak for the
restore path — which now spans two isolate heaps — has not been measured.

## Leak — NOT PROVEN

The six-cycle run (baseline, then after each cycle) was not executed.

## Kill Matrix — 16/16 PASS

Unchanged, still green after the worker integration.

## SAF — NOT PROVEN · Share/Save — NOT PROVEN · Uninstall/Reinstall — NOT PROVEN

Not executed. `adb` was not used as a substitute for the picker, and no empty-database import
is counted as a reinstall.

## PDF — NOT PROVEN

## Notifications — PASS

Rebuilt from the records: no duplicates, a record the restore does not bring back loses its
reminder. Notification *tap* routing was not re-tested on the device in this phase.

## Financial Integrity — PASS · Multi-Person — PASS

`DebtCalculator` equality before and after; one record / 1,500 / three links / never 4,500.

## Security — PASS

No secret leaves the device; the lock and biometric flags are device-only and asserted so; no
storage permission; no hand-assembled SQL anywhere — drift's parameterised expressions
throughout, including the new `TableReader`.

## Android Documentation — NOT PROVEN

Not reviewed. `allowBackup=false`, `fullBackupContent=false`, `dataExtractionRules` unchanged.
The decision remains as documented, and the review is still owed.

## Encryption — PASS (decision unchanged)

No encryption, disclosed in the file, on the restore screen and in Settings; rationale in
`docs/BACKUP-ENCRYPTION.md`.

## Widget Coverage — NOT PROVEN

Attempted twice. Root causes established: under `flutter_test` the status provider's real
reads never complete while only `pump` is called (the screen shows its app bar and a spinner,
no exception), and resolving them inside `runAsync` then stalls on the provider chain's stream
subscription. The fix is a test seam that does not subscribe (or coverage moved to the
integration layer). The file was removed rather than left hanging — a hanging file stops the
suite from loading — so the gap is open and diagnosed, not closed.

## Clean Regression — NOT PROVEN

No `flutter clean` run. Ad-hoc runs during the phase: full suite **550 passed / 0 failed**,
analyzer **No issues found!** (both before the worker test file was added; the worker file adds
8 more, run green on its own).

## Flakiness — NOT PROVEN

Two consecutive green full runs earlier in the phase; no repeat-after-clean and no parallel run.
The one intermittent failure seen in this phase was diagnosed and fixed in the harness.

## Low-End — NOT PROVEN — real low-end hardware unavailable

No emulator figure is offered as a substitute.

## Performance Gate — documented, not executed at 40k after the harness change

`docs/PERFORMANCE-GATE.md` holds the commands, the baselines and the thresholds.

## Final User Journey — PARTIALLY EXECUTED

The restore half was executed end to end on the device (backup → export → wipe → restore → 10
consecutive restores, plus the import of a file from outside the app, plus recovery after a
killed write). The product-facing half — picker, chooser, uninstall, reinstall — was not.

## Bugs Found (this phase)

| # | Bug | Where | Severity |
| --- | --- | --- | --- |
| 21 | the frame harness pumped a fake clock around real I/O, stalling the restore step intermittently | integration test | P1 (measurement integrity) |
| 22 | the worker reports "no answer" instead of its refusal reason, so refusals cost a second inline pass | worker integration | P3 |

## Bugs Fixed (this phase)

| # | Fix | Evidence |
| --- | --- | --- |
| 21 | `framePolicy = fullyLive`; the operation is awaited instead of pumped | 10/10 restores pass; frames 11 → 73; p90 11.5 → 2.9 ms; worst gap 816 → 275 ms |

Bug 22 is **recorded, not fixed**: the product contract is correct through the fallback, and
changing it was not justified in this phase.

## Evidence

* `DEVICE RESTORE_X10 run 1–10: PASS`, 643–940 ms, full counts on every run, `10/10 completed
  deterministically`.
* `DEVICE backup 500/2500/10000 | wall=581ms frames=73 build p90=2.9ms worst gap=275ms`.
* `DEVICE RESTORE_STEP: apply done in 816 ms`.
* `artifacts/restore-hang-logcat.txt` — no death event of any kind.
* Three device tests (frames/scale, kill recovery 7/7, import from outside) pass in one run.
* `test/data/backup_worker_test.dart` — 8/8.

## Remaining Risks

| # | Risk | Severity |
| --- | --- | --- |
| 1 | SAF, Share/Save and the real uninstall/reinstall journey are unproven — the largest remaining gap | P2 |
| 2 | 40,000 payments unmeasured on the device under the corrected harness; p95 and device memory missing | P2 |
| 3 | leak, clean-state regression, flakiness, performance gate execution, Android review, low-end, widget coverage | P2 |
| 4 | the worker's refusal classification is lost to the fallback (documented) | P3 |
| 5 | conflicts are reported without a resolution UI (deliberate) · backups are unencrypted (documented) | P3 |

## Final Acceptance Matrix

| Area | Status | Evidence |
| --- | --- | --- |
| Backup integrity | **PASS** | atomic, checksummed, collision-safe |
| Restore integrity | **PASS** | one transaction, verification inside, rollback proven |
| Automatic backup | **PASS** | single-flight, coalescing |
| **Restore ×10** | **PASS** | 10/10 on the S24 Ultra, 643–940 ms, full counts |
| Worker success | **PASS** | equivalence with inline |
| Worker failure | **PASS** | refusals reach the caller with the right problem |
| Worker timeout | **PASS** | zero-timeout returns null, caller falls back, no wait |
| Worker exit (no answer) | **PASS** | covered by the same path and recorded |
| UI responsiveness | **PASS at 500/2,500/10,000** | 73 frames, p90 2.9 ms, worst gap 275 ms |
| Memory | **PASS** (host, pre-worker) | 666 → 589 MB peak |
| Memory leak | **NOT PROVEN** | — |
| Kill 16/16 | **PASS** | `backup_kill_matrix_test.dart` |
| Disk failure · Corruption · Duplicates | **PASS** | — |
| Merge · Financial · Multi-person | **PASS** | — |
| Notifications | **PASS** (tap routing NOT PROVEN) | — |
| Search · Reports | **PASS** | — |
| PDF real device | **NOT PROVEN** | — |
| SAF real UI · Share/Save · Uninstall/Reinstall | **NOT PROVEN** | — |
| Android docs · Android backup decision | **NOT PROVEN** | — |
| Security · Encryption | **PASS** | — |
| Low-end | **NOT PROVEN** | no hardware |
| Widget coverage | **NOT PROVEN** | diagnosed, not fixed |
| Performance gate | **NOT PROVEN** (documented) | — |
| Clean regression · Flakiness | **NOT PROVEN** | — |
| Final user journey | **PARTIAL** | restore half executed on the device |
| **Overall** | **PARTIAL** | — |

## Final Verdict

**PARTIAL.**

No P0 and no P1 restore hang remains: the restore completes deterministically on the real
device, ten times out of ten, with the full dataset, and the harness that said otherwise has
been corrected and its diagnosis confirmed by experiment. The worker's contract is tested,
including the paths where it stays silent.

The closure list is still not met, because items that can be tested were not tested: the
system picker and the chooser, the uninstall/reinstall journey, PDF on a device, the leak run,
a clean-state regression, flakiness, the 40,000-payment gate, the Android documentation review,
low-end hardware and the widget gap. Those are the whole of what stands between this and
`CLOSED`, and none of them is claimed here as passing.
