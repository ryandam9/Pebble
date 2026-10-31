import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pebble/core/formatting.dart';
import 'package:pebble/data/pebble_database.dart';
import 'package:pebble/data/pebble_store.dart';
import 'package:pebble/ui/screens/home_screen.dart';
import 'package:pebble/ui/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => initializeDateFormatting('en_AU'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('monthly budget defaults to $2,000 and persists in exact AUD cents', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = PebbleStore(PebbleDatabase(NativeDatabase.memory()),
      preferences: preferences);
    expect(store.monthlyBudgetCents, 200000);
    await store.setMonthlyBudgetCents(258075);
    expect(store.monthlyBudgetCents, 258075);
    expect(preferences.getInt('monthlyBudgetCents'), 258075);
    store.dispose();

    final reopened = PebbleStore(PebbleDatabase(NativeDatabase.memory()),
      preferences: preferences);
    expect(reopened.monthlyBudgetCents, 258075);
    reopened.dispose();
  });

  test('invalid and corrupt budgets are rejected without replacing saved setting', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = PebbleStore(PebbleDatabase(NativeDatabase.memory()),
      preferences: preferences);
    await store.setMonthlyBudgetCents(177750);
    await expectLater(store.setMonthlyBudgetCents(0), throwsArgumentError);
    await expectLater(store.setMonthlyBudgetCents(-1), throwsArgumentError);
    await expectLater(
      store.setMonthlyBudgetCents(PebbleStore.maxMonthlyBudgetCents + 1),
      throwsArgumentError);
    expect(store.monthlyBudgetCents, 177750);
    store.dispose();

    await preferences.setString('monthlyBudgetCents', 'not an integer');
    final next = PebbleStore(PebbleDatabase(NativeDatabase.memory()),
      preferences: preferences);
    expect(next.monthlyBudgetCents, PebbleStore.defaultMonthlyBudgetCents);
    next.dispose();
  });

  testWidgets('Settings updates the budget and Home immediately reflects it', (tester) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = await SharedPreferences.getInstance();
    final store = PebbleStore(PebbleDatabase(NativeDatabase.memory()),
      preferences: preferences)..start();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SettingsScreen(store: store),
    )));
    await tester.pumpAndSettle();

    final budgetRow = find.text('Monthly budget');
    expect(budgetRow, findsOneWidget);
    await tester.ensureVisible(budgetRow);
    await tester.pumpAndSettle();
    await tester.tap(budgetRow);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('monthlyBudgetDialog')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('monthlyBudgetInput')), '2,350.75');
    await tester.tap(find.byKey(const Key('saveMonthlyBudget')));
    await tester.pumpAndSettle();
    expect(store.monthlyBudgetCents, 235075);
    expect(preferences.getInt('monthlyBudgetCents'), 235075);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomeScreen(
      store: store,
      onAdd: () {},
      onScan: () {},
      onExpenses: () {},
    ))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('monthlyBudgetSummary')), findsOneWidget);
    expect(find.textContaining(formatCents(235075)), findsWidgets);
  });

  testWidgets('over budget is shown instead of hiding the deficit', (tester) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = await SharedPreferences.getInstance();
    final store = PebbleStore(PebbleDatabase(NativeDatabase.memory()),
      preferences: preferences)..start();
    addTearDown(store.dispose);
    await store.setMonthlyBudgetCents(1000);
    await store.save(
      date: DateTime.now(),
      amountCents: 2550,
      description: 'Groceries',
      category: 'Groceries',
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomeScreen(
      store: store,
      onAdd: () {},
      onScan: () {},
      onExpenses: () {},
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('over budget'), findsOneWidget);
    expect(find.textContaining(formatCents(1550)), findsWidgets);
  });
}
