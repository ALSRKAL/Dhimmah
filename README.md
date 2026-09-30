# ذِمّة — Dhimmah

**اعرف ما لك وما عليك** · *Know what you owe. Know what you're owed.*

A personal ledger for the two sides of your financial life: the money you owe
people, the money people owe you, and the commitments that come back every month.
Offline-first, in the phone's own language — Arabic or English — and designed
to be understood in under a minute.

---

## What it does

| | |
|---|---|
| **الرئيسية / Home** | Where you stand, the two sides of the book, and what needs attention |
| **السجل / Ledger** | Every debt, switched between what you owe and what you are owed |
| **الالتزامات / Obligations** | Rent, bills, subscriptions, salaries — with automatic next periods |
| **التذكيرات / Reminders** | Local notifications for anything with a deadline |
| **التقارير / Reports** | A monthly report with paid, received and overdue totals |
| **الأشخاص / People** | One page per person, rolling up every debt linked to them — a debt linked to several people appears on each of their pages as one of their own |
| **كشف حساب / Statement** | A real PDF debt statement, in Arabic or English, to send or print |

Five destinations, no duplicates. The dashboard answers four questions before you
scroll: **where do I stand, how much do I owe, how much am I owed, and what is
late.** Below that it names the specific records that need attention, and the
monthly report adds one true sentence derived from the month's own figures —
never a guess.

### Deliberate limits

* **No exchange rates.** Balances are reported per currency and never added
  together. ﷼ and ₹ stay in separate columns until a real conversion layer exists.
* **One nudge, not a stream.** A late item produces a single reminder two days
  after the deadline, not a daily notification, and notifications come in three
  tiers so the loud one still means something.
* **Inexact reminders, and no exact-alarm permission.** A reminder is "look at
  this today", not an alarm clock, so nothing asks Android to fire at a precise
  millisecond — and the app therefore never requests `SCHEDULE_EXACT_ALARM`,
  which Android 14+ denies by default anyway, nor `USE_EXACT_ALARM`, which Play
  reserves for alarm and calendar apps.
* **The soonest 400, not everything.** Android — Samsung's build in particular —
  does not hold an unbounded number of alarms per app. A large ledger asks for
  more than any phone will keep, so the app arms the soonest four hundred and
  rebuilds the set on every launch, every save and every environment change.
* **No invented insight.** Every sentence the app says about your money is
  computed from records you entered.
* **Nothing shown twice.** One add button, one currency mechanism, one place per
  fact. Two ways to do the same thing is one too many.
* **Money in integers.** Amounts are stored as integer minor units, so
  `0.1 + 0.2` never decides whether a debt is settled.
* **No share per person.** A debt can be recorded with several people, and the
  app never divides it between them: there is no field to store a share and no
  rule to derive one. The amount is one amount, it is counted once in the ledger,
  and it is listed on every participant's page without being added to any of
  their balances — see *One record, several people* below for why that is the
  only answer that cannot be wrong.

---

## The statement PDF

Press **مشاركة كشف** on a person and Dhimmah builds a real financial document:
header with the mark and a document number, the account summary, a payment history
with a running balance, a status badge, and a footer with the file's own ID on
every page. The recipient sees a statement, not a picture of an app.

Arabic is the hard part, and it is handled in two halves that are deliberately
in different places:

* **Shaping is ours.** The PDF library lays text out glyph by glyph and applies no
  OpenType features, so Arabic handed to it raw comes out as disconnected letters.
  `core/pdf/arabic_shaper.dart` substitutes the contextual form each letter takes
  — and the obligatory lam-alef ligatures — in the Unicode presentation forms,
  which the bundled font covers. Shadda-and-vowel pairs the algorithm composes
  into legacy ligatures the font does *not* have are expanded back, so no code
  point can reach the page without a glyph.
* **Ordering, wrapping and alignment are the renderer's.** The text is handed over
  in logical order with a right-to-left direction, and the renderer applies the
  Unicode bidirectional algorithm, arranges each line from the reading side, and
  breaks lines in logical order. Doing the reordering here instead — which this
  file used to do — meant the width that was measured belonged to one string and
  the width that was drawn to another, and a long debt title was printed past the
  margin and clipped.
* **Direction is decided per string, not per document.** A Latin or numeric string
  is drawn left-to-right even in an Arabic statement, because the renderer
  reorders every right-to-left paragraph by reversing its words and `₹ 45,500`
  would come out as `45,500 ₹`. Bidi control characters are stripped: they are
  layout hints for a weaker engine, and here they are only a missing glyph
  sitting between two digits.
* **Mixed content.** `تم الدفع إلى Ahmed بمبلغ 1,250 INR` reads correctly in both
  directions, with the Latin words untouched and the Arabic shaped.
* **Separate layouts.** Arabic and English are laid out independently, not one
  mirrored from the other: reading order is not a transform.

The document is checked two ways: rasterised and looked at, and — for the
regression — read back. `test/core/pdf/statement_geometry_test.dart` parses the
finished file's own drawing instructions, works out where every run of text
lands, and asserts that nothing is drawn outside the margins and that a
right-to-left line reads in the order a person reads it. One of its tests draws a
deliberately overflowing line to prove the check can fail.

---

## Running it

```bash
flutter pub get
dart run build_runner build        # generates the drift database code
flutter gen-l10n                   # generates the localisations
flutter run
```

Requires Flutter 3.44+ / Dart 3.12+. SQLite is bundled through Dart's
native-assets build hooks, so there is no extra database setup on any platform.

```bash
flutter test                       # 888 tests
flutter analyze                    # clean
python3 tool/generate_icons.py     # rebuild every icon from the master artwork
flutter build apk --release

# Inspect the statement as a document (writes build/qa/*.pdf)
flutter test test/tool/generate_statement_samples_test.dart
pdftoppm -r 110 -png build/qa/ar-multipage.pdf build/qa/page

# Look at onboarding and the language picker: both languages, both themes,
# 390×844 and 360×640 at 1.5x text (writes build/qa/onboarding/*.png)
flutter test --update-goldens --dart-define=DHIMMAH_QA=true \
  test/tool/render_onboarding_test.dart
```

