# NOT CAPTURED — no iPadOS runtime on this machine

**Status: NOT PROVEN.** This folder is intentionally empty of images.

## Why it is on the list at all

The app declares `TARGETED_DEVICE_FAMILY = "1,2"` in `ios/Runner.xcodeproj`, so
it runs on iPad, and App Store Connect's screenshot specification says the 13″
iPad size (2064 × 2752 or 2048 × 2732 pixels) is "Required if app runs on iPad".
That is a real requirement of this app, not an optional extra.

## What was verified

| Check | Result |
| --- | --- |
| `TARGETED_DEVICE_FAMILY` | `1,2` — iPhone and iPad |
| Supported orientations (iOS) | portrait only, all three iPhone/iPad portrait keys |
| iPad simulator available | no — no macOS, no Xcode |
| Physical iPad connected | no |

## What closes it

```bash
# On a Mac with Xcode:
xcrun simctl boot "iPad Pro 13-inch (M4)"
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/store_capture_test.dart \
  -d "iPad Pro 13-inch (M4)" --keep-app-running \
  --dart-define=STORE_LANG=ar --dart-define=STORE_THEME=light \
  --dart-define=STORE_CURRENCY=yer
# then the same for en/usd, and compose onto 2064 × 2752.
```

The same test, the same screens, the same portrait-only rule: the iPad set is not
a different story, it is the same story at another size.

## Android tablets

Google Play also accepts a large-screen set (minimum 4 screenshots, 1080–7680 px,
9:16 portrait). None was produced this round either, although the Android
emulator could run one — recorded as missing rather than as done. Producing it
means creating a tablet AVD and re-running the same four commands with that
device:
`tool/store_capture/run_capture.sh <tablet-serial> ar light "" yer`.
