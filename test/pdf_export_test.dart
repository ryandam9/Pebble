import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:pebble/data/pdf_export.dart';

ByteData _font(String name) =>
    ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync());

void main() {
  setUpAll(() => initializeDateFormatting('en_AU'));

  test('exports a summary plus one page per expense with its pictures', () async {
    final picture = Uint8List.fromList(img.encodeJpg(img.Image(width: 40, height: 60)));
    final pdf = await buildExpensesPdf(
      [
        ExportExpense(
          date: DateTime(2026, 10, 30), amountCents: 4250,
          description: 'Groceries', category: 'Food', merchant: 'Woolworths',
          paymentMethod: 'Card', notes: 'Weekly shop',
          address: 'Woolworths, 727 Collins St, Docklands VIC 3008',
          map: picture, receipt: picture),
        ExportExpense(
          date: DateTime(2026, 10, 2), amountCents: 1200,
          description: 'Coffee’s on me · café', category: 'Other'),
      ],
      font: _font('PlusJakartaSans-Regular.ttf'),
      headingFont: _font('Fraunces-Regular.ttf'),
      generatedAt: DateTime(2026, 11, 1),
    );
    final text = String.fromCharCodes(pdf.take(5));
    expect(text, '%PDF-');
    final pages = RegExp(r'/Type\s*/Page\b').allMatches(String.fromCharCodes(pdf)).length;
    // The summary, then a page only for the expense with pictures.
    expect(pages, 2);
    expect(RegExp(r'/Subtype\s*/Image').allMatches(String.fromCharCodes(pdf)).length,
      greaterThanOrEqualTo(1));
  });

  test('an empty export still makes a valid PDF', () async {
    final pdf = await buildExpensesPdf(const [],
      font: _font('PlusJakartaSans-Regular.ttf'),
      headingFont: _font('Fraunces-Regular.ttf'),
      generatedAt: DateTime(2026, 11, 1));
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
  });
}
