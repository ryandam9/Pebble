# Pebble · Flutter milestone 1

## Status

This PR implements the **first functional foundation**: Flutter screens, expense entry, SQLite persistence, month navigation, list/search/filtering, spending summaries, and optional receipt image capture.

**Not yet implemented:** OCR extraction, auto categorisation, editable expense records, database migrations, budget settings, backups/exports, cloud sync, desktop adaptations, robust receipt cleanup, and full production-hardening.

The screens use native Flutter widgets with colours, card treatments, labels and layout derived from the [five SVG mockups](mockups/README.md). They are **not pixel-for-pixel identical**: responsive layout, system text, native navigation, and missing chart/illustration details are deliberate differences. A dedicated screenshot/visual-regression pass is required before accepting a claim of visual equivalence.

## Run locally

Requires the Flutter stable SDK, Android development toolchain, and (for iOS) macOS + Xcode.

The repository does not yet commit Flutter-generated Android/iOS scaffolding. Generate these once with:

```bash
flutter create --platforms=android,ios --project-name pebble .
flutter pub get
flutter run
```

On Linux, use `--platforms=android`. For tests:

```bash
flutter analyze
flutter test
```

The CI workflow generates the Android platform shell and runs analyzer and unit/widget tests.

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
