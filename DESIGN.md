# Dhimmah — Design

What the interface is made of, and why. Read this before changing anything
visual; if a value here is wrong, change it here first and then in the code.

---

## The product, and what the interface owes it

A personal ledger for the two sides of someone's money: what they owe, what they
are owed, and the commitments that come back every month. It opens in the phone's
language — Arabic or English, both complete — and it works with no network at all.

Three consequences run through every decision below:

1. **Numbers are the content.** Everything else exists to make a number
   readable, comparable, or actionable. Decoration competes with them.
2. **A statement leaves the app.** People send these to each other, so a figure
   that is ambiguous — a symbol that means two currencies, a colour with no label
   — can cost real money. Meaning never rests on colour alone.
3. **It is read daily, in a hurry.** Density is a feature; airiness is not. The
   screen is judged by how fast the four questions are answered.

## The four questions

Every information-architecture decision answers one of these, in this order:

1. How much do I owe? 2. How much am I owed? 3. What needs my attention?
2. What do I do next?

---

## Colour

**Deep pine ink on warm paper, with brass as the accent.** A ledger is a paper
object — something you keep, not a dashboard you watch — so the neutrals carry a
deliberate warmth instead of the blue-grey that every finance app reaches for,
and the brand is a deep pine that reads as ink rather than as the generic banking
blue.

The hues are the identity's own: a green at 180° and a gold at 73°, taken from
the reference the mark was drawn from. The brand ramp is the previous teal ramp
**rotated to that hue with its lightness and chroma held**, which is not a
stylistic detail — WCAG contrast is a function of relative luminance alone, and
rotating a hue at constant L\* leaves luminance untouched. Every ratio the
palette was built around still holds to two decimal places, and the sixteen
assertions in `test/core/palette_contrast_test.dart` still pass unchanged.

The warmth is kept at very low chroma on purpose. A warm grey reads as paper;
push it further and it becomes a cream palette, which is its own reflex and makes
white cards look like stickers stuck onto the page.

**The brand is green and so is "settled", and they are not the same green.** The
brand is a muted pine (L\* 32, C\* 21); the money greens are saturated emeralds
(L\* 45, C\* 40) — a ΔE\*ab of 25, driven mostly by lightness and chroma rather
than by hue. The rule that makes this safe is older than the palette: every
status also carries a shape or a word, so nothing in the app is ever read from
colour alone. If the brand changed tomorrow, every semantic colour would stay
exactly where it is.

| Token | Role |
|---|---|
| `brand` | Interactive: selected states, primary buttons, links. Never decoration. |
| `brandContainer` | The tint behind a selected or grouped element. |
| `gold` / `goldContainer` | The brand accent, used twice in the whole app: the terminal on the mark, and a 22×2 rule under the wordmark (`DhimmahWordmark`, the only place it is drawn — the dashboard and onboarding use the same widget). Never a status. |
| `surface` / `surfaceMuted` / `surfaceRaised` | Three levels: the page, a recessed well (input fills, grouped rows), and anything that floats above the page (sheets, dialogs). |
| `background` | Warm paper in light mode; warm charcoal in dark. Cards are white in light mode so they lift **without** a shadow. |
| `border` / `borderStrong` | Warm hairlines. A card is a surface plus a hairline, never a shadow. |
| `textPrimary` / `textSecondary` / `textTertiary` | Three weights of voice. Tertiary is metadata only, never content. |
| `owedToMe` | Money coming to the user. |
| `iOwe` | Money the user must pay. |
| `overdue` | Past its date and still unpaid. Deeper than `iOwe` so the two differ when they sit together. |
| `dueSoon` | Approaching its date. |
| `settled` | Fully paid. |
| `neutralStatus` | Active, archived, unknown. |

Every value in both themes was checked against WCAG AA before it was written, not
after. `dueSoon` needed darkening from `#B26A00` to `#9E5C00` to clear 4.5:1 on
warm paper. The dark palette's semantic colours are **not** the light ones
inverted — a red that reads on paper is unreadable on charcoal, so each is lifted
independently (verified at 6.8–10.2:1).

Every pairing the app actually renders is checked **by a test**, not by eye:
`test/core/palette_contrast_test.dart` asserts text on each of the four surfaces,
both directions of money, brand text on brand fills, and every status colour on
its own container — at 4.5:1 for text and meaningful icons.

That test was written *after* a manual pass had declared the palette clean, and it
immediately found four pairs that were not:

