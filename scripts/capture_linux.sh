#!/usr/bin/env bash
set -euo pipefail

# Run inside an Xvfb desktop session: this captures the real GTK/Flutter
# executable, not generated design artwork or a widget-test image.
OUT="${PEBBLE_CAPTURE_DIR:-build/linux-screenshots}"
mkdir -p "$OUT"
OUT="$(realpath "$OUT")"
BINARY="$(realpath build/linux/x64/release/bundle/pebble)"
export GDK_BACKEND=x11
export GDK_SCALE=1
export GDK_DPI_SCALE=1
export LIBGL_ALWAYS_SOFTWARE=1
export HOME="$(mktemp -d)"
openbox > "$OUT/window-manager.log" 2>&1 &
wm_pid=$!
"$BINARY" > "$OUT/app.log" 2>&1 &
app_pid=$!
cleanup() {
  kill "$app_pid" "$wm_pid" 2>/dev/null || true
  wait "$app_pid" "$wm_pid" 2>/dev/null || true
  rm -rf "$HOME"
}
trap cleanup EXIT

window=""
for attempt in {1..40}; do
  if ! kill -0 "$app_pid" 2>/dev/null; then
    echo "Pebble exited prematurely:"
    cat "$OUT/app.log"
    exit 1
  fi
  window="$(xdotool search --onlyvisible --name '[Pp]ebble' 2>/dev/null | tail -n 1 || true)"
  if [ -n "$window" ]; then break; fi
  sleep 1
done
if [ -z "$window" ]; then
  echo "No visible Pebble window after 40 seconds."
  cat "$OUT/app.log"
  exit 1
fi

xdotool windowsize --sync "$window" 440 940
xdotool windowmove --sync "$window" 40 35
xdotool windowactivate --sync "$window"
sleep 4
xdotool getwindowgeometry "$window" | tee "$OUT/window-geometry.txt"

capture() {
  local screen="$1"
  xdotool windowactivate --sync "$window"
  sleep 2
  scrot -u -o "$OUT/$screen.png"
  test -s "$OUT/$screen.png"
  file "$OUT/$screen.png"
}
tap() {
  xdotool mousemove --window "$window" "$1" "$2"
  xdotool click --clearmodifiers 1
  sleep 2
}

# The default UI is Home; the demo fixture is populated by --dart-define.
capture home

# Top-right + action opens the real manual form.
tap 397 54
capture add-expense
tap 28 28
capture home-return

# All tab clicks are relative to the native Flutter window.
tap 132 892
capture expenses
tap 220 892
capture scan
tap 310 892
capture insights
tap 396 892
capture settings

test "$(find "$OUT" -maxdepth 1 -name '*.png' | wc -l)" -eq 7
if cmp -s "$OUT/home-return.png" "$OUT/add-expense.png"; then
  echo "Back navigation did not close the form."
  exit 1
fi
for screen in expenses scan insights settings; do
  if cmp -s "$OUT/$screen.png" "$OUT/add-expense.png"; then
    echo "Navigation to $screen failed: the add-expense form is still visible."
    exit 1
  fi
done
if cmp -s "$OUT/expenses.png" "$OUT/insights.png"; then
  echo "Expenses and Insights were captured as the same screen."
  exit 1
fi
echo "Captured six distinct application screens and a back-navigation check."
