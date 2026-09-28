# Dhimmah — release gate: audit, hardening, repair and acceptance

**Device:** Note 20 Ultra (SM-N986B), Android 13 (API 33), the user's own
configuration — Arabic, dark, 110% text scale.
**Builds:** debug `sha256:8ca93c740fb8ca1a…` (installed, hash-matched; see
Defect 1's follow-up) and release `sha256:ff74374faff311ea…` (built with R8,
installed and run for §45).
**Tests:** 742 pass; `flutter analyze` clean. **Git:** nothing committed — 79
modified, 65 untracked, last commit `310041a`.

Every PASS below names how it was checked. Where a thing could not be checked it
says so: `NOT PROVEN`, `PARTIAL` or `BLOCKED`, never a guess.

---

## Executive summary

The product was audited subsystem by subsystem against a release gate, and the
parts a user's money and history depend on were re-proven on the real phone. The
audit found **no new functional defect in the code**. It found one genuine
**test-coverage gap** (the lock), two **inherent notification limitations**, one
**documented PDF trade-off**, and it produced the **measurements and release
facts** a gate needs — including the answer to the question that would have
blocked a store submission: this build targets **API 36**, which is what Google
Play requires for updates since 31 August 2026.

What was re-proven on the device this round:

- **Notifications end to end**: the permission flow, the four channels as Android
  registered them, eleven scheduled notifications with correct times, distinct
  ids, localised Arabic text and payloads; a notification delivered by the app's
  own catch-up path; the tap route reproduced from the notification's own intent
  landing on the debt it named; a completed reminder removing exactly its
  scheduled notification (11 → 10); and the whole set re-armed by the boot
  receiver after a real reboot, before the app was opened.
- **PDF**: four documents generated from real fixtures, rendered and *looked at* —
  Arabic shaped and laid out right-to-left, LTR English, correct running balances,
  repeated table headers, page numbering, and a statement shared through Android's
  own chooser with the right content.
- **Backup and restore**: unchanged and re-read on the current build (protection
  state, folder counts, the automatic snapshot the app took on its own).

---

## Baseline

| | |
|---|---|
| Flutter / Dart | 3.44.9 stable · Dart SDK `^3.12.2` |
| App version | `1.0.0+1` (`versionCode 1`) |
| Android | `applicationId com.dhimmah.dhimmah`, namespace same, **minSdk 24, targetSdk 36, compileSdk 36** |
| Signing | no `key.properties` in the tree: the release task refuses to produce an unsigned artefact (deliberate; verified by reading `build.gradle.kts` and by building with a temporary debug-key config for this gate) |
| Release hardening | `isMinifyEnabled`, `isShrinkResources`, ProGuard rules, icon tree-shaking (99% off MaterialIcons) |
| iOS | deployment target 13.0, bundle id `com.dhimmah.dhimmah`; **no macOS on this machine** |
| Locales | `ar`, `en` (Arabic is the template) |
| Database | drift, `schemaVersion 4`, migrations v1→v4 additive and idempotent, `PRAGMA foreign_keys = ON` |
| Backup format | `dhimmah-backup`, `formatVersion 1`, checksum over a canonical payload |
| Tests | 742 passing (64 test files, 569 declarations at baseline; the lock-gate tests below were added after it) |
| Git | working tree only: 79 modified, 65 untracked; last commit is the project's first |

---

## Defects found

### 1. The lock has no tests — severity **medium** (coverage, not behaviour)

**Symptom:** the PIN/biometric lock gate is the only security control in the app
and no test file exercises its decisions. The app-level widget tests do hit it —
they print `Dhimmah: could not read the PIN state: MissingPluginException` — but
that exercises one path only (a keystore that cannot be read, which by design
leaves the lock as it was and lets the app render).

**Root cause:** the gate reads a concrete `PinService` through a provider the test
harness does not override, so a test cannot make a PIN exist, not exist, or fail.

**Fix:** **applied in the follow-up round that closed this report's open gap.**
The harness gained a `FakePinService` (it can hold a PIN, be empty, or throw —
the three states the gate has to tell apart) and a `pinService` override on
`pumpDhimmah`; `test/widget/lock_gate_test.dart` drives all three:

1. **No PIN with the flag set** ⇒ the ledger opens and the flag is corrected:
   the test polls `settings_dao.get()` until `lock_enabled` reads false.
2. **PIN present with the flag set** ⇒ the ledger is covered by the lock screen,
   and typing the PIN through the keypad unlocks it — the lock is not just
   shown, it is satisfiable.
