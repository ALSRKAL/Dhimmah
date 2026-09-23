# ذِمّة — Dhimmah

**اعرف ما لك وما عليك** · *Know what you owe. Know what you're owed.*

A personal ledger for the two sides of your financial life: the money you owe
people, the money people owe you, and the commitments that come back every month.
Offline-first, Arabic-first, and designed to be understood in under a minute.

---

## What it does

| | |
|---|---|
| **الرئيسية / Home** | Where you stand, the two sides of the book, and what needs attention |
| **السجل / Ledger** | Every debt, switched between what you owe and what you are owed |
| **الالتزامات / Obligations** | Rent, bills, subscriptions, salaries — with automatic next periods |
| **التذكيرات / Reminders** | Local notifications for anything with a deadline |
| **التقارير / Reports** | A monthly report with paid, received and overdue totals |
| **الأشخاص / People** | One page per person, rolling up every debt linked to them |
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
* **No invented insight.** Every sentence the app says about your money is
  computed from records you entered.
* **Nothing shown twice.** One add button, one currency mechanism, one place per
  fact. Two ways to do the same thing is one too many.
* **Money in integers.** Amounts are stored as integer minor units, so
  `0.1 + 0.2` never decides whether a debt is settled.

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
flutter test                       # 333 tests
flutter analyze                    # clean
python3 tool/generate_icons.py     # rebuild every icon from the master artwork
flutter build apk --release

# Inspect the statement as a document (writes build/qa/*.pdf)
flutter test test/tool/generate_statement_samples_test.dart
pdftoppm -r 110 -png build/qa/ar-multipage.pdf build/qa/page
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
  exist, and the service replaces whatever was scheduled with that set. This is
  why paying a debt off cancels its reminders automatically.
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

Arabic is the default and English is complete. Direction is derived from the
language rather than set anywhere, so RTL is real layout mirroring, not a text
flip. No user-facing string is hardcoded — everything comes from `lib/l10n/arb/`,
including the notifications, which are composed from the same ARB files as the
screen they open.

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

---

## Testing

```
test/domain/        77 tests — balances, statuses, schedules, month arithmetic,
                               the attention list, the monthly insight, what the
                               planner decides to schedule and when, and what the
                               service refuses to store
test/core/         102 tests — Arabic shaping and bidi, amount parsing, currency
                               formatting, numerals, date phrasing, the WCAG
                               contrast of every colour pair in both themes, that
                               English is really English, and the statement's own
                               geometry read back out of the finished PDF
test/data/           9 tests — schema, converters, constraints, clearing fields,
                               opening a database written by an earlier build
test/integration/   26 tests — the service against a real SQLite database
test/widget/        65 tests — the real UI driven end to end: onboarding, recording,
                               RTL, dark mode, the statement screen, the
                               open-a-person-pay-and-share journey, layout at
                               1.0x/1.3x/1.5x text scale on a 360px screen, and the
                               places where a number must *not* mirror, and the
                               update card in both languages and both themes,
                               and an About screen that prints the installed
                               version rather than a hardcoded one
test/app/           34 tests — the start-up failure path (a schema from the
                               future is recognised, the screen names the cause
                               in both languages, never shows the raw error, and
                               survives 1.5x text scale), and the update
                               controller's state machine: one flow per tap, the
                               cooldown, the resume rules, and what a refusal
                               from Play does
test/platform/       9 tests — the Android declarations that no Dart test can see:
                               the activity can host a biometric prompt, the
                               permission is declared, a platform refusal is
                               classified apart from a user cancel, the update
                               channel names agree across the bridge, the Play
                               library is the per-feature one, and the update
                               path cannot reach the ledger
test/performance/    5 tests — a scale measurement (prints, does not assert) and
                               the proof that the SQL aggregate returns exactly
                               what summing the rows in Dart returned
test/tool/           2 tests — the seed and statement generators
```

329 tests. Several exist to hold a decision in place rather than to check a
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
