import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble/data/pebble_database.dart';

void main() {
  late PebbleDatabase database;

  setUp(() => database = PebbleDatabase(NativeDatabase.memory()));
  tearDown(() async => database.close());

  test('persists, updates and deletes expenses', () async {
    final date = DateTime(2026, 10, 30);
    final entry = ExpenseEntriesCompanion.insert(
      id: 'first',
      date: date,
      amountCents: 4875,
      description: 'Supermarket',
      createdAt: date,
    );
    await database.saveEntry(entry);
    var rows = await database.watchExpenses().first;
    expect(rows, hasLength(1));
    expect(rows.single.amountCents, 4875);
    expect(rows.single.category, 'Other');

    await database.saveEntry(ExpenseEntriesCompanion.insert(
      id: 'first',
      date: date,
      amountCents: 1500,
      description: 'Corrected',
      createdAt: date,
    ));
    rows = await database.watchExpenses().first;
    expect(rows, hasLength(1));
    expect(rows.single.amountCents, 1500);

    await database.removeEntry('first');
    expect(await database.watchExpenses().first, isEmpty);
  });
}
