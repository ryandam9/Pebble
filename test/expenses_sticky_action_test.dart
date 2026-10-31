import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pebble/data/pebble_database.dart';
import 'package:pebble/data/pebble_store.dart';
import 'package:pebble/ui/screens/expenses_screen.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('en_AU'));

  testWidgets('Add expense remains outside the scrolling history', (tester) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = PebbleStore(PebbleDatabase(NativeDatabase.memory()))..start();
    addTearDown(store.dispose);
    var opened = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ExpensesScreen(
        store: store,
        onAdd: () => opened = true,
        onEdit: (_) {},
      )),
    ));
    await tester.pumpAndSettle();

    final action = find.text('Add expense');
    expect(action, findsOneWidget);
    // The action must not be part of PebblePage's scrolling ListView.
    expect(find.ancestor(of: action, matching: find.byType(ListView)),
      findsNothing);

    // The primary action remains tappable even on an empty month.
    await tester.tap(action);
    expect(opened, isTrue);
  });
}
