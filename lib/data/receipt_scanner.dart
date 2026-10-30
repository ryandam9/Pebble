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
    final datePattern = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b');
    final totalPattern = RegExp(
      r'\b(?:grand\s+total|total\s+(?:amount|due|paid)?|amount\s+paid|balance\s+due)\s*[:=]?\s*(?:AUD)?\s*\$?\s*([\d,]+\.\d{2})\b',
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
    // Prefer the last explicitly labelled total, ignoring subtotals and "total savings".
    for (final line in lines.reversed) {
      if (RegExp(r'\b(?:sub\s*total|subtotal|total\s+savings)\b', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      final match = totalPattern.firstMatch(line);
      if (match != null) {
        total = parseAmount(match.group(1)!);
        if (total != null) break;
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

  Future<ReceiptDraft?> pickAndRecognize(ImageSource source) async {
    final photo = await _picker.pickImage(source: source, maxWidth: 2000, imageQuality: 90);
    if (photo == null) return null;
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