---

## How it is put together

`DESIGN.md` records the colour, type, spacing, shape, icon and motion systems,
and the layout rules that came out of reviewing the running app. Read it before
changing anything visual.

```
lib/
├── app/            # widget tree, router, dependency injection, lock gate
├── core/           # theme, formatting, money, notifications, security, widgets
│   └── pdf/        # Arabic shaping, bidi ordering, the statement template
├── data/           # drift database, DAOs, repositories, read models, services
├── domain/         # entities, enums, repository contracts, business rules
├── features/       # one folder per screen group
└── l10n/           # ARB sources and the generated localisations
```

The dependency rule is one-way: **features → data → domain → core**. A widget may
not do arithmetic on money, and the domain may not import Flutter.

### Where the behaviour lives

* **`domain/services/debt_calculator.dart`** — the only place a balance, a status
  or a total is worked out. Pure functions with the current date passed in, so
  every rule is testable and identical everywhere it appears.
* **`domain/services/obligation_schedule.dart`** — recurring schedules. Every
  period is derived from the *anchor* date, never from its predecessor, which is
  what keeps "the 31st" the 31st: 31 January → 28 February → **31 March**.
* **`data/services/ledger_service.dart`** — every write. Screens call this and
  nothing else, so the invariants hold whatever route the user took: a settled
  debt is never late, a payment always belongs to its record, and a recurring
  commitment always has its next period ready.
* **`domain/services/notification_planner.dart`** — pure planning. Given the
  records and a clock it returns the complete set of notifications that should
  exist; the service then makes the phone agree with it, which is why paying a
  debt off cancels its reminders automatically. The planner never touches the
  platform and the platform never decides anything: the records are the source
  of truth and a pending notification is only a scheduled representation of them.
  See **Reminders** below for what that costs and how it is kept in step.
* **`domain/services/attention_list.dart`** — what needs attention, derived from
  the records and a date. Nothing is invented; an item disappears the moment it is
  settled, which is what makes the section worth trusting.
* **`core/pdf/`** — the document pipeline: shaping, ordering, and the statement
  template. None of it knows about the database or the widget tree.

### Reading data

`data/read_models/ledger_queries.dart` reads a consistent snapshot and re-emits it
whenever any ledger table changes. Re-reading on change rather than combining five
live streams is deliberate: a personal ledger holds hundreds of rows, SQLite
answers a full read in well under a millisecond, and one read pass guarantees the
dashboard's totals always agree with the lists below them. Combining independent
streams is how those two quietly drift apart.

---

## Design language

A single deep-pine family with one brass accent, in light and dark. Colour is
rationed: green always means money coming to you, red always means money going
out, amber means something is nearly due — and every status *also* carries an
icon, so nothing depends on colour perception.

The mark is a green wallet holding a receipt and a coin: what is kept, and what
is owed. It is **artwork, not a drawing** — `assets/icon/icon.png` is the master,
and every other icon is derived from it: the launcher bitmaps, both adaptive
layers, the one-colour silhouettes, the iOS set, the logo the app draws and the
copy a statement embeds.

```bash
# Once, when the artwork changes. Crops the reference to its own edge.
python3 tool/generate_icons.py --import ~/Downloads/reference.png

# Afterwards.
python3 tool/generate_icons.py
```

**That script is not in this repository yet.** It is kept outside it because the
pre-commit security scan reports any Python file that writes a file as a
high-severity path traversal — including one whose path is a string literal,
which was confirmed with a controlled probe — so no shape of the script passes
the gate. It is parked next to the project as `dhimmah-icons-pipeline/`; move it
back to `tool/` before regenerating anything. The icons themselves are committed,
so the app builds and ships without it.

---

## Language and direction

Arabic and English are both complete, and **the app is in the phone's
language**: an Arabic phone opens in Arabic, an English one in English, and a phone
in neither opens in English. The first language on the phone's own list that the
app ships wins, so someone who reads French first and Arabic second gets Arabic.
Change the phone's language while Dhimmah is open and the app changes with it —
screens, dates, numbers, the statement and the reminders already scheduled.

An install from before this version follows the phone too: every one of them was
given Arabic without the phone being asked, so the upgrade hands a stored Arabic
back to the phone, and keeps an English that someone chose.

Settings → Language offers **لغة الجهاز / Device language** (the default) and each
language by its own name. What is stored is the *preference* — `system`, `arabic`
or `english` — never the resolved language, which is worked out in exactly one
place (`appLanguageProvider`) from the preference and the phone. Android 13+ also
lists both languages in the system's per-app language setting
(`res/xml/locales_config.xml`).

The first frame is already right. `main` reads the settings row before `runApp`
and seeds it into the providers (`loadBootSettings`), because the live settings
stream answers a frame late — which is how an English, or dark, user used to see
the app open in Arabic, or light, and then change under them.

Direction is derived from the language rather than set anywhere, so RTL is real
layout mirroring, not a text flip. No user-facing string is hardcoded — everything
comes from `lib/l10n/arb/`, including the notifications, which are composed from
the same ARB files as the screen they open, and are re-worded in place when the
language changes.

Amounts are wrapped in Unicode bidi isolates so `₹ 50,000` stays one
left-to-right unit inside an Arabic paragraph. Digit shapes follow a separate
setting (Western or Arabic-Indic) applied after formatting, because `intl`
silently ignores a numbering-system request and returns Western digits either way.

---

## Security

The app lock is a 4-digit PIN, stored as a salted, iterated HMAC-SHA256 digest in
the platform keystore — never in the database, never in a backup. The PIN itself
is written nowhere. Attempts back off after five misses.

