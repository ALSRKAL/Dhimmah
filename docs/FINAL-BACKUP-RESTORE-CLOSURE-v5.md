# FINAL RELEASE ACCEPTANCE — v5

**Date:** 2026-09-26 · **Verdict: PARTIAL** — no defect found; release-critical items remain
NOT PROVEN (§14).

## 1. Executive verdict

Three things changed from v4: the clean-environment regression, the flakiness runs, and the
Android documentation review. Originally written as two — the third flakiness run completed
after the first draft, and this file records it., both with evidence: the **clean-environment regression** was run
(`flutter clean` → `pub get` → analyzer → full suite: **558 passed, 1 skipped, 0 failed**),
and the **Android backup documentation review** was performed against the official page —
which produced a finding that belongs in the decision record, not in the manifest.

Nothing else moved. SAF, Share/Save, uninstall/reinstall, PDF on a device, the leak run,
the 40,000-payment gate, low-end hardware, widget coverage and notification tap
routing are **NOT PROVEN**: not attempted, or attempted and not completed. No release-critical
item is claimed as passing without evidence, and no FAIL was found in production behaviour.

## 2. Exactly what changed from v4

| Item | v4 | v5 |
| --- | --- | --- |
| Clean-environment regression | NOT PROVEN | **PASS** (one clean run) |
| Android backup documentation | NOT PROVEN | **reviewed; decision recorded** (§9–10) |
| Flakiness (critical subset ×3) | **PASS — deterministic** | 129 passed × 3 runs (20 s, 22 s, 20 s), 0 failures, no retries |
| Everything else | unchanged | unchanged |

No production file was modified in this phase.

## 3. Tests executed

| Suite | Result |
| --- | --- |
| `dart analyze lib test integration_test test_driver` (clean state) | **No issues found!** |
| `flutter test` (full, after `flutter clean`) | **558 passed, 1 skipped, 0 failed** in 4:24 |
| Backup suites (worker, hardening, kill matrix, round trip, failure, coordinator) | **110 passed** (last run, pre-clean) |
| Critical subset ×3 (clean state, flakiness) | **129 passed each — 20 s, 22 s, 20 s — 0 failures** |
| Device: audit test (frames/scale, kill recovery, import from outside) | **3/3 passed** |
| Device: `restore ×10` | **10/10 passed** (v4) |

The one skipped test is a platform-conditional skip in the existing suite; it is not a
backup/restore test and it is skipped in both runs, so nothing is hidden by it.

## 4. Exact commands

```bash
flutter clean
flutter pub get
dart analyze lib test integration_test test_driver
flutter test
flutter test test/data/backup_worker_test.dart test/data/backup_hardening_test.dart \
  test/data/backup_kill_matrix_test.dart test/data/backup_round_trip_test.dart \
  test/data/backup_failure_test.dart test/data/backup_coordinator_test.dart \
  test/data/notification_lifecycle_test.dart test/data/migration_test.dart
flutter test integration_test/backup_audit_on_device_test.dart -d <S24 serial>
flutter test integration_test/backup_audit_on_device_test.dart -d <S24 serial> --plain-name 'ten times'
```

## 5. Device / environment

| | |
| --- | --- |
| Device | Galaxy S24 Ultra (SM-S928U1), Android 16 (API 36) |
| Build | debug, wireless adb |
| Host | Linux 6.8, Flutter 3.44.9, Dart 3.12.2 |
| Dataset A | 500 people / 2,500 records / 10,000 payments (3.21 MB file) |
| Dataset B | 1,000 / 10,000 / 40,000 — host only (**not** device) |

## 6. Raw result summaries

```
=== flutter clean ===                       OK
=== flutter pub get ===                     Got dependencies!
=== analyze ===                             No issues found!
=== FULL SUITE (clean state) ===            04:24 +558 ~1: All tests passed!
=== DEVICE RESTORE_X10 ===                  10/10 completed deterministically (643–940 ms)
=== DEVICE backup 500/2500/10000 ===       wall=581ms frames=73 build p90=2.9ms worst gap=275ms
=== DEVICE RESTORE_STEP: apply done ===    816 ms
```

## 7. Performance measurements

Corrected harness, S24 Ultra, Dataset A (the old harness's figures are discarded as
contaminated):

