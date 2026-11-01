import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/design.dart';
import '../data/expense_location.dart';
import '../data/google_maps_key.dart';
import '../data/pdf_export.dart';
import '../data/pebble_store.dart';

/// Builds a PDF of every expense, with receipts and maps, and opens the
/// share sheet so it can be saved or sent. Shows progress while it works.
Future<void> exportExpensesPdf(BuildContext context, PebbleStore store) async {
  final progress = ValueNotifier('Preparing…');
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(content: Row(children: [
        const SizedBox(width: 26, height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.6)),
        const SizedBox(width: 18),
        Expanded(child: ValueListenableBuilder(
          valueListenable: progress,
          builder: (_, text, _) => Text(text))),
      ])),
    ),
  ));
  try {
    final expenses = store.expenses;
    final items = <ExportExpense>[];
    for (final (index, entry) in expenses.indexed) {
      progress.value = 'Adding expense ${index + 1} of ${expenses.length}…';
      final location = ExpenseLocation.of(entry);
      final receipt = await store.receiptFile(entry.receiptPath);
      items.add(ExportExpense(
        date: entry.date,
        amountCents: entry.amountCents,
        description: entry.description,
        category: store.categoryNameFor(entry.categoryId),
        merchant: entry.merchant,
        paymentMethod: entry.paymentMethod,
        notes: entry.notes,
        address: location?.address?.trim().isNotEmpty == true ? location!.address!.trim() : null,
        map: location != null && location.hasCoordinates
          ? await _mapImage(location.latitude!, location.longitude!) : null,
        receipt: receipt == null ? null : await _shrinkPhoto(receipt),
      ));
    }
    progress.value = 'Creating PDF…';
    final pdf = await buildExpensesPdf(
      items,
      font: await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
      headingFont: await rootBundle.load('assets/fonts/Fraunces-Regular.ttf'),
      generatedAt: DateTime.now(),
    );
    final now = DateTime.now();
    final stamp = '${now.year}-${_two(now.month)}-${_two(now.day)}';
    final file = File(p.join((await getTemporaryDirectory()).path,
      'pebble-expenses-$stamp.pdf'));
    await file.writeAsBytes(pdf, flush: true);
    navigator.pop();
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Pebble expenses',
      title: 'Pebble expenses',
    ));
  } on Object {
    navigator.pop();
    messenger.showSnackBar(const SnackBar(
      content: Text('Could not create the PDF. Please try again.')));
  } finally {
    progress.dispose();
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

/// A Google map of the spot, or null without a key or a connection.
Future<Uint8List?> _mapImage(double latitude, double longitude) async {
  if (googleMapsKey.isEmpty) return null;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(googleStaticMapUri(
      // The same shape as the PDF's map slot, so it is never cropped.
      latitude: latitude, longitude: longitude, width: 640, height: 232));
    googleAndroidHeaders().forEach(request.headers.set);
    final response = await request.close().timeout(const Duration(seconds: 15));
    final bytes = await consolidateHttpClientResponseBytes(response)
        .timeout(const Duration(seconds: 15));
    final type = response.headers.contentType?.primaryType;
    return response.statusCode == 200 && type == 'image' ? bytes : null;
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// The receipt photo at most 1400 px wide, as a JPEG, so the PDF stays a
/// sensible size. Null when the file can't be read as an image.
Future<Uint8List?> _shrinkPhoto(File file) async {
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(await file.readAsBytes());
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = math.min(descriptor.width, 1400);
    final codec = await descriptor.instantiateCodec(targetWidth: width);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final size = (image.width, image.height);
    image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    if (rgba == null) return null;
    return await Isolate.run(() => img.encodeJpg(
      img.Image.fromBytes(
        width: size.$1, height: size.$2,
        bytes: rgba.buffer, numChannels: 4, order: img.ChannelOrder.rgba),
      quality: 80,
    ));
  } on Object {
    return null;
  }
}

/// Settings row that starts the export.
class ExportPdfRow extends StatelessWidget {
  const ExportPdfRow({required this.store, super.key});
  final PebbleStore store;

  @override
  Widget build(BuildContext context) {
    final count = store.expenses.length;
    return InkWell(
      key: const Key('exportPdf'),
      borderRadius: BorderRadius.circular(10),
      onTap: count == 0 ? null : () => exportExpensesPdf(context, store),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          const Icon(Icons.picture_as_pdf_outlined, color: PebbleColors.blue),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Export to PDF', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(count == 0 ? 'No expenses to export yet'
                : 'All $count expenses with receipts and maps',
              style: const TextStyle(fontSize: 12, color: PebbleColors.muted)),
          ])),
          if (count > 0) const Icon(Icons.ios_share_rounded, color: PebbleColors.muted),
        ]),
      ),
    );
  }
}
