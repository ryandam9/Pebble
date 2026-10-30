import 'dart:async';
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

  /// The platform geocoder only exists on Android and iOS. It needs internet
  /// but no API key.
  @override
  bool get canSearch => Platform.isAndroid || Platform.isIOS;

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
    if (!canSearch || text.isEmpty) return const [];
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
    if (!canSearch) return null;
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
