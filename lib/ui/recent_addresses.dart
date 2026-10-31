import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/expense_location.dart';

/// Recently selected places are kept on this device only. No address is sent
/// anywhere by Pebble except when the user explicitly asks the geocoder.
class RecentAddresses {
  const RecentAddresses();

  static const key = 'pebble_recent_addresses_v1';
  static const maxItems = 5;

  Future<List<ExpenseLocation>> read() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final items = preferences.getStringList(key) ?? <String>[];
      final places = <ExpenseLocation>[];
      for (final item in items.take(maxItems)) {
        try {
          final json = jsonDecode(item);
          if (json is! Map<String, dynamic>) continue;
          final address = json['address'];
          final latitude = json['latitude'];
          final longitude = json['longitude'];
          if (address != null && address is! String) continue;
          if (latitude != null && latitude is! num) continue;
          if (longitude != null && longitude is! num) continue;
          if ((latitude == null) != (longitude == null)) continue;
          final location = ExpenseLocation(
            address: address as String?,
            latitude: (latitude as num?)?.toDouble(),
            longitude: (longitude as num?)?.toDouble(),
          );
          if (!location.isEmpty) places.add(location);
        } on FormatException {
          // A corrupt item must not prevent the picker from opening.
        } on TypeError {
          // An older, incompatible record can be ignored safely.
        }
      }
      return places;
    } on Object {
      // Recent addresses are an enhancement, never a dependency of editing.
      return [];
    }
  }

  Future<void> remember(ExpenseLocation location) async {
    if (location.isEmpty) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      final existing = await read();
      final address = location.address?.trim().toLowerCase();
      final matching = (ExpenseLocation candidate) {
        if (location.hasCoordinates && candidate.hasCoordinates &&
            location.latitude == candidate.latitude &&
            location.longitude == candidate.longitude) {
          return true;
        }
        return address != null && address.isNotEmpty &&
            candidate.address?.trim().toLowerCase() == address;
      };
      final deduplicated = [
        location,
        ...existing.where((previous) => !matching(previous)),
      ].take(maxItems);
      await preferences.setStringList(key, [
        for (final place in deduplicated)
          jsonEncode({
            'address': place.address,
            'latitude': place.latitude,
            'longitude': place.longitude,
          }),
      ]);
    } on Object {
      // Selection itself already completed; do not treat cache failure as an error.
    }
  }

  Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(key);
    } on Object {
      // The user can continue using search even if preferences fail.
    }
  }
}
