import 'package:flutter/material.dart';

import '../core/pebble_typography.dart';

/// Bento Studio: intentionally crisp and flat rather than watercolor.
/// Shared only by the expense editor so the rest of Pebble is unaffected.
abstract final class Bento {
  static const canvas = Color(0xFFF5F7FB);
  static const ink = Color(0xFF172A46);
  static const muted = Color(0xFF71829B);
  static const blue = Color(0xFF287AF5);
  static const line = Color(0xFFE5EBF3);
  static const paleBlue = Color(0xFFEAF3FF);
  static const mint = Color(0xFFE8F7EF);
  static const peach = Color(0xFFFFEFE6);
  static const lilac = Color(0xFFF4EAFB);
  static const sand = Color(0xFFFFF2D6);
}

class BentoTile extends StatelessWidget {
  const BentoTile({
    required this.child,
    this.padding = const EdgeInsets.all(15),
    this.color = Colors.white,
    this.radius = 20,
    this.onTap,
    this.keyName,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;
  final String? keyName;

  @override
  Widget build(BuildContext context) => Container(
    key: keyName == null ? null : Key(keyName!),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Bento.line.withValues(alpha: .76)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C20385B), blurRadius: 16, offset: Offset(0, 5)),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class BentoSectionTitle extends StatelessWidget {
  const BentoSectionTitle({required this.label, this.action, super.key});
  final String label;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: const TextStyle(
        color: Bento.ink, fontSize: 15, fontWeight: FontWeight.w800,
      ))),
      if (action != null) action!,
    ],
  );
}

class BentoFieldLabel extends StatelessWidget {
  const BentoFieldLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      color: Bento.muted, fontWeight: FontWeight.w700,
      letterSpacing: .7, fontSize: 10.5,
    ),
  );
}

class BentoIcon extends StatelessWidget {
  const BentoIcon(this.icon, {this.color = Bento.blue, this.background = Bento.paleBlue, super.key});

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: 37, height: 37,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 20),
  );
}

class BentoSaveButton extends StatelessWidget {
  const BentoSaveButton({
    required this.onPressed,
    required this.label,
    super.key,
  });
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 53,
    width: double.infinity,
    child: FilledButton.icon(
      key: const Key('bentoSaveButton'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Bento.blue,
        disabledBackgroundColor: Bento.blue.withValues(alpha: .6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
      ),
      icon: const Icon(Icons.check_rounded, size: 21),
      label: Text(label, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w800,
        fontFamily: PebbleTypography.body,
      )),
    ),
  );
}
