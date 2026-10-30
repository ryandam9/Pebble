import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble/ui/receipt_viewer.dart';

void main() {
  testWidgets('tapping a receipt preview opens the full-screen viewer', (tester) async {
    final file = File('receipt.png'); // Never read: the test only checks navigation.
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ReceiptThumbnail(file: file, height: 200),
    )));
    expect(find.text('Tap to enlarge'), findsOneWidget);

    await tester.tap(find.byType(ReceiptThumbnail));
    await tester.pumpAndSettle();
    expect(find.byType(ReceiptViewerScreen), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ReceiptViewerScreen), findsNothing);
  });
}