A four-digit PIN has little entropy, so the digest and the rate limiting are what
actually protect the records; the key stretching only raises the cost of an
offline attack on a leaked keystore. Biometrics are a convenience layered on top:
turning them off always leaves a working PIN, so nobody can lock themselves out of
their own ledger.

The biometric layer distinguishes three things a bool cannot: the user confirmed,
the user changed their mind, and the platform refused to show a prompt at all.
Only the last one is reported, because it is the only one where the fingerprint
button would otherwise be silently dead. It asks for biometrics only — never the
device PIN — so the setting that says "open with fingerprint" does exactly that.

---

## Data

Everything lives in one SQLite file on the device. Nothing is uploaded and the app
is fully usable in aeroplane mode. Export produces a complete JSON backup or a CSV
for a spreadsheet. Deleting a record is reversible for a few seconds rather than
gated behind a second confirmation.

Calendar dates are stored as `yyyy-MM-dd` rather than as instants, so a due date
cannot shift by a day when the device changes timezone.

### One record, several people

A debt is one financial fact: a dinner bill of 1,500 with three friends is one
record linked to three people, not three records of 1,500. Who a record is with
therefore lives in its own table — `debt_people`, keyed on `(debt_id, person_id)`,
so the database itself refuses to link the same person twice — rather than in a
column of ids or a blob of JSON.

`debts.person_id` survives as a *projection* of that table: the participant at
position 0, written by the one place that writes the links, so the two can never
disagree. It is what a payment's attribution, a notification's heading and the
foreign key that unlinks a debt when a person is deleted have always read.

The version-3 migration copies every existing `debts.person_id` into a link row
and touches nothing else. It is written as a sequence of additive steps — the new
table, then any index the file is missing, then the data — because drift's
`CREATE INDEX` is not conditional: the earlier version-2 migration's
`createAll()` worked on a version-1 file and failed on a version-2 one, and the
tests now build a real database in each old shape and upgrade it
(`test/data/migration_test.dart`).

**The relation is bookkeeping; the interface is a page per person.** Nothing in
the app calls a record "shared", and no person's page names the other people the
record is also linked to: each of them reads it as one of their own debts, with
the ordinary row, the ordinary figure and the ordinary totals. Who else is on the
record is visible on the record's own page, which is where it is edited, and in
the flat ledger list, where a row has to say who it is with.

**Counted once, never multiplied, never split.** Every aggregate reads the
`debts` table, and the link table is only ever joined to answer *who*: the
dashboard, the ledger, the monthly report and the statement each count the record
once, so a 1,500 dinner bill with three people on it is 1,500 and never 4,500.
Within one person's page it is counted once too — the page is the answer to "what
is between me and this person", and the record is one of the things between them.
There is no per-person share anywhere in the product, so the app divides nothing
either: a dinner bill is not always split evenly, and a car loan with a co-signer
is not split at all. Two people's pages can therefore each state the same record,
which is deliberate — pages are views of one relationship each and are never
added together. The ledger is the only place records are summed, and it sums each
one once.

### Reminders

A reminder is a *scheduled representation* of a record, never a second source of
truth. Every write, every launch and every change to the phone's environment
rebuilds the set the records ask for, and the phone is then made to agree with
it:

* **Reconciled, not wiped.** The service compares what it wants with what the
  platform reports holding, cancels only what is no longer wanted, and schedules
  only what is missing. The older behaviour — cancel everything, re-schedule
  everything — also cleared the notification shade, so every save erased the
  reminders the user had already received, and cost thousands of platform calls
  on a large ledger. The same correction made a payment write go from **1,819 ms
  to 40 ms** at 2,500 records and from **7,470 ms to 40 ms** at 10,000
  (measured by `test/tool/startup_write_profile_test.dart`).
* **Identity is the record, the kind of reminder and the moment.** Android
  replaces a notification with a matching id, so the id is derived from those
  three things and nothing else — never a position in a list, never the time of
  computing it. Two records can hash to the same 31-bit id in principle, so a
  clash is resolved deterministically inside a pass; a test arms 10,000 of them
  and fails on any duplicate.
* **The soonest four hundred are armed.** Android, and Samsung's implementation
  in particular, does not hold an unbounded number of alarms per app: exceeding
  the limit throws rather than degrading. The cap is by time, ties are broken by
  id so the choice is a function of the records alone, and every launch and save
  re-plans — so the reminders that are armed are always the ones closest to
  being due.
* **A tap opens the record.** The payload is `type:stable-id` and nothing else —
  no amounts, no names, nothing to leak from a lock screen. A tap that *launches*
  the app is read from the platform at start-up and routed after the first frame;
  the app used to lose it, so tapping a reminder on a closed app opened the
  dashboard.
* **A reminder that cannot arrive says so.** If reminders are switched off in
  Settings, or the system blocks notifications, the reminder field and the
  record's page say that the notification will not come. Permission is asked when
  the user turns reminders on, never at launch, and the state is re-read whenever
  the app comes back to the foreground — so granting it in the system settings
  starts working without a restart.
* **Boot and updates are the plugin's job.** `RECEIVE_BOOT_COMPLETED` and a
  `MY_PACKAGE_REPLACED` receiver are declared, and `flutter_local_notifications`
  re-arms its own store; if the alarms were lost anyway, the next reconciliation
  puts them back (`test/data/notification_lifecycle_test.dart` case 8).
* **Inexact by design.** Reminders are scheduled with `inexactAllowWhileIdle`:
  a few minutes of slack costs nothing for "look at this today", and exact
  scheduling needs a permission Android 14+ denies by default and Play restricts
  to alarm and calendar apps.

---

## Testing

