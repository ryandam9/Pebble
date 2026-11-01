import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geocoding_android/geocoder.dart' as android;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'expense_location.dart';
import 'google_maps_key.dart';

/// A problem the user can act on, with a message to show them.
class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// GPS, address search and "open in maps". An interface so tests can fake it.
abstract class LocationService {
  /// Whether [search] and address lookup work on this device.
  bool get canSearch;

  /// The device's position, with a street address when one can be found.
  Future<ExpenseLocation> currentLocation();

  /// Places matching [query]. Empty when nothing matches.
  Future<List<ExpenseLocation>> search(String query);

  /// Credit to show under search results, e.g. "Powered by Google".
  String? get searchAttribution;

  /// Shows [location] in the device's maps app (or a browser on desktop).
  Future<void> openInMaps(ExpenseLocation location);
}

class DeviceLocationService implements LocationService {
  const DeviceLocationService();

  /// The platform geocoder only exists on Android and iOS. It needs internet
  /// but no API key.
  @override
  bool get canSearch => _hasGeocoder;

  bool get _hasGeocoder => Platform.isAndroid || Platform.isIOS;

  @override
  String? get searchAttribution =>
      googleMapsKey.isNotEmpty || Platform.isAndroid ? 'Powered by Google' : null;

  @override
  Future<ExpenseLocation> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Location is turned off. Turn it on in your device settings.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException('Location permission is blocked. Allow it for Pebble in app settings.');
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
      throw const LocationException('Location permission was not granted.');
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) throw const LocationException('Could not get a GPS fix. Try again outdoors.');
      position = last;
    }

    return ExpenseLocation(
      address: await _addressAt(position.latitude, position.longitude),
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  /// Places in Australia matching [query], nearest to the user first.
  @override
  Future<List<ExpenseLocation>> search(String query) async {
    final text = query.trim();
    if (!canSearch || text.isEmpty) return const [];
    final near = await _nearbyPosition();
    final found = <ExpenseLocation>[];
    if (googleMapsKey.isNotEmpty) {
      found.addAll(await _placesSearch(text, near));
    } else if (Platform.isAndroid) {
      // Look around the user first, then the rest of Australia, so a nearby
      // store is found even when the same name exists in every city.
      LocationException? failure;
      for (final bounds in [
        if (near != null) boundsAround(near.latitude, near.longitude),
        australiaBounds,
      ]) {
        try {
          found.addAll(await _androidSearch(text, bounds));
        } on LocationException catch (error) {
          failure ??= error;
        }
        if (found.length >= 5) break;
      }
      if (found.isEmpty && failure != null) throw failure;
    } else {
      found.addAll(await _geocoderSearch(text));
    }
    return nearestFirst(
      found.where((place) => isInAustralia(place.latitude!, place.longitude!)),
      near?.latitude, near?.longitude,
    ).take(8).toList();
  }

  /// Google Places text search. Biased to 30 km around the user when known,
  /// otherwise limited to Australia.
  Future<List<ExpenseLocation>> _placesSearch(String text, Position? near) async {
    final body = jsonEncode({
      'textQuery': text,
      'regionCode': 'AU',
      'languageCode': 'en-AU',
      'pageSize': 10,
      if (near != null)
        'locationBias': {'circle': {
          'center': {'latitude': near.latitude, 'longitude': near.longitude},
          'radius': 30000.0,
        }}
      else
        'locationRestriction': {'rectangle': {
          'low': {'latitude': australiaBounds.south, 'longitude': australiaBounds.west},
          'high': {'latitude': australiaBounds.north, 'longitude': australiaBounds.east},
        }},
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(
          Uri.https('places.googleapis.com', '/v1/places:searchText'));
      request.headers
        ..contentType = ContentType.json
        ..set('X-Goog-Api-Key', googleMapsKey)
        ..set('X-Goog-FieldMask',
            'places.displayName,places.formattedAddress,places.location,places.addressComponents');
      googleAndroidHeaders().forEach(request.headers.set);
      request.write(body);
      final response = await request.close().timeout(const Duration(seconds: 15));
      final reply = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
      if (response.statusCode == 400 || response.statusCode == 403) {
        throw const LocationException(
          'Google Places refused the search. Check the API key and its restrictions.');
      }
      if (response.statusCode != 200) {
        throw const LocationException('Search failed. Please try again.');
      }
      return parsePlacesResults(jsonDecode(reply));
    } on TimeoutException {
      throw const LocationException('Search timed out. Check your internet connection.');
    } on IOException {
      throw const LocationException('Search failed. Check your internet connection.');
    } on FormatException {
      throw const LocationException('Search failed. Please try again.');
    } finally {
      client.close(force: true);
    }
  }

  /// Where the user is now, for ranking results. Asks for permission once if
  /// it has not been decided yet; null when it is refused or unavailable.
  Future<Position?> _nearbyPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 6),
        ),
      );
    } on Object {
      return null;
    }
  }

  /// Android's own geocoder, limited to [bounds]. It returns the business
  /// name ("feature name") the plugin's simple API throws away.
  Future<List<ExpenseLocation>> _androidSearch(String text, Bounds bounds) async {
    final geocoder = android.Geocoder(locale: android.Locale(identifier: 'en_AU'));
    final box = android.GeographicBounds(
      lowerLeftLatitude: bounds.south, lowerLeftLongitude: bounds.west,
      upperRightLatitude: bounds.north, upperRightLongitude: bounds.east,
    );
    const maxResults = 10;
    List<android.Address?> addresses;
    try {
      if (await android.Build.getSdkVersion() < 33) {
        addresses = await geocoder
            .getFromLocationNamePreAndroidApi33(text, maxResults, box)
            .timeout(const Duration(seconds: 15)) ?? const [];
      } else {
        final done = Completer<List<android.Address?>>();
        final listener = android.GeocodeListener(
          onGeocode: (_, list) { if (!done.isCompleted) done.complete(list); },
          onError: (_, message) {
            if (!done.isCompleted) done.completeError(PlatformException(code: 'GEOCODE', message: message));
          },
        );
        await geocoder.getFromLocationName(text, maxResults, listener, box);
        addresses = await done.future.timeout(const Duration(seconds: 15));
      }
    } on TimeoutException {
      throw const LocationException('Search timed out. Check your internet connection.');
    } on PlatformException {
      throw const LocationException('Search failed. Check your internet connection.');
    }
    final results = <ExpenseLocation>[];
    for (final address in addresses.nonNulls) {
      final latitude = await address.getLatitude();
      final longitude = await address.getLongitude();
      if (latitude == null || longitude == null) continue;
      final place = placeFromGeocoder(
        featureName: await address.getFeatureName(),
        subThoroughfare: await address.getSubThouroughfare(),
        thoroughfare: await address.getThouroughfare(),
        subLocality: await address.getSubLocality(),
        locality: await address.getLocality(),
        state: await address.getAdminArea(),
        postcode: await address.getPostalCode(),
        countryCode: await address.getCountryCode(),
        firstLine: await address.getAddressLine(0),
        latitude: latitude,
        longitude: longitude,
      );
      if (place != null) results.add(place);
    }
    return results;
  }

  /// The plugin's simple API (used on iOS): coordinates, then the street
  /// address at each one.
  Future<List<ExpenseLocation>> _geocoderSearch(String text) async {
    final List<geo.Location> matches;
    try {
      matches = await geo.Geocoding().locationFromAddress(text).timeout(const Duration(seconds: 15));
    } on PlatformException catch (error) {
      if (error.code == 'NOT_FOUND') return const [];
      throw const LocationException('Search failed. Check your internet connection.');
    } on TimeoutException {
      throw const LocationException('Search timed out. Check your internet connection.');
    }
    final results = <ExpenseLocation>[];
    for (final match in matches.take(5)) {
      results.add(ExpenseLocation(
        address: await _addressAt(match.latitude, match.longitude) ?? text,
        latitude: match.latitude,
        longitude: match.longitude,
      ));
    }
    return results;
  }

  /// Street address for coordinates, or null when offline or not found.
  Future<String?> _addressAt(double latitude, double longitude) async {
    if (!_hasGeocoder) return null;
    try {
      final places = await geo.Geocoding()
          .placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 8));
      return places.isEmpty ? null : formatPlacemark(places.first);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> openInMaps(ExpenseLocation location) async {
    for (final uri in mapUris(location, android: Platform.isAndroid, ios: Platform.isIOS)) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } on PlatformException {
        // No app handles this link; try the next one.
      }
    }
    throw const LocationException('No app could open the map.');
  }
}

