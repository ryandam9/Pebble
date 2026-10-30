import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pebble/data/pebble_database.dart';
import 'package:pebble/data/pebble_store.dart';
import 'package:pebble/ui/screens/editor_screen.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('en_AU'));

  testWidgets('editing an expense without a payment method keeps it unset', (tester) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = PebbleStore(PebbleDatabase(NativeDatabase.memory()))..start();
    addTearDown(store.dispose);

    // Receipt-screen saves have no payment method.
    await tester.runAsync(() => store.save(
      date: DateTime(2026, 10, 30), amountCents: 1250, description: 'Coffee', category: 'Food'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) =>
      TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<int>(builder: (_) =>
          EditorScreen(store: store, entry: store.expenses.single, onSwitchTab: (_) {}))),
        child: const Text('open'),
      )))));
    await tester.pumpAndSettle();
    expect(store.expenses.single.paymentMethod, isNull);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Not set'), findsOneWidget);

    // Change something else, so the test proves the save really happened.
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byKey(const Key('descriptionInput')), 150, scrollable: scroll);
    await tester.enterText(find.byKey(const Key('descriptionInput')), 'Flat white');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Save expense'), 250, scrollable: scroll);
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(store.expenses.single.description, 'Flat white');
    expect(store.expenses.single.paymentMethod, isNull);
  });
}
