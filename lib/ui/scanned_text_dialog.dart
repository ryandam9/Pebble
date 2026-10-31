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
      // Long receipts would otherwise stretch the dialog to the full screen.
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
      title: const Text('Scanned text'),
      content: SizedBox(
        width: double.maxFinite,
        // Stretch so the text area, and its scrollbar, span the dialog's full
        // width rather than only the longest line.
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(lineCount == 1 ? '1 line' : '$lineCount lines',
            style: const TextStyle(fontSize: 12, color: PebbleColors.muted)),
          const SizedBox(height: 8),
          Flexible(child: _ScrollingText(rawText.isEmpty ? '(no text detected)' : rawText)),
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

/// The text in its own scroll area, with a scrollbar that stays visible so
/// it's clear when there is more to read.
class _ScrollingText extends StatefulWidget {
  const _ScrollingText(this.text);
  final String text;

  @override
  State<_ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<_ScrollingText> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        // Keeps the text clear of the scrollbar.
        padding: const EdgeInsets.only(right: 12),
        child: SelectableText(
          widget.text,
          key: const Key('scannedTextBody'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
        ),
      ),
    );
  }
}
