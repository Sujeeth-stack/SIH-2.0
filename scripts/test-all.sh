#!/usr/bin/env bash
# Analyzer + the whole Flutter test suite. The e2e tests skip themselves
# when the API is not running.
set -e
source "$(dirname "$0")/env.sh"
cd "$SANGAM_ROOT/sangam_app"
flutter analyze
flutter test