/// "12 Smith St, Docklands, VIC 3008" from a geocoder result.
String? formatPlacemark(geo.Placemark place) {
  final street = [place.subThoroughfare, place.thoroughfare]
      .where((part) => part != null && part.trim().isNotEmpty)
      .join(' ');
  final state = [place.administrativeArea, place.postalCode]
      .where((part) => part != null && part.trim().isNotEmpty)
      .join(' ');
  final parts = <String>[];
  for (final part in [street.isEmpty ? place.name : street, place.locality, state]) {
    final text = part?.trim();
    if (text != null && text.isNotEmpty && !parts.contains(text)) parts.add(text);
  }
  return parts.isEmpty ? null : parts.join(', ');
}

/// A latitude/longitude box.
typedef Bounds = ({double south, double west, double north, double east});

/// Mainland Australia and Tasmania, with a little margin.
const Bounds australiaBounds = (south: -44.0, west: 112.0, north: -9.0, east: 154.5);

bool isInAustralia(double latitude, double longitude) =>
    latitude >= australiaBounds.south && latitude <= australiaBounds.north &&
    longitude >= australiaBounds.west && longitude <= australiaBounds.east;

/// Roughly 30 km either side of a point.
Bounds boundsAround(double latitude, double longitude) =>
    (south: latitude - .27, west: longitude - .34, north: latitude + .27, east: longitude + .34);

