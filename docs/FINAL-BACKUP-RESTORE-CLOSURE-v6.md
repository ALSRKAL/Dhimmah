# FINAL BACKUP / RESTORE CLOSURE v6

**Date:** 2026-09-26 · **Verdict: PARTIAL**

## 1. Executive Summary

Nothing new was closed in v6, and one earlier explanation was **corrected**. The v5 position
stands and is unchanged: the backup/restore engine is proven where it was proven (restore
10/10 on the device, kill 16/16, corruption, disk, duplicates, merge, financial, multi-person,
worker contract, a clean 558-test regression, three green flakiness runs), and the
release-critical device flows are still **NOT PROVEN** because they were not executed.

The one new finding is negative and precise: the backup screen does not render its body in
`flutter_test` **even when `backupStatusProvider` is overridden with a fixed value** — so the
blocker is not the provider chain, as v5 claimed, but something inside the screen's own widget
subtree. Three attempts, three different seams, same symptom. That is recorded as a diagnosis
correction and an open gap, not as progress.

## 2. Previous Open Gaps

| # | Gap | v5 | v6 |
| --- | --- | --- | --- |
| 1 | SAF / system picker | NOT PROVEN | **NOT PROVEN** |
| 2 | Share / Save | NOT PROVEN | **NOT PROVEN** |
| 3 | Uninstall / reinstall | NOT PROVEN | **NOT PROVEN** |
| 4 | PDF on a real device | NOT PROVEN | **NOT PROVEN** |
| 5 | Notification tap | NOT PROVEN | **NOT PROVEN** |
| 6 | Dataset B on a device | NOT PROVEN | **NOT PROVEN** |
| 7 | Device p95 / memory | NOT PROVEN | **NOT PROVEN** |
| 8 | Memory leak | NOT PROVEN | **NOT PROVEN** |
| 9 | Low-end device | NOT PROVEN | **NOT PROVEN** |
| 10 | Widget coverage | NOT PROVEN | **NOT PROVEN — with a corrected diagnosis** (§17) |

## 3. Gaps Closed

None. Every item above requires a physical-device UI flow or hardware this session did not
have, and the one item that was closable locally resisted three separate seams.

## 4. Bugs Found

**None in production behaviour.** No `FAIL` was produced by any executed test.

## 5. Fixes

None. **No production file was modified in v6.** The only file written was the widget test,
which was removed again when it failed — a hanging/red file stops the suite from loading, and
leaving one to make a checklist look better would have hidden every other test.

## 6. Real User Journey — **NOT PROVEN**

