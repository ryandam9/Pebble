import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble/data/pebble_database.dart';

void main() {
  late PebbleDatabase database;

  Future<void> addExpense(String id, String category) {
    final date = DateTime(2026, 10, 30);
    return database.saveEntry(ExpenseEntriesCompanion.insert(
      id: id, date: date, amountCents: 1000, description: 'Test',
      category: Value(category), createdAt: date,
    ));
  }

  Future<Map<String, String>> categoryById() async =>
      {for (final e in await database.watchExpenses().first) e.id: e.category};

  group('new database', () {
    setUp(() => database = PebbleDatabase(NativeDatabase.memory()));
    tearDown(() async => database.close());

    test('starts with the default categories, Other last', () async {
      final names = (await database.watchCategories().first).map((c) => c.name).toList();
      expect(names, defaultCategories.map((c) => c.$1).toList());
    });

    test('new categories appear before Other', () async {
      await database.addCategory(name: 'Travel', iconKey: 'flight', colorKey: 'teal');
      final names = (await database.watchCategories().first).map((c) => c.name).toList();
      expect(names.sublist(names.length - 2), ['Travel', otherCategory]);
    });

    test('renaming a category renames it on its expenses', () async {
      await addExpense('a', 'Food');
      await addExpense('b', 'Bills');
      final food = (await database.watchCategories().first).firstWhere((c) => c.name == 'Food');
      await database.updateCategory(food.id, name: 'Dining', iconKey: 'coffee', colorKey: 'brown');
      expect(await categoryById(), {'a': 'Dining', 'b': 'Bills'});
      final dining = (await database.watchCategories().first).firstWhere((c) => c.id == food.id);
      expect((dining.name, dining.iconKey, dining.colorKey), ('Dining', 'coffee', 'brown'));
    });

    test('deleting a category moves its expenses to Other', () async {
      await addExpense('a', 'Health');
      await addExpense('b', 'Bills');
      final health = (await database.watchCategories().first).firstWhere((c) => c.name == 'Health');
      await database.deleteCategory(health.id);
      expect(await categoryById(), {'a': otherCategory, 'b': 'Bills'});
      expect((await database.watchCategories().first).map((c) => c.name), isNot(contains('Health')));
    });

    test('Other cannot be renamed or deleted', () async {
      final other = (await database.watchCategories().first).firstWhere((c) => c.name == otherCategory);
      await expectLater(database.deleteCategory(other.id), throwsStateError);
      await expectLater(
        database.updateCategory(other.id, name: 'Misc', iconKey: 'other', colorKey: 'grey'),
        throwsStateError,
      );
      // Changing only its look is allowed.
      await database.updateCategory(other.id, name: otherCategory, iconKey: 'gift', colorKey: 'pink');
      final updated = (await database.watchCategories().first).last;
      expect((updated.name, updated.iconKey), (otherCategory, 'gift'));
    });
  });

  test('upgrading a version 1 database adds categories and keeps names in use', () async {
    database = PebbleDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute('''
        CREATE TABLE expense_entries (
          id TEXT NOT NULL PRIMARY KEY, date INTEGER NOT NULL, amount_cents INTEGER NOT NULL,
          description TEXT NOT NULL, category TEXT NOT NULL DEFAULT 'Other',
          payment_method TEXT, merchant TEXT, notes TEXT, receipt_path TEXT,
          created_at INTEGER NOT NULL)''');
      raw.execute("INSERT INTO expense_entries (id, date, amount_cents, description, category, created_at) "
          "VALUES ('old', 1790000000, 500, 'Legacy', 'Travel', 1790000000)");
      raw.execute('PRAGMA user_version = 1');
    }));
    addTearDown(database.close);

    final names = (await database.watchCategories().first).map((c) => c.name).toList();
    expect(names, containsAll([...defaultCategories.map((c) => c.$1), 'Travel']));
    expect(names.last, otherCategory);
    expect((await database.watchExpenses().first).single.category, 'Travel');
  });
}
