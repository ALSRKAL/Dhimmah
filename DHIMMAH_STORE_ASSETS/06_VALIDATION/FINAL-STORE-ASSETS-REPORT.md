# ذِمّة — Dhimmah: final store-assets report

**Package:** `DHIMMAH_STORE_ASSETS/`
**Built:** 2026-09-26 · **Host:** Linux, Flutter 3.44 · **Capture device:** Android
emulator `emulator-5556` (Pixel 6 AVD, 1080 × 2400 @ 420 dpi, android-36
google_apis_playstore)

**Overall verdict: PARTIAL.** Everything Android is produced, validated and
verifiable. The iPhone and iPad screenshot sets are **NOT PROVEN** — this machine
has no macOS, no Xcode and no iOS runtime, so none was produced and none was
faked. The exact commands that close that gap are written down in the package.

---

## 1. Official requirements

Read from the vendors' own pages on **2026-09-26**, never from memory. The full
table with the page each number came from is `00_README/STORE_REQUIREMENTS.md`;
two of the five pages needed care:

| Page | Result |
| --- | --- |
| App Store Connect — Screenshot specifications | read (the requested path now redirects to `reference/app-information/screenshot-specifications`) |
| App Store Connect — Upload app previews and screenshots | read |
| Apple HIG — App icons | the HTML is a JavaScript app; the content was read from the page's own JSON endpoint |
| Play Console Help — Add preview assets | read |
| `developer.android.com/.../feature-graphic` | **NOT FETCHED** — the page now redirects to a marketing page with no specifications (and to an OAuth sign-in on direct request). Nothing was taken from it; the feature graphic follows the Play Console Help numbers instead |

Values the package is built to: iPhone 6.9″ 1320 × 2868 · iPad 13″ 2064 × 2752
(required because the app targets iPad) · Apple 1–10 screenshots, no alpha ·
Play screenshots JPEG or 24-bit PNG, no alpha, 320–3840 px, max ≤ 2× min
dimension, max 8 per device type, 9:16 portrait ≥ 1080 × 1920 for recommendation
eligibility · feature graphic 1024 × 500 · Play icon 512 × 512 32-bit PNG with
alpha ≤ 1024 KB · "Screenshots must demonstrate the actual in-app or in-game
experience" · "Taglines should not take up more than 20% of the image".

## 2. Supported platforms

| Platform | State |
| --- | --- |
| Android | **proven** — the app was built, installed and run on the emulator; four capture runs executed the real UI and passed |
| iOS | project present (`ios/Runner.xcodeproj`), portrait-only keys set, but **no iOS runtime exists on this machine** — it has not been built or run here |
| iPad | supported by the app (`TARGETED_DEVICE_FAMILY = "1,2"`), **no runtime**, not captured |
| Landscape | not part of the phone experience; the app is portrait-only and every asset is portrait |

## 3. Supported devices

| Device class | Captured | Notes |
| --- | --- | --- |
| Android phone | yes — Pixel 6 AVD, 1080 × 2400 | the 8 + 8 frames behind every Play asset |
| Android tablet | no | the same harness runs on a tablet AVD; not attempted this round |
| iPhone 6.9″ | no | needs macOS |
| iPad 13″ | no | needs macOS |

## 4. Store dataset

Written through the app's own `LedgerService` by
`test/support/store_demo_seed.dart`, identical in both languages, entirely
fictional:

* **5 people** — AR: أحمد محمد، خالد العلي، محمد صالح، علي حسن، مكتب المحاسبة ·
  EN: Ahmed Mohammed, Khalid Al-Ali, Mohammed Saleh, Ali Hassan, Accounting Office
* **8 records** — one overdue, one settled in full, one with no due date, one
  belonging to two people
* **the flagship record** — «سلفة» / "Advance": 1,500 borrowed, 500 repaid,
  1,000 remaining (375,000 / 125,000 / 250,000 in riyals)
* **one record, two people** — «مصاريف مشتركة» / "Shared expenses" is on the page
  of each of its two people, with no "shared" wording anywhere, which is how the
  app behaves; proven by `test/tool/store_dataset_test.dart`
* **4 monthly commitments**, with one period already paid
* **3 reminders**

`test/tool/store_dataset_test.dart` asserts all of it, in both currencies,
including that no amount anywhere renders as rupees. **2 tests, both passing.**  The whole suite: `flutter analyze` clean, **561 tests pass**.

## 5. Currency used

| Listing | Currency | How it reads on the screens |
| --- | --- | --- |
| Arabic | **Yemeni riyal — YER** | «﷼ 375,000» (the app's own riyal sign) |
| English | **US dollar — USD** | "$ 1,500" |

Three layers enforce it:

1. **The dataset** scales its figures to the ledger's currency (250 riyals to the
   dollar), so the same story is told in each money.
