import 'dart:io';

/// The Google Maps Platform key, passed in at build time from the untracked
/// `secrets.json` (`--dart-define-from-file=secrets.json`). Empty when the
/// app is built without it; callers then fall back to free services.
const googleMapsKey = String.fromEnvironment('PLACES_API_KEY');

/// SHA-1 of the certificate the APK is signed with.
const _signingSha1 = String.fromEnvironment('PLACES_ANDROID_SHA1');

/// Headers that let an Android-restricted key work from plain HTTP calls.
Map<String, String> googleAndroidHeaders() => Platform.isAndroid && _signingSha1.isNotEmpty
    ? {
        'X-Android-Package': 'au.com.pebble.pebble',
        'X-Android-Cert': _signingSha1.replaceAll(':', '').toUpperCase(),
      }
    : const {};

/// A Google Maps Static API image centred on a red pin. [width] and [height]
/// are in logical pixels; the image is fetched at twice that for sharpness.
Uri googleStaticMapUri({
  required double latitude,
  required double longitude,
  required int width,
  required int height,
  String key = googleMapsKey,
}) {
  final point = '$latitude,$longitude';
  return Uri.https('maps.googleapis.com', '/maps/api/staticmap', {
    'center': point,
    'zoom': '16',
    // The Static API's largest size is 640 x 640 before scaling.
    'size': '${width.clamp(1, 640)}x${height.clamp(1, 640)}',
    'scale': '2',
    'markers': 'color:red|$point',
    'key': key,
  });
}
