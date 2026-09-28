# Dhimmah — Full-App UX Forensic Audit

**Device:** Note 20 Ultra (SM-N986B), Android 13, the user's own configuration —
Arabic, dark, 110% text scale.
**Builds:** debug `sha256:06c4128110fd3076…` (final, installed and hash-matched)
after `57a95bda…`, `f114555c…`, `8ca93c74…` — every finding below names the
build it was seen on.
**Tests:** 742 → **751** passing; `flutter analyze` clean. **Git:** nothing
committed — 89 modified, 73 untracked, last commit `310041a`.

This report is the record of the audit, the repairs, and what remains. Anything
untested says so: `NOT PROVEN`, `PARTIAL` or `BLOCKED`, never a guess.

---

## Executive summary

Every screen, sheet, dialog and form in the app was inventoried from the code
(21 routes + every bottom sheet and confirmation), then walked on the Note 20 in
Arabic and English, including two live interruption events: a mid-walk user
session (their own test record appearing and being deleted while this audit was
tapping), and a dialog-free read of the raw SQLite file for ground truth.

**12 defects were found and fixed** — every one with a regression test, then
re-proven on the rebuilt app on the phone. The three that matter most:

1. **The ledger headline lied on the owed-to-me side** — a bare ₹0 above
   ₹2,000 of open records (P1).
2. **Deleting a record could end with no snackbar, no undo, and (once) a blank
   screen** — the delete's own success unmounted the menu that started it, and
   the finale was doing raw Navigator pops that desynchronised go_router (P1).
3. **Every full-page form's Save button hid behind the keyboard** — proven with
   a screenshot and a widget test; with edge-to-edge the window never resizes,
   so the pinned bar needs the inset by hand (P1 in effect: a user could fill a
   form and find no way to save it).

