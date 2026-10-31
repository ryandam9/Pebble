import 'package:flutter/material.dart';

import 'watercolor.dart';
import 'bento.dart';
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
    this.bento = false,
    super.key,
  });

  final ExpenseLocation? value;
  final ValueChanged<ExpenseLocation?> onChanged;
  final LocationService service;
  final bool bento;

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
    if (widget.bento) return _buildBento(location);
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
  Widget _buildBento(ExpenseLocation? location) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const BentoSectionTitle(label: 'Location'),
      const SizedBox(height: 8),
      BentoTile(
        padding: EdgeInsets.zero,
        child: location == null
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    BentoIcon(Icons.location_on_outlined),
                    SizedBox(width: 10),
                    Expanded(child: Text('Add a location',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Bento.ink))),
                  ]),
                  const SizedBox(height: 6),
                  const Text('Save where this expense happened.',
                    style: TextStyle(fontSize: 12, color: Bento.muted)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 7, runSpacing: 2, children: [
                    TextButton.icon(
                      key: const Key('currentLocationButton'),
                      onPressed: _locating ? null : _useCurrentLocation,
                      icon: _locating
                        ? const SizedBox(width: 17, height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, size: 18),
                      label: Text(_locating ? 'Locating…' : 'Current location'),
                    ),
                    TextButton.icon(
                      key: const Key('searchAddressButton'),
                      onPressed: _locating ? null : _search,
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Search address'),
                    ),
                  ]),
                ],
              ),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Stack(children: [
                ExpenseMapPreview(
                  location: location,
                  onOpen: () => _openMap(location),
                ),
                Positioned(
                  left: 10, bottom: 9, right: 10,
                  child: Material(
                    color: Colors.white,
                    elevation: 1,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _openMap(location),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                        child: Row(children: [
                          const Icon(Icons.place_rounded,
                            color: Bento.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            location.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12,
                              color: Bento.ink, fontWeight: FontWeight.w700),
                          )),
                          const Icon(Icons.chevron_right_rounded,
                            color: Bento.muted, size: 19),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                child: Wrap(spacing: 1, runSpacing: 0, children: [
                  TextButton.icon(
                    key: const Key('openInMapsButton'),
                    onPressed: () => _openMap(location),
                    icon: const Icon(Icons.map_outlined, size: 17),
                    label: const Text('Open in Maps', style: TextStyle(fontSize: 11)),
                  ),
                  TextButton.icon(
                    key: const Key('changeLocationButton'),
                    onPressed: _search,
                    icon: const Icon(Icons.edit_location_alt_outlined, size: 17),
                    label: const Text('Change', style: TextStyle(fontSize: 11)),
                  ),
                  TextButton.icon(
                    key: const Key('removeLocationButton'),
                    onPressed: () => widget.onChanged(null),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFC94141)),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('Remove', style: TextStyle(fontSize: 11)),
                  ),
                ]),
              ),
            ]),
      ),
    ],
  );

}

