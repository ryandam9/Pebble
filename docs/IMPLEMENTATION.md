# Pebble · Flutter milestone 1

## Status

This PR implements the **first functional foundation**: Flutter screens, expense entry, SQLite persistence, month navigation, list/search/filtering, spending summaries, and optional receipt image capture.

**Not yet implemented:** OCR extraction, auto categorisation, editable expense records, database migrations, budget settings, backups/exports, cloud sync, desktop adaptations, robust receipt cleanup, and full production-hardening.

The screens use native Flutter widgets with colours, card treatments, labels and layout derived from the [five SVG mockups](mockups/README.md). They are **not pixel-for-pixel identical**: responsive layout, system text, native navigation, and missing chart/illustration details are deliberate differences. A dedicated screenshot/visual-regression pass is required before accepting a claim of visual equivalence.

## Run and verify on Linux

Pebble runs as a native **Flutter Linux GTK desktop app**. `sqflite_common_ffi` provides the SQLite database implementation used on Linux and Windows; mobile uses `sqflite`.

On Ubuntu with outbound access, from the repository root:

```bash
bash scripts/setup_linux.sh verify   # install Flutter if missing; analyze, test and build
bash scripts/setup_linux.sh          # same steps plus launch the app
```

If Flutter is already available, the script reuses it. It enables Linux desktop support, generates the Linux platform shell, runs the analyzer and tests, then builds the release binary. You can also run `flutter run -d linux` directly after setup.

For Android/iOS, generate the appropriate native platform shell. iOS setup requires macOS and Xcode:

```bash
flutter create --platforms=android,ios --project-name pebble .
flutter pub get
flutter run
```

## Automated Linux screen verification

The GitHub Actions [Flutter Linux workflow](../.github/workflows/flutter.yml) runs on Ubuntu, installs desktop libraries and Flutter, then:

1. Runs `flutter analyze` and `flutter test`, including an SQLite FFI persistence test.
2. Compiles the native Linux executable with `flutter build linux --release`.
3. Launches the **real Linux executable** inside Xvfb/Openbox using a read-only visual-demo fixture.
4. Uses actual mouse input to open Add Expense and switch between Home, Expenses, Scan, Insights and Settings.
5. Captures screenshots with `scrot`, checks navigation screenshots are distinct and uploads PNGs, logs and SVG reference designs as a workflow artifact.
6. Uploads the Linux release bundle separately.

See the [GitHub Actions runs](https://github.com/ryandam9/Pebble/actions) for downloadable screenshots and build artifacts.

**Visual acceptance status:** All six screens have been captured from Linux, but they are *not yet pixel-perfect replicas* of the SVG mockups. The current implementation uses native app typography and navigation, category charts now include a donut, and the transaction list uses compact cards. The receipt OCR review and final visual refinements are not complete. Screenshots must be reviewed against the SVGs; a green CI build proves functionality, not visual identity.

## Developer environment limitation

The authoring container cannot download the Flutter SDK or install Linux development packages because its outbound DNS is blocked. The GitHub Actions Ubuntu runner supplies the installation, native compilation, live execution and screenshots instead. The local setup script is provided for reproducing the same checks on an ordinary Linux machine.

## Storage

The app saves positive integer cents, never floating-point currency. `SqliteExpenseStore` uses `getDatabasesPath()/pebble.sqlite`. Photos are copied into the app's private documents directory under `receipts/` and their current absolute paths are saved in the database.

**Known limitation:** A full backup/restore must later replace absolute paths with stable relative paths and include receipt files. Removing an attachment from the draft currently leaves the copied image behind. Receipt cleanup should be added with record lifecycle management.

## Scanning

The Scan action currently launches the camera and attaches the captured image to the entry form. The user types the amount, date and description. It does **not** read OCR text yet. The UI states this explicitly.

## Product checks

- Install, add a `$48.75` grocery expense, restart, verify it persists.
- Select the prior month, navigate back, verify filters and sums.
- Attach a camera image and save; open the expense and view the photo.
- Try blank descriptions, zero amounts, and three decimal places; validate rejection.
- Deny camera/photos permissions and verify an error is shown.
- Verify light theme, screen-reader labels, keyboard entry, landscape and narrow screens.
- Verify Android back handling and empty states.
