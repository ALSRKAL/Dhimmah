# Dhimmah — the backup screen, final UX pass and release gate

The round before this one proved the subsystem: the engine, the scheduling, the
read-back verification, the folder lifecycle, the restore transaction and the
live agreement between the database, the engine, the screen and the switch. This
round changed none of that. It read the screen as a product, fixed what it found,
and ran the whole thing again on the phone.

**Build under test:** `sha256:5d4a2a47a8056458…`, hash-matched to the local APK,
installed on the Note 20 Ultra (SM-N986B, Android 13) in the user's own
configuration — Arabic, dark, 110% text scale, automatic saving on. Every
screenshot in this document is that build. `739` tests pass, `flutter analyze` is
clean.

Six defects were found **on the phone and not by a test**, and all six are fixed
and re-checked on the phone. Four of them were on paths the tests could not walk:
the folder-unavailable path (the app was killed by its own platform channel), the
first-run path (the headline contradicted the card under it), the reinstall path
(the screen offered no way to restore the copies it had just found) and the
restore preview (a date read a day early).

---

## What changed, and why

### The card reads as one ladder

| | Before | After |
|---|---|---|
| The state line | 17pt semibold | unchanged |
| When the last copy was made | 15pt **semibold**, primary colour — the same weight as the headline two points above it | 15pt regular, secondary colour |
| How many copies | 13.5pt, tertiary | unchanged |

Two titles stacked over a caption is not a hierarchy; the middle line is a fact
about the state, not a second heading. The three lines now descend in both size
and colour.

### Waiting is not a warning

`هناك تغييرات بانتظار الحفظ` was drawn in amber. That is the colour the app uses
for "something needs you", and this state is where the screen spends most of its
life: it is what being in the app looks like between an edit and the next
snapshot, and it clears itself. It is now the brand colour — the words carry the
meaning ("changes waiting to be saved"), and the icon stays a clock. Off, broken
and failed keep amber and red, because those are the states that do need
something.

### The details panel