| Metric | Value |
| --- | ---: |
| backup wall | 581 ms |
| backup frames | 73 |
| build p50 / p90 | not captured / 2.9 ms |
| worst frame | 179 ms |
| **worst gap** | **275 ms** |
| blocked ≈ | 505 ms |
| restore wall | 816 ms (×10: 643–940 ms) |

`p95`, device peak memory and Dataset B on the device were **not** measured. Host figures for
Dataset B exist (create 8.6 s, restore 11.0 s, peak 589 MB) and are **not** device claims.

## 8. UI evidence

Real-device UI evidence in this phase: none. The device runs exercise the service and
controller paths and one screen-independent spinner; the system picker, the chooser, the PDF
preview and the notification tap were **not** driven through the UI. The screenshots taken
during earlier phases (frame harness) are not store assets and are not offered as acceptance
evidence here.

## 9. Android documentation findings

Source: `developer.android.com/guide/topics/manifest/application-element` (Android Developers,
`<application>` element reference), checked **2026-09-26**.

| Field | Finding |
| --- | --- |
| `android:allowBackup` default | `true` |
| `allowBackup="false"` | disables all cloud backup **and** device-to-device transfer, including `adb` full-system backup |
| Android 12+ (API 31+) note | *"for apps targeting Android 12 (API 31) or later this behaviour varies. On devices from some manufacturers, device-to-device migration of app files cannot be disabled."* |
| `android:fullBackupContent` | XML rules for Auto Backup; API 30 and below |
| `android:dataExtractionRules` | XML rules for which files/directories may be copied as part of **backup or transfer**; the API 31+ lever |
| Official recommendation for sensitive data | keep `allowBackup="true"` and use `dataExtractionRules` to exclude sensitive keys |

**Impact on Dhimmah.** The manifest already carries `allowBackup="false"`,
`fullBackupContent="false"` and `dataExtractionRules="@xml/data_extraction_rules"`, and the
rules file documents the intent ("nothing leaves the device, on any Android version") and
states that the rules cover API 31+ where D2D is governed separately from cloud backup. The
documentation confirms what the manifest can do — cloud backup is genuinely closed — and adds
one caveat the code cannot close: **on some manufacturers' Android 12+ devices, D2D migration
of app files cannot be disabled**, so an unencrypted ledger could still travel on a
device-to-device migration on those devices.

## 10. allowBackup decision

**Keep `allowBackup="false"`.** Reasons, in order: it closes cloud backup on every Android
version (confirmed by the documentation above); it makes the promise the app already makes to
the user true; and the alternative the documentation suggests — `allowBackup="true"` with
exclusions — would leave the decision to a rules file that the app cannot verify is honoured,
for a feature (OS-managed restore) that Dhimmah's own portable file already provides better.

**Recorded caveat (new):** on some OEM Android 12+ devices, D2D migration of app files cannot
be disabled by any manifest attribute, so the ledger may be copied in a device-to-device
migration. This is a platform limitation, not an application defect, and it should appear in
the privacy/security notes rather than be implied away. It also strengthens the case for
eventually encrypting the *live* database, which is a separate decision from the backup
format's encryption (documented in `docs/BACKUP-ENCRYPTION.md`).

## 11. Bugs found

None in production behaviour in this phase.

## 12. Bugs fixed

None. No file was changed.

## 13. Rejected changes + reason

| Rejected | Reason |
| --- | --- |
| Switching to `allowBackup="true"` + exclusions | the documentation's recommendation targets apps that *want* OS-managed restore; Dhimmah's supported path is its own portable file, and the rules file's honour cannot be verified by the app |
| Adding encryption in this phase | no key lifecycle decided; the decision record stands, and a rushed implementation is the failure mode the record exists to prevent |
| Fixing the worker's refusal classification | the product contract is correct through the fallback (the caller learns the right problem); changing it without a user-visible defect is churn |
| Lowering test expectations to reach green | nothing failed |

## 14. Remaining NOT PROVEN