Two findings were withdrawn as **designed behaviour** once the code was read
(person pages name their records after the person; deleting a person keeps
their debts as nameless records so nothing is ever lost). One was **not
reproduced** (a floating tooltip seen once during the user's own session).
Two accepted limitations are stated as such (obligation delete has no undo and
now says so; the search field cannot be typed into from adb, so Arabic search
was proven by tests, not by hand).

**Verdict: READY WITH KNOWN LIMITATIONS** — up from the same verdict but with a
materially smaller list: everything found affecting trust, money display or
form completion is fixed and device-proven.

---

## Screen inventory (24 surfaces, from the code)

Tabs live in one shell (scroll positions survive switching); everything else is
pushed on top.

| # | Screen | Route / entry | Primary action | Sheets / dialogs | Device-walked |
|---|--------|---------------|----------------|------------------|---------------|
| 1 | Onboarding | `/onboarding`, first launch | complete setup | — | tests only (`NOT PROVEN` on device — wiping the live ledger was refused) |
| 2 | Dashboard | tab 1 | read position | — | ✓ |
| 3 | Ledger | tab 2, `?side=` | browse, + add | filters/sort | ✓ both sides |
| 4 | People | tab 3 | find/add person | search inline | ✓ |
| 5 | Obligations | tab 4 | track recurring | inline pay/skip | ✓ |
| 6 | More | tab 5 | reach secondary areas | — | ✓ |
| 7 | Add action sheet | FAB on every tab | pick record type | — | ✓ AR + EN |
| 8 | Person form | `/people/new`, `/people/:id/edit` | save person | leave-guard (new) | ✓ |
| 9 | Person detail | `/people/:id` | balance, statement, add debt | ⋮ archive/delete | ✓ |
| 10 | Debt form | `/debts/new(+params)`, `/debts/:id/edit` | save debt | leave-guard | ✓ validation + leave |
| 11 | Debt detail | `/debts/:id` | record payment | ⋮ archive/delete, payment sheet | ✓ |
| 12 | Payment sheet | from debt detail | record payment | date picker | ✓ |
| 13 | Statement (PDF) | `showStatement` (raw route) | preview/share | options sheet | ✓ rendered + read |
| 14 | Records | `/records?filter=&direction=` | browse filtered | — | ✓ |
| 15 | Obligation form | `/obligations/new`, `/:id/edit` | save obligation | — | ✓ |
| 16 | Obligation detail | `/obligations/:id` | complete/skip | ⋮, actions sheet | ✓ |
| 17 | Reminders | `/reminders` | manage reminders | completed toggle | ✓ |
| 18 | Reminder form | `/reminders/new`, `/:id/edit` | save reminder | — | ✓ |
| 19 | Search | `/search` | find anything | — | ✓ (Latin on device, Arabic by tests) |
| 20 | Reports | `/reports` | read the month | month switcher | ✓ |
| 21 | Settings | `/settings` | adjust preferences | 8 pickers + PIN sheet | ✓ |
| 22 | PIN sheet | from settings lock row | set/remove PIN | — | ✓ (opened, cancelled, keypad measured) |
| 23 | About | `/about` | read app info | licences | ✓ |
| 24 | Backup | `/backup` | protection management | history/restore/folder | re-verified; deep audit in the prior report |

---

## Findings, fixes and evidence

Severity: P0 data-loss · P1 wrong info / broken flow · P2 confusion, i18n, a11y
· P3 polish. Every fix names its regression test.

### F1 · Ledger headline wrong on the owed-to-me side — **P1, fixed**

- **Symptom (device, `8ca93c74…`):** "لي" selected — a bare **₹0** printed above
  two records of ₹1,000 remaining each; the dashboard said ₹2,000 for the same
  side. Reproduced identically in English ("Owed to Me / INR ₹0").
- **Root cause:** `_SummaryStrip` printed `entry.iOweMinor` unconditionally;
  `CurrencyTotals` carries both directions, and the strip ignored `direction`.
- **Fix:** select the bucket by the visible side.
- **Test:** `test/widget/ledger_summary_test.dart` — fails on the old code (the
  owed-to-me side printed the I-owe total), passes on the new.
- **Re-proven on device:** لي now reads `₹ 2,000` above the same two records.

### F2 · The dashboard's "late" figure omitted late obligations — **P1, fixed**

- **Symptom (device):** "يحتاج انتباهك" showed **المستحق قريبًا ₹1,000** above
  two items summing ₹1,800 — one of them (Rent ₹800) an **overdue obligation**
  that appeared in no total at all.
- **Root cause:** the attention *list* mixed debts and obligations, but the
  *figures* above it came from debt-only totals.
- **Fix:** `AttentionList.totalsFor` sums the items themselves (per currency,
  obligations included); the list is built once uncapped for the totals and
  capped at five for display.
- **Test:** `test/widget/dashboard_attention_test.dart` — ₹23,000 + ₹1,200 =
  ₹24,200.
- **Re-proven on device:** المتأخر ₹800 (the late Rent) + المستحق قريبًا ₹1,000,
  matching the two items exactly.

### F3 · One screen, two words for the same money — **P2, fixed**

- **Symptom (device, AR):** the big net figure labelled **لك** sat directly
  above a split row labelling the same ₹2,000 **لي**. English is unambiguous
  ("In your favour" / "Owed to Me") — the Arabic was not.
- **Fix:** `dashboardInYourFavour` AR → **لمصلحتك**.
- **Re-proven on device:** the dashboard now reads "لمصلحتك ₹2,000".

### F4 · Floating "عرض القائمة" chip — **not reproduced**

Seen twice on the debt detail during the user's own live session; on a clean
re-entry it did not appear and never recurred. It is Flutter's stock
`showMenuTooltip` on the ⋮ button; no app code involved. Recorded as an
observation, not a defect.

### F5 · Two share affordances on the debt detail — **P3, accepted**

The app bar shares the debt as text; the bottom share builds the PDF statement.
Different targets, same icon family. Kept: both are one tap from a real need,
and the app bar is the platform-conventional place. Noted for a future label
pass, not changed.

### F6 · "Record a payment" appeared not to open — driver artifact

The automation's first two taps missed the merged semantics node. Re-driven
through the repo's own resolver it opened instantly; the sheet itself
(prefilled remaining, full-close banner, privacy line, pinned Save) reads well.
No defect.

### F7 · Date field unreachable while the keyboard is up (payment sheet) — **P3, accepted**

The sheet pins its Save above the IME but does not scroll the date field into
view; the IME's Next action reveals it. Common bottom-sheet behaviour, no data
risk. Recorded.

### F8 · «متوازن» for a person with no records — **P3, accepted**

A person with no debts shows "لا توجد ديون" and a "متوازن" chip — two quiet
labels for an empty state. Redundant, not misleading. Recorded.

### F9 · Same-named rows on a person's page — **withdrawn (design)**

On Ahmed's page, both of his untitled debts read "Ahmed". Read as ambiguity at
first; the code documents the choice (`displayNameFor`: a person's page names a
record by its own title or by the person whose page it is on, never by the
others). Kept as designed.

### F22 · "بدون اسم" as a record title — **P2, fixed**

- **Symptom (device, PDF + rows):** untitled records read "بدون اسم" /
  "Unnamed" — wrong register for a financial document and, after a person
  delete, actively confusing.
- **Fix:** AR **بدون عنوان**, EN **Untitled**.
- **Note:** after deleting a person, their single-participant debts stay as
  exactly this — nameless records — by design (see F38 below); the fixed copy
  makes that state readable instead of odd.

### F21 · Statement operations column speaks in log verbs — **P3, accepted**

"تم إنشاء دين" / "تم تسجيل دفعة" as the operation column. Honest and precise;
nouns would be more formal but the verbs are not wrong. Recorded.

### F24 · The phone hint rendered bidi-scrambled — **P2, fixed**

- **Symptom (device, zoomed):** `+967 7XX XXX XXX` displayed as
  **"7XX XXX XXX 967+"** — the + detached and the groups reversed.
- **Root cause:** the bare string in an RTL field; two files hard-coded it.
- **Fix:** LTR isolates around the hint (`\u2066…\u2069`) in
  `person_form_screen.dart` and `person_picker_sheet.dart`.
- **Re-proven on device:** the hint now reads `+967 7XX XXX XXX`.

### F25 · The person form discarded typed text in silence — **P2, fixed**

- **Symptom (device):** typed into the name, pressed Back — the form exited
  and dropped the edit with no word. The debt form asks first for the same
  situation.
- **Fix:** the person form gained the debt form's guard: dirty tracking on all
  fields and swatches, `PopScope`, and the same "تغييرات غير محفوظة" dialog.
- **Test:** `test/widget/person_form_guard_test.dart` (dialog appears; leaving
  discards; no person is created).
- **Re-proven on device:** dirty Back raises the dialog; "خروج بدون حفظ" leaves
  the record untouched.

### F27 · An overdue obligation looked peaceful on its list — **P2, fixed**

- **Symptom (device):** Rent, three days late, rendered "الاستحقاق القادم 27
  سبتمبر" with no state — while the dashboard flagged it red and the detail
  carried a "متأخر" chip.
- **Fix:** the obligation card shows the dense status chip for **overdue** and
  **due today** only; "upcoming" is what the date already says.
- **Test:** `test/widget/obligations_list_test.dart`.
- **Re-proven on device:** the Rent card carries "متأخر".

### F29 · Search could not find a person — **P2, fixed**

- **Symptom (device):** searching "Ahmed" — an existing person's exact name —
  returned only his debts; a person with no records ("Sara") returned nothing
  at all, though the screen promises "search names, obligations and notes".
- **Fix:** a **أشخاص · N** group at the top of the results, matching name or
  phone, navigating to the person page.
- **Test:** `test/widget/search_people_test.dart`.
- **Re-proven on device:** "Sara" → `الأشخاص · 1`.

### F32 · The PIN sheet's keypad was mirrored — **P2, fixed**

- **Symptom (device):** the settings PIN pad read **3 2 1** across the top row
  under Arabic — the exact mirroring `PinKeypad` documents having fixed, but
  `pin_sheet.dart` builds its own grid without the LTR wrapper.
- **Fix:** `Directionality(textDirection: ltr)` around the sheet's grid.
- **Test:** `test/widget/pin_sheet_keypad_test.dart`, with a **negative check**
  run (RTL fails, LTR passes).
- **Re-proven on device:** the pad now reads 1 2 3 left to right.

### F33 · Every full-page form's Save hid behind the keyboard — **P1 in effect, fixed**

- **Symptom (device, person form):** with the IME open the screen showed the
  form's top and the keyboard — **no Save anywhere**; taps at its coordinates
  landed on the keyboard; two save attempts did nothing until the keyboard was
  dismissed. Reproduced in a widget test: with a faked 300 px IME the button
  rendered 52 px *below* the keyboard line.
- **Root cause:** with edge-to-edge (the Flutter default now) the window never
  resizes; `Scaffold` insets its body for the IME but leaves its
  `bottomNavigationBar` at the window bottom. A bare-Scaffold experiment in a
  widget test proved it is framework behaviour, not app code.
- **Fix:** all four forms (person, debt, obligation, reminder) pad the pinned
  bar by `MediaQuery.viewInsetsOf(context).bottom` — the same manual pattern
  the bottom sheet already used, which is why the sheet's Save worked all along.
- **Test:** `test/widget/keyboard_insets_test.dart` — with a faked IME, the
  Save must sit above the keyboard line; fails before, passes after.
- **Re-proven on device:** with the keyboard open, "حفظ التعديلات" floats
  directly above it.

### F35 · "This cannot be undone" — while the app could undo — **P2, fixed**

- **Symptom:** the debt-delete dialog said "لا يمكن التراجع" / "This cannot be
  undone", then the app offered an undo snackbar.
- **Fix:** the debt dialog now uses its own honest body —
  "سيُحذف الدين، ويمكنك التراجع خلال ثوانٍ." / "The debt will be deleted. You
  can undo this for a few seconds." Obligation and person deletes keep the
  original line because there the undo genuinely does not exist.

### F36 · Delete flows: no feedback, no undo, no pop, once a blank screen — **P1, fixed**

- **Symptom (device, `8ca93c74…`):** after confirming a debt delete the app
  sat on a "Total / Deleted" dead screen and no Undo ever appeared. Later, a
  person delete produced a half-dead screen ("Person deleted" alone). Deepest
  case: deleting from the ledger-end left a **completely blank screen**.
- **Root causes, in layers — instrumented on the device, not guessed:**
  1. The write's own success rebuilt the screen **without the ⋮ menu that
     started it**, so by the time the handler resumed, `context.mounted` was
     false and the final `return` skipped both pop and feedback. (The widget
     test raced the other way — that is why it looked fine there.)
  2. An unmounted context cannot reach `ScaffoldMessenger`; the undo offer
     needs handles taken **before** the await.
  3. The first fix captured `NavigatorState` — a raw pop under go_router, whose
     page list then disagreed with the Navigator's: the next delete from the
     ledger popped into a **blank screen** (seen, diagnosed, and fixed within
     the audit).
  4. The dead-state screen's title was the balance-card label (`detailTotal` →
     "Total" / "إجمالي الدين") with a bare "Deleted" — no way to tell what had
     happened.
