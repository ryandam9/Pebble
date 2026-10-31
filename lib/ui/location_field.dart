import 'package:flutter/material.dart';

import 'watercolor.dart';
import 'expense_map_preview.dart';
import 'address_search_dialog.dart';
import '../data/expense_location.dart';
import '../data/location_service.dart';

/// Lets the user set, view on a map, or clear an expense's location.
class LocationField extends StatefulWidget {
  const LocationField({
    required this.value,
    required this.onChanged,
    required this.service,
    super.key,
  });

  final ExpenseLocation? value;
  final ValueChanged<ExpenseLocation?> onChanged;
  final LocationService service;

  @override
  State<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<LocationField> {
  bool _locating = false;

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final location = await widget.service.currentLocation();
      if (mounted) widget.onChanged(location);
    } on LocationException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message('Could not get your location: $error');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _search() async {
    final picked = await showDialog<ExpenseLocation>(
      context: context,
      builder: (_) => AddressSearchDialog(service: widget.service),
    );
    if (mounted && picked != null) widget.onChanged(picked);
  }

  Future<void> _openMap(ExpenseLocation location) async {
    try {
      await widget.service.openInMaps(location);
    } on Object catch (error) {
      if (mounted) _message(error is LocationException ? error.message : 'Could not open the map: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const WatercolorSection(title: 'Location'),
      const SizedBox(height: 9),
      if (location == null)
        WatercolorPanel(
          tint: const Color(0xFFF1F6FE),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(children: [
              WatercolorIcon(Icons.location_on_outlined),
              SizedBox(width: 10),
              Expanded(child: Text('Add the place you visited',
                style: TextStyle(color: Watercolor.ink,
                  fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 9),
            Wrap(spacing: 8, runSpacing: 3, children: [
              TextButton.icon(
                key: const Key('currentLocationButton'),
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
                label: Text(_locating ? 'Locating…' : 'Current location'),
              ),
              TextButton.icon(
                key: const Key('searchAddressButton'),
                onPressed: _locating ? null : _search,
                icon: const Icon(Icons.search),
                label: const Text('Search address'),
              ),
            ]),
          ]),
        )
      else
        WatercolorPanel(
          tint: const Color(0xFFF3F7FF),
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const WatercolorIcon(Icons.location_on_outlined),
              const SizedBox(width: 9),
              Expanded(child: Text(location.label,
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13,
                  color: Watercolor.ink, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 9),
            ExpenseMapPreview(
              location: location,
              onOpen: () => _openMap(location),
            ),
            const SizedBox(height: 5),
            Wrap(spacing: 3, runSpacing: 2, children: [
              TextButton.icon(
                key: const Key('openInMapsButton'),
                onPressed: () => _openMap(location),
                icon: const Icon(Icons.map_outlined, size: 17),
                label: const Text('Open in Maps'),
              ),
              TextButton.icon(
                key: const Key('changeLocationButton'),
                onPressed: _search,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 17),
                label: const Text('Change'),
              ),
              TextButton.icon(
                key: const Key('removeLocationButton'),
                onPressed: () => widget.onChanged(null),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD3433E)),
                icon: const Icon(Icons.close, size: 17),
                label: const Text('Remove'),
              ),
            ]),
          ]),
        ),
    ]);
  }
}