- **Labels wrap no more.** `نسخ قابلة للاستعادة` broke across two lines in the
  middle of a phrase while the value beside it sat in space it did not need: the
  row was split one-to-two, giving the narrow column to the Arabic label. It is
  now an even split, and the two labels that were whole sentences
  (`هناك تغييرات بانتظار الحفظ` as a *label* beside a value reading "3 records are
  waiting to be saved") became labels: `تغييرات غير محفوظة`, `محاولات فاشلة`, with
  counts as values (`سجل واحد`, `3 مرات`).
- **The link lines up.** `تفاصيل الحماية` was inset from the card's edge by a text
  button's own padding; it now starts on the same line as everything else.
- **The two foot sections line up with each other** and with the section headings
  above them — one of them was four points out.

### Arabic inflects everywhere it counts

The restore sheets printed the number and the singular noun side by side, so a
copy holding two payments was offered as `2 دفعة`. The rest of the app inflects,
which is what made these stand out on the phone. Both count lines and the
currency line now inflect, read off the glass:

> `4 أشخاص · 3 ديون · دفعتان` · `التزام واحد · 0 تذكيرات · 4 ارتباطات` · `العملة: INR`

### A pronoun that could be read two ways

`بياناتك الحالية محفوظة داخل التطبيق. لن تُنشأ نسخ جديدة تلقائيًا حتى تعيد تشغيله.`
— the nearest noun before the pronoun is *the app*, so "until you restart it" was
available as a reading. It now says what it means: `حتى تُشغّل «الحفظ التلقائي»
مرة أخرى`.

### The first screen a new install shows

A clean install with no folder used to read `بياناتك محمية` — above a line saying
no copy had ever been made, above a card asking the user to choose a folder. The
first screen the product shows anyone was contradicting itself and answering "why
do I need a location?" with "you are protected already". An install with nowhere
to save now reads `لم يُحدَّد مكان دائم للنسخ`: not alarming — "your data is not
protected yet" stays reserved for a ledger with something in it — and not a claim
of protection either.

### The recovery path offers the recovery

A reinstall that found seven copies in the user's folder read `توجد نسخة يمكن
استعادتها` and offered **nothing to press**: the card that carries the restore
button was shown by asking whether the *app* had a snapshot of its own, and after
a wipe it never does. The card now follows the engine's own verdict, so a state
that says something can be put back always carries the way to put it back.

### The app's words, never the platform's

The folder row printed the provider's exception at the user: *"Failed to
determine if primary:Documents/Dhimmah Backups is child of primary:Documents:
java.io.FileNotFoundException…"* — English, Java, under an Arabic heading, in
three places (the row, the card and the message after a manual check). All three
now say what happened and what to do: `لم يعد للتطبيق وصول إلى هذا المجلد: إمّا أن
الإذن أُلغي، أو أن المجلد نُقل أو حُذف.` with `إعادة السماح` beside it. The
provider's message stays in the diagnostics, where it belongs.

### Copy

- English: `Computing the check digest` → `Computing its fingerprint`,
  `Preparing the snapshot` → `Preparing the copy`, `Tidying older snapshots` →
  `Tidying older copies`, `Re-authorize` → `Allow access again`,
  `Files named like backups but not valid` → `Files that look like backups but are
  not valid`, and the stray "and" in `5 copies inside the app · and 7 in your
  folder`, which the separator was already saying.
- **Nineteen strings the screen no longer draws** were removed from both `.arb`
  files, together with their metadata.
- **No motion was added.** The state change is a rebuild, the words and the
  colour carry it, and an animation here would be something to watch rather than
  something to read. The app's existing motion — the working overlay's spinner
  and the button progress — is unchanged.

---

## Visual QA

Screenshot by screenshot, on the phone, at the user's own text scale:

| State | What it showed |
|---|---|
| Protected | `بياناتك محمية` · `آخر نسخة ناجحة · 28 سبتمبر 2026` · `نسخة واحدة داخل التطبيق · 7 نسخ في مجلدك` |
| Protected, details open | the five facts, one line each, values in a column |
| Automatic off | `الحفظ التلقائي متوقف`, switch off, and the sentence that says the data inside the app is untouched and how to turn saving back on |
| Pending | `هناك تغييرات بانتظار الحفظ` in brand teal, `تغييرات غير محفوظة · سجل واحد` in the details |
| Automatic save, untouched | the app wrote `dhimmah-auto-20260928T031851283.dhimmah` by itself and the headline returned to `بياناتك محمية` |
| History | `نسخة يدوية` / `أحدث نسخة` / `27 سبتمبر 2026 · 8 KB · متحقق منها`, with the file name in small print under the folder's copies only |
| Restore preview | the copy, its date, its counts, both modes, the safety note, the encryption note, and one filled action |
| Folder unavailable | `النسخ الاحتياطية تحتاج انتباهك` · `لا شيء في مجلدك` · `بياناتك الحالية محفوظة داخل التطبيق ولم تتأثر.` + the re-link row |
| First run | `لم يُحدَّد مكان دائم للنسخ` + `أنشئ مكانًا لنسخك الاحتياطية` and one filled button |
| Reinstall recovery | `توجد نسخة يمكن استعادتها` + `وجدنا نسخة احتياطية` + `استعد من ملف` |
| After the restore | the ledger back at the copy's counts, then protected again after the app's own snapshot |
| English (LTR) | the whole screen mirrored, read line by line |
| 140% and 160% text | nothing clipped, no overflow, the details rows still one line each |

Defects found by looking, not by testing: the details label wrapping mid-phrase,
the provider's exception on the screen, the English counts reading `· and 7`, and
a screenshot from an earlier build that still showed the old wrap — which is why
every screenshot above was retaken on the one build.

---

## Arabic

- **RTL holds** at every scroll position and in every state: labels right, values
  left, controls on the leading edge, the switch at the trailing edge of its tile,
  chevrons on the leading edge of their rows.
- **No clipping, no truncation, no overflow** at 110% (the user's setting), 140%
  and 160%. The only ellipsis on the screen is the file name in the history, where
  the tail of a Latin file name is cut and the part that identifies the copy is
  kept.
- **Numbers** are Western digits throughout, as the settings ask for, and the
  plurals around them now agree with them: `نسخة واحدة داخل التطبيق`, `4 أشخاص`,
  `3 ديون`, `دفعتان`, `التزام واحد`, `4 ارتباطات`, `نسخة واحدة صالحة`.
- **Mixed Arabic and Latin** — `Dhimmah`, `INR`, file names — sits in the right
  direction in each case; the file name is a Latin run inside an RTL row and is
  rendered as one.
- **Punctuation**: the separator between the two copy counts is `·`, and the
  sentences that carried a stray connective after it lost it.
- Dates read `28 سبتمبر 2026` and, in the restore preview, now match the copy
  they describe: the file's own date and its newest change were being printed a
  day apart, because the rows' timestamps were read as UTC while the envelope's
  was converted to local time.

---

## English

The same screen, read as an English user, on the phone:

> Back · **Backup and restore** · `Your data is protected` · `Last successful copy
> · Sep 28, 2026` · `7 copies inside the app · 7 in your folder` ·
> `Protection details` · `Backup folder · Available · 7 valid backups` ·
> `Change folder` · `Check now` · `Automatic backup · On` · `Save an external
> copy` · `Share the copy`

- The layout mirrors rather than being translated in place: the back control and
  the status icons move to the leading edge, the switch to the trailing edge.
- Two awkward readings were fixed in this round (`· and 7 in your folder`,
  `Re-authorize`) and three more in the working-overlay steps, which were the only
  developer words left in a user-facing string (`check digest`, `snapshot`).
- Nothing else read as a literal translation: the sentences are short, active and
  about the user's data rather than about the app's machinery.

---

## Real device

The walkthrough, on the phone, through the app's own controls only:

| | What was done | What the phone said |
|---|---|---|
| **A** | opened the screen | `بياناتك محمية`, switch on, `7 نسخ داخل التطبيق · 7 نسخ في مجلدك` |
| **B** | turned automatic saving off, then on | `الحفظ التلقائي متوقف` ↔ `بياناتك محمية`, and the settings table agreed (`0` ↔ `1`) |
| **C** | made a real change (a new person, typed in the form) | `هناك تغييرات بانتظار الحفظ`, details `تغييرات غير محفوظة · سجل واحد` |
| **D** | put the phone down and touched nothing | at the next tick the app wrote `dhimmah-auto-20260928T031851283.dhimmah` by itself and the headline returned to `بياناتك محمية` — no tap, no leaving, no sheet |
| **E** | opened the history | both layers, `أحدث نسخة` marked, `متحقق منها` on every copy, the file name only where the user owns a file |
| **F** | opened the restore preview and closed it | the copy, its counts, both modes, the safety note; closing changed nothing (ledger counts identical before and after, no safety copy written) |
| **G** | moved the backup folder out of the way, cold-started, then put it back | `النسخ الاحتياطية تحتاج انتباهك` + `لا شيء في مجلدك` + `بياناتك الحالية محفوظة داخل التطبيق ولم تتأثر.` with the re-link row; after restoring the folder, the next start read `بياناتك محمية` again with all seven copies |
| **H** | force-stopped and relaunched | state, switch and folder all persisted |
| **I** | `pm clear`, then the whole recovery path | first-run asked for a folder, the folder was chosen through Android's own picker and consent dialog, the app found seven copies, offered `استعد من ملف`, the preview listed them, and the restore brought the ledger back exactly: `4 people · 3 debts · 2 payments · 1 obligation · 0 reminders · 4 links` — then the app snapshotted that work on its own and returned to `بياناتك محمية` |
| **J** | switched to English through Settings → Language and back | the screen mirrored correctly; the app was left in Arabic |

### The defects the phone found

1. **The app was killed by its own platform channel.** With the folder moved, the
   document calls raised `SecurityException`/`IllegalArgumentException`, and the
   Kotlin wrapper answered Flutter with the *value of the catch block* — `Unit`,
   which the standard codec cannot encode — so the process died with
   `FATAL EXCEPTION … Unsupported value: 'kotlin.Unit'`. This is the folder-missing
   and permission-revoked path: the two states a user reaches by moving or
   deleting their own folder. The wrapper now throws typed exceptions and the
   single answering point maps them, so one call gets exactly one reply.
2. **The provider's exception on the screen** (three call sites).
3. **The first-run headline contradicting the first-run card.**
4. **The recovery state with nothing to press.**
5. **The restore preview's "last change" a day early** (UTC vs local).
6. **The details panel wrapping mid-phrase.**

Each was fixed, tested where a test can reach it, and re-checked on the phone.

### What is not proven, and why

- *Backing up* is a state, not a screen: the write takes milliseconds on data this
  size. It is covered by the widget test that renders every state.
- *Storage issue* and *read-only folder* are rendered by widget tests; producing
  them on the phone means filling the disk or breaking the folder's permissions
  on the user's own storage, and the previous run already exercised the folder's
  health states and a revoked grant on this device.
- *Empty history* means deleting every copy the user has. Not done on their phone.
- *Restore failure* on this build: the refusals (a damaged file, a foreign file)
  were proven on the previous build and are pinned by tests; this build's restore
  success was proven end to end above.

---

## Tests

- `flutter analyze` — clean.
- `flutter test` — **739 pass** (738 before this round; one new widget test).
- Added or changed this round:
  - the protection engine's fresh-install case (`noLocation`, not `protected`),
    with the reasoning in the test;
  - the screen's recovery case: a reinstall with copies in the folder shows the
    found-copy card **and** the restore action;
  - the revoked-folder case now asserts the app's own sentence rather than the
    old fallback to the platform's message.
- **What the tests cannot reach:** the crash in (1) is Kotlin, and this project
  runs no Android instrumentation tests, so its regression test is the device
  reproduction recorded above. That is a gap, and it is named here rather than
  papered over.

---

## Regressions

None found. Two behaviour changes were made on purpose, both on paths the round
was asked to audit, and both are declared and tested:

- the empty-install-with-no-folder case now reports `noLocation`;
- the found-copy card now follows the engine instead of a second guess.

Nothing else in the frozen set moved: the coordinator, the scheduling policy, the
retention rules, the read-back verification, the folder architecture, the restore
transaction, the safety snapshot, the duplicate protection, the reconciliation and
the persistence are untouched, and the acceptance table from the previous round
was re-read on this build (`0`/off/`متوقف` and `1`/on/`محمية`, one press apart).

One process note: an edit script of mine damaged both `.arb` files mid-round. They
were rebuilt, the placeholder metadata was re-derived from the generated
signatures, and the result was verified by regenerating and diffing against the
previous generated output: only the intended strings changed.

---

## Known limitations

- **iOS: `NOT PROVEN — REAL IOS HARDWARE`.** Nothing was compiled or run for iOS.
- **The backup alert has still never been delivered on a device.** The channel and
  the decision are tested; delivery needs a real protection failure.
- **Storage pressure is emulated** by a read-only directory, because `dart:io` has
  no free-space query.
- **The states listed under "what is not proven"** are covered by widget tests
  rather than by a device pass, for the reasons given there.
- **The walk's own limits**: at 160% text scale the navigation heuristics needed a
  fix (the settings list scrolls its identifying words away); the fix is in the
  tool and is noted here because a tool that cannot reach a screen cannot audit
  it.
- **The emulator was never used as evidence**, at any point in this round.

---

## Git state

```
$ git status --short | wc -l        142
$ git status --short | grep -c '^ M'  78   (modified, tracked)
$ git status --short | grep -c '^??'  64   (untracked)
$ git log --oneline -1
310041a docs: the design document and the README
```

**Nothing was committed.** Everything from this round — and the whole backup
subsystem, which is untracked — lives in the working tree only. A `git clean`,
a hard reset or a careless checkout would take it with it. The last commit is from
the project's first session; the seventy-eight modified files are the app as it
now stands against that commit.

---

## Verdict

**READY WITH KNOWN LIMITATIONS.**

The rule this subsystem is held to — the user must never see `بياناتك محمية` while
automatic saving is off, or while nothing has been saved anywhere — held in every
state read off the phone this round, including the two that did not hold before it
(an empty install with no folder, and a folder that went missing under the app).
The screen answers the five questions in the order a person asks them, the six
defects the phone found are fixed and re-checked on the phone, and the limitations
that remain are the ones no amount of this work removes: iOS is unproven, the alert
has never actually been delivered, and a handful of states are covered by tests
because producing them on the user's own phone would mean damaging their data.

The device was left as it was found — Arabic, dark, automatic saving on, the
folder connected, the screen reading `بياناتك محمية`. Its ledger now holds the
copy that was restored during the recovery test (4 people, 3 debts, 2 payments,
1 obligation, 4 links) rather than the six records that were in it before the
wipe: those lived in the app's own snapshots, which a reinstall deletes, and the
restore brought back the newest copy the user's folder held. That is the whole
reason the folder exists, and it is stated here rather than glossed.