| Pair | Was | Now | Why it mattered |
|---|---|---|---|
| light `textTertiary` on paper | 3.02:1 | 4.83:1 | Tertiary carries real content in 26 places — currency codes, dates beside an amount, list counts. It was below the text bar everywhere. |
| dark `textTertiary` on night page | 4.23:1 | 5.77:1 | The same, on charcoal. |
| dark `textOnBrand` on `brand` | 2.75:1 | 5.12:1 | White on the *lifted* dark brand — the primary button and the add button, the two most prominent controls in the app. The dark brand is lifted precisely so it holds on charcoal, which is why white stopped working on it; the label goes dark instead, as it already did on gold. |
| light `gold` on `goldContainer` | 3.47:1 | 4.52:1 | The gold glint in the add-action sheet. |

The lesson is in the failures, not the fixes: a tint looks fine beside the swatch
it was mixed from, and the ratio that decides is the one against the surface it
actually lands on. Mixing a container by hand — `accent.withValues(alpha: 0.12)`,
which is how the onboarding discs were built — produced the same class of bug at
3.23:1. Containers are now taken from the token designed to pair with the status
colour, never derived from it.

The Android window behind the first frame is a colour too, and the easiest one to
forget: `android/app/src/main/res/values{,-night}/colors.xml` must equal
`background` for its brightness (`#F7F5F2` / `#131211`). It had been left on
`#F5F8FA` — the *previous*, cool palette — so every cold start flashed a colour
the app was not about to draw.

Rules that are not negotiable:

* **Colour never carries meaning alone.** Every status is a label plus a glyph
  plus a colour, so a greyscale printout and a colour-blind reader get the same
  information.
* **Two colours on a screen, not six.** A list of debts shows amounts in one
  semantic colour and statuses in their own; nothing else is tinted.
* **A tint marks a group, not a decoration.** Tinted icon tiles survive only where
  the icon is genuinely categorical (an obligation's category, a person's
  initials). Settings rows use plain icons: thirty coloured squares turn a quiet
  screen into a grid of buttons that are not buttons.

## Typography

One family: **IBM Plex Sans Arabic**, bundled. It has Latin and Arabic drawn to
the same weight and rhythm, so the two languages are the same product rather
than a translation of one.

| Style | Size / weight | Used for |
|---|---|---|
| `displaySmall` | 30 / 700 | The one headline figure on a screen. The dashboard's net position; a statement's total. Used once per screen or not at all. |
| `headlineSmall` | 20 / 600 | Screen titles, the amount in an amount field. |
| `titleLarge` | 19 / 600 | Sheet titles; a primary figure inside a card. |
| `titleMedium` | 17 / 600 | Section headers, app-bar titles, list-row names. |
| `titleSmall` | 15 / 600 | The amount on a record row. |
| `bodyLarge` | 16 / 400 | Long-form input, empty-state prose. |
| `bodyMedium` | 15 / 400 | Default reading size. |
| `bodySmall` | 13.5 / 400 | Secondary lines: dates, counts, hints. |
| `labelLarge` | 15 / 600 | Button labels, field labels. |
| `labelMedium` | 13 / 500 | Chip labels, inline labels. |
| `labelSmall` | 12 / 500 | Navigation labels, metadata. Never below 12. |

Money is always set with `AppTypography.moneyFeatures` (tabular, lining figures)
so a column of amounts aligns whether or not the font has proportional digits.
Arabic sits on a taller line box: `height` is 1.3–1.5 throughout, never tighter.

## Spacing

A fixed 4-based scale in `AppSpacing`: 2, 4, 8, 12, 16, 20, 24, 32, 40, 56.

The values that carry meaning:

* `md` (12) — inside a list row, between a label and its value.
* `lg` (16) — screen gutter, and the padding inside a card.
* `xl`/`xxl` (20/24) — between sections.
* `huge`/`massive` (40/56) — empty states, and clearance under a floating button.

Every screen uses `AppSpacing.screen` (16 horizontal) as its gutter. Nothing
touches the page edge.

## Numbers

A financial figure is the content, so it is set rather than printed.

* **`HeroAmount`** is the one large figure a screen may have. The currency symbol
  is set at half size and muted so it reads as a unit instead of competing with
  the digits; the digits use tabular figures with −0.8 tracking so they hold
  together as one shape and stay in the same place when the value changes.
* It is forced **left-to-right** whatever the interface language, because an
  amount is one unit and the shared formatter renders it that way everywhere else.
  Letting the ambient direction place the symbol printed the hero differently from
  every other figure on the same screen.
* The sign is carried explicitly, and it leads: `−₹ 39,200`, matching the order
  the shared formatter prints everywhere else. Drawing it inside the digit run
  produced `₹ −39,200`, which reads as "rupees, minus thirty-nine thousand".