Not executed. The restore half was executed on the device in v4 (backup → export → wipe →
restore, ten times, plus recovery after a killed write, plus importing a file from outside the
app's backup directory). The product-facing half — picker, chooser, uninstall, reinstall — was
not, and is not claimed.

## 7. SAF — **NOT PROVEN**

The system picker was not driven through the UI. `adb` was not used as a substitute, and no
result here rests on the file gateway's unit tests.

## 8. Share / Save — **NOT PROVEN**

The chooser was not driven. The file the app *produces* is proven (3.21 MB, checksum valid,
inspected and restored on the device); the act of *saving it somewhere the user chooses* is not.

## 9. Uninstall / Reinstall — **NOT PROVEN**

Not executed. What is known: the app's sandbox is removed with the app (observed), and a
3.21 MB `.dhimmah` file imports into a fresh, empty database through the app's own code
(observed, on the device). Neither is a reinstall journey, and neither is counted as one.

## 10. Notification Tap — **NOT PROVEN**

The scheduling, de-duplication and cancellation behaviour is proven in unit tests, and the
payload→route mapping is covered there. A real notification was not tapped on a device in any
of foreground, background, killed or cold-start state.

## 11. PDF Real Device — **NOT PROVEN**

The statement's *data* is proven (built from restored records, totals through `DebtCalculator`).
The rendered PDF was not opened on a device, so Arabic shaping, RTL, tables, page breaks and
clipping are unverified.

## 12. Dataset B — **NOT PROVEN**

1,000 people / 10,000 records / 40,000 payments was measured on the **host** only (create
8.6 s, restore 11.0 s, peak 589 MB). No device figure exists for it, and the host figure is not
offered as one.

## 13. Device Performance

Dataset A on the S24 Ultra, under the corrected harness: backup **581 ms**, **73 frames**,
build p90 **2.9 ms**, worst frame 179 ms, **worst gap 275 ms**, blocked ≈505 ms; restore
**816 ms** (and 643–940 ms across ten consecutive runs). **p95 and device peak memory were not
captured.**

## 14. Device Memory — **NOT PROVEN**

Only the host peak (589 MB, pre-worker) exists. The restore path now spans two isolate heaps
and that has not been measured on hardware.

## 15. Leak Test — **NOT PROVEN**

Six cycles with memory recorded between them were not run. Memory returning after a single
operation is not a leak result.

## 16. Low-End Device — **NOT PROVEN — no physical low-end hardware available**

No emulator figure is offered as a substitute, and nothing is claimed about behaviour there.

## 17. Widget Coverage — **NOT PROVEN, diagnosis corrected**

Three attempts, each with a different seam:

| attempt | seam | result |
| --- | --- | --- |
| 1 | real provider chain, `pump` only | body never drew; no exception |
| 2 | same + `runAsync` to resolve the chain | the chain's stream subscription stalled |
| 3 | **`backupStatusProvider` overridden with a fixed value** | **body still never drew** |

Attempt 3 is the informative one: with the status provider replaced by a constant, the screen
still renders only its app bar, so **the provider chain is not the cause** — the blocker is
inside the screen's own widget subtree when built under `flutter_test`, and it was not
identified. Nothing was changed in the screen to make a test pass; the gap is open with the
symptom, the three seams tried, and the elimination result recorded.

## 18. Performance Gate

`docs/PERFORMANCE-GATE.md` defines the commands, the datasets, the environment, the measured
baseline and the regression thresholds. It was **executed on the host** (Dataset A and B
phases) and, for Dataset A, on the device; **Dataset B on a device was not executed**, so the
gate's device half is documented and partially run, not fully run.

## 19. Clean Regression — **PASS**

From `flutter clean`: `pub get` → `dart analyze lib test integration_test test_driver` →
**No issues found!** → `flutter test` → **558 passed, 1 skipped, 0 failed** in 4:24. The single
skip is a platform-conditional test, present in every run, and not a backup/restore test.

## 20. Flakiness — **PASS — deterministic**

The critical subset (worker, hardening, kill matrix, round trip, failure, coordinator,
notifications, migration) was run **three times after `flutter clean`**: **129 passed** each, in
20 s / 22 s / 20 s — **0 failures, no retries used**. Together with the clean full run, that is
four green runs containing the critical tests.

## 21. Security — **PASS**

No secret leaves the device; the lock and biometric flags are excluded from the backup file and
asserted device-only; the app requests no storage permission; no hand-assembled SQL exists
anywhere — drift's parameterised expressions throughout, including `TableReader` and the
worker's path. Logs carry kinds, never records.

## 22. Android Backup Decision — **PASS (documented)**

Official source reviewed 2026-09-26
(`developer.android.com/guide/topics/manifest/application-element`): `allowBackup` defaults to
`true`; `false` disables all cloud backup and device-to-device transfer; **on Android 12+ some
manufacturers' devices cannot disable app-file migration between devices.** Decision: **keep
`allowBackup="false"`** — it closes cloud backup on every version, it makes the promise the app
already makes true, and the documented alternative (backup on, with exclusions) would leave the
outcome to a rules file the app cannot verify. The OEM device-to-device caveat is recorded as a
platform limitation for the privacy notes.

## 23. Remaining Risks

| # | Risk | Severity |
| --- | --- | --- |
| 1 | the import path (picker), the export path (chooser) and the uninstall/reinstall journey are the user's main recovery story and are untested | **P2 — release-critical** |
| 2 | PDF rendering, notification tapping and the 40k dataset are unverified on hardware | P2 |
| 3 | leak, device memory and device p95 unmeasured | P2 |
| 4 | the backup screen has no automated coverage, and the reason is not yet identified | P2 |
| 5 | low-end hardware unavailable | P2 |
| 6 | on some OEM Android 12+ devices, app files may migrate between devices despite `allowBackup="false"` | P3 (platform) |
| 7 | the worker's refusal classification is lost to the inline fallback (documented, no user-visible effect) | P3 |
| 8 | backups are unencrypted (documented decision) | P3 |

## 24. Final Acceptance Matrix

| Area | Status | Evidence |
| --- | --- | --- |
| Backup integrity | **PASS** | atomic write, checksum, collision-safe names |
| Restore integrity | **PASS** | one transaction, verification inside, rollback proven |
| Automatic backup | **PASS** | single-flight, coalescing, no false success |
| Kill 16/16 | **PASS** | `backup_kill_matrix_test.dart` |
| Disk failure | **PASS** | three scenarios on a refusing volume |
| Corruption | **PASS** | 15 cases, database unchanged |
| Duplicate protection | **PASS** | 3 restores, 3 merges |
| Merge | **PASS** | identity-based, conflicts reported |
| Financial integrity | **PASS** | `DebtCalculator` equality before/after |
| Multi-person | **PASS** | one record / 1,500 / three links |
| Notifications | **PASS** | no duplicates, stale cancelled |
| Notification tap | **NOT PROVEN** | not tapped on a device |
| Search | **PASS** | Arabic, English, phone, participants |
| Reports | **PASS** | built from restored records |
| PDF visual | **NOT PROVEN** | not opened on a device |
| SAF real UI | **NOT PROVEN** | not driven |
| Share/Save real UI | **NOT PROVEN** | not driven |
| Uninstall/Reinstall | **NOT PROVEN** | not executed |
| Dataset B real device | **NOT PROVEN** | host only |
| Device p95 | **NOT PROVEN** | harness reports p90 |
| Device memory | **NOT PROVEN** | host only |
| Memory leak | **NOT PROVEN** | not run |
| Low-end device | **NOT PROVEN** | no hardware |
| Widget coverage | **NOT PROVEN** | three seams tried; diagnosis corrected |
| Performance gate | **PARTIAL** | defined, host-executed, device half partial |
| Clean regression | **PASS** | 558 / 1 skipped / 0 failed from `flutter clean` |
| Flakiness | **PASS — deterministic** | 129 × 3, 0 failures, no retries |
| Android backup decision | **PASS** | official source reviewed, decision + caveat recorded |
| **Overall** | **PARTIAL** | — |

## 25. Final Verdict

**PARTIAL**

No P0 or P1 is open, and no defect was found in production behaviour — the engine is proven
where it was exercised, and it is safe to ship on that evidence. The closure criteria are
nonetheless unmet, because five release-critical user paths remain untested: the system picker,
the chooser, the uninstall/reinstall journey, PDF rendering and notification tapping. None of
them was replaced by a substitute that would have looked like a pass, and the one locally
closable gap (screen coverage) was attempted three times, failed, and is recorded with its
corrected diagnosis rather than its symptom alone.