2. **The capture** refuses any other currency — `STORE_CURRENCY` must be `usd` or
   `yer` — asserts the stored currency is the requested one before the first
   frame, and checks the rendered widgets for the rupee by symbol, code and name
   (all four spellings) before writing each frame.
3. **The validator** scans every text file in the package and records the result
   in `06_VALIDATION/currency_report.csv`.

The rupee appears nowhere in this package. The previous rupee revision is not in
it either — that folder was replaced, not merged.

## 6. Screenshots captured

Four runs, all from the running app on the emulator:

```bash
./tool/store_capture/run_capture.sh emulator-5556 ar light "" yer
./tool/store_capture/run_capture.sh emulator-5556 en light "" usd
./tool/store_capture/run_capture.sh emulator-5556 ar dark  "" yer
./tool/store_capture/run_capture.sh emulator-5556 en dark  "" usd
```

Each run: `All tests passed`, exit 0. Each wrote **8 frames** at the device's
native 1080 × 2400 from inside the app — `RenderRepaintBoundary.toImage` at the
device pixel ratio, not a screenshot of the screen, so no status bar, no emulator
chrome, no cursor and no notification can appear in them.

Result: **8 light + 8 dark frames per language, 32 in total** in
`04_SOURCE_SCREENSHOTS/ANDROID/{AR,EN}/`. Each frame carries its screen and its
language in its name — `01_dashboard_ar.png`, `01_dashboard_dark_ar.png` — so a
file is unambiguous wherever it is copied to. The light frames are the ones the
store assets are made from; the dark frame of the dashboard is an extra slide.

## 7. Assets generated

**22 assets**, every one listed in `00_README/ASSET_MANIFEST.{csv,json}` with its
source, dimensions, format, alpha, size, alt text, prompt and upload destination:

| Asset | Count | Files |
| --- | --- | --- |
| Google Play phone screenshots, Arabic | 8 | `01_GOOGLE_PLAY/PHONE_AR/01…08_*_ar_google_1080x1920.png` |
| Google Play phone screenshots, English | 8 | `01_GOOGLE_PLAY/PHONE_EN/01…08_*_en_google_1080x1920.png` |
| Dark dashboard alternates | 2 | `PHONE_{AR,EN}/ALTERNATES/01_dashboard_dark_*` |
| Feature graphics | 2 | `FEATURE_GRAPHIC_{AR,EN}/feature_graphic_*_1024x500.png` |
| Store icons | 2 | `03_ICONS/GOOGLE_PLAY/icon_512x512.png`, `03_ICONS/APPLE/icon_1024x1024.png` |

Story order (the order they are uploaded in): dashboard → add debt → people →
debt detail → obligations → ledger → backup → statement.

## 8. Dimensions

| Asset | Dimensions | Format | Alpha | Max size on disk |
| --- | --- | --- | --- | --- |
| Play phone screenshots | 1080 × 1920 (9:16) | PNG | none | 263 KB (limit 8 MB) |
| Play feature graphics | 1024 × 500 | PNG | none | 62 KB (limit 15 MB) |
| Play store icon | 512 × 512 | PNG | **present, as Play asks** | 288 KB (limit 1024 KB) |
| Apple icon | 1024 × 1024 | PNG | none | 997 KB |
| Source frames | 1080 × 2400 | PNG | — | not shipped to a store |

## 9. Localization

* Two complete listings: **Arabic (RTL)** and **English (LTR)**, same story, same
  dataset, same screens.
* The marketing text is drawn by the compositor in **IBM Plex Sans Arabic** — the
  app's own font files — with real Arabic shaping and bidi through Pillow/raqm.
  No image model writes the Arabic in this package, which is why it is spelled
  correctly.
* The capture asserts the rendered locale equals the requested one before any
  frame is written: an English run can never produce an Arabic screenshot, or the
  reverse.
* Alt text is provided for every asset in both languages, each under 140
  characters (checked).

## 10. Visual QA

Every asset was opened and read. The full record is `00_README/FINAL_QA.md`,
including the numbers that were re-added by hand to prove the dashboard is
internally consistent (1,417,500 − 600,000 = 817,500, and both sums decompose
into the seeded records).

Defects found and fixed in this pass:

