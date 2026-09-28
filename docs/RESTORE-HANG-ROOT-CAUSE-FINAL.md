# Restore hang — root-cause investigation

**Date:** 2026-09-26 · **Verdict: UNRESOLVED** — attributed to the measurement harness on
evidence, but **not confirmed**, and the confirming experiment did not complete.

## 1. Regression Description

On the S24 Ultra, with 500 people / 2,500 records / 10,000 payments (3.21 MB file), the
audit test's backup completed (802 ms, 11 frames) and then **the restore step never
finished**: `the app survives a large ledger being saved and restored - did not complete`,
followed by `(tearDownAll) - did not complete`. The same test, same phone, same dataset had
passed before this phase's changes (restore 1,022 ms, 12 frames, worst gap 383 ms).

## 2. Known-Good Baseline

| Build | Backup | Restore | Result |
| --- | --- | --- | --- |
| before this phase (`BackupFormat.build` + worker absent) | 769 ms / 12 frames / p90 10.7 ms | **1,022 ms / 12 frames / p90 2.3 ms / gap 383 ms** | PASS |
| current | 802 ms / 11 frames / p90 11.5 ms / gap 750 ms | **never finished** | FAIL |

## 3. Reproduction

| attempt | procedure | outcome |
| --- | --- | --- |
| 1 | audit test, `--plain-name 'app survives'`, frames pumped around the restore | **hung** after the export step, before any measurement |
| 2 | same, re-run | the run died at build/install and produced no test output at all |
| 3 | same, with the restore awaited directly (no pumping) and phase markers added | ran, but the harness produced no output — **no result** |

**Always, sometimes, or once?** On the evidence available: the pumped variant hung once and
passed once on this same code path (run 1 of this phase vs the pre-phase run), which makes it
**intermittent**, not deterministic. That is the single most important sentence in this
document.

## 4. Exact Hang Point

The previous log cannot name it. It ends at:

```
DEVICE exported: /data/user/0/com.dhimmah.dhimmah/app_flutter/audit-export.dhimmah (3.21 MB)
```

and the next print in that test was inside the restore step. Three candidate phases sit
between: the wipe transaction, `backups.read()`, and `apply()`. **Phase markers were added**
(`DEVICE RESTORE_STEP: wipe start/done`, `read done`, `apply start/done`) so the next run
names the phase instead of the test — but that run produced no output.

## 5. Bisect

Changes between the known-good run and the hang:

| Change | Touches the hung path? |
| --- | --- |
| `BackupFormat.build()` (one-pass payload) | **no** — write path only |
| `backup_worker.dart` + `open()` delegation | **no** — `read()`/`apply()` are what the hung test calls |
| chunked writes + `TableReader._breathe()` yields | **present in the known-good run too** |
| frame-pumping `measured()` loop | **present in the known-good run too**, and it is the only component that differs between the hanging run and the passing un-pumped run in the same file |

A logical bisect therefore points at the *combination* of frame pumping and the yields
inside the restore's transaction — not at either change made this phase.

## 6. Root Cause — attributed, not proven

**Candidate, with mechanism:** `TableReader._breathe()` and the chunked writes call
`Future.delayed(Duration.zero)` **inside the `db.transaction()` body**. Under
`flutter_test`, the test body runs on a *fake* clock, and `tester.pump(16 ms)` advances that
fake clock. A timer created inside drift's transaction zone is not necessarily a timer of
the pumping zone, so a pump can advance the clock without firing it — the transaction then
waits forever and the test hangs, while the application (a real event loop, no fake clock)
completes the same restore immediately.

**Evidence for it:**

* `apply()` **completed on this same phone with the same file and dataset today**, in the
  import test of this very file, with no pumping: `DEVICE imported counts: {people: 500,
  debts: 2500, debtPeople: 2500, payments: 10000, ...}`.
* The only run that hung was the pumped one; the same code path passed pumped before.
* The backup pumped fine in both runs — its long stretches are DB reads and one
  `Future.delayed` per page, not yields inside a transaction.

**Evidence against / unknown:** the pre-phase pumped restore passed *with* chunked writes
and `_breathe()` in place, so the mechanism is timing-dependent rather than deterministic,
and I could not run the discriminating experiment to completion.

## 7. Fix

