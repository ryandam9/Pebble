import 'dart:ui' show FontFeature;

/// Centralised type families for Pebble's watercolor and finance UI.
///
/// Downloaded during scripts/bootstrap.sh, bundled with the application,
/// and available without a network connection after installation.
abstract final class PebbleTypography {
  static const body = 'PlusJakartaSans';
  static const editorial = 'Fraunces';

  /// Equal-width digits help expense amounts align in transaction lists.
  static const tabularFigures = <FontFeature>[FontFeature.tabularFigures()];
}
