#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter SDK is required: https://docs.flutter.dev/get-started/install' >&2
  exit 1
fi
# This initial development PR keeps native Flutter templates generated on demand.
# Platform files will be committed after Android/iOS integration is validated.
python3 scripts/check_launcher_assets.py
python3 scripts/fetch_fonts.py
flutter create --project-name pebble --org au.com.pebble --platforms=android,ios,linux --no-pub .
python3 scripts/configure_native.py
flutter pub get
# Generated platform directories are ignored by git; always apply launcher art
# after flutter create so a fresh checkout never displays the stock Flutter icon.
dart run flutter_launcher_icons
dart run build_runner build --delete-conflicting-outputs
echo 'Pebble initialised. Run: flutter run'