| Defect | Fix |
| --- | --- |
| Marketing band measured 20.5% (EN dashboard) and 22.8% (EN obligations) — over Play's published 20% | the compositor now fits the whole set: one type scale, the tallest band inside the cap; worst case 18.6% |
| cards sat at different heights across a set | card top is measured from the tallest band, so all eight line up exactly |
| the composed brand row put the wordmark before the mark | rebuilt to lead with the mark at the reading edge, matching the app's own header |
| stale frames from the previous revision were still on the device | every run now empties the device folder first; the stale frames were deleted, not shipped |
| a tool hook left a hidden state folder inside the package | removed, and the scan plus a new stray-file check now skip hidden directories |

## 11. Source fidelity

18 composed screenshots compared against the 18 source frames they were built
from, in `06_VALIDATION/source_fidelity_report.csv`:

* the composed card is the source scaled to the card's size and pasted whole
* the comparison insets 6 px to step over the 2 px border ring and the rounded
  corners, which are composition rather than screenshot
* **18 / 18 pass**, threshold 4.0 mean absolute channel difference, **worst
  measured 0.04**

Nothing inside any screenshot was redrawn, re-coloured, re-typed or retouched.
The only operations on a frame are LANCZOS scaling and a rounded-corner mask.

## 12. Nano Banana prompts

* **20 prompts** in `05_NANO_BANANA_PROMPTS/GOOGLE_PLAY/` — one beside each
  composable asset: 8 Arabic slides, 8 English slides, 2 dark alternates, 2
  feature graphics. The validator checks that every composed asset has its prompt.
* `05_NANO_BANANA_PROMPTS/MASTER_PROMPT.md` — one copy-paste prompt that produces
  the whole set: the source-of-truth and do-not-modify rules, the exact palette,
  the type sizes and margins, the currency, the per-slide attach/headline/support
  table for both languages, the never list, and the instruction that if the model
  cannot reproduce the Arabic exactly it should leave the text band empty,
  because the correct finished images already exist.
* The two store icons have **no prompt by design**: they are the app's shipped
  artwork resized to each store's requirement, so there is nothing for an image
  model to be asked for. The manifest records this rather than hiding it.

## 13. Validator results

`python3 tool/validate_store_assets.py` — exit code 0.

```
assets:    22 in the manifest
checks:    293
passing:   293
failing:   0
fidelity:  18/18 pass
duplicates:0
warnings:  2
  WARN apple_iphone — NOT PROVEN — no iOS runtime on this machine
  WARN apple_ipad   — NOT PROVEN — no iOS runtime on this machine
```

What it checks: existence, dimensions, format, alpha, file size against each
store's limit, 320–3840 px bounds, 9:16 aspect, naming, set membership and
completeness per language, source capture size, prompt coverage, alt-text length,
the marketing band against the 20% rule, source fidelity, duplicates by SHA-256,
the declared currency, banned currencies in every text file, coverage per
platform, stray files, and that every PNG in the package is in the manifest.

Reports written: `dimension_report.csv`, `format_report.csv`, `alpha_report.csv`,
`file_size_report.csv`, `localization_report.csv`, `prompt_coverage.csv`,
`duplicate_report.csv`, `source_fidelity_report.csv`, `currency_report.csv`,
`coverage.csv`, plus `source_map.json`, `build_info.json` and the two contact
sheets.

## 14. Upload order

* `00_README/GOOGLE_PLAY_UPLOAD_ORDER.md` — the eight files per language in
  order, with the alt text to paste for each, then the feature graphic, then the
  icon, then the fields that are not in this package.
* `00_README/APPLE_UPLOAD_ORDER.md` — what can be uploaded today (the icon), what
  cannot (everything else), and the order to fill the screens once a Mac is
  available.

## 15. Missing assets

| Missing | Why |
| --- | --- |
| iPhone screenshots (8 AR + 8 EN) | no iOS runtime on this machine |
| iPad screenshots (8 AR + 8 EN) | same; required because the app targets iPad |
| Android tablet screenshots (≥ 4) | not attempted this round — known gap, not a blocker for the phone listing |
| App preview video | none produced |
| Store listing copy (title, short description, 80-char limit) | outside this package |
| Play "large screen" set | same as the Android tablet row |

## 16. NOT PROVEN items

1. **iPhone screenshots — NOT PROVEN.** No iOS runtime (no macOS, no Xcode, no
   simulator, no device). Nothing was mocked, upscaled from Android or generated
   to fill the folder.
2. **iPad screenshots — NOT PROVEN.** Same reason; additionally the app declares
   `TARGETED_DEVICE_FAMILY = "1,2"`, so this is a real requirement of this app and
   it remains open.
3. **The iOS build itself is NOT PROVEN** — the project exists and is configured
   portrait-only, but it has not been compiled on this machine.

## 17. Rejected assets

