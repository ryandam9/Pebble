import 'package:flutter_test/flutter_test.dart';
import 'package:pebble/core/formatting.dart';

void main() {
  group('parseAmount', () {
    test('preserves cents exactly', () {
      expect(parseAmount('20'), 2000);
      expect(parseAmount('20.5'), 2050);
      expect(parseAmount('20.05'), 2005);
      expect(parseAmount(r'$1,250.00'), 125000);
    });

    test('rejects invalid or empty input', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('0'), isNull);
      expect(parseAmount('-5'), isNull);
      expect(parseAmount('NaN'), isNull);
      expect(parseAmount('1.005'), isNull);
    });
  });
}
