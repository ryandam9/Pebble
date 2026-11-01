import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'expense_location.dart';

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

  /// Up to five places matching [query]. Empty when nothing matches.
  Future<List<ExpenseLocation>> search(String query);

  /// Shows [location] in the device's maps app (or a browser on desktop).
  Future<void> openInMaps(ExpenseLocation location);
}

class DeviceLocationService implements LocationService {
  const DeviceLocationService();

  /// Search uses OpenStreetMap's Photon service (internet, no API key), so it
  /// works everywhere. The platform geocoder is only on Android and iOS.
  @override
  bool get canSearch => true;

  bool get _hasGeocoder => Platform.isAndroid || Platform.isIOS;

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

  @override
  Future<List<ExpenseLocation>> search(String query) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    LocationException? failure;
    try {
      final places = await _searchPhoton(text);
      if (places.isNotEmpty) return places;
    } on LocationException catch (error) {
      failure = error;
    }
    // Photon knows shops and places; the platform geocoder is sometimes
    // better at plain street addresses, so try it when Photon finds nothing.
    if (_hasGeocoder) {
      try {
        return await _searchGeocoder(text);
      } on LocationException {
        if (failure != null) throw failure;
        rethrow;
      }
    }
    if (failure != null) throw failure;
    return const [];
  }

  /// Shops, places and addresses from OpenStreetMap, nearest first when the
  /// device already knows roughly where it is.
  Future<List<ExpenseLocation>> _searchPhoton(String text) async {
    final near = await _lastKnownPosition();
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': text,
      'limit': '8',
      'lang': 'en',
      if (near != null) ...{
        'lat': near.latitude.toStringAsFixed(3),
        'lon': near.longitude.toStringAsFixed(3),
      },
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'Pebble expense app (au.com.pebble)');
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const LocationException('Search failed. Please try again.');
      }
      return parsePhotonResults(jsonDecode(body)).take(5).toList();
    } on TimeoutException {
      throw const LocationException('Search timed out. Check your internet connection.');
    } on SocketException {
      throw const LocationException('Search failed. Check your internet connection.');
    } on HttpException {
      throw const LocationException('Search failed. Check your internet connection.');
    } on FormatException {
      throw const LocationException('Search failed. Please try again.');
    } finally {
      client.close(force: true);
    }
  }

  /// Rough position for ranking nearby results. Never prompts for permission.
  Future<Position?> _lastKnownPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      return await Geolocator.getLastKnownPosition().timeout(const Duration(seconds: 2));
    } on Object {
      return null;
    }
  }

  Future<List<ExpenseLocation>> _searchGeocoder(String text) async {
    final List<geo.Location> matches;
    try {
      matches = await geo.Geocoding().locationFromAddress(text).timeout(const Duration(seconds: 15));
    } on PlatformException catch (error) {
      // Android reports "no results" as an error.
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

/// Locations from a Photon (OpenStreetMap) search response. A shop or other
/// named place gets its name in front: "Woolworths, 833 Collins Street,
/// Docklands, Victoria 3008". Malformed features are skipped.
List<ExpenseLocation> parsePhotonResults(Object? json) {
  if (json is! Map || json['features'] is! List) return const [];
  final results = <ExpenseLocation>[];
  final seen = <String>{};
  for (final feature in json['features'] as List) {
    if (feature is! Map) continue;
    final geometry = feature['geometry'];
    final props = feature['properties'];
    if (geometry is! Map || props is! Map) continue;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2 ||
        coordinates[0] is! num || coordinates[1] is! num) {
      continue;
    }
    String? field(String key) {
      final value = props[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final street = [field('housenumber'), field('street')].whereType<String>().join(' ');
    final suburb = field('district') ?? field('locality') ?? field('city');
    final state = [field('state'), field('postcode')].whereType<String>().join(' ');
    var name = field('name');
    // Only a shop, venue or building name is worth a heading; a street or
    // suburb result's "name" is just the street or suburb itself.
    final type = field('type');
    final isPlace = type == null || type == 'house' || type == 'other';
    if (name != null && (!isPlace || name == street)) name = null;

    final parts = <String>[];
    for (final part in [
      name,
      street.isEmpty ? (name == null ? field('name') : null) : street,
      suburb,
      state,
      if (field('countrycode') != 'AU') field('country'),
    ]) {
      if (part != null && part.isNotEmpty && !parts.contains(part)) parts.add(part);
    }
    if (parts.isEmpty) continue;
    final address = parts.join(', ');
    if (!seen.add(address)) continue;
    results.add(ExpenseLocation(
      address: address,
      name: name,
      latitude: (coordinates[1] as num).toDouble(),
      longitude: (coordinates[0] as num).toDouble(),
    ));
  }
  return results;
}

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
