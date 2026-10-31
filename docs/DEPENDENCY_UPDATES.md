# Dependency updates — Pebble

Last checked: 31 October 2026 (Flutter stable / Dart 3.12 minimum).

## Current direct packages

Pebble's direct application and development dependencies are already on the
latest **stable** published version, or their caret constraints permit it.
The two minimum versions in `pubspec.yaml` that lagged their resolved
`pubspec.lock` versions were updated here:

| Package | Old minimum | New minimum | Already locked |
| --- | --- | --- | --- |
| `intl` | `^0.20.2` | `^0.20.3` | `0.20.3` |
| `build_runner` | `^2.16.2` | `^2.17.1` | `2.17.1` |

Other direct packages (including Drift, ML Kit, geolocator, shared_preferences,
and the existing Flutter launcher generator) were checked against their
latest releases and left unchanged.

## What the "18 packages have newer versions incompatible..." message means

That list consists of **indirect/transitive** dependencies pulled in by
Flutter, code-generation tools, desktop plugins, or other packages.
An available higher major version does not mean Pebble can safely demand it.
For example, `built_collection` 6.x, `cross_file` 0.4.x and
`sqlite3` 3.8.x need their upstream dependents' constraints to agree.
Some packages are version-pinned by the Flutter SDK itself.

Do not add `dependency_overrides` simply to silence this informational
message: forcing a major version can break code generation, the Android
build, Linux plugins or existing SQLite data.

Use the following workflow to check and apply *resolvable* updates:

```bash
flutter pub outdated --transitive
flutter pub upgrade
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --debug
```

**When changing a direct major version**, review the dependency's changelog,
then test the Android and Linux application. The guarded alternative
`flutter pub upgrade --major-versions --dry-run` reports proposed changes
without modifying the project. Only apply major upgrades on their own branch.

A checked-in `pubspec.lock` is deliberate for this application; the same
resolved versions are used by CI and local builds. If an upgrade changes
`pubspec.lock`, commit it alongside the reviewed `pubspec.yaml` change.

## Ongoing maintenance

`.github/dependabot.yml` checks Dart/Pub and GitHub Actions weekly.
Compatible minor and patch updates are grouped into reviewable pull requests.
Major updates are separate and are **not automatically merged**.
Each update must pass Flutter analysis, widget/unit tests, and the Android
APK build before merging.

Drift model changes also require regenerating
`lib/data/pebble_database.g.dart` with `build_runner`.
Never delete an existing `pebble.sqlite` database to fix generated-code
errors: existing user expenses must survive schema migrations.
