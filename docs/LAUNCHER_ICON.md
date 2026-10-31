# Pebble · app launcher icon

![Watercolor stacked pebbles](../assets/launcher/pebble_icon.png)

This is **option 1** from the approved icon concepts: three watercolor pebbles stacked beside a leafy sprig. No text is embedded in the launcher artwork; the OS displays the application name separately.

## Platform artwork

| Asset | Purpose |
|---|---|
| `assets/launcher/pebble_icon.png` | Opaque, square **1024 × 1024** artwork for Android legacy and iOS AppIcon |
| `assets/launcher/pebble_adaptive_foreground.png` | Transparent 1024 × 1024 artwork inset for Android adaptive icon masks |
| `assets/launcher/pebble_monochrome.png` | Transparent black silhouette for Android 13+ themed launcher icons |

Android adaptive background colour: `#FFFBF3` (watercolor paper). The icon also remains legible against light and dark launcher backgrounds.

## Generate the actual installed icons

Pebble deliberately does **not commit generated Android/iOS platform directories**. Running its existing setup will therefore create the native directories **and then install Pebble's launcher icons**:

```bash
bash scripts/bootstrap.sh
flutter run
```

To regenerate after editing artwork:

```bash
flutter pub get
dart run flutter_launcher_icons
```

The `flutter_launcher_icons` configuration is in `pubspec.yaml`. It generates the Android mipmap densities, the Android 8+ adaptive foreground/background and Android 13+ monochrome layers, and the iOS AppIcon sizes. iOS output is opaque.

On an existing app installation, the home-screen icon can be cached by the launcher; a reinstall or clearing launcher icon cache may be required to see the updated version. On Linux, the PNG master can be used by distribution packagers, but this setup targets **Android and iOS installed launchers**; it does not create a Linux `.desktop` installer entry.

The icon artwork is stored locally in the repository, so no icon-generation service or external image download is required during builds.
