# Pebble

**Small records. Clear picture.**

Pebble is an offline-first personal expense and receipt tracker for Android and iOS, built with Flutter.

## Design

[![Pebble Home screen](docs/mockups/home.svg)](docs/mockups/README.md)

Explore the [five-screen mockup gallery](docs/mockups/README.md) and the [complete product specification](docs/Pebble_Design_and_Build_Specification.md).

## Launcher icon

![Pebble watercolor icon](assets/launcher/pebble_icon.png)

Pebble uses the **stacked watercolor pebbles** icon on Android and iOS. [See icon assets and build instructions](docs/LAUNCHER_ICON.md).

## Flutter MVP

- Native Flutter UI based on the five approved Pebble screen mockups.
- Manual entry, edit and delete; amounts stored as integer cents in local Drift/SQLite.
- Optional photo attachments in private on-device storage.
- Expense search, monthly history, category filters, spending insights.
- Receipt capture/gallery import and on-device OCR, followed by editable field review and explicit save confirmation.
- No bank connection or backend required.

## Build and run

Install the Flutter stable SDK and Android/iOS tooling. Then:

~~~bash
bash scripts/bootstrap.sh
flutter run
~~~

The bootstrap generates Flutter Android/iOS native templates and Drift code. Platform files are not yet committed; consult the [implementation notes](docs/IMPLEMENTATION_STATUS.md) before native release.

**After pulling changes that modify `lib/data/pebble_database.dart`, regenerate Drift's model before running Flutter.** The generated `lib/data/pebble_database.g.dart` is intentionally ignored by Git; an older local copy will not automatically be replaced by `git pull`:

~~~bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter run
~~~

Alternatively, run `bash scripts/bootstrap.sh` again. Errors such as `No named parameter 'categoryId'` or `The getter 'categoryId' isn't defined for ExpenseEntry` indicate that the generated model is stale. **Do not delete `pebble.sqlite` or clear app data** to solve this; the v4 migration preserves existing expenses.

## Quality checks

~~~bash
dart format lib test
flutter analyze
flutter test
~~~

GitHub Actions also runs analysis and tests.

## Docs

- [Product Design & Build Specification](docs/Pebble_Design_and_Build_Specification.md)
- [UI mockups](docs/mockups/README.md)
- [Implementation status, limitations, setup](docs/IMPLEMENTATION_STATUS.md)

**Status:** Working-source MVP pending CI and device validation. Pixel-perfect mockup parity and native production readiness have not yet been confirmed.