* **Callers pass a magnitude.** Both screens that own a hero put the direction in
  the sentence above it ("عليك" / "لك"), so a signed figure would double-encode
  the same fact and read as a double negative. The widget still handles a signed
  value correctly, because a money widget that quietly got that wrong would be
  worse than one that never needed to.
* It **animates** to a new value over 420ms. A balance that visibly moves after a
  payment is the app's real confirmation — it says more than a toast, and it costs
  no extra chrome.
* Away from the hero, a bar of progress is the only other ornament a figure gets.

## Shape

| Radius | Used for |
|---|---|
| `rSm` (12) | Icon tiles, chips, small inner surfaces. |
| `rMd` (16) | Inputs, buttons, inner panels, sheets' content blocks. |
| `rLg` (20) | Cards — the one shape a list row group takes. |
| `rXl` (24) | Dialogs. |
| `rPill` (999) | Chips and badges. |

Not every surface is rounded the same on purpose: a card is 20, the input inside
it is 16, and the chip on that is a pill. That progression is the shape system.

## The mark

**A green wallet holding a receipt and a coin.** What is kept, and what is owed —
which is what the app is for, said as a picture rather than as a ledger glyph.

The identity is **artwork, not a drawing**, and the app does not redraw it.
`assets/icon/icon.png` is the master: the reference picture cropped square. Every
other icon is derived from that one file by `tool/generate_icons.py` — the
launcher bitmaps, both adaptive layers, the one-colour silhouettes, the iOS set,
the logo the app draws and the smaller copy a printed statement embeds. There is
no second drawing to drift out of step, which is not a nicety: the previous mark
existed twice, once as a Python drawing and once as Dart, and by the time anyone
looked the two had already drifted apart.

Three things in the generator are worth knowing, because none of them is
obvious:

* **The mark is separated from its ground by its edge, not by its colour.** The
  wallet is the same green as the tile it sits on, so no threshold can tell them
  apart. What can is that the ground is a smooth gradient and the mark has a hard
  boundary: a flood fill from the border walks the gradient and stops at the
  boundary.
* **The adaptive background is reconstructed, not patched.** The mark covers more
  than a third of the tile, and inpainting a hole that size leaves a stain behind
  the logo. The ground's own shading is almost flat, so the hole is closed and
  the whole field blurred hard enough that only the gradient survives.
* **The iOS set is a full square.** iOS applies its own mask, so an icon whose
  corners are already rounded would show that rounding inside the system's; the
  corners are grown from the ground's own edge.

In one colour — a themed icon or a status-bar silhouette — the mark becomes its
own alpha painted white. The system tints the whole layer, so the wallet, the
receipt and the coin read as one shape, which is what a one-colour icon is.

## Elevation

**Cards have no shadow.** A card is a surface plus a hairline border. Shadows are
reserved for things that genuinely float above the page: the add button, sheets,
dialogs. Two exceptions is the entire list — if a third appears, one of the three
is wrong.

## Iconography

One family: **Material Icons**, and only the outlined weight, with two
deliberate exceptions:

* A navigation destination shows the **filled** icon when selected and the
  outlined one when not — that is the platform convention for "you are here".
* A **selected** choice (a ticked language) is filled; an unselected one is
  outlined.

Icons carry no text of their own, so every icon that is the only label for an
action has a tooltip and a semantic label.

## Layout of a screen

```
app bar or header     32–56   title, at most two actions
─────────────────────────────────────────────────────────
primary content       —       one job per screen
─────────────────────────────────────────────────────────
bottom navigation    68       five destinations, or none
floating add button  56       only inside the shell
```

Each screen has **one** primary action. A shell destination never declares its
own add button — the shell owns it, and two would overlap. There is a test for
this.

---

## Motion

Motion explains a change; it never performs. `AppMotion` holds four durations
(140/220/280/320 ms) and two curves. The whole app uses:

