#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter SDK is required: https://docs.flutter.dev/get-started/install' >&2
  exit 1
fi
# This initial development PR keeps native Flutter templates generated on demand.
# Platform files will be committed after Android/iOS integration is validated.
flutter create --project-name pebble --org au.com.pebble --platforms=android,ios --no-pub .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
echo 'Pebble initialised. Run: flutter run'