**None applied.** A fix would be justified only after the mechanism is confirmed, and the
candidate fixes (yield with a frame-aware primitive in the harness, or pump with a real
event-loop turn) change the *test*, not the product — which is exactly the kind of change
that must not be made to hide a symptom. No product code was touched for this.

## 8. Worker Analysis

The worker is not on the hung path: that test calls `backups.read()` (inline
`BackupFormat.parse`) and `apply()`. The worker **is** exercised on the device — the import
test calls `backups.open(exportedPath)` → `openOnWorker` → and it returned the payload and
verdict (`DEVICE imported from outside the app: {people: 500, ...}` was printed by that
path). So the worker has one device success and no observed hang. Its failure paths
(timeout, `onError`, `onExit`, fallback) remain **untested**.

## 9. Inline Analysis

`openInline()` is the reference path and is exercised by the whole unit suite (96 backup
tests) — green. On the device, the un-pumped restore (which does not call `open()` at all)
completed. No evidence against it.

## 10. Transaction Analysis

No deadlock was demonstrated. The relevant structure, for whoever picks this up:

* `_applyInserts` / `_replaceRows` chunk at 400 rows and `await _breathe()` between chunks —
  **inside** the transaction.
* `_verify` reads every table through `TableReader`, which `await _breathe()`s between
  pages — **inside** the transaction, after the writes.
* No nested transaction exists; the coordinator's stream subscription is not created by this
  test; `rebuildDerivedState` runs *after* the transaction commits.

The one place to look first is a pending `Future.delayed` inside the transaction while the
caller pumps a fake clock.

## 11. Before/After

Nothing changed as a result of this investigation except the audit test, which now awaits
the restore directly and prints phase markers. Frame numbers for the restore remain
**NOT PROVEN** until the pumped variant is stable.

## 12. Real Device Results

| Path | Device | Result | Time | Hang |
| --- | --- | --- | ---: | --- |
| Known-good inline (pre-phase, pumped) | S24 | PASS | 1,022 ms | no |
| Current inline, **un-pumped**, same file/dataset (import test, today) | S24 | **PASS** | — | no |
| Current inline, **un-pumped**, wipe + restore (instrumented run) | S24 | no output | — | unknown |
| Current pumped (**the regression**) | S24 | **did not complete** | — | **yes, once** |

## 13. Repeated Restore Results — **NOT RUN**

`restore × 10` in one process, then restart and × 10: not executed. This is the experiment
that would settle whether the harness is flaky or the product is.

## 14. Failure Injection — n/a for this investigation

Kill (16/16), disk full and corruption suites are green on the product path.

## 15. Regression Tests

`flutter analyze` → **No issues found!** · backup suites (hardening, round trip, failure,
coordinator, kill matrix) → **96 passed, 0 failed** · the worker path itself is covered by
every one of them, because they read files through `open()`/`inspect()`.

## 16. Remaining Risks

| # | Risk | Severity |
| --- | --- | --- |
| 1 | the hang is intermittent and attributed, not proven — the confirming experiments (phase markers, `restore × 10`, un-pumped repeat) did not complete | **P1** |
| 2 | if the mechanism is *not* the fake clock, then a real `apply()` stall exists and this becomes BLOCKED | **P1 (conditional)** |
| 3 | the worker's failure paths (timeout/error/exit/fallback) have no test | P2 |
| 4 | the restore has no trusted frame measurement since the pumping harness became suspect | P2 |

## 17. Final Verdict

**UNRESOLVED.**

The regression is **attributed** to the frame-pumping measurement harness interacting with
the yields inside the restore's transaction — on the evidence that the same restore
completes on the same phone with the same file without pumping (today's import run), and
that the pumped variant both passed and hung on the same code path. It is **not confirmed**:
the experiments that would settle it (phase markers between the wipe, the read and `apply`;
`restore × 10`; a repeat of the un-pumped run) did not produce output before this
investigation stopped.

There is **no evidence of a data-integrity defect**: the restore's transaction, verification
and rollback are green in the suite, and an un-pumped restore of the full 3.21 MB file
succeeded on the device today. That is why this is not BLOCKED — and it is not FIXED either,
because nothing was fixed and the mechanism is unconfirmed.

Next, in order: (1) run the instrumented test once and read which `RESTORE_STEP` line it
stops after; (2) `restore × 10` un-pumped, then pumped, in one process; (3) only then change
either the harness (pump with a real event-loop turn) or, if the markers point inside
`apply()`, treat it as a product defect.
