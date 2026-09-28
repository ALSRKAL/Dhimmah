# App Store — upload order

## Status first: there are no iPhone or iPad screenshots in this package

**NOT PROVEN.** No iOS runtime exists on the machine that built this package (no
macOS, no Xcode, no simulator, no device), so no App Store screenshot was
produced. `02_APP_STORE/` is empty on purpose; see `NOT_PRODUCED.md` there and
`../04_SOURCE_SCREENSHOTS/IOS/NOT_CAPTURED.md` for the verification and the exact
commands that close the gap.

The icon **is** produced: `03_ICONS/APPLE/icon_1024x1024.png`.

## What can be uploaded today

| Field in App Store Connect | File | Notes |
| --- | --- | --- |
| App icon (1024 × 1024) | `03_ICONS/APPLE/icon_1024x1024.png` | no alpha, the shipped artwork |
| iPhone 6.9″ screenshots | — | **not produced** (needs a Mac; sizes: 1320 × 2868, 1290 × 2796 or 1260 × 2736) |
| iPad 13″ screenshots | — | **not produced** (required because the app targets iPad; sizes: 2064 × 2752 or 2048 × 2732) |
| App previews (video) | — | none |

## The order to fill the screens when the Mac is available

The same eight-screen story as the Play listing, in the same order, so the two
stores read identically:

| # | Screen | Capture key | What it shows |
| --- | --- | --- | --- |
| 1 | Dashboard | `01_dashboard` | what you owe and what you're owed |
| 2 | Add debt | `02_add_debt` | the add form |
| 3 | People | `03_people` | every person and their balance |
| 4 | Debt detail | `04_debt_detail` | paid and remaining on one record |
| 5 | Obligations | `05_obligations` | the recurring month |
| 6 | Ledger | `06_ledger` | the whole ledger |
| 7 | Backup | `08_backup` | backup and export |
| 8 | Reports | `07_reports` | the monthly statement |

Alt text: the same strings as the Play listing, in
`GOOGLE_PLAY_UPLOAD_ORDER.md` — the screens are the same, so the descriptions are
the same.

## Then

```bash
# Arabic (Yemeni riyal) and English (US dollar), 6.9-inch and 13-inch iPad
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/store_capture_test.dart \
  -d "iPhone 16 Pro Max" --keep-app-running \
  --dart-define=STORE_LANG=ar --dart-define=STORE_THEME=light \
  --dart-define=STORE_CURRENCY=yer
# … four runs per device size, exactly as Android was captured
```

Compose onto 1320 × 2868 (iPhone) and 2064 × 2752 (iPad), PNG with no alpha,
1–10 screenshots per size and language. Apple's published numbers are in
`STORE_REQUIREMENTS.md` with the page each one came from.
