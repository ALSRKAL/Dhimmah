# Backup as a system, not a button — what changed, and what was proven

> The final UX pass and release gate that followed this work is
> [`backup-ux-final-report.md`](backup-ux-final-report.md): it reads the screen as
> a product on the Note 20 Ultra, fixes six defects the phone found (including a
> crash on the folder-unavailable path and a first-run headline that contradicted
> the card under it), and carries the current build's hash, screenshots and
> verdict. Where the two disagree about a *state's* wording, that one is later.

## Before

The subsystem was already real, and the audit at the start of this work found
more there than the brief assumed: a `BackupCoordinator` with a crash-safe
policy, lifecycle triggers, per-kind retention, a safety snapshot before
restore, a folder layer with eight health states, and 154 tests. What it was not
was *finished* as a protection system, and three things were missing that
mattered.

It could report a saved backup it had not checked. `BackupService.create` wrote
the file and re-parsed the envelope **it still held in memory**, with checksum
verification explicitly disabled — it never opened the file again. A write that
returned without throwing was treated as a backup.

It could not cope with failing. A failed automatic snapshot was swallowed and
forgotten: no record, no backoff, no limit, no way for the screen to say the app
had stopped managing to keep its promise.

And it had no idea what to tell the user. The screen showed a card derived from
two of the three things that decide whether data is protected, and the words it
had were "a snapshot is stored" / "changes are waiting". On a device whose
folder permission had been revoked, or whose writes had been failing for an hour,
it had nothing to say at all.

## After

**Every snapshot is read back off the disk before it is called saved.**
`create` now writes, reopens, parses, recomputes the checksum from the bytes on
disk, compares it to the one it meant to write, and compares the row counts to
the rows it read from the ledger. Any disagreement deletes the file and throws,
so a failure leaves the previous snapshot untouched and the list unchanged.
`BackupFormat.checkReadBack` is pure, so all five ways it can say no are unit
tested directly. A kill during verification is a new point in the kill matrix.

**Failing is a state, not a silence.** A new `BackupAttempts` model records the
last attempt, the last success, consecutive failures and the reason, in a small
JSON file beside the folder location — deliberately not in the database, because
a schema column would bump the version stamped into every backup file. The wait
between attempts doubles from two minutes to an hour, and past five consecutive
failures the state stops calling it a blip and says so; the app keeps trying, but
no more than hourly. Choosing a folder, re-authorizing one, asking for a check,
or saving by hand clears the record, because the user has just changed the thing
that was broken.

**The app now answers the question the user arrived with.** One pure engine folds
the snapshots, the folder's own report and the attempt history into a single
state — `protected`, `pending`, `backingUp`, `neverBackedUp`, `recoverable`,
`noLocation`, `storageIssue`, `attentionNeeded` — ordered most-actionable first.
The screen is built around that sentence instead of around its buttons, with the
numbers behind a "protection details" control and every previously-proven action
demoted below it.

## Automation — when a snapshot is taken, and why

Unchanged in spirit, extended in one place. A snapshot is due when:

- **a burst has changed the ledger** — twenty or more records since the last
  snapshot, whatever the interval;
- **the app is leaving the foreground** and the last snapshot is at least fifteen
  minutes old — the one moment when writing a few megabytes cannot be seen;
- **the user has been working** and the last snapshot is at least fifteen minutes
  old and nothing has been written for five seconds — so a long session produces
  recovery points without the user having to leave, and the write does not start
  in the same moment as the save that triggered it.

A foreground tick every five minutes *asks* the question and decides nothing on
its own — the policy answers. Observed doing exactly that on the phone at
21:35:35, with the user doing nothing for the preceding ten minutes. There is no background job, and the reason is not battery: **nothing can
change the ledger while the app is closed**, so a background snapshot could not
capture anything a session cannot, while a second process opening the same
database is a real way to corrupt it.

The dead `_changesSinceCheck` counter — incremented on every table update and
read by nothing — is gone, replaced by the timestamp the quiet period actually
needs.

## Safety — how data loss is prevented

- **Read-back verification** on every snapshot, of every kind.
- **Retention stated as promises**, and tested as such: a manual snapshot is
  never deleted; the newest of each kind is never deleted; at least two snapshots
  survive whenever there were two; only then do the counts apply.
