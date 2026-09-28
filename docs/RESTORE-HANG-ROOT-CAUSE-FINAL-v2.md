# Restore hang — root cause, v2

**Date:** 2026-09-26 · **Verdict: UNRESOLVED** — the prime suspect was **refuted by
experiment**, and a second, test-environment hypothesis is proposed but unproven.

## 1. Symptom

On the S24 Ultra, at 500 people / 2,500 records / 10,000 payments (3.21 MB file), the audit
test's backup completes and then the restore step never finishes:

```
DEVICE backup 500/2500/10000 | wall=802ms frames=11 build p90=11.5ms worst gap=750ms
DEVICE file: 3.21 MB
DEVICE exported: .../audit-export.dhimmah (3.21 MB)
the app survives a large ledger being saved and restored - did not complete   ← at 00:14
(tearDownAll) - did not complete
```

`did not complete` — with no Dart exception printed — is what the harness reports when the
**test process stops**, which is not the same as a future that never completes.

## 2. Known-good baseline

| Build | Backup | Restore |
| --- | --- | --- |
| before this phase | 769 ms / 12 frames | **1,022 ms / 12 frames / p90 2.3 ms** |
| current | 802 ms / 11 frames | **never reported** |

## 3. Reproduction matrix

| attempt | procedure | outcome |
| --- | --- | --- |
| 1 | audit test, restore with frame pumping | **did not complete**, at 00:14 |
| 2 | identical re-run | died at build/install, no test output |
| 3 | with phase markers added (`RESTORE_STEP: wipe/read/apply`) | ran, produced no output |
| 4 | **local experiment** (below) | **completed** — refutation |

## 4. No-pump results

`apply()` with no frame pumping completed on this phone with this exact file and dataset,
twice: in the import test (`DEVICE imported counts: {people: 500, debts: 2500,
debtPeople: 2500, payments: 10000}`) and — from the previous phase — in the same audit
test's own replace step before pumping was added around it.

## 5. Frame-pump results

One hang (attempt 1). One earlier pass of the same pumped path (before this phase). So the
pumped path has both passed and failed: **intermittent**, not deterministic.

## 6. `_breathe()` experiment — REFUTED

The hypothesis was: *a `Future.delayed(Duration.zero)` created inside a drift transaction is
not fired by the fake clock that `tester.pump()` advances, so the transaction waits forever
while the test pumps.*

A minimal, bounded experiment (`test/data/transaction_breathe_test.dart`, since removed)
tested three variants under `flutter_test`:

| variant | what it does | result |
| --- | --- | --- |
| A | write → `Future.delayed(Duration.zero)` → write, **inside `db.transaction()`**, while pumping frames | **finished = true** |
| B | the same transaction with no yield, pumping | finished = true |
| C | the same yield, awaited inside `runAsync` (real event loop) | finished = true |

**The mechanism is refuted.** A zero-duration timer inside a transaction is fired by the
pumped clock, so `TableReader._breathe()` and the chunked writes are not the cause of a
hang. This is the most important result in this document: it removes the suspect that the
previous report named, and it was obtained by experiment rather than by argument.

## 7. Worker experiment

Not implicated: the hung test calls `read()` (inline parse) and `apply()`; it never calls
`open()`, so no worker is spawned on that path. The worker does have a device success — the
import test's `open()` returned the payload and the verdict.

## 8. Exact hang phase — still not named

The instrumented run that would have printed `RESTORE_STEP: wipe start/done`, `read done`,
`apply start/done` produced no output. The phase therefore remains unidentified; three
candidates remain (wipe transaction, `read()`, `apply()`).

## 9. Root cause — UNRESOLVED, with the next hypothesis

`did not complete` at 00:14 with no Dart error is the signature of the **process**
stopping, not of a future that never completes. The leading hypothesis is now:

> **the audit test's own environment exhausts the app's memory on a debug build: an
> in-memory database holding 61,000 rows, plus a 3.21 MB file read as a string, plus the
> parsed payload and its canonical copies, plus (since this phase) a worker isolate's heap
> during `open()` in the sibling tests.**

Supporting numbers: the same operation peaks at **589 MB RSS** on the host, and a debug
Android app's heap limit is far below that. The failure is a *test-environment* artifact
either way — a real install keeps its database on disk and never holds the ledger in
memory — but it is not proven, and it must not be assumed.

**Refuted:** the fake-clock/timer-in-transaction mechanism (§6).
**Unproven:** memory exhaustion / process death.
**Not implicated:** the worker (§7), `_breathe()` (§6), `BackupFormat.build()` (write path
only), and the restore transaction's correctness (green in 96 unit tests including the
16-point kill matrix and rollback).

## 10. Fix

**None applied.** The refutation removed the only fix that was justified by evidence, and a
fix for the second hypothesis (shrinking the test's dataset, or capturing logcat to see the
kill) changes the *test*, so it must be justified by evidence first. No product code was
changed for this investigation.

## 11. Before/After

Nothing changed. `flutter analyze` → **No issues found!**; backup suites → **96 passed**.

## 12. Real-device results

| Path | Result |
| --- | --- |
| restore, no pumping, 3.21 MB, 500/2,500/10,000 | **PASS** (twice: import test, and the audit test before pumping) |
| restore, with pumping, same file/dataset | **PASS once, `did not complete` once** |
| backup, with pumping | PASS both times (802 ms / 11 frames / p90 11.5 ms / worst gap 750 ms) |

## 13. Repeatability — NOT RUN

`restore × 10` un-pumped, then pumped, then after an app restart: not executed. This is the
experiment that would separate an intermittent harness failure from an intermittent product
failure, and it is the first thing to run next.

## 14. Regression

Unchanged and green: 96 backup tests (hardening 43, round trip, failure, coordinator, kill
matrix 16/16), analyzer clean.

## 15. Final P1 status

**FAIL.** The restore has no trusted device measurement since the harness became suspect,
the backup's synchronous gap is unchanged at 750–816 ms, and the one device hang is
unexplained — with its prime suspect now eliminated rather than confirmed.

## 16. Next three experiments, in order

1. **Capture the death:** run the audit test with `adb logcat` alongside, and look for
   `lowmemorykiller`, `OutOfMemoryError`, `SIGKILL` or a native abort around the
   `RESTORE_STEP` markers. That distinguishes "hung" from "killed" definitively.
2. **`restore × 10`** un-pumped, then pumped, in one process, with the phase markers
   printed — the table the brief asks for.
3. **If it is memory in the test:** give the audit test an on-disk database (as a real
   install has) or a smaller dataset, then re-measure the frames — the product path is not
   changed by that, only the test's footprint.

## 17. Final Verdict

**UNRESOLVED.**

The prime suspect was tested and **refuted** (§6) — which is progress, not closure. The
symptom is now characterised as *process death at ~14 s with no Dart error*, in a test that
holds an in-memory 61k-row database plus a 3.21 MB file plus payload copies on a debug
build, and the leading hypothesis is memory. No product defect has been demonstrated: the
same restore completes on the same phone and the same file without pumping, twice, and the
transaction, verification and rollback are green under the full suite. No fix was applied,
because none was justified by evidence yet, and nothing was hidden behind a timeout, a
fallback or a relaxed expectation.