```
test/domain/       123 tests — balances, statuses, schedules, month arithmetic,
                               the attention list, the monthly insight, what the
                               planner decides to schedule and when, what the
                               service refuses to store, and which language a
                               phone's language list resolves to
test/core/         143 tests — the notification delivery policy against a fake
                               platform (idempotent scheduling, reconciliation,
                               re-wording in place, the cap, permission and
                               timezone changes, the cold-start tap), plus Arabic
                               shaping and bidi, Arabic search folding, amount
                               parsing, currency formatting, numerals, date
                               phrasing, the WCAG contrast of every colour pair
                               in both themes, that English is really English
                               and both ARB files hold the same keys, and the
                               statement's own geometry read back out of the
                               finished PDF
test/data/         292 tests — schema, converters, constraints, the link table's
                               own rules, clearing fields, opening a database
                               written by every earlier version, several people
                               on one record, backups and restores, the language
                               preference across a restart and a backup, and the
                               reminder lifecycle — including one pass at a time
test/integration/   39 tests — the service against a real SQLite database,
                               including a record edited, closed and reopened from
                               the file it was written to, and a deleted record
                               undone with its history
test/widget/       206 tests — the real UI driven end to end: onboarding in the
                               phone's language from the first frame, the
                               language switch, following a phone that changes
                               language, recording, RTL, dark mode, the statement
                               screen, editing every field of a record, required
                               fields and their errors, one record linked to three
                               people, layout at 1.0x/1.3x/1.5x text on a 360px
                               screen, the places where a number must *not*
                               mirror, and the update card in both languages
test/app/           35 tests — the start-up failure path and the update
                               controller's state machine
test/platform/      27 tests — the Android declarations that no Dart test can
                               see, and the file gateway
test/performance/    7 tests — two scale measurements (print only) and the proof
                               that the SQL aggregate matches the Dart sum
test/tool/          16 tests — the seed and statement generators and the
                               query-plan and write profiles (plus a screenshot
                               renderer that only runs when asked, below)
```

