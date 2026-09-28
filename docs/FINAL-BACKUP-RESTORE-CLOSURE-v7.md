# FINAL BACKUP / RESTORE CLOSURE v7

**Date:** 2026-09-26 · **Verdict: PARTIAL**

## 1. Executive Summary

One more gap was closed with device evidence: **memory across six real backup-and-restore
cycles on the S24 Ultra**, which reaches a working set and stays there rather than climbing —
so the leak question is answered for the workload that matters, with numbers.

The rest of the v6 list is unchanged, and unchanged for one reason: every remaining item is a
**physical-device UI flow** — the system picker, the chooser, an uninstall/reinstall cycle, a
rendered PDF, a tapped notification — and those were not driven. They are recorded as
NOT PROVEN with what each one needs, and none of them was replaced by a substitute that would
have looked like a pass. No production file was changed in v7.

## 2. v6 Remaining Gaps

| Gap | v6 | v7 |
| --- | --- | --- |
| SAF / system picker | NOT PROVEN | **NOT PROVEN** |
| Share / Save | NOT PROVEN | **NOT PROVEN** |
| Uninstall / reinstall | NOT PROVEN | **NOT PROVEN** |
| PDF on a device | NOT PROVEN | **NOT PROVEN** |
| Notification tap | NOT PROVEN | **NOT PROVEN** |
| Dataset B on a device | NOT PROVEN | **NOT PROVEN** |
| Device p95 | NOT PROVEN | **NOT PROVEN** |
| Device memory | NOT PROVEN | **PASS — six cycles measured** |
| Memory leak | NOT PROVEN | **PASS for six cycles** (RSS only; a heap profile was not taken) |
| Low-end device | NOT PROVEN | **NOT PROVEN — no hardware** |
| Widget coverage | NOT PROVEN | **NOT PROVEN — harness limitation** |

## 3. What Was Tested

`flutter test integration_test/backup_audit_on_device_test.dart -d <S24> --plain-name
'six backup and restore cycles'`, plus everything carried forward from v4–v6 (restore ×10,
kill recovery, import from outside, the 16-point kill matrix, the corruption matrix, disk
failure, duplicates, merge, financial and multi-person integrity, the worker's contract, the
clean regression and the flakiness runs). The full ledger is
`docs/final-acceptance/TEST-LEDGER.md`: 22 rows PASS, 11 rows NOT PROVEN, 0 FAIL.

## 4. Real Device Evidence

S24 Ultra (SM-S928U1), Android 16 (API 36), debug build, wireless adb:

* restore ×10: **10/10**, 643–940 ms, full counts on every run;
* backup 500/2,500/10,000: **581 ms**, 73 frames, build p90 2.9 ms, worst gap 275 ms;
* restore: **816 ms**;
* six cycles: memory **443 → 498/512 → 506/506/507/509 MB**;
* kill recovery checklist **7/7**;
* import from outside the app: `{people: 500, debts: 2500, debtPeople: 2500, payments: 10000}`.

## 5. SAF — **NOT PROVEN**

Not driven. Requires the system picker to be operated on the device; `adb` was not substituted.

## 6. Share/Save — **NOT PROVEN**

Not driven. The backup *file* is proven valid and importable; the act of saving it through the
chooser is not.

## 7. Uninstall/Reinstall — **NOT PROVEN**

Not executed. Known but not counted as a journey: the sandbox is removed with the app, and a
3.21 MB file imports into a fresh database through the app's own code.

## 8. Notification Tap — **NOT PROVEN**

Scheduling and payload→route mapping are proven in unit tests; a real notification was not
tapped in foreground, background, killed or cold-start state.

## 9. PDF — **NOT PROVEN**

Statement data is proven; the rendered document was not opened on a device.

## 10. Dataset B — **NOT PROVEN on device**

Host only: create 8.6 s, restore 11.0 s, peak 589 MB. Not offered as a device result.

## 11. Device Performance

Dataset A as above. p95 and device peak memory were not reported by the harness.

## 12. Device Memory — measured

| point | RSS |
| --- | ---: |
| baseline | 443 MB |
| cycle 1 | 498 MB |
| cycle 2 | 512 MB |
| cycle 3 | 506 MB |
| cycle 4 | 506 MB |
| cycle 5 | 507 MB |
| cycle 6 | 509 MB |

## 13. Leak Test — **PASS for six cycles**

The figure rises 55–69 MB over the first two cycles (warming: statement caches, payload
buffers, the in-memory ledger) and then **plateaus within 6 MB across cycles 3–6**. A leak
would climb monotonically; this does not. Recorded honestly: this is **VmRSS of a debug build
whose database is in memory**, which inflates the working set, and no heap/retained-object
profile was taken — so "no leak" is claimed for this workload and this metric, not as a
general statement about the allocator.

## 14. Kill Recovery — **PASS**

16/16 on the host across every phase boundary, plus 7/7 on the device after a killed write.

## 15. Data Integrity — **PASS**

