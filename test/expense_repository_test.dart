import 'package:flutter_test/flutter_test.dart';
import 'package:pebble/data/expense_repository.dart';

void main() {
  test('expense maps preserve money, date and category', () {
    final now = DateTime(2026, 10, 30);
    final entry = Expense(
      date: now, amountCents: 4875, description: 'Groceries',
      category: 'Groceries', merchant: 'Woolworths',
      receiptPath: '/private/receipt.jpg',
    );
    final restored = Expense.fromMap({...entry.toMap(), 'id': 3});
    expect(restored.id, 3);
    expect(restored.amountCents, 4875);
    expect(restored.date, now);
    expect(restored.merchant, 'Woolworths');
    expect(restored.receiptPath, '/private/receipt.jpg');
  });
}