* a bottom sheet sliding up (the platform's own),
* a screen transition (the platform's own),
* `AnimatedSize` + `AnimatedRotation` on the one disclosure in the debt form,
* `AnimatedContainer` on the PIN dots,
* onboarding's step slide and its progress segments — and with the system's
  "remove animations" on, the step changes without the slide.

Nothing bounces, nothing loops, nothing animates on first paint.

## Feedback

* A short `SnackBar` confirms anything that was saved, and carries the **undo**
  for anything deleted. Deleting is reversible for six seconds rather than
  gated behind a second dialog.
* One light haptic on a successful write, and nowhere else. It keeps meaning
  "that was saved".
* Errors say what the user can do, never what went wrong inside.

---

## Layout rules that came from review

Each of these was a defect found by looking at the running app, not by reading
the code.

1. **No gradient headers.** The dashboard's position is carried by one large
   figure on the page surface. A coloured panel added weight without adding
   information.
2. **No emoji in interface copy**, including greetings.
3. **Four facts, one hierarchy.** The dashboard states where you stand, then the
   two sides of the book, then what is urgent. It is not four equal cards.
4. **Nothing is shown twice.** The attention list absorbed the old "upcoming"
   strip; the header's currency switch absorbed the "other balances" strip; the
   ledger merged two near-identical destinations into one.
5. **Empty states are copy, not clip art.** No large circle containing a large
   icon — a shape every app has, which says nothing. A short rule in the state's
   own colour, a sentence that explains the situation, and the one action that
   changes it. An unfiltered empty ledger is good news and is shown in the settled
   green; a filter that matched nothing is not.
6. **Progressive disclosure in forms.** Only what a debt always needs is visible;
   description, reminder, date and notes are one tap away, and the disclosure
   opens itself for a record that already uses them.
7. **Latness is always stated as lateness**, however old — never as a bare date.
8. **Money is one value type.** Never a `double`, never an unformatted string, and
   never two currencies added together.
9. **One focus figure per screen, and the direction goes in words.** A screen may
   have one large number; two would mean it has none. The number is a magnitude
   and the sentence above it carries the direction — "عليك" then `₹ 39,200`, never
   "عليك" then `−₹ 39,200`, which reads as a double negative. The dashboard and a
   person's page state the same figure the same way.
10. **A name is written large once.** On a person's page the name is the header
    card's headline; the app bar is blank until the card scrolls out of view and
    the name drifts up into it. Showing both at once said the same thing twice in
    one screenful.
11. **One status mark per row.** The leading icon already differs by shape for
    overdue, due today and due soon, and the line beneath names the state in words
    ("متأخر 17 يومًا"). A chip repeating that word, with the same icon drawn a
    second time, only crowded the amount beside it.
12. **A fact is stated once per screen.** The person page's header used to count
    the debts in one wording while the list controls counted them in another.
    Where two components can count the same thing, only one of them may.
13. **A required field says so before Save, in more than one channel.** The label
    carries `*`, the message appears under the field itself, and the save that
    found it says how many are missing and moves the screen to the first one. The
    asterisk and the words carry the meaning; the colour only reinforces it, so a
    raised-contrast or greyscale screen loses nothing. A form that answers with a
    single sentence about "invalid input" is a form that makes the user hunt.
14. **A field with no answer is not given one.** `عليّ / لي` opens with neither
    side selected, because a debt recorded as "I owe" only because that is what
    the form happened to be showing is a wrong record that nobody chose. The same
    rule applies to the optional fields: a default is only allowed where the
    product genuinely has one (the currency comes from settings, the reminder
    from the user's own preference), never to make a required field look filled.
15. **One record can be linked to several people, and none of them is told.**
    The link is bookkeeping. On a person's page the record is one of *their*
    debts: the ordinary row, the ordinary figure, the ordinary totals — no
    `مشترك` label, no banner, no list of the other people, and nothing that
    leaks their names. The record's own page names everyone it is with, because
    that is where it is edited, and the flat ledger list names them too, because
    a row in a list of records has to say who it is with. The amount is printed
    once wherever it appears, whichever page it is on.

16. **A reminder is a representation of a record, never a second truth.** The
    records decide what should be pending; the phone is then made to agree with
    them, and nothing is stored about a notification that the records do not
    already say. Reconciling compares the two sets and acts on the difference —
    cancelling only what is no longer wanted, scheduling only what is missing —
    because "clear everything and re-add it" also clears the notifications the
    user has already received. An id is the record, the kind of reminder and the
    moment, so the same reminder is the same notification on every pass, and the
    choice at the platform's limit is a function of the records rather than of
    the order they happened to be read in.
17. **A reminder that cannot arrive is never implied.** If reminders are off, or
    the system blocks notifications, the form where the reminder is chosen and
    the record where it is read both say so. The permission is asked when the
    user turns reminders on — never at launch — and re-read whenever the app
    comes back, because the user can change it while Dhimmah is in the
    background. A reminder is also never exact: "look at this today" does not
    need a millisecond, and the permission that would buy one is denied by
    default on Android 14+ and reserved by Play for alarm and calendar apps.

18. **The app is in the phone's language, and says which.** Nothing asks for a
    language on first run: the first frame is already in the phone's, and the
    other language is offered by its own name — «العربية», "English" — on every
    onboarding step, because the person who needs that button is the one who
    cannot read the screen it is on. Settings lists the phone first, with the
    language it currently means beneath it, and names every language in its own
    script. Coming back to the phone's own language stores "follow the phone",
    not a pinned copy of it.
19. **Onboarding is three steps with one action each.** What the app is, the
    currency new records use, and reminders — stating the real defaults (the
    lead, the hour, the month-end summary) so "turn on" is a decision about
    something visible. The action is pinned below the content so it can never be
    scrolled away at 1.5x text on a 360px phone, a hairline above it says when
    there is more below, and the system back gesture walks back through the
    steps. Skip never raises a permission dialog; "Not now" is an answer and is
    stored as one.

**Numbers do not mirror.** Every dialer puts 1 at the top left in Cairo exactly
as in London, and a PIN is a sequence of digits read left to right. The keypad
and its progress dots are laid out left to right whatever the app's language —
the one place where "the app is Arabic, so lay it out from the right" is the
wrong answer. `test/widget/number_direction_test.dart` pins the order of every
row.

Three of these are enforced rather than documented:
`test/widget/design_invariants_test.dart` walks every destination and fails if a
screen shows two focus figures or two primary actions, and checks the person page
leads with one balance, states the count once, and blanks its app-bar title at
rest.

## What the screens taught when they were looked at

Three defects that only appeared when the rendered screens were inspected, and
what they had in common: each one was a *container or a colour* doing a job the
content should have done.

* **A group heading named after its own row.** The More screen's first card holds
  Reports and Reminders, and its heading was `navReminders` — so the card read as
  "Reminders: Reports, Reminders". A heading labels the group; it may not be the
  title of one of its members. Now «المتابعة» / "Follow-up".
* **A card around one figure.** The ledger's total sat in a full-width card with
  roughly half of it empty, and the count it printed ("4 سجلات · INR") was printed
  again in the row directly underneath. Two containers' worth of chrome and a
  duplicated fact, for one number. The total now stands on its own under the side
  switch, which also lifted the first list row into view on a 360×640 screen.
* **One colour carrying two meanings on one row.** A partially paid debt drew its
  progress bar in `forDirection` — the same red as the "متأخر" chip beside it — so
  red meant both "money you owe" and "this is late". Progress is neither, and now
  uses the brand lane. The row had also re-drawn the bar instead of using
  `DebtProgressBar`, which is how it lost the widget's screen-reader label; it
  uses the shared widget again, so the bar is announced as "paid, 40%".

The rule they add to the list above: **a container earns its place by grouping
things, and a colour earns its place by meaning one thing.**

## Known trade-offs

* A statement's Arabic is drawn with Unicode presentation forms, so its text is
  not extractable by copy-paste in a PDF reader. Real OpenType shaping is not
  available in the Dart PDF stack, and a document that prints correctly was
  judged more important than one that can be searched.
* A statement carries the mark as a bitmap rather than as vector art, because
  the identity is a picture and redrawing it as paths would be a second version
  of it. It is sized for the page — 200px across a 26pt logo, about 550dpi — and
  flattened onto white, so the document grows by about 70kB rather than by a
  megabyte.
* The statement's *ordering*, line breaking and alignment are the renderer's,
  which is what makes them correct — it applies the Unicode bidirectional
  algorithm and arranges each line from the reading side. The price is that the
  document depends on the renderer continuing to do so: a version of the `pdf`
  package that changed its right-to-left handling would change the output
  silently. `test/core/pdf/statement_geometry_test.dart` reads the drawing
  instructions back out of the finished file and asserts the reading order, so
  such a change fails a test rather than reaching a reader.
* The floating add button still passes over list content while scrolling. Each
  scrollable ends with `AppSpacing.addButtonClearance` (the button's height plus
  the margin `Scaffold` leaves) so the last row can always be scrolled clear of
  it, but mid-scroll the button sits over whatever is beneath it. Hiding it on
  scroll would trade a known, bounded overlap for motion the screen does not need.
* On the empty dashboard the add button and the empty state's primary action both
  lead to adding something. They are not quite the same action — the button opens
  the action sheet, the labelled one goes straight to a debt — and hiding the
  button only in the empty state would mean the shell had to know the dashboard's
  contents. The overlap was judged cheaper than that coupling.
* The launcher mark is fitted to the adaptive icon's safe circle by measuring its
  own bounding box (`tool/generate_icons.py`), so the mark's corners and the coin
  terminal survive any mask the launcher applies. On a very wide mask the mark
  therefore reads slightly smaller than a full-bleed icon would.