- **A full disk gives space back rather than failing.** On a failed write the app
  drops the snapshots beyond its promised floor — never a manual one, never the
  newest — and retries once. If that does not help, the failure is reported as it
  stands, and it never goes below the floor to make room.
- **A safety copy before an irreversible act**: deleting a person, and clearing
  all data. Freshness-guarded, so ten deletions make one copy and not ten. Not
  added before schema migration, and deliberately: a snapshot needs a readable
  database, and if the migration is what is failing there is nothing to read —
  the migration's own transaction is the protection there.
- **Restore is unchanged**: still user-confirmed with a preview, still one
  transaction, still with a safety copy taken first.

## Real device

**Note 20 Ultra (SM-N986B, Android 13).** The phone dropped off the network
mid-session and came back on a new address; the run below is on
`192.168.0.3:5555`, and the APK on it was hash-compared to the local build first
(`sha256:421d4403…38d328`, identical).

The install was **upgraded in place**: it already had a configured folder, a
persisted grant and a snapshot from the previous build, so this is the state a
real user is in when they update the app.

| What | Result |
|---|---|
| The new screen, in Arabic, on the phone | `بياناتك محمية · آخر نسخة ناجحة · 27 سبتمبر 2026 · نسخة واحدة داخل التطبيق، 7 نسخ في مجلدك`, with `تفاصيل الحماية` and every previous action below it |
| The same header with work waiting | `هناك تغييرات بانتظار الحفظ` after a change was made and before it was saved |
| **An automatic snapshot with no tap** | after enabling automatic saving and bringing the app back to the front, `dhimmah-auto-20260927T195914593.dhimmah` appeared — 8 914 bytes, and it **contains the change that was waiting** (`SmokeCheck` among the 5 people). This is the **new in-session rule**: nothing was leaving the foreground, the last snapshot was 117 minutes old and the app had observed no changes of its own — the old policy would have returned "not due" |
| The alert channel, as Android registered it | `dhimmah_backup`, name `مشكلة في النسخ الاحتياطي`, importance 3 — beside the three existing channels |
| That file, independently | checksum recomputed over the canonical payload and matching; counts `5 people · 3 debts · 4 links · 2 payments · 1 obligation · 3 occurrences · 12 activity` |
| The attempt record | `dhimmah_backup_attempts.json` written on success: `lastSuccessAt` set, `consecutiveFailures: 0` |
| The switch | reflects the stored setting, and the app persists it |
| The history sheet | both layers intact, including the new snapshot as `9 KB · نسخة تلقائية` with restore, share and delete |
| An internal restore | `تمت الاستعادة بنجاح` in 45 s of driving; a safety copy (`dhimmah-safety-…200234205.dhimmah`, 8 916 bytes) was taken first, through the new verified path, and the ledger went to the snapshot's 4 people |

**One thing this run found that the tests could not.** The protection state did
not consider whether automatic saving was *on*. The upgrade inherited a `false`
for that setting — a restore carries the settings with it — and with automatic
saving off the app still said `بياناتك محمية`. Nothing was watching, and the
screen said it was. That is now a state of its own.

**One thing that was not a defect.** The first attempt at proving the automatic
path produced nothing at all, and the reason was that very setting: the app was
correctly refusing to save on its own because it had been told not to. It is
recorded here because "nothing happened" was, for a while, indistinguishable
from a broken engine.

### The defect this run found, and fixed

**Bug.** Turning automatic saving off stored `backup_auto_enabled = 0` and
changed nothing on screen. The switch stayed on, the headline stayed
`بياناتك محمية`, and the details still said automatic saving was enabled. Only a
restart showed the truth. The acceptance rule it broke: the app must never tell
the user their data is protected while it is not saving on its own.

**Root cause — `AppSettings.==`, one layer below the screen.**
`domain/entities/app_settings.dart` compared seventeen of its nineteen fields.
`backupAutoEnabled` and `defaultReminderLeads` were missing from both `==` and
`hashCode`.

That is not a cosmetic omission. Every consumer of a settings value decides
whether to do work by comparing it:

```
settingsRepository.update()      → writes the row, returns the new AppSettings
settingsDao.watch()              → emits the new row               ✓ proved
StreamProvider<AppSettings>      → holds the new value             ✓ proved
Provider<AppSettings> (folded)   → recomputes only if it changed   ✗ here
FutureProvider<BackupStatus>     → never re-ran
the screen                       → never rebuilt
```