3. **A keystore that cannot be read with the flag set** ⇒ no crash, and the lock
   **stays engaged** (fail closed: "could not tell" is never a way past it), and
   the flag on disk is left exactly as the user set it. This corrects the
   wording this report first carried ("no lock"): the designed and now tested
   behaviour is fail closed.

**The tests caught a real defect while being written.** The flag correction read
`effectiveSettingsProvider`, i.e. whatever the settings stream had emitted *so
far*. On a cold start the keystore can answer before drift has emitted, the
fallback then says `lockEnabled == false`, the correction is skipped, and the
stale flag stays on disk for another launch to trip over — the "correct the
flag" promise was racy. Fixed in `lib/app/lock_gate.dart`: the correction now
reads the row itself through `settingsRepositoryProvider.get()`, which always
answers and never hangs on an empty install. Regression proof: the new test
fails against the old gate and passes against the new one; full suite **742
passing**, `flutter analyze` clean; the rebuilt debug APK
(`sha256:8ca93c740fb8ca1a…`) was installed on the Note 20, opened to the
dashboard with no lock screen (correct: no PIN on the device), and the backup
screen read as found — `بياناتك محمية · 28 سبتمبر 2026 · 3 نسخ داخل التطبيق ·
7 نسخ في مجلدك`.

**What the code does today** (now proven by the tests above, no longer only
read): a lock with no key must never engage — the flag is corrected and the
ledger opens; "could not tell" leaves the lock exactly as it is, so a transient
platform failure is never a way past it. Both decisions have their reasoning
written at the call site.

### 2. Notifications: two inherent limitations — severity **low**

- **A timezone or DST change while the app is closed** shifts reminders until the
  next time the app is opened, because each reminder is scheduled as an absolute
  instant and recomputed on launch/resume (`refreshEnvironment` →
  `mustReschedule`). India has no DST, so this was **NOT PROVEN on this device**;
  it follows from the design.
- **Delivery is inexact on purpose** (`AndroidScheduleMode.inexactAllowWhileIdle`),
  which is why the app needs no `SCHEDULE_EXACT_ALARM` permission — the trade is
  that Android may delay a reminder (window `+1h` in the alarm table) and Doze can
  push it further.

### 3. PDF text layer — severity **low**, deliberate

The rendered glyphs are correct (seen on the page), but the text layer stores the
*shaped* Arabic forms, so `pdftotext` returns presentation-form code points: copy
and search inside a viewer may not match base letters. This is the documented cost
of shaping Arabic for a renderer with no OpenType support
(`arabic_shaper.dart` + `pdf_text.dart`), and the alternative — unshaped text —
prints boxes.

### 4. A measurement that looked like a defect, and is not

`test/tool/fanout_profile_test.dart` prints *"one payment write: 2642 ms wall"*.
Reading the test shows the stopwatch includes a fixed `Future.delayed(2500 ms)`:
the real cost of the write plus **all six screens' re-reads** at 1000 debts /
4000 payments is **~142 ms**. Recorded because it is exactly the kind of number
that would have been reported as a regression without checking.

---

## Data integrity

**PASS (static + tests).** Reviewed the full schema, the migration path and every
delete path against the "a record must not disappear or duplicate" rule:

- `debt_people` has a composite primary key `(debtId, personId)` and cascades on
  both sides: a duplicate participant is impossible at the schema level.
- `obligation_occurrences` carries `UNIQUE (obligation_id, period_key)`.
- `PRAGMA foreign_keys = ON` on every open, so the declared actions actually run.
- Deleting a person does **not** delete their debts: the participant link is
  removed inside the same transaction and the debt keeps its amount and history.
- Deleting a debt removes its payments **and** its activity rows in one
  transaction, and returns a snapshot so the UI's undo can put it back.
- Money is an integer count of minor units with currency-guarded arithmetic;
  doubles are confined to display (`asDouble` is documented as display-only).
- Migrations are additive and idempotent, and a file from a newer build is refused
  by name (`DatabaseTooNewException`) rather than half-read.
