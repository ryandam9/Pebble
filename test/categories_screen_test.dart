import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pebble/data/pebble_database.dart';
import 'package:pebble/data/pebble_store.dart';
import 'package:pebble/ui/screens/categories_screen.dart';
import 'package:pebble/ui/screens/editor_screen.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('en_AU'));

  Future<PebbleStore> pumpWith(WidgetTester tester, Widget Function(PebbleStore) screen) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = PebbleStore(PebbleDatabase(NativeDatabase.memory()))..start();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: screen(store)));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('add, rename and delete a category', (tester) async {
    final store = await pumpWith(tester, (store) => CategoriesScreen(store: store));
    expect(find.text('Groceries'), findsOneWidget);

    // Add
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('categoryNameInput')), 'Travel');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Travel'), findsOneWidget);
    expect(store.categoryNames, contains('Travel'));

    // Duplicate names are rejected
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('categoryNameInput')), 'travel');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('A category with this name already exists'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Rename
    await tester.tap(find.text('Travel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('categoryNameInput')), 'Holidays');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Holidays'), findsOneWidget);
    expect(find.text('Travel'), findsNothing);

    // Delete (with confirmation)
    await tester.tap(find.text('Holidays'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No expenses use this category.'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Holidays'), findsNothing);
    expect(store.categoryNames, isNot(contains('Holidays')));
  });

  testWidgets('Other offers no delete and keeps its name', (tester) async {
    await pumpWith(tester, (store) => CategoriesScreen(store: store));
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    final field = tester.widget<TextField>(find.descendant(
      of: find.byKey(const Key('categoryNameInput')), matching: find.byType(TextField)));
    expect(field.enabled, isFalse);
  });

  testWidgets('New tile in the expense editor creates and selects a category', (tester) async {
    await pumpWith(tester, (store) => EditorScreen(store: store, onSwitchTab: (_) {}));
    // Bento Studio uses a horizontal carousel rather than a vertical grid.
    final carousel = find.byKey(const Key('bentoCategories'));
    await tester.ensureVisible(carousel);
    await tester.drag(carousel, const Offset(-1050, 0));
    await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('newCategoryTile')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('categoryNameInput')), 'Pets');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The new category is selected (its tile has a visible border).
    final tile = find.ancestor(of: find.text('Pets'), matching: find.byType(Container)).first;
    final decoration = tester.widget<Container>(tile).decoration! as BoxDecoration;
    expect((decoration.border! as Border).top.color, isNot(Colors.transparent));
  });
}
