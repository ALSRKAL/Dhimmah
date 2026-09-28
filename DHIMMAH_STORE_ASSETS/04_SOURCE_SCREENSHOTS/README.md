# Source screenshots

The raw frames, exactly as the app drew them. **Nothing here is edited.** Every
composed store image in `../01_GOOGLE_PLAY/` is one of these files scaled and
placed on a page — no pixel inside the card is retouched.

## Android — captured

| Folder | Files | Ledger |
| --- | --- | --- |
| `ANDROID/AR/` | 8 light + 8 dark (`*_dark.png`) | Yemeni riyal (﷼), Arabic UI |
| `ANDROID/EN/` | 8 light + 8 dark (`*_dark.png`) | US dollar ($), English UI |

Size: 1080 × 2400 each (the emulator's own screen; the store canvases are
1080 × 1920). Files are named `<screen>_<lang>.png`, and a dark frame adds
`_dark`: `01_dashboard_ar.png`, `01_dashboard_dark_ar.png`,
`01_dashboard_en.png`, `01_dashboard_dark_en.png`.

| Key | Screen | How it is reached in the app |
| --- | --- | --- |
| `01_dashboard` | Dashboard | the screen the app opens on |
| `02_add_debt` | Add debt | the floating button, then "money I owe" in the add sheet |
| `03_people` | People | bottom bar, "الأشخاص" / "People" |
| `04_debt_detail` | A debt with a payment | bottom bar "السجل" / "Ledger", then the «سلفة» / "Advance" row |
| `05_obligations` | Obligations | bottom bar, "الالتزامات" / "Obligations" |
| `06_ledger` | Ledger | bottom bar, "السجل" / "Ledger" |
| `07_reports` | Reports | pushed from the dashboard's reports entry |
| `08_backup` | Backup and restore | pushed from the dashboard's backup entry |

## How they were taken

`integration_test/store_capture_test.dart`, run through
`tool/store_capture/run_capture.sh`:

```bash
./tool/store_capture/run_capture.sh emulator-5556 ar light "" yer
./tool/store_capture/run_capture.sh emulator-5556 en light "" usd
./tool/store_capture/run_capture.sh emulator-5556 ar dark  "" yer
./tool/store_capture/run_capture.sh emulator-5556 en dark  "" usd
```

The test wipes the app's database, seeds the demonstration ledger through the
real `LedgerService`, starts the real app, walks to each screen the way a person
would, and writes the rendered frame at the device's native pixel ratio from
inside the app. Before a frame is written it refuses to continue if the rendered
locale is not the requested one, if the stored theme is not the requested one, if
the ledger's currency is not the requested one, or if the rupee appears anywhere
on screen.

## iOS and iPad — not captured

See `IOS/NOT_CAPTURED.md` and `IPAD/NOT_CAPTURED.md`. No iOS or iPadOS runtime
exists on this machine (Linux, no macOS, no Xcode, no simulator). Nothing was
faked to fill the folders.
