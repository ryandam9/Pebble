import 'pebble_database.dart';

/// Where an expense happened: an address, coordinates, or both.
class ExpenseLocation {
  const ExpenseLocation({this.address, this.latitude, this.longitude})
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

  final String? address;
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
}
