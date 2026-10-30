import 'package:flutter/material.dart';

import '../core/design.dart';
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
      builder: (_) => _AddressSearchDialog(service: widget.service),
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
      const Text('Location', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      if (location == null)
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            key: const Key('currentLocationButton'),
            onPressed: _locating ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            label: Text(_locating ? 'Locating…' : 'Current location'),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            key: const Key('searchAddressButton'),
            onPressed: _locating ? null : _search,
            icon: const Icon(Icons.search),
            label: const Text('Search address'),
          )),
        ])
      else
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F6FE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.place_outlined, color: PebbleColors.blue),
            const SizedBox(width: 10),
            Expanded(child: Text(location.label, maxLines: 3, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600))),
            IconButton(
              tooltip: 'Open in maps',
              onPressed: () => _openMap(location),
              icon: const Icon(Icons.map_outlined, color: PebbleColors.blue),
            ),
            IconButton(
              tooltip: 'Change location',
              onPressed: _search,
              icon: const Icon(Icons.edit_location_alt_outlined, color: PebbleColors.muted),
            ),
            IconButton(
              tooltip: 'Remove location',
              onPressed: () => widget.onChanged(null),
              icon: const Icon(Icons.close, color: PebbleColors.muted),
            ),
          ]),
        ),
    ]);
  }
}

class _AddressSearchDialog extends StatefulWidget {
  const _AddressSearchDialog({required this.service});
  final LocationService service;

  @override
  State<_AddressSearchDialog> createState() => _AddressSearchDialogState();
}

class _AddressSearchDialogState extends State<_AddressSearchDialog> {
  final _query = TextEditingController();
  List<ExpenseLocation>? _results;
  String? _error;
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_query.text.trim().isEmpty || _searching) return;
    setState(() { _searching = true; _error = null; });
    try {
      final results = await widget.service.search(_query.text);
      if (mounted) setState(() => _results = results);
    } on LocationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Search failed: $error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typed = _query.text.trim();
    final results = _results;
    return AlertDialog(
      title: const Text('Find a place'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: TextField(
              key: const Key('addressQueryInput'),
              controller: _query,
              autofocus: true,
              textInputAction: widget.service.canSearch ? TextInputAction.search : TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(hintText: 'Shop name or address'),
            )),
            if (widget.service.canSearch) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  key: const Key('addressSearchButton'),
                  onPressed: _searching || typed.isEmpty ? null : _search,
                  icon: _searching
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search, size: 18),
                  label: const Text('Search'),
                ),
              ),
            ],
          ]),
          if (widget.service.canSearch && results == null && _error == null)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Type a name or address, then tap Search to see matching places.',
                style: TextStyle(fontSize: 12, color: PebbleColors.muted)),
            ),
          if (!widget.service.canSearch)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Address search isn’t available on this device. The address is saved as typed, '
                  'and the maps app looks it up when you open it.',
                style: TextStyle(fontSize: 12, color: PebbleColors.muted)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
            ),
          if (results != null && results.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('No places found.', style: TextStyle(fontSize: 12, color: PebbleColors.muted)),
            ),
          if (results != null)
            for (final result in results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined, color: PebbleColors.blue),
                title: Text(result.label, style: const TextStyle(fontSize: 14)),
                onTap: () => Navigator.of(context).pop(result),
              ),
          if (typed.isNotEmpty)
            ListTile(
              key: const Key('useTypedAddress'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_note_outlined, color: PebbleColors.muted),
              title: Text('Use “$typed” as typed', style: const TextStyle(fontSize: 14)),
              subtitle: const Text('Saved without map coordinates', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.of(context).pop(ExpenseLocation(address: typed)),
            ),
        ])),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      ],
    );
  }
}
