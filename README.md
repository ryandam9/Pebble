# Pebble

**Small records. Clear picture.**

Pebble is an offline-first personal expense and receipt tracker for Android and iOS, built with Flutter.

## Design

[![Pebble Home screen](docs/mockups/home.svg)](docs/mockups/README.md)

Explore the [five-screen mockup gallery](docs/mockups/README.md) and the [complete product specification](docs/Pebble_Design_and_Build_Specification.md).

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
