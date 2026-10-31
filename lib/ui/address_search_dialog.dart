import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/expense_location.dart';
import '../data/location_service.dart';
import 'recent_addresses.dart';
import 'watercolor.dart';

/// Search-first address picker: quiet watercolor header, one search field,
/// genuine location shortcuts, and clearly labelled geocoded vs typed results.
/// Deliberately does not show fake Home/Work bookmarks or fabricated map pins.
class AddressSearchDialog extends StatefulWidget {
  const AddressSearchDialog({
    required this.service,
    this.recents = const RecentAddresses(),
    super.key,
  });

  final LocationService service;
  final RecentAddresses recents;

  @override
  State<AddressSearchDialog> createState() => _AddressSearchDialogState();
}

class _AddressSearchDialogState extends State<AddressSearchDialog> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  List<ExpenseLocation>? _results;
  List<ExpenseLocation> _recent = [];
  String? _error;
  bool _searching = false;
  bool _locating = false;
  bool _showRecent = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final stored = await widget.recents.read();
    if (mounted) setState(() => _recent = stored);
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _pick(ExpenseLocation location) {
    unawaited(widget.recents.remember(location));
    Navigator.of(context).pop(location);
  }

  Future<void> _currentLocation() async {
    if (_locating || _searching) return;
    _focus.unfocus();
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final location = await widget.service.currentLocation();
      if (mounted) _pick(location);
    } on LocationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) setState(() => _error =
        'Could not find your location. Check location permissions and try again.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _search() async {
    final typed = _query.text.trim();
    if (!widget.service.canSearch || typed.isEmpty || _searching || _locating) {
      return;
    }
    _focus.unfocus();
    setState(() {
      _searching = true;
      _results = null;
      _error = null;
      _showRecent = false;
    });
    try {
      final found = await widget.service.search(typed);
      if (!mounted || _query.text.trim() != typed) return;
      setState(() => _results = found);
    } on LocationException catch (error) {
      if (mounted && _query.text.trim() == typed) {
        setState(() => _error = error.message);
      }
    } on Object {
      if (mounted && _query.text.trim() == typed) {
        setState(() => _error = 'Search failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Widget _shortcut({
    required String label,
    required IconData icon,
    required Color tint,
    required VoidCallback? onPressed,
    Key? key,
    bool busy = false,
  }) => Expanded(child: Semantics(
    button: true,
    label: label,
    child: Material(
      color: tint, borderRadius: BorderRadius.circular(17),
      child: InkWell(
        key: key,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(17),
        child: SizedBox(
          height: 74,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            busy
              ? const SizedBox(height: 25, width: 25,
                  child: CircularProgressIndicator(strokeWidth: 2.2))
              : Icon(icon, size: 26, color: Watercolor.cobalt),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: Watercolor.ink)),
          ]),
        ),
      ),
    ),
  ));

  Widget _placeRow(ExpenseLocation location, {bool recent = false}) {
    final label = location.label;
    return ListTile(
      key: Key('addressResult_' + label),
      contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      leading: Container(
        width: 39, height: 39,
        decoration: BoxDecoration(
          color: recent ? const Color(0xFFFFF0E2) : const Color(0xFFE6F2FF),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(recent ? Icons.history_rounded : Icons.location_on_outlined,
          color: Watercolor.cobalt),
      ),
      title: Text(label,
        maxLines: 2, overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Watercolor.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
      subtitle: Text(
        location.hasCoordinates ? 'Map location available' : 'Saved as address',
        style: const TextStyle(fontSize: 11, color: Watercolor.muted),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Watercolor.muted),
      onTap: () => _pick(location),
    );
  }

  Widget _sectionLabel(String name, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Row(children: [
      Expanded(child: Text(name,
        style: const TextStyle(color: Watercolor.ink,
          fontSize: 16, fontWeight: FontWeight.w800))),
      if (trailing != null) trailing,
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final typed = _query.text.trim();
    final height = MediaQuery.sizeOf(context).height;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final dialogHeight = math.min(720.0,
      math.max(300.0, height - keyboard - 52));
    return Dialog(
      backgroundColor: Watercolor.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 470,
        height: dialogHeight,
        child: WatercolorCanvas(
          child: Column(children: [
            SizedBox(
              height: 161,
              child: Stack(fit: StackFit.expand, children: [
                const IgnorePointer(child: CustomPaint(
                  painter: _AddressSkylinePainter())),
                Positioned(
                  top: 5, right: 7,
                  child: IconButton(
                    tooltip: 'Close address search',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Watercolor.ink),
                  ),
                ),
                const Positioned(
                  bottom: 10, left: 16, right: 16,
                  child: Column(children: [
                    Text('Search address',
                      style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800,
                        color: Watercolor.ink, fontFamily: 'serif')),
                    SizedBox(height: 4),
                    Text('Find a street, suburb or place',
                      style: TextStyle(fontSize: 12, color: Watercolor.muted)),
                  ]),
                ),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  TextField(
                    key: const Key('addressQueryInput'),
                    controller: _query,
                    focusNode: _focus,
                    autofocus: false,
                    textInputAction: widget.service.canSearch
                      ? TextInputAction.search : TextInputAction.done,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {
                      _error = null;
                      _results = null;
                      _showRecent = false;
                    }),
                    onSubmitted: (_) {
                      if (widget.service.canSearch) {
                        _search();
                      } else if (typed.isNotEmpty) {
                        _pick(ExpenseLocation(address: _query.text.trim()));
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Address, suburb or place...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                        color: Watercolor.cobalt),
                      suffixIcon: typed.isNotEmpty
                        ? IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded, size: 19),
                          onPressed: () {
                            _query.clear();
                            setState(() {
                              _error = null;
                              _results = null;
                            });
                          },
                        ) : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F3F8),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(18)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(18)),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Watercolor.cobalt, width: 1.5),
                        borderRadius: BorderRadius.circular(18)),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 15),
                    ),
                  ),
                  if (widget.service.canSearch) ...[
                    const SizedBox(height: 9),
                    SizedBox(
                      height: 42,
                      child: FilledButton.icon(
                        key: const Key('addressSearchButton'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Watercolor.cobalt,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                        onPressed: typed.isEmpty || _searching || _locating
                          ? null : _search,
                        icon: _searching
                          ? const SizedBox(width: 17, height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white))
                          : const Icon(Icons.search_rounded, size: 19),
                        label: Text(_searching ? 'Finding places…' : 'Search places'),
                      ),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(top: 9),
                      child: Text('Address lookup is unavailable on this device. '
                        'You can still save an address exactly as typed.',
                        style: TextStyle(
                          color: Watercolor.muted, fontSize: 12)),
                    ),
                  const SizedBox(height: 16),
                  Row(children: [
                    _shortcut(
                      label: 'Current',
                      icon: Icons.my_location_rounded,
                      tint: const Color(0xFFE3F0FF),
                      key: const Key('dialogCurrentLocation'),
                      busy: _locating,
                      onPressed: _locating || _searching ? null : _currentLocation),
                    const SizedBox(width: 9),
                    _shortcut(
                      label: 'Use typed',
                      icon: Icons.edit_location_alt_outlined,
                      tint: const Color(0xFFFFEDE1),
                      onPressed: typed.isEmpty ? null
                        : () => _pick(ExpenseLocation(address: typed))),
                    const SizedBox(width: 9),
                    _shortcut(
                      label: 'Recent',
                      icon: Icons.history_rounded,
                      tint: const Color(0xFFF0E8FC),
                      onPressed: _recent.isEmpty ? null
                        : () {
                          _focus.unfocus();
                          setState(() {
                            _results = null;
                            _showRecent = true;
                          });
                        },
                    ),
                  ]),
                  if (_error != null) ...[
                    const SizedBox(height: 13),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE9E5),
                        borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFC74437), size: 21),
                        const SizedBox(width: 9),
                        Expanded(child: Text(_error!, style: const TextStyle(
                          color: Color(0xFF8B3329), fontSize: 12))),
                      ]),
                    ),
                  ],
                  if (_results != null && !_showRecent) ...[
                    _sectionLabel(_results!.isEmpty ? 'No matching places' : 'Search results'),
                    if (_results!.isEmpty)
                      const Text('Try a full street address, suburb or postcode.',
                        style: TextStyle(fontSize: 12, color: Watercolor.muted)),
                    for (final result in _results!) _placeRow(result),
                  ] else if (_recent.isNotEmpty && (typed.isEmpty || _showRecent)) ...[
                    _sectionLabel('Recently selected',
                      trailing: TextButton(
                        key: const Key('clearRecentAddresses'),
                        onPressed: () async {
                          await widget.recents.clear();
                          if (mounted) setState(() {
                            _recent = [];
                            _showRecent = false;
                          });
                        },
                        child: const Text('Clear',
                          style: TextStyle(color: Watercolor.cobalt)),
                      )),
                    for (final item in _recent) _placeRow(item, recent: true),
                  ] else if (typed.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 23),
                      child: Text('Choose Current to use your position, '
                        'or enter an address above.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12, color: Watercolor.muted)),
                    ),
                  if (typed.isNotEmpty) ...[
                    _sectionLabel('Or save exactly what you typed'),
                    ListTile(
                      key: const Key('useTypedAddress'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 5),
                      leading: const Icon(Icons.edit_note_rounded,
                        color: Watercolor.cobalt),
                      title: Text(typed, maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: const Text('Saves the address without map coordinates',
                        style: TextStyle(fontSize: 11, color: Watercolor.muted)),
                      trailing: const Icon(Icons.chevron_right_rounded,
                        color: Watercolor.muted),
                      onTap: () => _pick(ExpenseLocation(address: typed)),
                    ),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A muted watercolor city silhouette. No geographic claims or network assets.
class _AddressSkylinePainter extends CustomPainter {
  const _AddressSkylinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFD9ECFD), Color(0xFFFCE8D8), Color(0xFFFFFBF3)],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);
    final water = Paint()..color = const Color(0xFF9FC4DB).withValues(alpha: .25);
    canvas.drawOval(Rect.fromLTWH(-30, size.height * .50,
      size.width + 60, size.height * .49), water);
    final coast = Path()
      ..moveTo(0, size.height * .74)
      ..quadraticBezierTo(size.width * .35, size.height * .62,
        size.width, size.height * .78)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(coast, Paint()
      ..color = const Color(0xFFA3C5D6).withValues(alpha: .19));
    final towers = [
      (.26, .54, .038, .28), (.31, .45, .028, .36),
      (.35, .51, .047, .33), (.42, .40, .024, .40),
      (.47, .50, .043, .31), (.55, .55, .030, .30),
      (.59, .47, .040, .36), (.66, .57, .033, .24),
      (.72, .62, .052, .19),
    ];
    final buildingPaint = Paint()
      ..color = const Color(0xFF618CA8).withValues(alpha: .28);
    for (final (x, top, width, h) in towers) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * x, size.height * top,
            size.width * width, size.height * h),
          const Radius.circular(2)),
        buildingPaint,
      );
    }
    final sun = Paint()
      ..color = const Color(0xFFEBAF7C).withValues(alpha: .27);
    canvas.drawCircle(
      Offset(size.width * .77, size.height * .27), 31, sun);
  }

  @override
  bool shouldRepaint(covariant _AddressSkylinePainter oldDelegate) => false;
}
