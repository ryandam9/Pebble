import 'dart:io';

import 'package:flutter/material.dart';

/// A receipt preview that opens the full-screen viewer when tapped.
class ReceiptThumbnail extends StatelessWidget {
  const ReceiptThumbnail({required this.file, required this.height, this.fillWidth = false, super.key});
  final File file;
  final double height;
  /// When true, crops the surrounding photo rather than letterboxing it.
  /// The full image is still available in the tap-to-zoom viewer.
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'View receipt full screen',
      child: GestureDetector(
        onTap: () => openReceiptViewer(context, file),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(children: [
            Image.file(file, height: height, width: double.infinity,
              fit: fillWidth ? BoxFit.cover : BoxFit.contain),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.zoom_in, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Tap to enlarge', style: TextStyle(color: Colors.white, fontSize: 11)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

Future<void> openReceiptViewer(BuildContext context, File file) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => ReceiptViewerScreen(file: file),
  ));
}

/// Full-screen receipt: fits the screen first; pinch or double-tap to zoom.
class ReceiptViewerScreen extends StatefulWidget {
  const ReceiptViewerScreen({required this.file, super.key});
  final File file;

  @override
  State<ReceiptViewerScreen> createState() => _ReceiptViewerScreenState();
}

class _ReceiptViewerScreenState extends State<ReceiptViewerScreen> {
  static const _doubleTapScale = 3.0;
  final _transform = TransformationController();
  Offset _tapPosition = Offset.zero;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_transform.value.getMaxScaleOnAxis() > 1.01) {
      _transform.value = Matrix4.identity();
      return;
    }
    // Zoom in around the tapped point.
    final p = _tapPosition;
    _transform.value = Matrix4.identity()
      ..translateByDouble(-p.dx * (_doubleTapScale - 1), -p.dy * (_doubleTapScale - 1), 0, 1)
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Receipt'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        onDoubleTapDown: (details) => _tapPosition = details.localPosition,
        onDoubleTap: _toggleZoom,
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 8,
          child: SizedBox.expand(
            child: Image.file(widget.file, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
