import 'expense_repository.dart';

/// Visual verification fixture, enabled only by --dart-define=PEBBLE_DEMO=true.
/// Runs against the same SQLite repository as a normal installation.
Future<void> seedDemoExpenses(ExpenseStore store) async {
  if ((await store.all()).isNotEmpty) return;

  final now = DateTime.now();
  final entries = [
    (day: 29, merchant: 'Woolworths', description: 'Weekly groceries', category: 'Food', cents: 4875),
    (day: 28, merchant: 'Metro', description: 'Public transport', category: 'Travel', cents: 1590),
    (day: 27, merchant: 'Cafe Central', description: 'Coffee', category: 'Food', cents: 820),
    (day: 26, merchant: 'Amazon', description: 'Household items', category: 'Shopping', cents: 3240),
    (day: 25, merchant: 'Fuel', description: 'Petrol', category: 'Travel', cents: 7200),
    (day: 24, merchant: 'Target', description: 'Clothes', category: 'Shopping', cents: 27760),
    (day: 23, merchant: 'Energy Australia', description: 'Electricity', category: 'Bills', cents: 18000),
    (day: 22, merchant: 'Internet', description: 'Internet subscription', category: 'Bills', cents: 9000),
    (day: 21, merchant: 'Restaurant', description: 'Weekend dining', category: 'Food', cents: 35505),
    (day: 20, merchant: 'Myki', description: 'Travel card top-up', category: 'Travel', cents: 16810),
  ];
  // Populate five earlier months so the actual Linux Insights screenshot
  // demonstrates the six-month chart instead of five empty bars.
  final historical = [98000, 112000, 103200, 124800, 106500];
  for (var i = 0; i < historical.length; i++) {
    await store.add(Expense(
      date: DateTime(now.year, now.month - 5 + i, 15),
      amountCents: historical[i],
      description: 'Representative historical spending',
      category: 'Other',
      merchant: 'Sample month ${i + 1}',
    ));
  }

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
