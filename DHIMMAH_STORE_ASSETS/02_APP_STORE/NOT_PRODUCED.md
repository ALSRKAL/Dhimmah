# App Store screenshots — NOT PRODUCED

**Status: NOT PROVEN.**

This folder (`IPHONE_AR/`, `IPHONE_EN/`, `IPAD_AR/`, `IPAD_EN/`) is intentionally
empty. Not one image in this package was produced from a running iOS app, because
no iOS runtime exists on the machine that built this package.

## Why

| Requirement | Available here |
| --- | --- |
| macOS | no (Linux host) |
| Xcode / `xcrun simctl` | no |
| iPhone or iPad simulator | no |
| A physical iPhone or iPad | no |
| The Flutter iOS project itself | **yes** — the harness would run unchanged |

## What is proven instead

* iPhone 6.9″ screenshots must be **1320 × 2868** (or one of the other published
  sizes) and iPad 13″ **2064 × 2752** — read from Apple's own specification page
  on 2026-09-26, see `../00_README/STORE_REQUIREMENTS.md`.
* The app is portrait-only on iOS and targets both iPhone and iPad.
* The Android set in `../01_GOOGLE_PLAY/` is a real capture of the same screens,
  from the same build, with the same dataset — but it is **not** an App Store
  screenshot and is not offered as one.

## What closes it

The exact commands are in `../04_SOURCE_SCREENSHOTS/IOS/NOT_CAPTURED.md` and
`../04_SOURCE_SCREENSHOTS/IPAD/NOT_CAPTURED.md`. They are copy-paste ready and
use the same integration test that produced the Android frames, so no new
harness has to be written on the Mac.

## What was deliberately not done

* No Android screenshot relabelled as an iPhone screenshot.
* No 1320 × 2868 canvas with an Android frame pasted into it.
* No model-generated "iPhone mockup" of the app.
