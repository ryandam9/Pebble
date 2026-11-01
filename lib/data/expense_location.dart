import 'pebble_database.dart';

/// Where an expense happened: an address, coordinates, or both.
class ExpenseLocation {
  const ExpenseLocation({this.address, this.latitude, this.longitude, this.name, this.distanceMeters})
      : assert((latitude == null) == (longitude == null), 'Set both coordinates or neither');

  /// The saved location of [entry], or null if it has none.
  static ExpenseLocation? of(ExpenseEntry entry) {
    final location = ExpenseLocation(
      address: entry.locationAddress,
      latitude: entry.latitude,
      longitude: entry.longitude,
    );
    return location.isEmpty ? null : location;
  }

  /// Full text saved with the expense, e.g. "Woolworths, 833 Collins St, Docklands".
  final String? address;

  /// Shop or place name, when search found one. It is already part of
  /// [address]; kept separately only so pickers can show it as a heading.
  final String? name;

  /// How far a search result is from the user. Shown in pickers, never saved.
  final double? distanceMeters;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isEmpty => (address == null || address!.trim().isEmpty) && !hasCoordinates;

  /// Short text for display: the address, else the coordinates.
  String get label {
    final text = address?.trim();
    if (text != null && text.isNotEmpty) return text;
    return '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}';
  }

  /// The address without the leading place [name], for a subtitle.
  /// Null when there is no separate name.
  String? get addressWithoutName {
    final place = name?.trim();
    final text = address?.trim();
    if (place == null || place.isEmpty || text == null) return null;
    final rest = text.startsWith('$place, ') ? text.substring(place.length + 2) : text;
    return rest == place ? null : rest;
  }
}
