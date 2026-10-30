# Pebble Flutter MVP — implementation status

**30 October 2026**

## Implemented

- Flutter application with Australian locale, matching Pebble palette and five bottom navigation destinations.
- Reactive Drift/SQLite store; amounts stored as integer cents.
- Manual expense creation, editing, deletion, validation and optional receipt attachments saved in private application storage.
- Monthly transaction history, category filters and search.
- Real monthly spending dashboard and Insights charts, without fake example transactions.
- Camera/gallery image selection, on-device OCR (Google ML Kit), editable detected fields and human confirmation before saving.
- Tests covering amounts, OCR parsing, database persistence and the manual entry UI.

## Not yet finished

- Exact pixel parity against the five SVG references **has not been verified**. The Flutter UI follows the tokens and layout but is a native responsive implementation rather than a static reproduction of the SVG.
- No locally executed Flutter build was possible in the author's environment. The GitHub workflow is intended to run analysis and tests.
- Full backup/restore, CSV export, adjustable budgets, receipt cropping/rotation, and duplicate detection are later milestones.
- Native platform scaffolds and generated Drift code are created by the bootstrap script and should be reviewed and committed before release.
- iOS ML Kit integration requires a deployment target of at least 15.5, camera and photo library usage strings, and compatible Xcode/Swift.
- Android native projects must be checked for ML Kit compile SDK requirements and camera/gallery permissions. Verify on physical devices.

## Developer setup

Install Flutter (stable) with Android or iOS toolchain:

~~~bash
bash scripts/bootstrap.sh
flutter analyze
flutter test
flutter run
~~~

The bootstrap script generates the Android/iOS native directories (ignored in this milestone), installs dependencies and runs Drift code generation.

## Design mapping

| Design | Flutter implementation |
| --- | --- |
| [Home](mockups/home.svg) | lib/ui/screens/home_screen.dart |
| [Add expense](mockups/add-expense.svg) | lib/ui/screens/editor_screen.dart |
| [Scan receipt](mockups/scan-receipt.svg) | lib/ui/screens/receipt_screen.dart |
| [Expenses](mockups/expenses.svg) | lib/ui/screens/expenses_screen.dart |
| [Insights](mockups/insights.svg) | lib/ui/screens/insights_screen.dart |

Mockup SVGs include a decorative phone frame. The Flutter app renders the interactive screen content inside actual device safe areas.