/// Straight-line distance in metres.
double distanceBetween(double lat1, double lon1, double lat2, double lon2) {
  const earth = 6371000.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * earth * math.asin(math.sqrt(a));
}

/// [places] without duplicates, closest to ([latitude], [longitude]) first,
/// each with its distance. Kept in the given order when there is no position.
List<ExpenseLocation> nearestFirst(Iterable<ExpenseLocation> places, double? latitude, double? longitude) {
  final seen = <String>{};
  final unique = [for (final place in places) if (seen.add(place.label.toLowerCase())) place];
  if (latitude == null || longitude == null) return unique;
  final measured = [
    for (final place in unique)
      ExpenseLocation(
        address: place.address, name: place.name,
        latitude: place.latitude, longitude: place.longitude,
        distanceMeters: place.hasCoordinates
          ? distanceBetween(latitude, longitude, place.latitude!, place.longitude!)
          : null,
      ),
  ];
  measured.sort((a, b) => (a.distanceMeters ?? double.infinity).compareTo(b.distanceMeters ?? double.infinity));
  return measured;
}

/// A geocoder result as a location: "Woolworths, 727 Collins Street,
/// Docklands, VIC 3008". The business name leads when there is one. Null for
/// a result outside Australia or with nothing to show.
ExpenseLocation? placeFromGeocoder({
  String? featureName,
  String? subThoroughfare,
  String? thoroughfare,
  String? subLocality,
  String? locality,
  String? state,
  String? postcode,
  String? countryCode,
  String? firstLine,
  required double latitude,
  required double longitude,
}) {
  String? clean(String? text) => text == null || text.trim().isEmpty ? null : text.trim();
  if (clean(countryCode) != null && clean(countryCode)!.toUpperCase() != 'AU') return null;
  final street = [clean(subThoroughfare), clean(thoroughfare)].nonNulls.join(' ');
  final suburb = clean(subLocality) ?? clean(locality);
  final region = [clean(state), clean(postcode)].nonNulls.join(' ');
  // For a plain address the feature name is just the house number, street
  // or suburb; only keep it when it is something else, like a shop name.
  var name = clean(featureName);
  if (name != null &&
      (RegExp(r'^\d').hasMatch(name) ||
          [subThoroughfare, thoroughfare, street, subLocality, locality, state, postcode]
              .any((part) => clean(part)?.toLowerCase() == name!.toLowerCase()))) {
    name = null;
  }
  final parts = <String>[];
  final fallback = clean(firstLine?.split(',').first);
  for (final part in [name, street.isEmpty ? fallback : street, suburb, region]) {
    if (part != null && part.isNotEmpty && !parts.contains(part)) parts.add(part);
  }
  if (parts.isEmpty) return null;
  return ExpenseLocation(
    address: parts.join(', '), name: name, latitude: latitude, longitude: longitude);
}