The new settings compared **equal** to the old ones, so the folded provider was
never invalidated and nothing downstream was told anything had happened. The
value was in memory the whole time; nothing was listening for it.

This is why every earlier suspicion was wrong in an instructive way. The write
was fine, the drift stream was fine, Riverpod was fine, the backup screen was
fine — and each was ruled out by measurement, in that order, before the value
object was opened. A provider chain is only as honest as the `==` of the value it
carries.

**Fix.**

1. `AppSettings.==` and `hashCode` now cover **every** field.
   `defaultReminderLeads` is compared element-wise and hashed with
   `Object.hashAll` — comparing it by identity would make every emission look
   like a change, and comparing nothing (what the old code effectively did) makes
   a real change invisible.
2. `BackupProtection.automaticOff` is a state of its own, ranked above `pending`
   (with automatic saving off, waiting changes will never be captured by
   waiting) and applied whenever automatic saving is off **whatever the ledger
   holds** — an empty install must not read "protected" either.
3. The test harness no longer forces `backupAutoEnabled: true` into every seeded
   settings row, which is why no test could express the state an upgrade lands in.

**What it was not.** No `setState`, no polling, no timer, no forced rebuild, no
restart, and no change to the screen's structure. One value object was lying
about equality; the screen was reading the truth all along.

### The acceptance, on the phone, after the fix

The build on the device was hash-compared to the local APK first
(`sha256:e9802e3a…cb4e9d`). Every reading below is the phone's own state —
`app_flutter/dhimmah.sqlite` read straight out of the app's directory, and the
screen read with `uiautomator` while the guard confirmed Dhimmah owned it. A
walk that used blind coordinates earlier in the session landed on Samsung's
Device Care and described a screen that was not the app, which is why every press
now goes through the guard.

| | Database | Switch | Headline | Agree |
|---|---|---|---|---|
| **B** — automation off, app open | `0` | off | `الحفظ التلقائي متوقف` | yes |
| **B** — off, then a real change, then backgrounded | `0` | off | off | yes — **no `auto` snapshot was written and the attempt record did not move**, exactly as the coordinator's gate requires |
| **C** — the switch turned on, live | `1` | on | `هناك تغييرات بانتظار الحفظ` | yes — and it does **not** say protected, because work was waiting |
| **D** — off, force stop, launch | `0` | off | `الحفظ التلقائي متوقف` | yes |
| **E** — on, force stop, launch | `1` | on | — | yes |
| **A** — automation on, a change made, then **nothing at all** | `1` | on | `بياناتك محمية` after it saved | yes — at 21:35:35 the app wrote `dhimmah-auto-20260927T213535045.dhimmah` by itself: no tap, no leaving the app, no boundary. The five-minute timer asked, the policy said yes, and the file (10 159 bytes, checksum verified) contains both changes made during the test — `GateCheck` and `TimedGate` |

No restart was used to make anything true; restarts were used only to check that
the value is in the file rather than in the session. The state changed on screen
at the moment the switch was pressed, which is the thing that was broken.

The order of the readings is the argument. With automatic saving **off** the
headline was `الحفظ التلقائي متوقف`; turning it on with work waiting moved it to
`هناك تغييرات بانتظار الحفظ` — not to "protected", because work was waiting; and
only after the app had saved that work on its own, with nothing pending and the
folder reachable, did it read `بياناتك محمية`. Storage state, engine state,
protection state and UI state agreed at every step, and the last one was earned
rather than asserted.

### The states audited on the phone

On the Note 20 Ultra (`sha256:24be7fea…6989`, hash-matched to the local APK),
screenshot by screenshot:

| State | What the phone showed |
|---|---|
| Protected | `بياناتك محمية` · `آخر نسخة ناجحة · 27 سبتمبر 2026` · `5 نسخ داخل التطبيق · 7 نسخ في مجلدك` |
| Protected, details open | `الحفظ التلقائي : مفعّل` · `آخر نسخة : 27 سبتمبر 2026` · `نسخ قابلة للاستعادة : 12 نسخة` · `مجلد النسخ : متاح` |
| Automatic off | `الحفظ التلقائي متوقف`, the tile reading `النسخ التلقائي · متوقف` with the switch off, and the footer saying the current data is saved inside the app and no new copies will be made until it is turned back on |
| Folder available | `مجلد النسخ الاحتياطية · متاح · 7 نسخة صالحة` with `تغيير المجلد` and `فحص الآن` |
| History, several copies | `نسخة يدوية` / `27 سبتمبر 2026 · 8 KB · متحقق منها` with `أحدث نسخة` on the newest, the file name in small print, and the internal layer under `داخل التطبيق` |
| Restore preview | `استعادة نسخة احتياطية` · `هل تريد استعادة هذه البيانات؟` · the copy's date, its counts (`6 شخص · 3 دين · 3 دفعة`, `1 التزام · 0 تذكير · 4 ارتباط`), its currency, both modes with what each one does, `سيأخذ Dhimmah نسخة من بياناتك الحالية قبل الاستعادة، ويمكنك الرجوع إليها.`, and `الملف غير مشفّر: من يفتحه يقرأ بياناتك.` |

The preview is the one part of the restore flow that can be audited on a phone
holding the user's real data, because nothing happens until its confirm is
pressed. So the run opened it, read it, left by the sheet's own close control,
and then checked that it had changed nothing: the ledger's five counts were
identical before and after (`6 · 3 · 3 · 1 · 15`) and no safety copy had
appeared, so the sheet had offered and not acted.

**The states that are not in that table, and why.**

- *Pending* — captured live in the acceptance table above: with work waiting,
  the headline read `هناك تغييرات بانتظار الحفظ` and not "protected".
- *Backing up* — a screenshot of it would be a screenshot of a frame. On data
  this size the write takes milliseconds; the state is covered by the widget
  test that renders every state, not by a device pass.
- *No location*, *permission problem*, *storage problem* — each one needs the
  phone's real condition to be broken: the folder removed, the grant revoked,
  the disk filled. All three were exercised on this same phone in the previous
  run, which is where the folder layer's health states and the revoked grant
  were proven end to end; on this build they are rendered by widget tests. The
  choice here was not to break the user's own folder setup to photograph a state
  the tests already pin.
- *Empty history* — reaching it means deleting every copy the user has,
  including the ones outside the app. Not done on their phone; covered by the
  widget test.
- *Restore success and failure* — proven on this phone in the previous run, end
  to end and on real data: a restore timed at 2.78 s ending in
  `تمت الاستعادة بنجاح`, the safety copy holding the pre-restore state, a
  restore from the user's own folder on a wiped app coming back exactly, and
  three refusals (a damaged `.dhimmah`, a `.txt`, a re-restore) that left the
  folder and the ledger untouched. That run was on the build before this one.
  What is proven on the final build is the preview above, read off the glass,
  and the finished and failed sheets by the widget tests that render them.

### The English screen, on the phone

The acceptance asks for both directions, so the app's own Settings → Language row
was used to switch it — not a forced locale, not a debug flag — and the backup
screen read again in English:

> Back · **Backup and restore** · `Your data is protected` · `Last successful
> copy · Sep 27, 2026` · `5 copies inside the app · 7 in your folder` ·
> `Protection details` · `Backup folder · Available · 7 valid backups` ·
> `Change folder` · `Check now` · `Automatic backup · On` · `Save an external
> copy` · `Share the copy`

The layout mirrors rather than being translated in place: the app bar's back
control and the card's icon move to the left, the switch moves to the right of
its tile, the chevrons move to the right of their rows, and the Arabic holds
right-to-left with its values on the left. Both were read off the glass,
screenshot by screenshot.

Switching the language is a user setting, so the run puts it back: the app was
returned to Arabic and read again on the same build, and the two readings are
`docs/final-acceptance/device/n20-ux/logs/LANGUAGE_en.json` and `LANGUAGE_ar.json`.
`tool/language_audit.py` is the walk that does it, in either direction.

The counts fix below produced a second build (`sha256:8ce6473d…b47d`, also
hash-matched to the local APK), because a string is still a build. The state
readings were repeated on it, one press apart: switch on with `بياناتك محمية` and
`1` in the settings table, then switch off with `الحفظ التلقائي متوقف` and `0`,
then on again — and the English reading above is from it. The acceptance table
earlier in this section and the restore preview were taken on `24be7fea…`, and
the only difference between the two builds is that one line of copy in each
language.

Two copy defects were found **by looking at the screen and not by a test**, and
fixed before the final build:

- the details row read `الحفظ التلقائي : الحفظ التلقائي مفعّل` — the value was a
  headline sentence reused as a value, so it repeated its own label;