Corruption (15 cases, database fingerprint unchanged), duplicates (3 restores, 3 merges),
merge by identity with conflicts reported, migration v1–v4 accepted and a future schema
refused.

## 16. Financial Integrity — **PASS**

`DebtCalculator` equality before and after; currencies never merged; amounts integer minor units.

## 17. Multi-Person Integrity — **PASS**

One record, 1,500, three links, 500 paid, 1,000 remaining — never 4,500, and the import run on
the device reproduced the same counts.

## 18. Performance Gate

Documented in `docs/PERFORMANCE-GATE.md` with commands, datasets, baseline and thresholds;
executed on the host for both datasets and on the device for Dataset A. **Dataset B on a device
was not executed.**

## 19. Clean Regression — **PASS**

`flutter clean` → `pub get` → analyzer **No issues found!** → `flutter test` **558 passed,
1 skipped, 0 failed** in 4:24.

## 20. Flakiness — **PASS — deterministic**

Critical subset ×3 after the clean build: **129 passed** each, 20 s / 22 s / 20 s,
**0 failures, no retries**.

## 21. Widget Harness Limitation — recorded, no production change

Three seams were tried (real chain; chain + `runAsync`; `backupStatusProvider` overridden with
a constant). Under the third, the screen still renders only its app bar, which **eliminates the
provider chain** as the cause and leaves something in the screen's own subtree unidentified.
Per the rule for this phase, **no production UI was changed to make a test pass**; the gap is
classified as a test-harness limitation, and the screen's real behaviour is covered where it
can be observed — on the device, where the app runs.

## 22. Android Backup Decision — **PASS (documented)**

Official page reviewed 2026-09-26; `allowBackup="false"` kept, with the platform caveat that
some OEM Android 12+ devices cannot disable device-to-device file migration.

## 23. Bugs Found

None in v7. No production defect was observed in any executed test.

## 24. Fixes Applied

None. No production file was modified in v7; the only change was to the integration test, which
gained the six-cycle memory measurement.

## 25. Remaining Risks

| # | Risk | Severity |
| --- | --- | --- |
| 1 | the five release-critical device flows (picker, chooser, reinstall, PDF, tap) are untested | **P2 — release-critical** |
| 2 | Dataset B and p95 unmetered on hardware | P2 |
| 3 | leak verified by RSS over six cycles only | P2 |
| 4 | no automated coverage of the backup screen | P2 (harness) |
| 5 | no low-end hardware | P2 |
| 6 | OEM device-to-device migration cannot be blocked on some devices | P3 (platform) |
| 7 | backups unencrypted (documented decision) | P3 |

## 26. Final Acceptance Matrix

| Area | Status | Evidence |
| --- | --- | --- |
| Backup integrity | **PASS** | atomic, checksummed, collision-safe |
| Restore integrity | **PASS** | transaction, verification inside, rollback proven |
| Automatic backup | **PASS** | single-flight, coalescing |
| Kill recovery | **PASS** | 16/16 host, 7/7 device |
| Disk failure | **PASS** | three scenarios |
| Corruption | **PASS** | 15 cases |
| Duplicate restore | **PASS** | 3 × restore, 3 × merge |
| Merge | **PASS** | identity, conflicts reported |
| Financial integrity | **PASS** | `DebtCalculator` equality |
| Multi-person | **PASS** | 1 / 1,500 / 3 links |
| Notifications | **PASS** | no duplicates, stale cancelled |
| Notification tap | **NOT PROVEN** | not tapped |
| Search | **PASS** | Arabic, English, phone, participants |
| Reports | **PASS** | from restored records |
| PDF visual real device | **NOT PROVEN** | not opened |
| SAF real UI | **NOT PROVEN** | not driven |
| Share/Save real UI | **NOT PROVEN** | not driven |
| Uninstall/Reinstall | **NOT PROVEN** | not executed |
| Dataset B device | **NOT PROVEN** | host only |
| Device p95 | **NOT PROVEN** | not reported |
| Device memory | **PASS** | six cycles, 443 → ~510 MB plateau |
| Memory leak | **PASS for six cycles** | no cumulative growth; RSS metric only |
| Low-end device | **NOT PROVEN** | no hardware |
| Widget coverage | **NOT PROVEN** | harness limitation |
| Performance gate | **PARTIAL** | documented; device half is Dataset A only |
| Clean regression | **PASS** | 558 / 1 skipped / 0 failed |
| Flakiness | **PASS — deterministic** | 129 × 3, 0 failures |
| Android backup decision | **PASS** | documented with the platform caveat |
| **Overall** | **PARTIAL** | — |

## 27. Final Verdict

**PARTIAL**

No P0 or P1, and no defect found in production behaviour: what has been exercised holds, and
the engine is safe to ship on that evidence. The closure criteria are still unmet, because the
user-facing half of the recovery story — choosing a file with the system picker, saving one
with the chooser, and surviving an uninstall and reinstall — has not been executed at all, and
neither has a rendered PDF, a tapped notification, Dataset B on hardware or a low-end device.
Those are not "difficult to automate" items to be waved through; they are untested, and the
ledger says so.