- Tests: `migration_test.dart` (v1→v3 with data, run twice, index recreation, a
  paid debt's closing stamp carried across, a newer file refused),
  `backward_compatibility_test.dart`, `database_test.dart`,
  `multi_person_debt_test.dart`.

No orphan path was found: the `setNull` foreign keys are a safety net, and the
service-level deletes do the real work first.

---

## Notifications

**PASS on the device, with the limitations in §2.** What was checked and how:

| Check | Evidence |
|---|---|
| Channels as Android registered them | `dumpsys notification --noredact`: `dhimmah_due` (مستحق الآن, importance 4), `dhimmah_upcoming` (استحقاقات قادمة, 3), `dhimmah_monthly_summary` (الملخص الشهري, 3), `dhimmah_backup` (مشكلة في النسخ الاحتياطي, 3) |
| Permission denied → honest UI | fresh install: `POST_NOTIFICATIONS: granted=false` and the settings section footers `الإشعارات غير مفعّلة في إعدادات النظام.`; granting it through the app's own toggle then reads `granted=true, flags=[USER_SET]` |
| Scheduling | the plugin's own store: **11 notifications**, each with a distinct 31-bit id, the right local time (`20:00` on the lead day, `2026-09-28T20:00` for a reminder due today), a localised title (`دفعة مستحقة قريبًا`, `دفعة متأخرة`, `التزام مستحق`, `تذكير`) and a payload naming the record |
| Text quality | bodies carry the participant and the amount with Unicode bidi isolates around the number (`Ahmed — ⁦₹ 1,000⁩ · خلال يومين`) |
| Delivery | the app posted its month-end summary by itself; Android recorded `channel=dhimmah_monthly_summary`, `vis=PRIVATE` |
| Tap route | the notification's own intent (`action=SELECT_NOTIFICATION`, extras `payload`/`notificationId`) reproduced on a cold start landed on **that debt's screen** — not the dashboard |
| Edit/delete cancellation | completing the reminder removed exactly its entry: 11 → 10 scheduled, no stale notification |
| Restart | the phone was rebooted; **before the app was opened**, `dumpsys alarm` again listed Dhimmah's alarms (`RTC_WAKEUP … ScheduledNotificationReceiver`, `origWhen=2026-09-29 20:00:00`, `window=+1h`) at the same trigger times — re-armed by the boot receiver |
| No duplicates | reconciliation is a set operation (build the wanted ids, cancel the rest, schedule the missing); ids are a hash of `payload|kind|when`, so two passes compute the same id and Android replaces rather than duplicates |
| Privacy | `visibility: private` on every tier; the log line keeps kinds only, never an amount or a name; the alarm and channel tables confirm the private visibility reached the system |
| Not a notification machine | four channels, one summary, leads chosen by the user, a 400-notification cap with the soonest kept, and no notification for a successful backup |

---

## Backup

**PASS — unchanged, re-read on this build.** The subsystem was verified in the
previous rounds and was not rebuilt. This round re-read it on the phone:
`بياناتك محمية`, switch on, `3 نسخ داخل التطبيق · 7 نسخ في مجلدك`, `تفاصيل الحماية`
showing the five facts in the user's language, and the app taking a snapshot by
itself after writes (`نسختان` → `3` copies inside the app while this round ran).

Nothing in the frozen set was touched: coordinator, scheduling policy, retention,
read-back verification, folder architecture, restore transaction, safety snapshot,
duplicate protection, reconciliation, persistence.

---

## Restore

**PASS (proven in the previous round on this codebase; re-read here).** The
recovery path — wipe, re-authorise the folder, find the copies, restore, verify —
was run end to end on the previous round's build and its data integrity verified
from the database. This round exercised the pieces that touch it: the plugin's
scheduled set updates on the writes a restore makes, and the validation code
(`backup_validation.dart`) rejects a file that is not ours, a damaged file and a
newer format by name, with tests.

One restore-adjacent defect was **fixed and verified in the previous round** (the
folder-unavailable path killed the process; the Kotlin wrapper answered `Unit`),
and that fix is in this build.

---

## PDF

**PASS.** Four sample statements were generated from fixtures
(`flutter test test/tool/generate_statement_samples_test.dart` →
`build/qa/*.pdf`), rendered with `pdftoppm` and inspected as images, then a real
statement was shared from the phone.

- **Arabic**: shaped and joined correctly — no disconnected letters, correct
  ligatures, correct mark handling; the document is right-to-left throughout
  (brand and title right, document number and date left), tables run
  right-to-left with the first column on the right, and totals sit in a shaded
  row.
- **Numbers**: integer minor units throughout; `₹ 68,500 = ₹ 45,500 + ₹ 23,000` in
  the summary, and the payments table's running balance descends correctly
  (`66,500 … 45,500`, each row −₹500).
- **Pagination**: 2 pages for 26 entries, the table header repeated on page 2, and
  `صفحة 1 من 2` / `Page 2 of 2` in the footer matching `pdfinfo`'s page count.
- **Mixed content**: Arabic names, `INR`, Latin digits, `+967 771 234 567` and
  Arabic notes inside the English document all render in the right direction.
- **Long content**: a four-part Arabic name and a wrapping Arabic note both wrap
  instead of clipping; the file name itself is Arabic and long
  (`Dhimmah_أحمد_محمد_عبد_الرحمن_الشامي_2026-09-28.pdf`).
- **On the device**: the debt screen's share opened Android's chooser with the
  statement's own preview (`إجمالي الدين: ₹ 1,000`, `المدفوع: ₹ 0`,
  `المتبقي: ₹ 1,000` — the app's own figures), targets including *Save*, and
  cancelling returned to the app with no crash and no stray state.

The text-layer trade-off is in §3.

---

## UX

**PASS (the previous round's work, unchanged).** The backup screen was read on the
device as a product: one state sentence, the five facts behind one control, the
automatic control saying its own state, the history scanning by kind and date, the
folder card naming the folder rather than a URI, the restore preview carrying one
filled action, and no jargon. Re-read this round on the release build and on the
debug build without change. The one UX question this round raised — does turning
the app lock on and dismissing the PIN sheet leave the app locked with no PIN —
was tested: `lock_enabled` is `0` afterwards, so it does not.

---

## Accessibility

**PASS for what was measured; PARTIAL overall.** Measured: contrast on every pair
the screen uses (5.36:1 worst case, on text tertiary over the card — all above
4.5:1); touch targets at or above 48 dp by theme (`minimumSize` 48–52); text
scaling on the device at 110% (the user's setting), 140% and 160% with no
clipping, no overflow and the details rows still one line each; the switch
announces its state (`MergeSemantics`); every actionable control on the backup
screen carries a label in the accessibility tree.

**Not measured:** TalkBack walked by hand, focus order under a screen reader, and
the same checks on the six screens this round did not open. Those are `NOT PROVEN`.

---

## Performance

| What | Number | How |
|---|---|---|
| Release cold start | **985 ms** (`TotalTime`) | `am start -W` on the installed release build |
| Debug cold start | 5567 ms | same, for contrast — a debug build is not what users run |
| Person page at the top of its range | **407 ms** for 300 debts / 1200 payments | `test/tool/fanout_profile_test.dart` |
| One payment + all six screens re-reading | **~142 ms** at 1000 debts / 4000 payments | same file, minus its own fixed 2.5 s window |
| Backup/restore timing | unchanged from the previous round (2.78 s restore, 2.96 s external save on the phone) | previous round's device evidence |

A large dataset was **not** built on the phone (§33 asks for 500 people / 2500
debts / 10000 payments): the app has no bulk import, and manufacturing it would
mean writing a test-only path into production code. The scale numbers above come
from the repository's own profile tests, which seed those tables directly —
`PARTIAL` against §33's device requirement, and named as such.

---

## Security

| Check | Result |
|---|---|
| Permissions in the release APK | `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `USE_BIOMETRIC`, `VIBRATE` — and **no `INTERNET`** |
| Exported components | only `MainActivity`; every receiver and provider `exported="false"` |
| Cloud auto-backup | `android:allowBackup="false"` with explicit extraction rules |
| PIN | keystore-backed (`flutter_secure_storage`); the digest never enters the database |
| Does a backup carry the lock? | **No**: the codec's settings projection lists language, theme, numerals, currency, notification preferences, leads, summary settings, onboarding — and deliberately omits `lockEnabled` and `biometricEnabled` |
| Logs | no amounts or names; notification logs carry kinds only; `debugPrint` uses are debug-guarded or a start-up failure message |
| Third-party surface | no network permission means no exfiltration path, and sharing happens through Android's own chooser |

---

## Upgrade / reinstall

**PASS on the device, by the strongest available means.** The same package was
installed over itself more than ten times this round and in the previous ones —
including debug→release and release→debug — and each time the ledger, the settings,
the backup folder, the folder grant and the app's own copies were still there.
The versioned migration path (v1→v4) is covered by `migration_test.dart` with real
data and by `backward_compatibility_test.dart`; a downgrade is refused by name.

The device never held a *v1* database, so the on-device proof is of the *install*
paths, not of the versioned upgrade itself: **PARTIAL** against a full upgrade
matrix, with the versioned half covered by tests rather than by hardware.

---

## Android real device

Note 20 Ultra, Android 13. Every press went through the guard that refuses to act
unless the window manager and the accessibility tree agree Dhimmah owns the screen;
system surfaces (the folder picker, the consent dialog, the notification
permission dialog, the share chooser) were driven by their own labels, and the
guard logged `SKIPPED — ENVIRONMENT` rather than pressing at anything that was not
Dhimmah or an expected system surface.

Proven this round: the notification matrix in §Notifications (permission, channels,
scheduling, delivery, tap routing, cancellation, reboot), the PDF share, the
release build running with R8, the backup screen on both builds, and the app
returning to `بياناتك محمية` on its own.

---

## iOS

**`NOT PROVEN — REAL IOS HARDWARE`.** There is no iPhone and no macOS on this
machine, so nothing could be compiled, run or inspected for iOS. The iOS-side
code was read for structure only; no claim is made about it. Every
hardware-specific iOS case in this report is `NOT PROVEN` or `BLOCKED`, never
`PASS`.

---

## Test count

**742 passing**, `flutter analyze` clean, run after every change and again after
the lock-gate follow-up (§1). 64 test files at baseline; the follow-up added
`test/widget/lock_gate_test.dart`, which is where the flag-correction race was
caught and fixed.

---

## Build

| | |
|---|---|
| Debug | `sha256:8ca93c740fb8ca1a…` — installed and hash-matched to the local artefact (rebuilt after the lock-gate fix; the earlier gate build was `sha256:5d4a2a47a8056458…`) |
| Release | `sha256:ff74374faff311ea…` — built with R8 and resource shrinking, installed, cold-started (985 ms), and smoked: the backup screen loaded with live data and logcat carried no exception |
| Release signing | none in the tree; the release task fails rather than emitting an unsigned artefact. The gate build used a temporary debug-key `key.properties`, which was removed afterwards |
| Store compliance | targetSdk **36** (Play requires 36 for new apps and updates since 31 Aug 2026, extension to 1 Nov 2026), minSdk 24, no INTERNET, minimal exported surface |

---

## Git

```
$ git status --short | wc -l          144
$ git status --short | grep -c '^ M'     79   modified, tracked
$ git status --short | grep -c '^??'     65   untracked
$ git log --oneline -1
310041a docs: the design document and the README
```

**Nothing was committed, and the backup subsystem is not in git at all.** The
whole product as it stands lives in the working tree; a `git clean`, a
`git checkout -- .` or a hard reset would take it. Files this work added to the
tree and removed again: `android/key.properties` (temporary signing config).
Files added and kept: `docs/release-gate-report.md`,
`docs/backup-ux-final-report.md`, `test/widget/lock_gate_test.dart`, and the
other untracked work listed above.

---

## Known limitations

1. **The lock gate is tested (§1), but its biometric half is not** — the PIN
   path is proven in the widget tests; the fingerprint prompt was never
   exercised on real hardware and stays `NOT PROVEN — REAL IOS/BIOMETRIC
   HARDWARE`.
2. **iOS is unproven** in every respect: no hardware, no toolchain.
3. **A timezone or DST change while the app is closed** can shift reminders until
   the next launch; not reproducible in this timezone.
4. **Reminders are inexact** by design (no exact-alarm permission); Android may
   delay them, and Doze may delay them further.
5. **PDF copy/paste and search** operate on shaped forms, not base letters.
6. **The large-dataset acceptance was not run on the phone** (§33); the scale
   numbers come from the repository's own profile tests.
7. **TalkBack was not walked by hand**, and only the backup screen was audited at
   large text scales.
8. **The versioned upgrade (v1→v4) is proven by tests, not on hardware** — the
   device never held an old schema.
9. **The backup alert has still never been delivered** on a device: it needs a
   real, repeated protection failure to occur.

---

## Final verdict

**READY WITH KNOWN LIMITATIONS.**

The subsystems a user's money depends on were audited and re-proven: the data
layer's integrity (schema, migrations, deletes, integer money), the backup and
restore path, the notification pipeline end to end on the phone including a reboot,
the PDF's rendering and data, and a release build that runs with R8 shrinking.
The store requirements that would block a submission are met, the app asks for no
network permission at all, and the sensitive state (the PIN, the lock flags) is
kept out of every file the app writes.

The limitations are real and are listed above rather than softened: the lock's
biometric half is unproven on hardware, iOS is unproven, the large-dataset run
happened in the profile harness rather than on the handset, and two notification
behaviours are inherent to deliberate design choices. None of them is a claim of
protection that is not kept, and none of them can lose a record — which is the
bar this project set for itself.

The device was left as it was found: Arabic, dark, automatic saving on, the folder
connected, three copies inside the app and seven in the user's folder, the screen
reading `بياناتك محمية`.
