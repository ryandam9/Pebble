import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pebble/data/receipt_scanner.dart';

void main() {
  const parser = ReceiptParser();
  final fakePhoto = XFile('sample.jpg');

  test('extracts labelled total, date and GST', () {
    final draft = parser.parse(fakePhoto, '''
WOOLWORTHS
Market Street
30/10/2026
Milk 3.90
Bread 4.80
Subtotal 46.60
GST 2.15
TOTAL $48.75
Thank you
''');
    expect(draft.merchant, 'WOOLWORTHS');
    expect(draft.date, DateTime(2026, 10, 30));
    expect(draft.totalCents, 4875);
    expect(draft.taxCents, 215);
  });

  test('unlabelled amounts are not guessed as totals', () {
    final draft = parser.parse(fakePhoto, 'LOCAL CAFE\n31/10/2026\nFlat white 5.50');
    expect(draft.totalCents, isNull);
  });

  test('invalid calendar dates are not accepted', () {
    final draft = parser.parse(fakePhoto, 'LOCAL CAFE\n31/02/2026\nTOTAL 5.50');
    expect(draft.date, isNull);
  });
}
