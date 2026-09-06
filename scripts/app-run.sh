#!/usr/bin/env bash
# Runs the Flutter app against the local API.
# Pass a device: ./app-run.sh <device-id>   (see: flutter devices)
set -e
source "$(dirname "$0")/env.sh"
cd "$SANGAM_ROOT/sangam_app"

# An Android emulator reaches the host at 10.0.2.2, not 127.0.0.1.
BASE="${API_BASE_URL:-}"
if [ -z "$BASE" ]; then
  case "${1:-}" in
    emulator*|android*) BASE="http://10.0.2.2:4000" ;;
    *)                  BASE="http://127.0.0.1:4000" ;;
  esac
fi

# DEMO=1 pins the app to the seeded demo device so Home and My reports have
# something in them. Unset, the app mints its own ID like a real phone would.
DEFINES=(--dart-define=API_BASE_URL="$BASE")
if [ "${DEMO:-0}" = "1" ]; then
  DEFINES+=(--dart-define=DEVICE_ID=00000000-0000-4000-8000-000000000001)
  echo "DEMO device pinned"
fi

echo "API_BASE_URL=$BASE"
if [ -n "${1:-}" ]; then
  flutter run -d "$1" "${DEFINES[@]}"
else
  flutter run "${DEFINES[@]}"
fi
