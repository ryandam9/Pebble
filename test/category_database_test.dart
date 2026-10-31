import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble/data/pebble_database.dart';

void main() {
  late PebbleDatabase database;

  Future<void> addExpense(String id, String category) async {
    final date = DateTime(2026, 10, 30);
    await database.saveEntry(ExpenseEntriesCompanion.insert(
      id: id, date: date, amountCents: 1000, description: 'Test',
      categoryId: await database.categoryIdForName(category), createdAt: date,
    ));
  }

  Future<Map<String, String>> categoryByEntryId() async {
    final categories = {for (final c in await database.watchCategories().first) c.id: c.name};
    return {for (final e in await database.watchExpenses().first)
      e.id: categories[e.categoryId] ?? 'missing'};
  }

  group('fresh schema with category IDs', () {
    setUp(() => database = PebbleDatabase(NativeDatabase.memory()));
    tearDown(() async => database.close());

    test('seeds categories with Other last and resolves ID', () async {
      final categories = await database.watchCategories().first;
      expect(categories.map((c) => c.name).toList(),
        defaultCategories.map((c) => c.$1).toList());
      expect(await database.categoryIdForName('Food'),
        categories.firstWhere((c) => c.name == 'Food').id);
      expect(await database.categoryIdForName('does not exist'),
        categories.firstWhere((c) => c.name == otherCategory).id);
    });

    test('new categories appear before Other', () async {
      await database.addCategory(name: 'Travel', iconKey: 'flight', colorKey: 'teal');
      final names = (await database.watchCategories().first).map((c) => c.name).toList();
      expect(names.sublist(names.length - 2), ['Travel', otherCategory]);
    });

    test('rename changes displayed name while expense FK remains unchanged', () async {
      await addExpense('a', 'Food');
      await addExpense('b', 'Bills');
      final food = (await database.watchCategories().first)
          .firstWhere((c) => c.name == 'Food');
      final originalId = (await database.watchExpenses().first)
          .firstWhere((e) => e.id == 'a').categoryId;
      await database.updateCategory(food.id, name: 'Dining',
        iconKey: 'coffee', colorKey: 'brown');
      expect(await categoryByEntryId(), {'a': 'Dining', 'b': 'Bills'});
      expect((await database.watchExpenses().first).firstWhere((e) => e.id == 'a').categoryId,
        originalId);
      final dining = (await database.watchCategories().first)
          .firstWhere((c) => c.id == food.id);
      expect((dining.name, dining.iconKey, dining.colorKey),
        ('Dining', 'coffee', 'brown'));
    });

    test('deletion reassigns referenced expenses to Other before deleting', () async {
      await addExpense('a', 'Health');
      await addExpense('b', 'Bills');
      final health = (await database.watchCategories().first)
          .firstWhere((c) => c.name == 'Health');
      await database.deleteCategory(health.id);
      expect(await categoryByEntryId(), {'a': otherCategory, 'b': 'Bills'});
      expect((await database.watchCategories().first).map((c) => c.name),
        isNot(contains('Health')));
      expect(await database.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    });

    test('Other cannot be renamed or deleted', () async {
      final other = (await database.watchCategories().first)
          .firstWhere((c) => c.name == otherCategory);
      await expectLater(database.deleteCategory(other.id), throwsStateError);
      await expectLater(
        database.updateCategory(other.id, name: 'Misc', iconKey: 'other', colorKey: 'grey'),
        throwsStateError);
      await database.updateCategory(other.id, name: otherCategory,
        iconKey: 'gift', colorKey: 'pink');
      final updated = (await database.watchCategories().first).last;
      expect((updated.name, updated.iconKey), (otherCategory, 'gift'));
    });

    test('SQLite rejects orphaned category IDs with FK enforcement enabled', () async {
      expect((await database.customSelect('PRAGMA foreign_keys').getSingle())
        .read<int>('foreign_keys'), 1);
      final date = DateTime(2026, 10, 30);
      await expectLater(database.saveEntry(ExpenseEntriesCompanion.insert(
        id: 'invalid', date: date, amountCents: 100,
        description: 'Invalid category', categoryId: 9999999, createdAt: date,
      )), throwsA(isA<Exception>()));
    });
  });

  test('fresh installation builds category_id foreign key without legacy columns', () async {
    final database = PebbleDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final categories = await database.watchCategories().first;
    expect(categories.length, defaultCategories.length);

    final columns = await database.customSelect(
      'PRAGMA table_info(expense_entries)').get();
    final names = columns.map((row) => row.read<String>('name')).toList();
    expect(names, contains('category_id'));
    expect(names, isNot(contains('category')));

    final foreignKeys = await database.customSelect(
      'PRAGMA foreign_key_list(expense_entries)').get();
    expect(foreignKeys, hasLength(1));
    expect(foreignKeys.single.read<String>('table'), 'expense_categories');
    expect(foreignKeys.single.read<String>('from'), 'category_id');
    expect(foreignKeys.single.read<String>('to'), 'id');
    expect(await database.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    expect((await database.customSelect('PRAGMA user_version').getSingle())
      .read<int>('user_version'), 1);
  });
}
