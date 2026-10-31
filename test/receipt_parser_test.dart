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

  // Text read by ML Kit from a supermarket receipt. The label column comes
  // first, then every price, so "Total $" is followed by the item prices
  // before the total itself.
  test('supermarket receipt: total is the largest amount after the label', () {
    final draft = parser.parse(fakePhoto, r'''
Description
Phone Number D3 9888 2399
OPEN 7 DAYS A WEEK
*CHECKOUT BAG OXO BIO 40UM
CHICKEN DRUMSTICKS
*DOVE B0DY BAR EXFOL
RITCHIES FUEL OFFER
DOCKET DEAL
SUNNY 100/200 C0OKED PD PRAWNS
BEERENBRG SCE PEPPRCORN
HNZ MAYO PERI PERI SOZ
BAN/BT SSCRN SPRT SPR50+ #200ML
Promot i on saving $3.50
*SWISSPERS CTN TIP PAP STM#
YUMMY PEARL BARLEY
HYDROPONIC CORIANDER
CELERY TRIMMED
TOMATOES TRUSS-HYDRO
BANANAS
BEETROOT
0.705kg NET @ $3.89/kg
Promotion saving $3.60
ONIONS RED LOOSE
0.930kg NET $5.99/kg
2@ $2.99
0.590kg NET $4.99/kg
0.670kg NET 9 $5.99/kg
TOTAL (Inc GST)
16 Items
Paid by EFTPOS
00000000
426557 886
00000000 0
Credit
Total $
0.15*
5.65
10.00x
9.99
6.40
5.80
21.50
1.20*
2.29
5.98
4.99
2.74
5.57
2.94
4.01
$89.21
$89.21
''');
    expect(draft.totalCents, 8921);
  });
}