- the two copy counts ran together as `5 نسخ داخل التطبيق 7 نسخ في مجلدك`, which
  reads as one long number; they are now separated by `·`.

A third was found by reading the English screen on the phone, which is what that
audit is for:

- the English line read `5 copies inside the app · and 7 in your folder`. The
  separator already joins the two counts, so the "and" — and the Arabic `و` in
  the same two plural forms, which the phone did not happen to be showing —
  was doing the same job twice. Fixed in both `.arb` files, regenerated, and read
  again on the device in both languages.

RTL holds throughout: labels right, values left, controls on the left of each
row, the switch on the left of its tile, and no clipped Arabic. The English
screen is covered by a widget test that renders it end to end — an overflow in a
widget test is thrown, not logged, so reaching the end is the check.

The last reading of the session put the phone back where it was found. Automatic
saving had been turned off during the audit, and the press that was meant to turn
it back on went to the history sheet instead: a sheet covers the screen it came
from, the page behind it leaves the hierarchy, and this walk — which reads the
page to find its controls — could see neither the switch nor the marker it knows
the screen by. It pressed at the sheet's list, and the reading afterwards
(`backup_auto_enabled = 0`) looked like an app that had ignored the press. Both
faults were the walk's, and both are fixed in it rather than worked around: it
leaves a sheet by the sheet's own close control, and it recognises the backup
screen from the action rows that survive scrolling as well as from the protection
card, scrolling back to the top before it reads or presses. With those, the phone
read switch `false` and `الحفظ التلقائي متوقف` — in agreement with the database —
and a single press moved the switch to `true`, the headline to `بياناتك محمية`,
and the file to `backup_auto_enabled = 1`. The device is left as it was found,
with automatic saving on.

