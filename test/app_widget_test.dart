import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble/data/expense_repository.dart';
import 'package:pebble/main.dart';

class FakeExpenseStore implements ExpenseStore {
  final List<Expense> values = [];
  @override
  Future<List<Expense>> all() async => List.of(values);
  @override
  Future<int> add(Expense expense) async { values.add(expense); return values.length; }
  @override
  Future<void> delete(int id) async { values.removeAt(id - 1); }
}

void main() {
  testWidgets('home is empty and manual expense screen opens', (tester) async {
    await tester.pumpWidget(PebbleApp(store: FakeExpenseStore()));
    await tester.pumpAndSettle();
    expect(find.text('No expenses yet. Add your first one!'), findsWidgets);
    await tester.tap(find.text('Add expense').first);
    await tester.pumpAndSettle();
    expect(find.text('Save expense'), findsOneWidget);
    expect(find.text('AMOUNT (AUD)'), findsOneWidget);
  });

  testWidgets('home includes all five navigation items', (tester) async {
    await tester.pumpWidget(PebbleApp(store: FakeExpenseStore()));
    await tester.pumpAndSettle();
    for (final label in ['Home', 'Expenses', 'Scan', 'Insights', 'Settings']) {
      expect(find.byWidgetPredicate((widget) => widget is NavigationDestination &&
        widget.label == label), findsOneWidget);
    }
  });
}