- **Fixes:** capture messenger, icon colour and the **GoRouter object** before
  the write; `AppFeedback.undoableDetached` / `infoDetached` present the offer
  with no live context (the undo is real for debts; obligation and person
  deletes carry no fake button); the dead state now reads `recordGone`
  ("هذا السجل لم يعد موجودًا.") and **pops itself** through go_router, so any
  stale path heals; debt-delete feedback is offered before the pop.
- **Tests:** `test/widget/delete_flow_test.dart` — no dead screen, the Undo
  action present and functional, and a detail whose record is gone removes
  itself. The blank-screen layer was caught on the device (a widget test cannot
  easily race go_router's bookkeeping) and re-proven after the fix.
- **Re-proven on device (final build):** delete from the ledger-end lands
  cleanly on the ledger, shows "تم الحذف · تراجع"; tapping تراجع restores the
  record (verified in the ledger); deleting again and the person leaves the
  ledger exactly as it was.

### F38 · Deleting a person leaves nameless debts — **designed, confirmed against the file**

Reading the raw database after the audit's own cleanup confirmed the behaviour:
deleting a person removes the links and keeps their single-participant debts as
records "naming nobody" — deliberate, documented at `deletePerson`, and exactly
the rule that a record must never disappear. Those records stay visible in the
ledger (now titled "بدون عنوان", F22) and are deletable like any other. Not a
defect; recorded because it surprised the audit itself.

### F37 · "تم حذف دين" for a deleted reminder — **P2, found late, NOT fixed**

The activity log labels a deleted reminder as a deleted **debt**
("تم حذف دين TestReminder" in the device log). Found during device verification
after the fix rounds; the mislabel is cosmetic (the log is a history list, the
reminder itself deletes correctly). Recorded here rather than rushed: it needs
its own activity type and translation pair, which is a small but real change
and is listed in the roadmap below.

---

## Form audit (device)

| Form | Verdict | Evidence |
|------|---------|----------|
| Person (new/edit) | hydration ✓, required marks ✓, optional labelled ✓, bidi hint fixed, guard added, Save lifts | device walk + tests |
| Debt (new/edit) | **no hidden direction default** ✓ (required, both options unselected), no hidden due date ✓, participants pre-filled from context and cleared explicitly, validation says what/where (`حقلان مطلوبان لم يكتمل..`, per-field messages), leave-dialog ✓, edit hydrates and keeps participants ✓ | device walk (validation + leave + edit) |
| Payment sheet | pre-fills the remaining, full-close banner, date picker localized RTL, Save pinned above the IME, cancel discards cleanly | device walk |
| Obligation | defaults (monthly, today, Housing) visible not hidden; day-of-month chips; edit hydrates | device walk |
| Reminder | title/date/notes; statement of what it is ("something not to forget") | device walk |
| Search | instant, groups by kind, clear button | device walk + tests |
| Task flows | create person → debt → edit → partial payment (33%) → full payment (100%, "Paid") → delete → undo → restore, obligation create/delete, reminder create/delete — all on the device with DB ground-truth checks | device walk |

---

## Arabic audit

Read on the device, screen by screen, not from the ARB. Strengths: plural
agreement is real (`دينان`, `سجلان`, `حقلان`, `قبل يوم`), the empty states and
the add sheet speak like a product (`أضف شخصًا لتتابع أرصدته`), and the
protection states are calm. Fixes made: **لمصلحتك** (F3), **بدون عنوان** (F22),
**سيُحذف الدين، ويمكنك التراجع خلال ثوانٍ** (F35), **هذا السجل لم يعد موجودًا**
(F36). The statement's numeric table dates (`7/10/2026`) beside Arabic month
names in the header are a deliberate document convention, noted (F23, P3).

## English audit

Walked after switching the language through Settings. The add sheet is
excellent ("Debt I owe — Money you have to pay"). Fixes: **Untitled** (F22),
the debt dialog body (F35). Noted: the update card's button reads
"Follow-up" (المتابعة) — reads like a noun; recorded for the roadmap (F39, P3).
LTR mirroring is correct throughout (back arrows, row chevrons, app-bar
actions), verified on the same screens as the Arabic pass.

## RTL / LTR

Arrows, chevrons, sheet drag handles, and the reports' month switcher all
mirror correctly (the "previous month" control sits on the right and changes
the month leftward, verified by tapping). Two mirroring defects were found and
fixed: the PIN sheet keypad (F32) and the phone hint (F24). The PIN dots and
keypad deliberately do not mirror — a dialer convention now consistent between
the lock screen and the settings sheet.

## Navigation

Reachability: every route has a way in and a way out; Back from every pushed
screen lands where the user came from — including from the statement and the
settings sub-screens. The defects found were all in the delete finales (F36),
now healed, including a self-healing dead state that removes itself instead of
sitting over nothing.

## Accessibility

Tab bar items announce position ("علامة التبويب N من 5"); switches merge their
label and state into one node; the keypad's backspace and the ⋮ carry labels;
touch targets for pins and primary buttons are ≥48 dp. Not walked by hand:
TalkBack traversal order end-to-end — `NOT PROVEN` (recorded in Known
limitations). One noticed redundancy: two rows on Settings are both named
"وقت الإشعار" — clear from their sections, ambiguous to a screen reader (P3,
roadmap).

## Visual design

Calm and consistent with the design principles: one type scale, restrained
palette, status colour used only for status, no card-in-card, no gradients.
The attention card, the statement preview and the backup screen are the
strongest surfaces. No AI-slop patterns found.

## Performance UX

No jank observed in the walks (list scrolling, sheet opens, PDF preview);
timings measured earlier in the release build (985 ms cold start) still stand
for this build's shared code. The audit added no measurable work except one
uncapped list build on the dashboard (in-memory, ~dozens of items).

---

## Scoreboard

| Metric | Count |
|--------|-------|
| Screens/surfaces inventoried | 24 |
| Screens device-walked (AR) | 21 |
| Screens device-walked (EN) | 12 |
| Forms audited | 7 |
| Fields inspected | 24 |
| Findings raised | 21 |
| — Critical (P0) | 0 |
| — High (P1) | 4 (F1, F2, F33, F36) |
| — Medium (P2) | 9 (F3, F22, F24, F25, F27, F29, F32, F35, F37) |
| — Low (P3, recorded/accepted) | 6 (F5, F7, F8, F21, F23, F39) |
| Fixed | 12 (F1, F2, F3, F22, F24, F25, F27, F29, F32, F33, F35, F36) |
| Withdrawn, not reproduced, or by design | 4 (F4, F6, F9, F38) |
| Unfixed, recorded (F37 log label) | 1 |
| Regression tests added | 9 |
| Tests before / after | 742 / 751 |
| Device re-verifications on the final build | 9 behaviours |

## Real-device evidence

- Device: Note 20 Ultra (SM-N986B), Android 13, serial `RZCN8017T9E`.
- Evidence root: `docs/final-acceptance/device/n20-forensic/` — screenshots,
  hierarchy dumps and text extracts for every stop, named by step.
- Ground truth read from the device's own SQLite file after every mutating
  flow: final state **4 people (the originals), 3 debts (the originals), Rent,
  1 reminder, lock off, automatic backup on** — the ledger the audit started
  with.
- The backup screen reads `بياناتك محمية · 7 نسخ صالحة` on the final build.

## Tests

`flutter analyze`: clean. `flutter test`: **751 passing** (742 before, 9 new:
ledger summary, delete flow ×2, keyboard insets, person-form guard, PIN keypad,
obligations list, search people, dashboard attention). Two of the new tests
were also run **negative first** (they fail against the old behaviour), and the
whole suite was re-run after every change.

## Remaining / Known limitations

1. **F37** — the activity log calls a deleted reminder "حذف دين". Cosmetic,
   needs a new activity type; listed for the next pass.
2. **Onboarding was not device-tested** (widget-tested only): proving it on the
   phone means wiping the live ledger, which this audit refused to do.
3. **The statement's numeric table dates** beside Arabic header dates (F23) —
   accepted document convention.
4. **TalkBack traversal** — components were checked, the full hand-walk was not.
5. **Arabic typing via automation** — adb cannot type Arabic; Arabic search
   was proven by tests, English by hand on the device.
6. Carried from the release gate: iOS `NOT PROVEN`, timezone/DST shift while
   closed, inexact alarms, the lock's biometric half, the large-dataset run in
   the profiler rather than the handset.

## Roadmap (what a next pass should do)

1. F37's activity type; the "Follow-up" button label; the two "وقت الإشعار"
   rows; the person-delete flow surfacing its kept nameless records in the
   confirmation ("سيبقى دينه في السجل بدون اسم").
2. A TalkBack hand-walk with the same evidence discipline as this audit.
3. Make the payment sheet scroll its focused field above the IME (F7).

## Final product question

*Would a person who has never seen Dhimmah understand it and finish the basic
tasks on this phone without the developer?* **Yes, with the fixes in this
audit.** The add sheet states what each record type is for, the forms refuse to
guess a debt's direction, validation says what is missing and where, saving
says it saved, deleting offers an undo, and the backup screen says in one line
whether the data is protected. The places where that answer was "no" before —
a headline that contradicted its own list, a save button hidden by the
keyboard, a person form that discarded work in silence, a search that could not
find a person — are the fixes above, each now proven on the phone.

## Post-report change (owner request)

**The debt form's description moved into the open form.** On request after the
report: «الوصف» used to be the first field inside the collapsed «خيارات إضافية»
section; it now sits directly under the amount + currency block, always
visible, with the hint «مثال: سلفة، قرض سيارة». The amount was and remains a
first-class field of the open form — never inside the disclosure — and the
collapsed section now holds only the issue date, reminder, repeat and notes
(its summary no longer mentions the description).

Verified: a new regression test (`debt_form_test.dart`, "what is visible
without expanding anything") holds the amount and description visible and the
date still behind the toggle; the full suite ran green (**752**); on the device
the complete cycle was replayed — fill amount + description → save → the ledger
row reads «Sara — TestDesc · ₹55» → edit hydrates the description in the open
form → untouched back is silent → delete lands cleanly with the undo offer →
the database is back to its original three debts and four people. Build
`sha256:3c8da703a976a675…`.

## Final verdict

**READY WITH KNOWN LIMITATIONS.**

No defect affecting trust, money display, form completion or data safety
remains open. The limitations are named, not softened: one cosmetic log label,
one untested first-run on hardware, and the carried platform caveats (iOS,
DST, inexact alarms, biometrics, large-dataset on-device).