888 tests. Several exist to hold a decision in place rather than to check a
behaviour: the contrast test, the design invariants (one focus figure and one
primary action per screen, the person page's single balance), and the two journeys
driven the way a person drives them — open someone, record a payment, watch the
balance fall, then share the statement.

The layout tests exist because a number that overflows its row cannot be read.
They pump every destination at three text scales and fail on any overflow, and
they assert the rules that have been broken once already — one add button per
screen, and a people tab whose add button can actually add a person.

Bugs the tests and the rendered documents caught, each now covered by a
regression test:

1. **Recurrence drift.** Monthly debts chained from the previous period, so a
   schedule anchored on the 31st collapsed to the 28th permanently.
2. **`1.234.567` read as `1.23`.** The amount parser treated the first separator
   as a decimal point, turning a million into one and twenty-three.
3. **Cleared fields silently reverting.** Drift's upsert and `update().write(row)`
   both skip columns whose new value is null, so clearing a due date, a note or a
   person link appeared to work and came back on the next read. Writes now go
   through a companion with every value present.
4. **Boxes in the middle of Arabic words.** The bidirectional algorithm composes
   shadda-and-vowel pairs into ligatures the chosen font does not contain. The
   shaping pipeline now expands them, and a font-coverage test guards the rest.
5. **A PIN keypad that read 3 2 1.** The keypad was laid out with the app's own
   direction, so the top row printed backwards and the dots filled from the wrong
   end — a four-digit code read backwards to the person unlocking their own
   ledger. A dialer is not mirrored in any language; the keypad and the dots are
   now laid out left to right whatever the app's language, and a test asserts the
   order of every row (it failed on the old code with `1` at x=492 and `3` at
   x=308).
6. **Headings hugging the left margin.** «ملخص الحساب», «تفصيل الديون» and
   «سجل الدفعات» are rows only as wide as their own text, and the page lays its
   children out from the left, so they sat under the document number instead of
   over the sections they name. They are now packed to the reading side.
7. **A lam-alef that joined nothing.** A lam followed by an alef collapses into
   one ligature, and the ligature has a connected form and a standing one. The
   choice was made by asking whether a previous letter *existed* rather than
   whether it joins forward — so «الاستحقاق», «الأول» and «والأرض» took the
   connected form and were drawn with a tail joining a letter that cannot join.
8. **A long Arabic debt title printed off the page.** The wrapping measured the
   string in its logical form and the page drew it in its shaped form, and on
   Arabic the two disagree by about a third: a 22-character title measured 122pt
   and drew at 92pt. The cell had room to spare and still pushed its last word
   past the margin, where it was clipped. Wrapping is now the renderer's, so the
   width that is measured and the width that is drawn are the same string; a test
   reads every run back out of the finished file and fails if any leaves the
   margins.
6. **A statement ending in a blank page.** The closing note could spill onto a
   page of its own; it now lives in the footer, which repeats on every page.
7. **Two add buttons stacked on top of each other.** A screen that became a
   navigation destination kept its own button while the shell also drew one. A
   test now walks all five destinations and fails if any has more than one.
8. **A people tab that could not add a person.** The shell's add button opened
   the record sheet everywhere, so the one screen about people had no way to add
   one. It now leads with "new person" where that is what you came for.
9. **A cold start flashing the wrong colour.** The Android window behind the
   first frame was still pinned to the *previous*, cool palette, so every launch
   opened on a blue-white screen before the warm page arrived. It matched the
   theme by hand; it is now checked against it.
10. **A launch icon clipped by its own mask.** The foreground layer was cropped
    rather than scaled into the adaptive icon's safe circle, slicing the bar ends
    and the gold terminal — and it had no adaptive-icon descriptor at all, so
    Android wrapped the legacy bitmap in a white disc. The generator now measures
    the mark's own bounding box and fits it to the circle, and the layers are
    declared together.
11. **Four colours below the contrast floor**, including white on the dark brand —
    the primary button and the add button — at 2.75:1. All four had been through a
    manual pass that declared the palette clean. The contrast test found them in
    its first run.
12. **A hero figure that read as a double negative.** `عليك` followed by
    `−₹ 39,200` says "you owe" and then subtracts, which can be read as the
    opposite. The direction is now in the words and the figure is a magnitude.
13. **A person's page that stated their name once per row.** Every debt row on
    Ahmed's page was titled "أحمد محمد", because the row leads with the person on
    the mixed ledger. Rows on a person's own page now lead with the debt.
14. **A fingerprint button that could never work.** `MainActivity` extended
    `FlutterActivity`, and `androidx.biometric` shows its prompt through a
    fragment, so `local_auth` refused to run at all — it answered
    *"The current Activity must be a FragmentActivity"*. Nothing said so: the
    wrapper caught the exception and returned `false`, so the button did nothing
    and looked exactly like a prompt the user had dismissed. Fixed by extending
    `FlutterFragmentActivity`, and the wrapper now tells a refusal apart from a
    cancel so a dead button can never again pass for a quiet one. Verified on a
    device with an enrolled fingerprint: the prompt opens, the sensor reports
    `success: true`, and the app unlocks.
15. **Reminders that were switched on and never arrived.** Onboarding stored
    `notificationsEnabled = true` from the "Start" and "Skip" buttons without
    ever asking the platform. On a fresh install permission is denied, so the
    scheduler bailed and nothing was ever scheduled, while Settings showed
    reminders as on. The flag now records what the platform actually granted;
    Skip no longer raises a permission dialog, and Start asks for one.
16. **Every pending reminder delivered at once, on opening the app.** The
    planner compared a wall-clock moment against *midnight*, so a reminder whose
    hour had already passed today was still "in the future" and was handed to
    Android as a past instant. Opening the app after 20:00 produced a burst of
    notifications about things the user was already looking at. Every guard now
    compares against the actual instant.
17. **A negative payment made a debt grow.** Nothing rejected a negative or zero
    amount — not the service, not the schema — and because a payment is
    subtracted from what has been paid, recording `-10,000` turned a 10,000 debt
    into an 11,000 one. Amounts are now validated by one rule the domain owns,
    which the form and the service both ask.
18. **Editing a debt's currency left its payments behind.** A payment is recorded
    in the debt's currency and inherits it, so correcting the debt from rupees to
    dollars left rupee minor units being summed and reported as dollars. A
    currency correction now carries the payments with it, without inventing an
    exchange rate.
19. **Obligation reminders opened a page saying the record was deleted.** The
    payload carried the *occurrence* id while the route looks the record up by
    obligation id, so every obligation notification was always wrong. Obligations
    also never produced an overdue reminder at all — a monthly commitment could
    pass its date in silence.
20. **A notification's identity was its position in the list.** Android replaces
    a notification that shares an id; positional ids meant the same reminder
    became a different notification whenever any other record changed. Ids are
    now derived from the record, the kind of reminder and the moment.
21. **Arabic in the English app.** Three keys existed only in the Arabic file;
    because Arabic is the template, `gen-l10n` back-filled English with the
    Arabic text, so the debt form showed «خيارات إضافية» to a reader of English.
    Two keys were also defined twice with different values, so the wording that
    appeared was a coin toss.
22. **"1 ديون متأخرة" and "1 debts are overdue".** The report insights put a raw
    count into a fixed noun, so a count of one was ungrammatical in both
    languages and Arabic's dual and few/many forms were unreachable. Counts are
    now plural categories.
23. **An Arabic keyboard could not type an amount.** The amount field's input
    filter admitted only Western digits while the parser behind it handles
    Arabic-Indic ones, so a user on an Arabic keyboard watched every keystroke
    disappear.
24. **A launch screen that could never recover.** The first database read was the
    only unguarded step in start-up, and it is the one that fails when the file
    cannot be opened — a rolled-back update, a restored backup, a device ahead of
    this build. `runApp` was never reached, so the user got a frozen launch screen
    with no message and nothing to do but force-quit. That read is now guarded and
    a failure draws a screen that names the cause, says the records were not
    touched, and offers a retry that reopens from scratch. Verified on a device by
    planting a database stamped version 99: previously a dead splash, now
    «تعذّر فتح دفاترك» with the specific reason.
25. **An error handler that killed the app it was reporting for.** The new failure
    screen did not appear on the first device test, and the log showed why:
    handing a drift failure to `FlutterError.reportError` crashes, because a
    failure that crossed the database's isolate carries a
    `===== asynchronous gap =====` line that Flutter's own stack filter asserts
    on. Start-up diagnostics now go through `debugPrint`, which parses nothing.
    The same latent crash was in the warm-up and notification handlers that
    already existed.
26. **A typed error that lost its type in transit.** The screen showed the generic
    message for a known cause: drift marshals failures across the isolate port,
    so `DatabaseTooNewException` arrived as a plain exception carrying only its
    `toString()`, and `is` could never match. The classifier now accepts either
    the type or the name, which is the only signal that survives.
27. **English sentences with their full stops at the wrong end.** The failure
    screen shows both languages, and the English block sat inside a right-to-left
    paragraph, so the bidirectional algorithm moved every full stop to the start
    of its line — ".Nothing in your ledger was changed". It has its own LTR
    direction now.
28. **Every screen re-read the whole ledger, and every foreign key scanned the
    whole table.** Measured at 500 people / 2,500 debts / 10,000 payments: the
    dashboard read took 1.4 s and the monthly report 4.5 s, and reading one
    person's five debts took 265 ms because the schema had no secondary index and
    the query filtered in Dart after loading the table. The person page ran that
    query once per debt. Fixed by declaring the missing indexes (schema version 2,
    added by a migration that only creates what is missing) and by pushing the
    per-debt payment total into a `SUM … GROUP BY`: 20 ms instead of 499 ms, and
    the person page 23 ms instead of 287 ms. `test/performance/` prints the
    numbers and pins the aggregate against the Dart sum it replaced.

29. **Editing any field of a debt silently unlinked it from its person.** The form
    read the amount, the note, the dates, the reminder and the title back out of
    the stored record, and never read the person — so the first save wrote
    `personId: null`. The record stayed in the database with all its money and
    vanished from the page it was recorded on, which is the worst shape a bug in
    a ledger can take: silent, and about the wrong number. Fixed by hydrating
    every field the form owns, and by making the *service* refuse a record that
    names nobody, so no screen can write one. There is a test per field
    (`test/widget/debt_edit_test.dart`), and the write path that used to drop the
    link is pinned by the tests that create, edit, close and reopen the file.
30. **A migration that could only run once.** `createAll()` was doing double duty
    as "create what is missing": it emitted `CREATE TABLE IF NOT EXISTS` for
    tables and a bare `CREATE INDEX` for indexes, so it was safe on a version-1
    file (which had no indexes) and failed on a version-2 one with
    *index idx_debts_person already exists*. The version-3 upgrade that adds the
    link table hit it immediately. The migration is now explicit about each step
    and creates indexes with `IF NOT EXISTS` from the generated schema, and
    `test/data/migration_test.dart` builds a database in the shape of version 1
    *and* version 2 and upgrades both — a fixture the shipped build could never
    have exercised.
31. **An empty direction field that had already answered.** `عليّ / لي` opened
    with `عليّ` selected, because the form's direction parameter defaulted to it —
    so a debt recorded without touching the field was recorded as money the user
    owes, and the one screen that could have caught it showed a choice the user
    never made. The field now starts unselected (`DebtDirection?`), the route
    passes only the side the user actually tapped, and a save without it says
    *اختر نوع الدين: عليّ أو لي* next to the field and scrolls to it.
32. **A form that failed without saying what was missing.** A save with gaps did
    nothing visible if the user had scrolled past the field, or showed a single
    generic sentence. Required fields are now marked with `*`, each carries its
    own message, the screen scrolls to the first one and puts the caret in the
    amount, a summary at the top counts them, and nothing the user typed is
    cleared. `test/widget/debt_form_test.dart` drives the whole refusal and retry,
    including the draft surviving it.
33. **A record with three people on it presented as a shared debt.** A debt linked
    to several people was labelled `مشترك`, each participant's page listed the
    *others* by name, the statement carried a `ديون مشتركة` section beside the
    total, and the person's balance left the record out with a note explaining
    why. The relation is bookkeeping: it stays in `debt_people`, and none of it is
    shown as a concept. Each person's page now shows the record as one of their
    own — the ordinary row, the ordinary figure, counted once — the statement is
    that page in print, and the shared vocabulary is gone from the interface
    entirely. `test/widget/multi_person_pages_test.dart` opens all three pages and
    fails if another participant's name appears on one of them, and
    `integration_test/multi_person_on_device_test.dart` does the same on a phone.

34. **Tapping a reminder on a closed app opened the dashboard.** The tap was
    delivered through the plugin's callback, which only fires while the app is
    running; a process *started* by the tap was never asked what launched it. The
    payload is now read from the platform during start-up and routed after the
    first frame, so a cold start lands on the record — the case a reminder is
    most likely to be tapped in.
35. **Every save erased the notification shade.** Reconciliation called
    `cancelAll()`, which on Android is `NotificationManager.cancelAll()`: it
    clears what is *displayed* as well as what is scheduled, so saving a payment
    deleted the reminders the user had already received. It now cancels only
    pending notifications and only the ones the records no longer ask for.
36. **One save rebuilt the whole plan, and asked the phone for thousands of
    alarms.** `refreshNotifications` read every record, every payment and every
    person on every write — 1,819 ms at 2,500 records and 8,112 ms at 10,000, all
    of it inside the write — and then asked Android to hold every notification
    the ledger implied, which Samsung's Android caps at 500 per app and throws
    beyond. The plan now reads only the records that carry a reminder, soonest
    first, in pages, stopping as soon as nothing further out could deliver
    earlier; and only the soonest four hundred notifications are armed. A
    payment write went from 1,819 ms to 40 ms, and from 7,470 ms to 40 ms at
    10,000 records.
37. **A reminder that could not possibly arrive said nothing.** With reminders
    switched off, or notifications blocked by the system, the form happily
    offered lead times and the record stated them as if they would fire. Both now
    say so where the choice is made and where it is read, and the permission is
    re-read whenever the app returns to the foreground — granting it in the
    system settings used to require a restart.
38. **An install was greeted by a month-end summary reporting zeroes.** The
    catch-up path had nothing to catch up on and delivered anyway; it now needs a
    ledger with something in it.
39. **A cap boundary could swap a notification for no reason.** The armed set is
    the soonest four hundred, and ties were ordered by nothing in particular — so
    two passes over the same records could choose different members of a tie and
    Android would cancel and re-schedule a reminder for no reason at all. Ties
    are now broken by id, which makes the choice a function of the records alone.

40. **An app that never asked the phone which language it was in.** The
    language was a stored setting seeded with Arabic, so an English phone opened
    in Arabic and had to find the setting four screens into onboarding. The
    stored value is now a preference whose default is the phone. Version 5 of the
    schema hands every stored Arabic back to the phone — onboarded, skipped or
    neither, it was the seed and not a choice — and keeps a stored English,
    which only a tap could have written. A backup file from before version 5 is
    read the same way, so restoring one does not pin Arabic again. Verified by
    installing 1.0.1 over 1.0.0 on an English-language emulator: every row
    identical, the one changed value `settings.language` (`arabic` → `system`),
    the PIN still unlocking, and the app in English.
41. **A first frame in somebody else's settings.** The providers drew the
    defaults until the settings stream answered, one query later — so a user who
    had chosen English, or dark, watched the app open in Arabic, or light, and
    switch under them. The row read before `runApp` is now the app's starting
    state.
42. **Reminders in the language the user had left.** Reconciliation matched
    pending notifications by id alone, and the id is the record, the kind and the
    moment — not the words. After a change of language every reminder already
    armed still arrived in the old one. It now compares the words the platform is
    holding and re-schedules the ones that differ in place, under the same id,
    and renames the channels the system settings list.
43. **Two reminder passes racing.** A save and a change of language arriving
    together ran two rebuilds at once, and whichever finished last won — even
    when it had read the older records. Passes now run one at a time, and every
    caller that arrives while one runs shares the single pass after it.

44. **Reminders that stated the wrong number of days.** A reminder's "in N days"
    was counted from the day the plan ran, not the day it arrives, so a reminder
    planned six days out arrived the day before the deadline saying «خلال 6
    أيام», and the nudge after the deadline said the debt was due in the future.
    It is now counted from the moment of delivery — which also keeps the words
    the same from one day to the next, so re-wording in place never re-schedules
    the whole set daily. The first launch after the update corrects the
    reminders an older build left behind, under the same ids.

Found in a review of the whole app, and fixed with a regression test each:

45. **Editing a payment recorded a second one.** "Edit" opened the sheet for a
    new payment, so a correction was saved beside the original, and "pay in
    full" saved the balance while the field still showed the typed amount. The
    sheet now edits the payment it was given and writes what it saves into the
    field. A correction that pays a debt off closes it exactly as a payment does.
46. **A month-end summary that was never armed, about the wrong money.** It only
    ever arrived as a catch-up on the next launch; its "paid" added lifetime
    totals; and a catch-up recorded the day it arrived, so the next month's
    summary was skipped. It is now armed in the last three days before its
    moment, "paid" is that month's payments, and the month it summarises is what
    is recorded. A month's report no longer changes when a later payment arrives,
    and skipped periods are not money due.
47. **Notification taps that went nowhere, or twice.** The backup alert matched
    no route, a month-end summary opened the current month, a second tap stacked
    a second copy of the page, and an unknown location printed the router's
    exception in English. Each now opens its own page once, and a missing record
    says so in the app's language.
48. **Commitment periods nobody scheduled.** Changing monthly to weekly filled
    in a late week for each of the last two months; undoing a payment left its
    paid date behind; paying the last period archived a commitment with earlier
    periods unpaid; a 31st started in February stayed on the 28th; and
    31 December was keyed like 1 January. A schedule is now only extended after
    its last period, and "next due" is decided in one place.
49. **A ledger drawn unlocked for its first frames.** The lock read settings that
    had not arrived yet, and locking tore the navigator down, losing a half-typed
    form and any answer from a system picker. It now reads the settings seeded
    before the first frame, and the app stays mounted, unpainted, beneath it.
50. **A safety copy that did not hold the newest records.** Deleting everything
    skipped the safety copy whenever one was under ten minutes old, even with
    records added since. A recent copy now stands in only when nothing has
    changed; a ledger of reminders alone is no longer "empty"; and a CSV cell
    that starts like a formula opens as text.
51. **"Late" that added up six debts.** The attention figures were summed from the
    dashboard's display lists, which stop at six debts and four periods, and a
    commitment counted only its oldest period. They now count everything late or
    due, and a ledger of commitments alone is no longer shown as empty.
52. **«احمد» could not find «أحمد».** Search and the people picker compared raw
    text. Both now fold the hamza forms, ى and ي, ة and ه, vowel marks, the
    tatweel and Arabic-Indic digits.
53. **"Deleted" before anything was deleted.** A reminder's delete was fired
    without waiting and announced at once, so a failed one was reported as done;
    a failed delete or undo of a debt was an error nothing caught; and saving an
    edited reminder said "created". Each now says what actually happened.
54. **An undo that rewrote history.** Undoing a debt's deletion replaced its feed
    with one new "created" entry, and failed outright if a person on the record
    had been deleted in between. The feed comes back as it was, and a missing
    person is left out.
55. **Yesterday's deadline still "due today".** The day moved only when the app
    came back from the background, so a ledger left open overnight kept the old
    one. It now turns over at midnight.
56. **Three small ones.** A second tap on the start-up retry opened a second
    database connection; editing a repeating debt erased the end of its series;
    and `184467440737095517` parsed as 0.84, because the multiplication wrapped
    round before the limit was checked.

### On a device

Two suites need real hardware, because they measure the engine and the platform
rather than the widgets:

```
flutter test integration_test/frame_measure_test.dart -d `device`
flutter test integration_test/multi_person_on_device_test.dart -d `device`
flutter test integration_test/notifications_on_device_test.dart -d `device`
```

The notification run needs the runtime permission, and Android 13+ installs an
app with it off, so allow it first — otherwise the test checks the denied path
(nothing armed, ledger intact) instead:

```
adb shell pm grant com.dhimmah.dhimmah android.permission.POST_NOTIFICATIONS
```

The first seeds 500 people / 2,500 debts (a third of them linked to three people)
and reports the engine's own frame timings for the dashboard, the ledger, the
people list and the obligations list. On a Galaxy S24 Ultra (Android 16) the two
long lists scrolled at a p90 build of 20.1 ms and 16.9 ms with no frame over
33 ms. The third drives the real notification plugin: it arms the reminders for
two records, checks the phone is holding exactly four (a lead and the nudge for
each), re-runs the write and confirms nothing changed, delivers one notification
and finds it in the system's list, and then switches reminders off and confirms
the phone is holding nothing. The second is deliberately small — three people, two records — so it runs
where the first one cannot: it opens each participant's page and asserts that the
record is there and that nobody else is named. A 500-person benchmark wants a
device with room to spare; a phone under memory pressure will have the process
reaped by the system's low-memory killer, which is a property of the device, not
of the app.

---

## Publishing

The release build refuses to run without a signing key, on purpose: it used to
fall back to the Android debug key, which is public in every SDK, so the bundle it
produced could be signed by anyone and would be rejected by Play anyway.

```bash
# 1. Create the upload key, once. Keep it out of the repository — android/.gitignore
#    already ignores key.properties, *.jks and *.keystore.
keytool -genkeypair -v -keystore ~/dhimmah-upload.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# 2. Point the build at it. This file is gitignored.
cat > android/key.properties <<'EOF'
storeFile=/absolute/path/to/dhimmah-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
EOF

# 3. Build the artifact Play wants.
flutter build appbundle --release
```

Lose the upload key and you cannot ship an update to an existing listing; Play App
Signing keeps the *app* signing key, not your upload key. Back it up somewhere the
repository is not.

### Version numbers

`versionName` is what a person reads; `versionCode` is what Play compares. Play
decides whether an update exists by comparing version codes, so the code must go
up by at least one on every upload and must never be reused or lowered — a build
whose code is not higher than the published one is not an update, and Play will
not offer it however new the name looks.

```yaml
# pubspec.yaml — the part after the plus is the version code.
version: 1.0.0+1     # first upload
version: 1.0.1+2     # a fix
version: 1.1.0+3     # a feature
version: 1.2.0+4     # the next one
```

The app never compares version strings itself. It asks Play, and Play answers —
see 'Updating an installed app' below.

### Updating an installed app

Dhimmah updates through Google Play's own in-app updates, and through nothing
else. There is no APK download, no server that reports a version, no custom
installer and no `REQUEST_INSTALL_PACKAGES`: the Play Store app decides whether a
newer version is available to *this* install, downloads it, and installs it. The
app never sees a byte of it.

The flow a user gets:

1. Open Dhimmah. It is on screen and usable before anything is checked.
2. A few moments later, if Play has a newer version, a card appears on the
   dashboard: **تحديث جديد متوفر** with **تحديث الآن** and **لاحقًا**.
3. **تحديث الآن** starts a flexible update. Play downloads in the background and
   the user keeps using the ledger; the card shows the progress.
4. When the download finishes the card becomes **التحديث جاهز للتثبيت** with one
   button. Pressing it hands the install to Play, which restarts Dhimmah.

An *immediate* (full-screen) update is used only for a release whose
`inAppUpdatePriority` is 4 or 5 — set with the Play Developer API when the release
is rolled out, not in the Console UI:

```json
{ "releases": [{
    "versionCodes": ["4"],
    "inAppUpdatePriority": 5,
    "status": "completed"
}] }
```

Everything else is offered quietly. A user who says **لاحقًا** is not asked again
for six hours, and a user on the current version never learns the update system
exists.

**Checking it for real.** In-app updates come from the Play Store, so a locally
built APK — `flutter run`, a sideloaded release build, a debug build — will never
show one. That is not a bug in the app. To see the flow:

```bash
# 1. Install version N from Play — internal testing or internal app sharing,
#    with the same applicationId and the same signing key.
# 2. Upload version N+1 to the same track and wait for it to become available
#    (a new rollout is not instant, and an account that does not own the app
#    never sees it).
# 3. Open the installed version N and wait for the card.
# 4. Press تحديث الآن, watch the download, then restart and check the version.
```

The device must have the Play Store, must be signed in with an account that has
the app, and must have received the new version — none of which the app can
influence or detect.

### Play Console declarations, and what each rests on

| Declaration | Dhimmah's answer | Why |
|---|---|---|
| Ads | **No** | No ad SDK is on the classpath and nothing in `lib/` loads one. |
| Account creation | **None** | There is no sign-in, no server and no user account. Nothing to delete remotely, so no account-deletion flow is required. |
| Data safety | **No user data collected, no user data shared.** | The app's own code makes no network request of any kind — `test/platform/android_setup_test.dart` refuses an HTTP client on the update path, and every other dependency is local: SQLite, notifications, PDF, sharing, secure storage. The one thing that does talk to Google is the Play in-app update library, which is Google's own and reports usage data and device metadata for update eligibility under the Play Core SDK terms. **Confirm the current wording of the form before submitting**: the Console's own exemption for Google Play SDKs decides whether that is a declaration or not, and this line cannot be verified without the form in front of you. |
| Financial features | **None** | It records debts the user types in. It does not lend, does not transfer money, does not give advice and does not connect to a bank. |
| Target audience | **Adults** | Nothing in the interface, the copy or the store listing is child-directed. |
| App access | **No credentials needed** | The app opens on the dashboard from a fresh install. The optional PIN lock is off until the user turns it on, so a reviewer is never asked for one. |
| Cloud backup | **Disabled** (`allowBackup="false"` + `data_extraction_rules.xml`) | The app tells the user their data is on their device only, and the default would have uploaded the ledger to Google's backup. The keystore is never backed up, so a restored ledger could not be unlocked either. |
| In-app updates | **Yes** — Google Play's own system | `com.google.android.play:app-update`. It adds **no permission** to the manifest (verified on the release artifact: four permissions, unchanged) and the app sends it nothing — the library asks the Play Store app what it would install, and the ledger is never part of that. |

## Not built yet

Deliberately out of scope: cloud sync, sign-in, multi-device, subscriptions,
home-screen widgets, and a separate monthly-report document (the monthly figures
are computed and shown, but only the debt statement is rendered to PDF). The
schema and the service layer are shaped to accept the first four — identifiers are
generated client-side so a record created offline already has its final identity.

One known trade-off: because the statement is drawn with Arabic presentation
forms, its Arabic text is not extractable by copy-paste or search in a PDF reader.
The alternative — real OpenType shaping inside the PDF — is not available in the
Dart PDF stack, and a document that prints correctly was judged more important
than one that can be searched.