/// Locations from a Google Places text search response. A business keeps its
/// name in front: "Woolworths, 727 Collins St, Docklands VIC 3008". Places
/// outside Australia and malformed entries are skipped.
List<ExpenseLocation> parsePlacesResults(Object? json) {
  if (json is! Map || json['places'] is! List) return const [];
  final results = <ExpenseLocation>[];
  for (final place in json['places'] as List) {
    if (place is! Map) continue;
    final location = place['location'];
    if (location is! Map || location['latitude'] is! num || location['longitude'] is! num) continue;
    final components = place['addressComponents'];
    final country = components is List
        ? components.whereType<Map>().where((part) =>
            part['types'] is List && (part['types'] as List).contains('country')).firstOrNull
        : null;
    if (country != null && country['shortText'] != 'AU') continue;

    var address = (place['formattedAddress'] as Object?) is String
        ? (place['formattedAddress'] as String).trim() : '';
    if (address.endsWith(', Australia')) {
      address = address.substring(0, address.length - ', Australia'.length);
    }
    final display = place['displayName'];
    var name = display is Map && display['text'] is String
        ? (display['text'] as String).trim() : null;
    // A plain street address comes back with the address as its "name".
    if (name != null && (name.isEmpty || address.toLowerCase().startsWith(name.toLowerCase()))) {
      name = null;
    }
    final full = [name, address].where((part) => part != null && part.isNotEmpty).join(', ');
    if (full.isEmpty) continue;
    results.add(ExpenseLocation(
      address: full,
      name: name,
      latitude: (location['latitude'] as num).toDouble(),
      longitude: (location['longitude'] as num).toDouble(),
    ));
  }
  return results;
}

/// "350 m" or "2.4 km".
String formatDistance(double meters) => meters < 1000
    ? '${(meters / 10).round() * 10} m'
    : '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';

/// Links to try, best first. Android's `geo:` lets the user pick any maps app;
/// the web link is the fallback everywhere.
List<Uri> mapUris(ExpenseLocation location, {required bool android, required bool ios}) {
  final query = location.hasCoordinates
      ? '${location.latitude},${location.longitude}'
      : location.address!.trim();
  final web = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query});
  if (android) {
    final label = location.address?.trim();
    final geoUri = location.hasCoordinates
        ? Uri.parse('geo:$query?q=${Uri.encodeComponent(
            label == null || label.isEmpty ? query : '$query($label)')}')
        : Uri.parse('geo:0,0?q=${Uri.encodeComponent(query)}');
    return [geoUri, web];
  }
  if (ios) {
    final apple = Uri.https('maps.apple.com', '/', {
      'q': location.address?.trim().isNotEmpty == true ? location.address!.trim() : query,
      if (location.hasCoordinates) 'll': query,
    });
    return [apple, web];
  }
  return [web];
}
