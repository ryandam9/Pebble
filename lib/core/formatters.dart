import 'package:intl/intl.dart';

String money(int cents) =>
    NumberFormat.currency(locale: 'en_AU', symbol: r'$', decimalDigits: 2)
        .format(cents / 100);

int? amountToCents(String input) {
  final clean = input.trim().replaceAll(',', '').replaceAll(r'$', '');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(clean)) return null;
  final parts = clean.split('.');
  final dollars = int.tryParse(parts[0]);
  if (dollars == null) return null;
  final fractional = parts.length == 2
      ? int.parse(parts[1].padRight(2, '0'))
      : 0;
  final cents = dollars * 100 + fractional;
  return cents > 0 ? cents : null;
}
