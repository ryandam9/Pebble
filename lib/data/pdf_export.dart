import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/formatting.dart';

/// One expense as it appears in the export, with its pictures already loaded.
class ExportExpense {
  const ExportExpense({
    required this.date,
    required this.amountCents,
    required this.description,
    required this.category,
    this.merchant,
    this.paymentMethod,
    this.notes,
    this.address,
    this.map,
    this.receipt,
  });

  final DateTime date;
  final int amountCents;
  final String description;
  final String category;
  final String? merchant;
  final String? paymentMethod;
  final String? notes;
  final String? address;

  /// PNG or JPEG bytes of the location map, if one could be fetched.
  final Uint8List? map;

  /// JPEG bytes of the receipt photo, already shrunk for the page.
  final Uint8List? receipt;
}

const _ink = PdfColor.fromInt(0xFF182238);
const _muted = PdfColor.fromInt(0xFF728099);
const _blue = PdfColor.fromInt(0xFF287CF5);
const _stroke = PdfColor.fromInt(0xFFE8EEF5);
const _paleBlue = PdfColor.fromInt(0xFFEAF2FF);

/// A PDF of [expenses] (newest first): a summary with a table of every
/// expense, then a page for each one with a map, receipt, location or notes.
/// [font] and [headingFont] are TrueType bytes.
Future<Uint8List> buildExpensesPdf(
  List<ExportExpense> expenses, {
  required ByteData font,
  required ByteData headingFont,
  required DateTime generatedAt,
}) {
  final body = pw.Font.ttf(font);
  final heading = pw.Font.ttf(headingFont);
  final document = pw.Document(
    title: 'Pebble expenses',
    author: 'Pebble',
    creator: 'Pebble',
    theme: pw.ThemeData.withFont(base: body, bold: body, italic: body, boldItalic: body),
  );
  final total = expenses.fold<int>(0, (sum, expense) => sum + expense.amountCents);
  final dates = expenses.map((expense) => expense.date).toList()..sort();
  final range = dates.isEmpty
      ? 'No expenses'
      : '${friendlyDate.format(dates.first)} – ${friendlyDate.format(dates.last)}';

  pw.Widget title(String text, double size) => pw.Text(text,
      style: pw.TextStyle(font: heading, fontSize: size, color: _ink));
  pw.Widget small(String text, {PdfColor color = _muted}) =>
      pw.Text(text, style: pw.TextStyle(fontSize: 9, color: color));

  pw.Widget footer(pw.Context context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 12),
        child: small('Pebble · page ${context.pageNumber} of ${context.pagesCount}'),
      );

  document.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    footer: footer,
    build: (context) => [
      title('Pebble expenses', 26),
      pw.SizedBox(height: 4),
      small('Exported ${friendlyDate.format(generatedAt)}'),
      pw.SizedBox(height: 18),
      pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: _paleBlue, borderRadius: pw.BorderRadius.circular(10)),
        child: pw.Row(children: [
          _stat('Total', formatCents(total), heading),
          _stat('Expenses', '${expenses.length}', heading),
          _stat('Dates', range, heading, flex: 2),
        ]),
      ),
      pw.SizedBox(height: 18),
      if (expenses.isNotEmpty)
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Description', 'Category', 'Payment', 'Amount'],
          data: [
            for (final expense in expenses)
              [
                friendlyDate.format(expense.date),
                expense.merchant == null
                    ? expense.description
                    : '${expense.description}\n${expense.merchant}',
                expense.category,
                expense.paymentMethod ?? '',
                formatCents(expense.amountCents),
              ],
          ],
          border: null,
          headerStyle: pw.TextStyle(fontSize: 9, color: _muted),
          headerDecoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _stroke))),
          cellStyle: const pw.TextStyle(fontSize: 9.5, color: _ink),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          rowDecoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _stroke, width: .5))),
          columnWidths: {
            0: const pw.FixedColumnWidth(68),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(1.4),
            3: const pw.FlexColumnWidth(1.2),
            4: const pw.FixedColumnWidth(64),
          },
          cellAlignment: pw.Alignment.topLeft,
          headerAlignment: pw.Alignment.centerLeft,
          cellAlignments: {4: pw.Alignment.topRight},
          headerAlignments: {4: pw.Alignment.centerRight},
        ),
    ],
  ));

  // An expense with more than the table shows gets its own page, so its map
  // and receipt stay together.
  for (final expense in expenses.where(_hasDetails)) {
    final details = <(String, String)>[
      ('Date', friendlyDate.format(expense.date)),
      ('Category', expense.category),
      if (expense.merchant != null) ('Merchant', expense.merchant!),
      if (expense.paymentMethod != null) ('Payment', expense.paymentMethod!),
      if (expense.address != null) ('Location', expense.address!),
      if (expense.notes != null) ('Notes', expense.notes!),
    ];
    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: footer,
      build: (context) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: title(expense.description, 20)),
          pw.SizedBox(width: 12),
          pw.Text(formatCents(expense.amountCents),
            style: pw.TextStyle(font: heading, fontSize: 20, color: _blue)),
        ]),
        pw.SizedBox(height: 12),
        for (final (label, value) in details)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(width: 70, child: small(label)),
              pw.Expanded(child: pw.Text(value,
                style: const pw.TextStyle(fontSize: 10.5, color: _ink))),
            ]),
          ),
        if (expense.map != null) ...[
          pw.SizedBox(height: 12),
          pw.ClipRRect(
            horizontalRadius: 8, verticalRadius: 8,
            // Shown whole, never cropped: Google's logo and credit must stay.
            child: pw.Image(pw.MemoryImage(expense.map!), fit: pw.BoxFit.contain),
          ),
        ],
        if (expense.receipt != null) ...[
          pw.SizedBox(height: 16),
          small('Receipt'),
          pw.SizedBox(height: 6),
          pw.Center(child: pw.Image(pw.MemoryImage(expense.receipt!),
            height: expense.map != null ? 330 : 540, fit: pw.BoxFit.contain)),
        ],
      ],
    ));
  }
  return document.save();
}

bool _hasDetails(ExportExpense expense) =>
    expense.map != null || expense.receipt != null ||
    expense.address != null || expense.notes != null;

pw.Widget _stat(String label, String value, pw.Font heading, {int flex = 1}) =>
    pw.Expanded(flex: flex, child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(font: heading, fontSize: 15, color: _ink)),
      ],
    ));