The longer walk in `backup_device_session.py` had the same fault from the other
end, and it cost a run: asked to reach the backup screen while the app was
already on it, it read the page, did not find the restore row — which is below
the fold and simply not in the hierarchy from the top of the list — called the
screen unrecognised, and pressed Back, walking away from the page it had been
asked to reach. Its own warning says what to do about that ("this tool must be
corrected rather than believed"), and it was: it now recognises the screen by the
protection card's control as well as by the restore row, and scrolls a control
onto the glass before pressing it. The preview audit above ran on the corrected
walk.

## UX — what changed, and what it was before

| | Before | After | Why |
|---|---|---|---|
| The head of the screen | a card answering "is my data safe?" in three fixed sentences | one state sentence, then when the last copy was made, then where the copies are | the user arrived with a question, not with a task list |
| The state | derived inside the card from two of the three facts | `BackupProtection`, one engine folding snapshots + folder + attempts | one answer, and it can be tested without a screen |
| The automatic control | a switch with a fixed sentence under it | the tile says `مفعّل` / `متوقف`, the icon changes, and the sentence under it changes too | a switch makes the user read the answer off a piece of furniture; and "off" is a different sentence, not the same one with a different position |
| Off means… | one sentence either way | `بياناتك الحالية محفوظة داخل التطبيق. لن تُنشأ نسخ جديدة تلقائيًا حتى تعيد تشغيله.` | the fear to answer is "did I just lose my data", and the answer is no |
| Protection details | folder state, pending count, a failure line | automatic on/off, last copy, restorable copies, waiting changes, folder state | the five things a user opens it to find — and nothing technical |
| Primary action | five rows of equal weight | one filled action, and only in the states where no card below already offers it | two buttons for one act is clutter; a screen with five equal actions has none |
| History rows | the file name, then kind · date · size | kind, then date · size · verified, then the file name in small print | the user is choosing *when* to go back to; the name is how they find the file in their own folder |
| The newest copy | found by comparing timestamps | marked `أحدث نسخة` | work the app can do instead of the user |
| Verified | implicit | `متحقق منها` on every row that was checked | the app's strongest claim, said plainly |
| Screen reader | the switch announced itself with an **empty label** | `MergeSemantics` on the tile: the row reads as one control, name and state | measured on the device, not assumed: "switch, on" and no word for *what* |

**The state model, unchanged in substance.** `protected · pending · backingUp ·
automaticOff · noLocation · neverBackedUp · recoverable · storageIssue ·
attentionNeeded`, ordered most-actionable first, from `protectionFrom` — pure,
and tested for every state and for every pair that has to be ranked.

**What was deliberately not added.** No charts, no storage dashboards, no badges,
no illustrations, no gamification, no cards inside cards. The screen gained a
button, four lines of detail and two words per history row; it lost a duplication
and a filename-as-headline.

## Tests

**738 tests pass** (617 before this work — 121 added). `flutter analyze` is clean.

The UX pass added 7 more: the automatic control stating its own position in both
positions, the header offering one action in a state that needs one and none in
the state whose whole point is that nothing is needed, the history marking its
newest copy and saying what was verified, the whole screen rendered in English,
and what a screen reader receives from the switch.

The fix itself added 32: an equality test that walks **every** `AppSettings`
field (so the next field added cannot be forgotten), two UI tests that toggle the
switch and watch the headline move both ways, three coordinator tests for the
switch being flipped while the app runs, and five persistence tests that close a
real database file and open it again.

| Area | Tests added |
|---|---|
| Read-back verification (`backup_verification_test.dart`) | 10 |
| Attempts, backoff, the store (`backup_attempts_test.dart`) | 15 |
| Coordinator: in-session rule, quiet period, backoff, give-up, restart, user action (`backup_coordinator_test.dart`) | +8 |
| Retention promises and the full-disk path (`backup_retention_test.dart`) | 8 |
| Protection engine, every state and every ordering (`backup_protection_test.dart`) | 23 |
| The screen in each state (`backup_protection_screen_test.dart`) | 12 |
| Kill matrix: a process killed during verification | +1 |

## Performance

Not re-measured on this build. The read-back adds one file read and one parse per
snapshot, and the existing profiling tools (`test/tool/backup_profile_test.dart`,
`backup_phase_profile_test.dart`, and the frame-timing integration test) are the
way to measure it — which needs the phone.

## Known limitations

- **iOS: `NOT PROVEN — REAL IOS HARDWARE`.** Nothing here was compiled or run for
  iOS. The alert tier's `DarwinNotificationDetails` uses the same defaults as the
  existing tiers, and that is all that can be said.
- **The alert has never been delivered on a device.** The channel exists — Android
  registered `dhimmah_backup` with the Arabic name, on both the phone and the
  emulator — and the decision behind it is unit tested. Posting one needs a real
  protection failure to happen on a running phone, which this run did not produce
  and which cannot be manufactured without breaking something on purpose.
- **Storage pressure is exercised by a read-only directory.** `dart:io` has no
  free-space query, so a full disk is emulated by the failure it produces.
- **`storageIssue` is not reachable in a widget test through the screen** — the
  folder check the screen runs is shallow, so `readOnly` only appears after an
  explicit deep check. It is covered by the engine tests and by the coordinator's
  real write failure.
- **The alert fires at most once per app run per state.** In-memory, by design:
  the app keeps no cross-launch record of what it has already said.

## Verdict

**READY WITH KNOWN LIMITATIONS.**

The acceptance rule is met, and it was checked in the direction that matters: the
user cannot see `بياناتك محمية` while the app is not saving on its own. Storage
state = engine state = protection state = UI state, with no delay and no restart —
on the physical Note 20 Ultra, in all five scenarios, with the database read out
of the app's own directory and compared against the screen at each step.

Both halves of the system were re-proven after the fix: with automatic saving
**off** a real change produced no automatic snapshot and the coordinator's attempt
record did not move; with it **on** the app captured the pending work by itself,
from the foreground timer, with the user doing nothing.

738 tests pass and the analysis is clean.

On the UX: the screen now answers the question in one sentence, says out loud
what the automatic control is doing, offers exactly one action when one is
needed and none when none is, describes each copy by when it was made rather than
by its file name, and tells a screen reader the name and the state of the switch.
The restore preview was read off the phone's own glass on this build: it names
the copy, its date, what is inside it, what each mode would do, what is taken
before it acts, and that the file is not encrypted — and leaving it by its own
close control changed nothing at all (`6 · 3 · 3 · 1 · 15` before and after, and
no safety copy written). None of the behaviour underneath it changed — the
engine, the verification, the folder, the restore and the retention are the ones
proven above, and they were re-run after every change.

The limitations that remain are the ones no amount of this work can remove: iOS is
`NOT PROVEN — REAL IOS HARDWARE`, and the alert has never actually been delivered
on a device because that needs a real protection failure to occur.
