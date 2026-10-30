import 'package:flutter_test/flutter_test.dart';
import 'package:pebble/core/formatters.dart';

void main() {
  test('parses whole dollars and cents without floating point rounding', () {
    expect(amountToCents('12'), 1200);
    expect(amountToCents('12.3'), 1230);
    expect(amountToCents(r'$1,234.56'), 123456);
  });

  test('rejects malformed and nonpositive amounts', () {
    for (final input in ['', '0', '-5', '12.345', 'hello', '1e5']) {
      expect(amountToCents(input), isNull, reason: input);
    }
  });

  test('formats Australian dollars', () {
    expect(money(123456), contains('1,234.56'));
  });
}
