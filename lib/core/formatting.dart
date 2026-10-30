import 'package:intl/intl.dart';

final aud = NumberFormat.currency(locale: 'en_AU', symbol: r'$');
final friendlyDate = DateFormat('d MMM yyyy', 'en_AU');
final monthTitle = DateFormat('MMMM yyyy', 'en_AU');

String formatCents(int cents) => aud.format(cents / 100);

/// Convert AUD entry to integer cents without floating-point arithmetic.
/// Inputs like 20.5, 20.50, $20.50 and 1,250.00 are accepted.
int? parseAmount(String input) {
  final value = input.trim().replaceAll(RegExp(r'[\s,$]'), '');
  if (!RegExp(r'^\d{1,9}(?:\.\d{1,2})?$').hasMatch(value)) {
    return null;
  }
  final parts = value.split('.');
  final whole = int.parse(parts[0]);
  final fractional = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  final cents = whole * 100 + fractional;
  return cents > 0 ? cents : null;
}