| Item | Why | What it needs |
| --- | --- | --- |
| SAF / system picker | not driven through the UI | device UI automation or a guided manual pass with screenshots |
| Share/Save chooser | same | same, plus verifying the file at the destination |
| Uninstall → reinstall → restore via picker | not executed | the full journey on a device, with a semantic snapshot before and after |
| PDF on a device | not opened on a device | render a statement after a restore and inspect Arabic RTL, shaping, tables, amounts |
| Memory leak (6 cycles) | not run | six backup/restore cycles with memory recorded between them |
| Flakiness | **closed** — 3/3 runs green | — |
| Dataset B / 40k on device | not run | the audit test at 1,000/10,000/40,000 on the phone |
| p95, device peak memory | not captured | harness reporting them |
| Low-end device | no physical device available | a real mid/low-end device; an emulator is not a substitute |
| Widget coverage for the backup screen | two attempts, root causes known | a test seam that does not subscribe (or coverage moved to the integration layer) |
| Notification tap routing (foreground/background/killed/cold) | not tested | tap a real notification after a restore and assert the destination |
| Android docs, API-level specifics | one official page reviewed | the Auto Backup and data-extraction guides, if the D2D caveat needs narrowing per OEM |

## 15. Final acceptance matrix

| Area | Status | Evidence | Device/Env | Remaining Risk |
| --- | --- | --- | --- | --- |
| Restore ×10 | **PASS** | 10/10, 643–940 ms, full counts | S24 Ultra | — |
| Restore hang investigation | **CLOSED — harness** | no OS death event; local experiment refuted the alternative; corrected harness passes | S24 + host | none known |
| Worker success | **PASS** | payload/verdict identical to inline | host | — |
| Worker failure | **PASS** | refusals reach the caller with the right problem | host | extra inline pass (P3) |
| Worker timeout | **PASS** | zero timeout returns null, caller falls back, no wait | host | — |
| Worker exit (no answer) | **PASS** | same path, recorded | host | — |
| SAF | **NOT PROVEN** | not driven | — | import path unverified |
| Share/Save | **NOT PROVEN** | not driven | — | export path unverified |
| Uninstall/Reinstall | **NOT PROVEN** | not executed | — | the user's main recovery story |
| PDF real device | **NOT PROVEN** | not opened | — | rendering unverified |
| Memory / leak | **PARTIAL** | peak 589 MB (host, pre-worker); leak not run | host | device peak, retained memory |
| Clean environment | **PASS** | clean → 558/1 skipped/0 failed | host | one run only |
| Flakiness | **PASS — deterministic** | 129 × 3 runs green after `flutter clean`, plus the clean full run; 0 failures, no retries | host | — |
| Dataset A | **PASS** | 581 ms backup, 816 ms restore | S24 Ultra | — |
| Dataset B | **NOT PROVEN** | host only | host | device not measured |
| 40k performance | **NOT PROVEN** | host: create 8.6 s, restore 11.0 s | host | not a device claim |
| Android backup documentation | **PASS** | official page reviewed, finding recorded | — | OEM D2D caveat remains |
| allowBackup decision | **PASS** | keep `false`; caveat documented | — | platform limitation |
| Low-end device | **NOT PROVEN** | no hardware | — | responsiveness unknown there |
| Widget coverage | **NOT PROVEN** | two attempts, diagnosed | host | screen has no automated cover |
| Notification tap routing | **NOT PROVEN** | not tested | — | deep link unverified |
| Financial integrity | **PASS** | `DebtCalculator` equality before/after | host | — |
| Multi-person integrity | **PASS** | one record / 1,500 / three links | host | — |
| Corruption recovery | **PASS** | 15 cases, database unchanged | host | — |
| Kill / recovery | **PASS** | 16/16; device checklist 7/7 | host + S24 | — |
| Search | **PASS** | Arabic, English, phone, participants | host | — |
| Reports | **PASS** | built from restored records | host | PDF rendering NOT PROVEN |
| **Overall** | **PARTIAL** | — | — | — |

## 16. Release recommendation, strictly from evidence

**Ship the backup/restore engine; do not yet claim the release gate is closed.**

* The engine is safe to release: the restore is deterministic on the real device (10/10), the
  kill, disk, corruption, duplicate, merge, financial and multi-person behaviours are proven,
  the worker's contract including its silence is tested, and a clean build is green.
* The release gate is not closed: no **critical or high** severity defect was found, but
  several release-critical items are untested — the system picker and the chooser, the
  uninstall/reinstall journey, PDF rendering on a device, the leak run, flakiness, the 40k
  dataset on a device and tap routing. Each of those is a user-facing path that the app's own
  marketing will mention, so each needs either a pass or an explicit, written decision to ship
  without it.
* The one platform finding of the phase — device-to-device transfer cannot be disabled on some
  OEM Android 12+ devices — should be reflected in the privacy notes, and it is an argument
  for revisiting live-database encryption on its own merits.

**Verdict: PARTIAL.**
