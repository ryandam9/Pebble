#!/usr/bin/env bash
set -euo pipefail

# Run from the Pebble repository root on Ubuntu or another Debian-based Linux.
# Usage:
#   bash scripts/setup_linux.sh         # install, build, and launch the desktop app
#   bash scripts/setup_linux.sh verify  # install, analyze, test, build (no launch)
#
# Requires outbound access to GitHub, Flutter downloads and pub.dev.

sudo apt-get update
sudo apt-get install -y \
  curl git unzip xz-utils zip libglu1-mesa \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libsqlite3-dev libsecret-1-dev

if command -v flutter >/dev/null 2>&1; then
  echo "Using existing Flutter: $(command -v flutter)"
else
  flutter_dir="${FLUTTER_INSTALL_DIR:-$HOME/.local/share/flutter}"
  mkdir -p "$(dirname "$flutter_dir")"
  if [ ! -d "$flutter_dir/.git" ]; then
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$flutter_dir"
  fi
  export PATH="$flutter_dir/bin:$PATH"
  echo "Flutter added to PATH for this shell: $flutter_dir/bin"
fi

flutter config --enable-linux-desktop
flutter doctor -v
flutter create --platforms=linux --project-name pebble .
flutter pub get
flutter analyze
flutter test
flutter build linux --release

if [ "${1:-run}" != "verify" ]; then
  flutter run -d linux
fi
