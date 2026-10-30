import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pebble/data/pebble_database.dart';
import 'package:pebble/data/pebble_store.dart';
import 'package:pebble/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => initializeDateFormatting('en_AU'));

  testWidgets('user can add a manual expense and see it in history', (tester) async {
    final store = PebbleStore(PebbleDatabase(NativeDatabase.memory()))..start();
    addTearDown(store.dispose);

    await tester.pumpWidget(PebbleApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Pebble'), findsOneWidget);

    await tester.tap(find.text('Add expense').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('amountInput')), '48.75');
    await tester.enterText(find.byKey(const Key('descriptionInput')), 'Groceries');
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(find.text('Expenses'), findsWidgets);
    expect(find.text('Groceries'), findsWidgets);
    expect(find.textContaining('48.75'), findsWidgets);
  });
}
