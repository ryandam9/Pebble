import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A restrained paper-and-pigment system for expense editing.
///
/// The decoration is painted locally: no raster asset, network request,
/// animation, image permission, or additional platform plugin is required.
abstract final class Watercolor {
  static const paper = Color(0xFFFFFBF3);
  static const ink = Color(0xFF203452);
  static const muted = Color(0xFF657591);
  static const cobalt = Color(0xFF245FAE);
  static const sky = Color(0xFFD9EEFB);
  static const peach = Color(0xFFFFD7C0);
  static const violet = Color(0xFFEADAF8);
  static const lilac = Color(0xFFF6EDFF);
  static const sand = Color(0xFFFFE6AE);
  static const rose = Color(0xFFF9D8E2);
  static const stroke = Color(0xFFE8DFD1);
}

class WatercolorCanvas extends StatelessWidget {
  const WatercolorCanvas({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(children: [
    const Positioned.fill(child: IgnorePointer(
      child: ColoredBox(color: Watercolor.paper))),
    const Positioned.fill(child: IgnorePointer(
      child: CustomPaint(painter: _WashPainter(background: true)))),
    child,
  ]);
}

/// Irregular translucent overlapping pigment rather than conventional gradients.
class WatercolorPanel extends StatelessWidget {
  const WatercolorPanel({
    required this.child,
    this.tint = Colors.white,
    this.padding = const EdgeInsets.all(14),
    this.radius = 19,
    this.onTap,
    this.keyName,
    super.key,
  });
  final Widget child;
  final Color tint;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final String? keyName;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: keyName == null ? null : Key(keyName!),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Watercolor.stroke.withValues(alpha: 0.64)),
        boxShadow: const [
          BoxShadow(color: Color(0x0C9F7752), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(children: [
            Positioned.fill(child: IgnorePointer(
              child: CustomPaint(painter: _WashPainter(background: false)))),
            Padding(padding: padding, child: child),
          ]),
        ),
      ),
    );
  }
}

class WatercolorSection extends StatelessWidget {
  const WatercolorSection({required this.title, this.trailing, super.key});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(title, style: const TextStyle(
      fontSize: 21, color: Watercolor.ink, fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic, fontFamily: 'serif',
    ))),
    if (trailing != null) trailing!,
  ]);
}

class WatercolorSave extends StatelessWidget {
  const WatercolorSave({required this.label, required this.onPressed, super.key});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    decoration: BoxDecoration(
      color: Watercolor.cobalt,
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [BoxShadow(color: Color(0x29215EA9), blurRadius: 12, offset: Offset(0, 5))],
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(children: [
      const Positioned.fill(child: IgnorePointer(child: CustomPaint(
        painter: _WashPainter(background: false)))),
      SizedBox.expand(child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.check_rounded, color: Colors.white),
        label: Text(label, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
        style: TextButton.styleFrom(foregroundColor: Colors.white),
      )),
    ]),
  );
}

class WatercolorSegment extends StatelessWidget {
  const WatercolorSegment({
    required this.label, required this.icon, required this.selected,
    required this.onTap, super.key,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(child: WatercolorPanel(
    tint: selected ? Watercolor.cobalt : const Color(0xFFF6F0E8),
    radius: 24,
    padding: EdgeInsets.zero,
    onTap: onTap,
    child: SizedBox(height: 43, child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 19, color: selected ? Colors.white : Watercolor.ink),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
          color: selected ? Colors.white : Watercolor.ink)),
      ],
    )),
  ));
}

class WatercolorIcon extends StatelessWidget {
  const WatercolorIcon(this.icon, {this.tint = Watercolor.sky, super.key});
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
    child: Icon(icon, size: 21, color: Watercolor.cobalt),
  );
}

class _WashPainter extends CustomPainter {
  const _WashPainter({required this.background});
  final bool background;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shorter = math.min(size.width, size.height);
    final blobs = background ? <(Offset, double, Color)>[
      (Offset(size.width * 0.98, size.height * 0.10), shorter * .52, Watercolor.sky),
      (Offset(size.width * 0.02, size.height * 0.73), shorter * .39, Watercolor.peach),
      (Offset(size.width * 0.92, size.height * 0.93), shorter * .33, Watercolor.violet),
    ] : <(Offset, double, Color)>[
      (Offset(size.width * .10, size.height * .10), shorter * .72, Watercolor.sky),
      (Offset(size.width * .92, size.height * .96), shorter * .62, Watercolor.peach),
      (Offset(size.width * .78, size.height * .15), shorter * .45, Watercolor.violet),
    ];
    for (final (centre, radius, pigment) in blobs) {
      final wash = Paint()..shader = RadialGradient(
        colors: [
          pigment.withValues(alpha: background ? 0.33 : 0.40),
          pigment.withValues(alpha: 0.12),
          pigment.withValues(alpha: 0),
        ],
        stops: const [0.08, 0.55, 1],
      ).createShader(Rect.fromCircle(center: centre, radius: radius));
      canvas.drawOval(Rect.fromCenter(center: centre,
        width: radius * 2.5, height: radius * 1.7), wash);
    }
    // A few tiny irregular pigment flecks, with fixed positions for stable UI.
    if (background) {
      final random = math.Random(42);
      for (var i = 0; i < 75; i++) {
        final x = random.nextDouble() * size.width;
        final y = random.nextDouble() * size.height;
        final radius = .4 + random.nextDouble() * 1.2;
        canvas.drawCircle(Offset(x, y), radius, Paint()
          ..color = (i % 2 == 0 ? Watercolor.peach : Watercolor.cobalt)
              .withValues(alpha: .075));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WashPainter oldDelegate) =>
      oldDelegate.background != background;
}
