#!/usr/bin/env bash
# Runs the store capture on a device and pulls the frames to the host.
#
#   DH_OUT=<folder> tool/store_capture/run_capture.sh <device> <ar|en> [light|dark] [screens] [currency]
#
# Example — the full Arabic set in Yemeni riyals from a booted emulator:
#   tool/store_capture/run_capture.sh emulator-5556 ar light "" yer
#
# The currency is `usd` or `yer` (default usd). The capture refuses anything
# else, so a listing can never be photographed in another money.
#
# DH_OUT names the asset folder the captures land in (default
# DHIMMAH_STORE_ASSETS), so a second revision — a different currency, say — can
# be produced beside the first without touching it.
#
# The screens are captured inside the app (see
# integration_test/store_capture_test.dart) and written to the app's own
# documents directory. `flutter test` removes the app when it finishes — and the
# captures with it — so the run goes through `flutter drive --keep-app-running`,
# which leaves the app installed, and the frames are fetched from there with
# `run-as` (the capture build is debuggable). Nothing on the phone outside the
# app's own container is read.
set -uo pipefail

DEVICE="${1:?usage: run_capture.sh <device> <ar|en> [light|dark] [only] [currency]}"
LANG="${2:?usage: run_capture.sh <device> <ar|en> [light|dark] [only] [currency]}"
THEME="${3:-light}"
ONLY="${4:-}"
CURRENCY="${5:-usd}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PKG="com.dhimmah.dhimmah"
OUT_DIR="${DH_OUT:-DHIMMAH_STORE_ASSETS}"
LANGDIR="$(echo "$LANG" | tr '[:lower:]' '[:upper:]')"
DEST="$ROOT/$OUT_DIR/04_SOURCE_SCREENSHOTS/ANDROID/$LANGDIR"

mkdir -p "$DEST"

echo "== capturing ($LANG/$THEME/$CURRENCY) on $DEVICE -> $OUT_DIR"
cd "$ROOT"
# A permission prompt is a system dialog, and a system dialog in a store
# screenshot is a defect: the frame must contain the app and nothing else. The
# grant is safe to fail — on a device that does not have the app yet there is
# nothing to grant, and the run that installs it is the one to repeat.
adb -s "$DEVICE" shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS \
  2>/dev/null || true

# Each run starts from an empty capture folder on the device. A frame left over
# from an earlier revision — another currency, say — must not be fetchable by a
# later run that happens not to overwrite it, so the fetch below can only ever
# bring home frames this run wrote.
adb -s "$DEVICE" shell run-as "$PKG" rm -rf app_flutter/store_capture \
  2>/dev/null || true
DEFINES=(--dart-define="STORE_LANG=$LANG" --dart-define="STORE_THEME=$THEME"
         --dart-define="STORE_CURRENCY=$CURRENCY")
[ -n "$ONLY" ] && DEFINES+=(--dart-define="STORE_ONLY=$ONLY")
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/store_capture_test.dart \
  -d "$DEVICE" \
  --keep-app-running \
  "${DEFINES[@]}"
STATUS=$?
echo "== capture exit: $STATUS"

echo "== fetching to $DEST"
adb -s "$DEVICE" exec-out run-as "$PKG" sh -c \
  "cd app_flutter/store_capture && tar -cf - $LANG" > /tmp/dhimmah_capture.tar
tar -xf /tmp/dhimmah_capture.tar -C "$DEST" --strip-components=1
rm -f /tmp/dhimmah_capture.tar

# The frames are named after their screen; the language is added here, so a file
# carries both wherever it is later copied. Idempotent: a frame that already has
# its language is left alone.
for frame in "$DEST"/*.png; do
  case "$frame" in
    *_"$LANG".png) ;;
    *) mv "$frame" "${frame%.png}_$LANG.png" ;;
  esac
done

echo "== files"
ls -l "$DEST"
exit $STATUS
