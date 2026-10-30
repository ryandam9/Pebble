import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../core/formatting.dart';

class ReceiptDraft {
  const ReceiptDraft({
    required this.image,
    required this.rawText,
    this.merchant,
    this.date,
    this.totalCents,
    this.taxCents,
  });
  final XFile image;
  final String rawText;
  final String? merchant;
  final DateTime? date;
  final int? totalCents;
  final int? taxCents;
}

class ReceiptParser {
  const ReceiptParser();

  ReceiptDraft parse(XFile image, String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((text) => text.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final merchant = lines.isEmpty ? null : lines.first;
    DateTime? date;
    int? total;
    int? gst;
    // Day first, separated by / - or . (card terminals print 02.10.2026).
    // OCR sometimes adds spaces around separators: "02.10. 2026".
    final datePattern = RegExp(r'\b(\d{1,2})\s*[/.-]\s*(\d{1,2})\s*[/.-]\s*(\d{2,4})\b');
    // A total label, up to 20 non-digit characters ("amount due:", "-EFT AUD:",
    // "(inc GST) $"), then the amount.
    final totalPattern = RegExp(
      r'\b(?:total|amount\s+paid|balance\s+due)\b[^\d]{0,20}?([\d,]+\.\d{2})\b',
      caseSensitive: false,
    );
    final taxPattern = RegExp(
      r'\b(?:gst|tax)\s*[:=]?\s*\$?\s*([\d,]+\.\d{2})\b',
      caseSensitive: false,
    );
    for (final line in lines) {
      if (date == null) {
        final match = datePattern.firstMatch(line);
        if (match != null) {
          var year = int.parse(match.group(3)!);
          if (year < 100) year += year <= 69 ? 2000 : 1900;
          final month = int.parse(match.group(2)!);
          final day = int.parse(match.group(1)!);
          final parsed = DateTime(year, month, day);
          if (parsed.year == year && parsed.month == month && parsed.day == day) date = parsed;
        }
      }
      final taxMatch = taxPattern.firstMatch(line);
      if (taxMatch != null) gst = parseAmount(taxMatch.group(1)!);
    }
    // Lines that mention "total" but aren't the amount paid, e.g.
    // "TOTAL INCLUDES GST $4.43" or "Total savings 3.00".
    final notTotal = RegExp(
      r'\b(?:sub\s*total|subtotal|total\s+savings|total\s+(?:gst|tax)|includes?\s+(?:gst|tax))\b',
      caseSensitive: false,
    );
    // Prefer the last explicitly labelled total, ignoring subtotals and "total savings".
    for (final line in lines.reversed) {
      if (notTotal.hasMatch(line)) continue;
      final match = totalPattern.firstMatch(line);
      if (match != null) {
        total = parseAmount(match.group(1)!);
        if (total != null) break;
      }
    }
    // Two-column receipts (e.g. card terminal slips) are read label column
    // first, so "Total AUD:" and its amount end up on different lines. Use the
    // first line after the last total label that is only an amount.
    if (total == null) {
      final totalLabel = RegExp(r'\b(?:total|amount\s+paid|balance\s+due)\b', caseSensitive: false);
      final amountLine = RegExp(r'^(?:AUD)?\s*\$?\s*([\d,]+\.\d{2})$', caseSensitive: false);
      final labelIndex = lines.lastIndexWhere((line) => totalLabel.hasMatch(line) && !notTotal.hasMatch(line));
      if (labelIndex >= 0) {
        for (final line in lines.skip(labelIndex + 1)) {
          final match = amountLine.firstMatch(line);
          if (match != null) {
            total = parseAmount(match.group(1)!);
            break;
          }
        }
      }
    }
    return ReceiptDraft(
      image: image,
      rawText: rawText,
      merchant: merchant,
      date: date,
      totalCents: total,
      taxCents: gst,
    );
  }
}

/// OCR is performed on the device; a scan must be reviewed before database save.
class ReceiptScanner {
  ReceiptScanner({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  /// ML Kit text recognition only ships for Android and iOS.
  static bool get supportsOcr => Platform.isAndroid || Platform.isIOS;

  /// image_picker can only open a camera on mobile; desktop gets a file chooser.
  static bool get supportsCamera => Platform.isAndroid || Platform.isIOS;

  Future<ReceiptDraft?> pickAndRecognize(ImageSource source) async {
    final photo = await _picker.pickImage(source: source, maxWidth: 2000, imageQuality: 90);
    if (photo == null) return null;
    // Without OCR the user enters every field by hand from the attached image.
    if (!supportsOcr) return ReceiptDraft(image: photo, rawText: '');
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final image = InputImage.fromFilePath(photo.path);
      final text = await recognizer.processImage(image);
      return const ReceiptParser().parse(photo, text.text);
    } finally {
      await recognizer.close();
    }
  }
}
