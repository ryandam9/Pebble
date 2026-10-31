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

  group('schema 4 category IDs', () {
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

  test('upgrades schema 1 and keeps user-defined legacy category names', () async {
    database = PebbleDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute('''
        CREATE TABLE expense_entries (
          id TEXT NOT NULL PRIMARY KEY, date INTEGER NOT NULL,
          amount_cents INTEGER NOT NULL, description TEXT NOT NULL,
          category TEXT NOT NULL DEFAULT 'Other', payment_method TEXT,
          merchant TEXT, notes TEXT, receipt_path TEXT,
          created_at INTEGER NOT NULL
        )''');
      raw.execute('''
        INSERT INTO expense_entries (id, date, amount_cents, description,
          category, created_at) VALUES
        ('old', 1790000000, 500, 'Legacy', 'Travel', 1790000000)
      ''');
      raw.execute('PRAGMA user_version = 1');
    }));
    addTearDown(database.close);
    final categories = await database.watchCategories().first;
    final names = categories.map((c) => c.name).toList();
    expect(names, containsAll([...defaultCategories.map((c) => c.$1), 'Travel']));
    expect(names.last, otherCategory);
    final expense = (await database.watchExpenses().first).single;
    expect(expense.categoryId, categories.firstWhere((c) => c.name == 'Travel').id);
    expect(expense.amountCents, 500);
    expect(await database.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('schema 3 migration retains receipt, merchant, notes, location and category', () async {
    database = PebbleDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute('''
        CREATE TABLE expense_categories (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE, icon_key TEXT NOT NULL,
          color_key TEXT NOT NULL, position INTEGER NOT NULL
        )''');
      raw.execute('''
        INSERT INTO expense_categories (name, icon_key, color_key, position)
        VALUES ('Food', 'restaurant', 'coral', 0),
               ('Other', 'other', 'grey', 1)
      ''');
      raw.execute('''
        CREATE TABLE expense_entries (
          id TEXT NOT NULL PRIMARY KEY, date INTEGER NOT NULL,
          amount_cents INTEGER NOT NULL, description TEXT NOT NULL,
          category TEXT NOT NULL DEFAULT 'Other', payment_method TEXT,
          merchant TEXT, notes TEXT, receipt_path TEXT,
          location_address TEXT, latitude REAL, longitude REAL,
          created_at INTEGER NOT NULL
        )''');
      raw.execute('''
        INSERT INTO expense_entries (
          id, date, amount_cents, description, category, payment_method,
          merchant, notes, receipt_path, location_address, latitude, longitude, created_at
        ) VALUES (
          'historic', 1790000000, 2990, 'Flat white', 'Food', 'Card',
          'Test Cafe', 'Remember this', 'receipts/historic.jpg',
          'Docklands VIC', -37.82, 144.94, 1790000123
        ), (
          'missing', 1790000000, 1000, 'Old custom', 'Custom',
          NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1790000124
        )
      ''');
      raw.execute('PRAGMA user_version = 3');
    }));
    addTearDown(database.close);

    final rows = await database.watchExpenses().first;
    final categories = {for (final c in await database.watchCategories().first) c.id: c.name};
    final saved = rows.firstWhere((e) => e.id == 'historic');
    expect(saved.amountCents, 2990);
    expect(saved.description, 'Flat white');
    expect(categories[saved.categoryId], 'Food');
    expect(saved.paymentMethod, 'Card');
    expect(saved.merchant, 'Test Cafe');
    expect(saved.notes, 'Remember this');
    expect(saved.receiptPath, 'receipts/historic.jpg');
    expect(saved.locationAddress, 'Docklands VIC');
    expect(saved.latitude, closeTo(-37.82, .000001));
    expect(saved.longitude, closeTo(144.94, .000001));
    expect(categories[rows.firstWhere((e) => e.id == 'missing').categoryId], 'Custom');
    final cols = await database.customSelect('PRAGMA table_info(expense_entries)').get();
    expect(cols.map((r) => r.read<String>('name')), contains('category_id'));
    expect(cols.map((r) => r.read<String>('name')), isNot(contains('category')));
    final fk = await database.customSelect('PRAGMA foreign_key_list(expense_entries)').get();
    expect(fk, isNotEmpty);
    expect(await database.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    expect((await database.customSelect('PRAGMA user_version').getSingle())
      .read<int>('user_version'), 4);
  });
}
