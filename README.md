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

### Development database (fresh install only)

Pebble is not yet in production, so the SQLite schema is maintained as a **fresh-install schema, version 1**. There are **no database migrations**. New installs create the `expense_entries.category_id` foreign key directly, seed default categories and enable SQLite foreign-key enforcement.

If you installed an older development build, **back up anything you want to keep, then reset its local `pebble.sqlite` file or clear the app's local data** before running the new build. Only do this if you are certain there is no data to preserve. Updating Dart source or rerunning `bootstrap.sh` does **not** delete an older database.

After a schema change regenerate Drift's ignored `.g.dart` file:

~~~bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
~~~

A stale generated model may report missing `categoryId` getters or parameters. Regenerating code fixes that compilation issue; resetting an old empty database addresses the independent **on-disk schema** mismatch.


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
