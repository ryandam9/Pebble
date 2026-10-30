import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pebble/data/receipt_scanner.dart';

void main() {
  const parser = ReceiptParser();
  final fakePhoto = XFile('sample.jpg');

  test('extracts labelled total, date and GST', () {
    final draft = parser.parse(fakePhoto, r'''
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

  // Text read by ML Kit from a real card-terminal slip (labels and values in
  // separate columns, so the total's amount comes many lines after its label).
  test('card terminal slip: dotted date and total in a separate column', () {
    final draft = parser.parse(fakePhoto, '''
ANZ STAFF CLUB AUSTRAL IA
BU ILD ING C, 833 COLL INS
DOCKLANDS VIC 3008
Purchase
VISA Contactless
Visa Credit
XXXXXXXXXXXX0000 / 0
Account Type:
02.10. 2026
Auth. Code:
ATC:
00000C00
Credit
09:43: 54
Total -EFT AUD:
1111
22222222
28
A0000000000000
33333
0600
01/0A
29.90
''');
    expect(draft.merchant, 'ANZ STAFF CLUB AUSTRAL IA');
    expect(draft.date, DateTime(2026, 10, 2));
    expect(draft.totalCents, 2990);
  });

  test('a total label with no amount after it gives no total', () {
    final draft = parser.parse(fakePhoto, 'SHOP\n01/10/2026\nCoffee 4.50\nTotal:\n1234');
    expect(draft.totalCents, isNull);
  });

  test('times and amounts are not mistaken for dates', () {
    final draft = parser.parse(fakePhoto, 'SHOP\n09:43:54\nTOTAL 12.50');
    expect(draft.date, isNull);
    expect(draft.totalCents, 1250);
  });

  test('total label with extra words before the amount', () {
    final draft = parser.parse(fakePhoto, 'ANZ STAFF CLUB\n02.10. 2026\n01/0A\nTotal -EFT AUD: 29.90');
    expect(draft.totalCents, 2990);
    expect(draft.date, DateTime(2026, 10, 2));
  });

  test('"total includes GST" is GST, not the total', () {
    final draft = parser.parse(fakePhoto, 'COLES\n30/10/2026\nTOTAL \$48.75\nTOTAL INCLUDES GST \$4.43');
    expect(draft.totalCents, 4875);
    expect(draft.taxCents, 443);
  });

  test('"Total (inc GST)" is the total', () {
    final draft = parser.parse(fakePhoto, 'CAFE\n30/10/2026\nTotal (inc GST) \$12.00\nGST 1.09');
    expect(draft.totalCents, 1200);
    expect(draft.taxCents, 109);
  });
}
