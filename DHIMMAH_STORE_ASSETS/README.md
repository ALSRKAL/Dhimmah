# ذِمّة — Dhimmah store assets

**Upload from `01_GOOGLE_PLAY/`.** Everything there is finished, sized to the
stores' published requirements, and numbered in the order a visitor should read
it.

## The 60-second path

1. Open `00_README/GOOGLE_PLAY_UPLOAD_ORDER.md` and upload `PHONE_AR/` (8 files)
   and `PHONE_EN/` (8 files) in the numbered order, pasting the alt text given
   for each.
2. Upload `FEATURE_GRAPHIC_AR/feature_graphic_ar_1024x500.png` and
   `FEATURE_GRAPHIC_EN/feature_graphic_en_1024x500.png`.
3. Upload `03_ICONS/GOOGLE_PLAY/icon_512x512.png` as the store icon.
4. Optionally check the set against `06_VALIDATION/contact_sheets/…png`.

Read `06_VALIDATION/FINAL-STORE-ASSETS-REPORT.md` for what is proven, what is
not, and why.

## The ledger in the pictures

| | Arabic listing | English listing |
| --- | --- | --- |
| Currency | **Yemeni riyal** — YER, ﷼ | **US dollar** — USD, $ |
| Flagship record | سلفة 375,000 ﷼ · مدفوع 125,000 · متبقٍ 250,000 | Advance $1,500 · paid $500 · remaining $1,000 |

Both were photographed from the running app with the same dataset, built through
the app's own service layer. All names and amounts are fictional.

## Honesty rules this package follows

* Every screenshot is a photograph of the real app. Nothing is drawn, mocked,
  upscaled from another platform or invented.
* The rupee appears nowhere: the captures are guarded on the device, and the rest
  of the package is scanned — see `06_VALIDATION/currency_report.csv`.
* Portrait only, because the app is portrait-locked.
* If something was not produced, it is not in here. `02_APP_STORE/` is empty and
  says so, with the exact commands that would fill it.

## What is missing

| Missing | Why |
| --- | --- |
| iPhone screenshots (8 AR + 8 EN) | no macOS / Xcode / iOS runtime on this machine — **NOT PROVEN**, commands ready in `04_SOURCE_SCREENSHOTS/IOS/NOT_CAPTURED.md` |
| iPad screenshots (8 AR + 8 EN) | same, and required because the app targets iPad — see `04_SOURCE_SCREENSHOTS/IPAD/NOT_CAPTURED.md` |
| Android tablet screenshots | not attempted this round; the same harness runs on a tablet emulator |
| App preview videos | none produced |
| Store listing text (title, short description) | not part of this package |

## Map

```
00_README/          requirements with sources and dates, guide, upload orders, QA, manifest
01_GOOGLE_PLAY/     PHONE_AR, PHONE_EN, FEATURE_GRAPHIC_AR, FEATURE_GRAPHIC_EN
02_APP_STORE/       empty on purpose — NOT_PRODUCED.md explains
03_ICONS/           GOOGLE_PLAY/icon_512x512.png, APPLE/icon_1024x1024.png
04_SOURCE_SCREENSHOTS/   the raw frames, untouched, per platform and language
05_NANO_BANANA_PROMPTS/  one prompt per asset + MASTER_PROMPT.md
06_VALIDATION/      every check and its result, contact sheets, the final report
```

## Rebuilding it

```bash
./tool/store_capture/run_capture.sh emulator-5556 ar light "" yer
./tool/store_capture/run_capture.sh emulator-5556 en light "" usd
./tool/store_capture/run_capture.sh emulator-5556 ar dark  "" yer
./tool/store_capture/run_capture.sh emulator-5556 en dark  "" usd
python3 tool/store_capture/compose_assets.py
python3 tool/store_capture/generate_prompts.py
python3 tool/validate_store_assets.py
flutter test test/tool/store_dataset_test.dart
```

`DH_OUT=<folder>` sends the whole output somewhere else, so another currency can
be produced beside this one without touching it.
