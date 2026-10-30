import 'package:flutter_test/flutter_test.dart';
import 'package:pebble/core/formatters.dart';

void main() {
  test('Pebble uses Australian money precision', () {
    expect(amountToCents('48.75'), 4875);
    expect(money(4875), contains('48.75'));
  });
}
