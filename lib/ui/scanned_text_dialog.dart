import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design.dart';

/// Debug view of the full text ML Kit read from a receipt, exactly as the
/// receipt parser receives it.
Future<void> showScannedTextDialog(BuildContext context, String rawText) {
  final lineCount = rawText.split('\n').where((line) => line.trim().isNotEmpty).length;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Scanned text'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lineCount == 1 ? '1 line' : '$lineCount lines',
            style: const TextStyle(fontSize: 12, color: PebbleColors.muted)),
          const SizedBox(height: 8),
          Flexible(child: SingleChildScrollView(
            child: SelectableText(
              rawText.isEmpty ? '(no text detected)' : rawText,
              key: const Key('scannedTextBody'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
            ),
          )),
        ]),
      ),
      actions: [
        TextButton.icon(
          onPressed: rawText.isEmpty ? null : () async {
            await Clipboard.setData(ClipboardData(text: rawText));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanned text copied')));
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy'),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    ),
  );
}
