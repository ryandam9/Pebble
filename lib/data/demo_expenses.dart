import 'expense_repository.dart';

/// Visual verification fixture, enabled only by --dart-define=PEBBLE_DEMO=true.
/// Runs against the same SQLite repository as a normal installation.
Future<void> seedDemoExpenses(ExpenseStore store) async {
  if ((await store.all()).isNotEmpty) return;

  final now = DateTime.now();
  final entries = [
    (day: 29, merchant: 'Woolworths', description: 'Weekly groceries', category: 'Food', cents: 12700),
    (day: 28, merchant: 'Metro', description: 'Public transport', category: 'Travel', cents: 12000),
    (day: 27, merchant: 'Cafe Central', description: 'Lunch with friends', category: 'Food', cents: 28500),
    (day: 26, merchant: 'Amazon', description: 'Household items', category: 'Shopping', cents: 17500),
    (day: 25, merchant: 'Coles Express', description: 'Fuel', category: 'Travel', cents: 13600),
    (day: 24, merchant: 'Target', description: 'Clothes', category: 'Shopping', cents: 13500),
    (day: 23, merchant: 'Energy Australia', description: 'Electricity', category: 'Bills', cents: 18000),
    (day: 22, merchant: 'Internet', description: 'Internet subscription', category: 'Bills', cents: 9000),
  ];
  for (final entry in entries) {
    await store.add(Expense(
      date: DateTime(now.year, now.month, entry.day),
      amountCents: entry.cents,
      merchant: entry.merchant,
      description: entry.description,
      category: entry.category,
    ));
  }
}
