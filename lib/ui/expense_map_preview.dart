import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/expense_location.dart';
import 'watercolor.dart';

/// A real map for coordinate-backed expenses. Tiles require a network
/// connection; saved expense information itself remains completely offline.
class ExpenseMapPreview extends StatelessWidget {
  const ExpenseMapPreview({required this.location, required this.onOpen, super.key});
  final ExpenseLocation location;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (!location.hasCoordinates) {
      return const DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFFEDF2FA)),
        child: SizedBox(
          height: 100,
          child: Center(child: Text(
            'Map preview needs location coordinates',
            style: TextStyle(color: Watercolor.muted, fontSize: 12),
          )),
        ),
      );
    }
    final point = LatLng(location.latitude!, location.longitude!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        height: 132,
        child: Stack(children: [
          FlutterMap(
            key: ValueKey('map_' + point.latitude.toString() + '_' + point.longitude.toString()),
            options: MapOptions(
              initialCenter: point,
              // A whole zoom level keeps tiles at their native scale; a
              // fractional one stretches them and blurs the labels.
              initialZoom: 16,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'au.com.pebble',
                retinaMode: RetinaMode.isHighDensity(context),
              ),
              MarkerLayer(markers: [
                Marker(
                  point: point, width: 40, height: 40,
                  // The glyph's tip, 22/24 of the way down, marks the spot.
                  alignment: const Alignment(0, 1 - 2 * 22 / 24),
                  child: const Icon(Icons.location_on_rounded,
                    size: 40, color: Color(0xFFE65C4B),
                    shadows: [Shadow(color: Color(0x59000000), blurRadius: 4, offset: Offset(0, 1))]),
                ),
              ]),
            ],
          ),
          Positioned.fill(child: Material(
            color: Colors.transparent,
            child: InkWell(onTap: onOpen),
          )),
          const Positioned(top: 8, right: 8,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xF2FFFFFF),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, 1))],
                ),
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.open_in_new_rounded,
                    size: 16, color: Watercolor.ink),
                ),
              ),
            ),
          ),
          Positioned(right: 5, bottom: 4,
            child: Material(
              color: const Color(0xEFFFFFFF),
              borderRadius: BorderRadius.circular(5),
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  child: Text('© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 9, color: Watercolor.ink)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
