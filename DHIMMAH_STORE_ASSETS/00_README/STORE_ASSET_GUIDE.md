# What is in this package, and how it was made

## The one rule

**Every screenshot is a photograph of the real app.** The frames were captured
inside the running application on an Android emulator, at the device's own pixel
ratio, from a demonstration ledger written through the app's real service layer.
The compositor scales a frame and places it on a page; it never redraws a button,
a number, a name or a line of text. If a figure is in these images, the app drew
it.

## Folder map

| Folder | What is in it |
| --- | --- |
| `00_README/` | requirements (with sources and dates), this guide, both upload orders, the final QA and the asset manifest |
| `01_GOOGLE_PLAY/PHONE_AR/` | 8 finished Arabic phone screenshots, 1080 × 1920, ready to upload in numbered order |
| `01_GOOGLE_PLAY/PHONE_EN/` | 8 finished English phone screenshots, same canvas and order |
| `01_GOOGLE_PLAY/PHONE_*/ALTERNATES/` | the dark dashboard, as an extra slide — not part of the numbered set |
| `01_GOOGLE_PLAY/FEATURE_GRAPHIC_AR/`, `..._EN/` | the 1024 × 500 banner for each language |
| `02_APP_STORE/` | empty by design — see `NOT_PRODUCED.md` |
| `03_ICONS/GOOGLE_PLAY/` | 512 × 512, 32-bit PNG with alpha (Play asks for alpha, ≤ 1024 KB) |
| `03_ICONS/APPLE/` | 1024 × 1024 PNG, no alpha |
| `04_SOURCE_SCREENSHOTS/ANDROID/AR|EN/` | the raw frames, untouched, 8 light + 8 dark per language |
| `04_SOURCE_SCREENSHOTS/IOS|IPAD/` | empty by design — see the `NOT_CAPTURED.md` in each |
| `05_NANO_BANANA_PROMPTS/` | one prompt per produced asset, plus `MASTER_PROMPT.md` |
| `06_VALIDATION/` | every check, its result, the source-fidelity report, contact sheets, the build record and the final report |

## The ledger in the pictures

| | Arabic listing | English listing |
| --- | --- | --- |
| Currency | Yemeni riyal (YER, ﷼) | US dollar (USD, $) |
| People | 5 (أحمد محمد، خالد العلي، محمد صالح، علي حسن، مكتب المحاسبة) | 5 (Ahmed Mohammed, Khalid Al-Ali, Mohammed Saleh, Ali Hassan, Accounting Office) |
| Records | 8 | 8 |
| Flagship | سلفة: 375,000 borrowed, 125,000 repaid, 250,000 left | Advance: $1,500 borrowed, $500 repaid, $1,000 left |
| One record, two people | مصاريف مشتركة (محمد صالح + علي حسن) | Shared expenses (Mohammed Saleh + Ali Hassan) |
| Recurring | 4 monthly commitments, one period paid | same |
| Reminders | 3 | 3 |

All names and amounts are fictional. The same story is told in both languages so
the two listings are the same product seen twice, not two different products.

## Why the composition looks the way it does

* **Portrait only.** The app is portrait-locked; a landscape listing would be a
  promise the product does not keep.
* **The screenshot is never cropped**, only scaled, and it keeps its own colours
  and its own theme.
* **The marketing text is drawn by the compositor**, in the app's own font (IBM
  Plex Sans Arabic from `assets/fonts`), with real Arabic shaping and RTL. No
  image model ever writes the Arabic in these files, which is the only way to
  guarantee it is spelled correctly.
* **The page palette is the app's palette** (`#F7F5F2` paper, `#1C1917` ink), so
  the listing looks like the product rather than like a template.
* **No invented UI, no invented numbers, no ratings, no awards, no "as seen in".**
  The pictures show a ledger and the screens that manage it, and nothing else.

## Re-running the pipeline

```bash
# 1. capture from the running app (per language, theme and currency)
./tool/store_capture/run_capture.sh emulator-5556 ar light "" yer
./tool/store_capture/run_capture.sh emulator-5556 en light "" usd
./tool/store_capture/run_capture.sh emulator-5556 ar dark  "" yer
./tool/store_capture/run_capture.sh emulator-5556 en dark  "" usd

# 2. compose the store canvases, prompts and icons
python3 tool/store_capture/compose_assets.py
python3 tool/store_capture/generate_prompts.py

# 3. validate everything, write the manifests and the contact sheets
python3 tool/validate_store_assets.py

# 4. the dataset's own contract (amounts, people, no rupee)
flutter test test/tool/store_dataset_test.dart
```

`DH_OUT=<folder>` moves the whole output to another folder, so a second revision
(a different currency, say) can be built beside this one without touching it.