| Rejected | Reason |
| --- | --- |
| The 8 dark frames captured at 11:02 during the previous revision | they belong to the earlier currency revision and would have been fetched beside the new ones — deleted from the host and prevented by emptying the device folder at the start of every run |
| The earlier rupee revision of this package | the rupee must not appear anywhere in a store listing; the folder was replaced rather than merged |
| The two intermediate compose passes in this run (bands at 20.5% and 22.8%) | over Play's 20% rule; superseded by the fitted composition that is now in the package |
| A hidden tool-state folder found inside `04_SOURCE_SCREENSHOTS/` | not part of the package; removed, and the validator now fails on stray files |

## 18. Reasons

* The rejected frames were stale, not wrong: they were real captures of the same
  app in a previous currency, and shipping them beside the new set would have put
  two different moneys in one listing.
* The rejected compose passes were correct in every respect except one published
  rule; the fix was to fit the type to the rule rather than to argue about it.
* The missing iOS sets are an environment gap, and the honest response to an
  environment gap is a written-down command, not a picture.

## 19. Final risks

| Risk | Assessment |
| --- | --- |
| Play's 20% tagline rule could be read more strictly (e.g. as a share of area, or counting the brand row) | measured conservatively as band height ÷ canvas height, worst case 18.6%; the brand row is the logo, not a tagline |
| The store icon's artwork has rounded corners baked in while Play masks icons itself | it is the app's shipped icon and the brief was not to redesign it; Play's mask crops only the corner padding, which is transparent |
| The add-debt slide shows the form empty | it is the real opening state; staged typing was deliberately avoided |
| One currency per listing means the multi-currency grouping is not shown | deliberate: consistent listings over one extra feature |
| The dataset is dated relative to "today" | due dates are computed from the capture date, so re-running the pipeline later shifts them — the screens stay internally consistent, which is what the pictures claim |
| Tablets and iPad not covered | recorded as missing; Play still publishes the phone listing, App Store Connect will require the iPad set |

## 20. Final acceptance

| Asset / requirement | Status | Evidence |
| --- | --- | --- |
| Android screenshots | **PASS** | 4 runs, `All tests passed`, exit 0; 8 + 8 frames per language at 1080 × 2400 in `04_SOURCE_SCREENSHOTS/ANDROID/` |
| iPhone screenshots | **NOT PROVEN** | no iOS runtime; `02_APP_STORE/NOT_PRODUCED.md`, `04_SOURCE_SCREENSHOTS/IOS/NOT_CAPTURED.md` |
| iPad screenshots | **NOT PROVEN** | same, plus `TARGETED_DEVICE_FAMILY = "1,2"` |
| Arabic | **PASS** | full AR listing; RTL and shaping verified by eye and by the compositor's raqm shaper |
| English | **PASS** | full EN listing |
| Feature graphic | **PASS** | 1024 × 500 × 2, dimensions/format/alpha/size checked |
| Google icon | **PASS** | 512 × 512, alpha present, 288 KB < 1024 KB |
| Apple icon | **PASS** | 1024 × 1024, no alpha |
| Dimensions | **PASS** | 293/293 checks, `dimension_report.csv` |
| Alpha | **PASS** | `alpha_report.csv` — none on screenshots and feature graphics, present on the Play icon |
| File sizes | **PASS** | `file_size_report.csv` |
| Store copy | **PASS** | headlines, supporting lines and alt text for all 20 composable assets; alt ≤ 140 chars |
| Currency | **PASS** | YER (AR) / USD (EN) — on-device guard, dataset test, `currency_report.csv`; no rupee anywhere |
| Real UI fidelity | **PASS** | 18/18 at worst 0.04 mean absolute difference; every frame captured inside the running app |
| Nano Banana prompts | **PASS** | 20 prompts, one per composable asset, + `MASTER_PROMPT.md`; coverage checked by the validator |
| Manifest | **PASS** | 22 assets, `ASSET_MANIFEST.csv` / `.json`, every PNG accounted for; 293 checks, 0 failures |
| Validator | **PASS** | 293 checks, 0 failures, exit code 0, reports in `06_VALIDATION/` |
| Visual QA | **PASS** | every asset opened; 5 defects found and fixed — `FINAL_QA.md` |
| Official requirements | **PASS** with one caveat | four of five pages read on 2026-09-26; Google's feature-graphic page **NOT FETCHED** (no longer serves specifications) — recorded, nothing taken from it |
| Upload order | **PASS** | both upload orders written, file by file |
| **Overall** | **PARTIAL** | Google Play: complete and verified. App Store screenshots: NOT PROVEN — no iOS runtime on this machine; the commands that close it are in `04_SOURCE_SCREENSHOTS/IOS/NOT_CAPTURED.md` and `IPAD/NOT_CAPTURED.md` |
