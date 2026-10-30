import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pebble/data/expense_location.dart';
import 'package:pebble/ui/expense_map_preview.dart';
import 'package:pebble/ui/watercolor.dart';

void main() {
  testWidgets('watercolor expense controls remain actionable', (tester) async {
    var saved = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Column(children: [
        WatercolorPanel(
          tint: Watercolor.sky,
          child: const Text('Amount (AUD)'),
        ),
        WatercolorSave(
          label: 'Save expense',
          onPressed: () => saved = true,
        ),
      ]),
    )));
    expect(find.text('Amount (AUD)'), findsOneWidget);
    await tester.tap(find.text('Save expense'));
    expect(saved, isTrue);
  });

  testWidgets('address-only location never invents a map coordinate', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: ExpenseMapPreview(
        location: ExpenseLocation(address: 'Docklands VIC'),
        onOpen: _nothing,
      ),
    )));
    expect(find.text('Map preview needs location coordinates'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });
}

void _nothing() {}
