import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'storage.dart';

part 'pebble_database.g.dart';

class ExpenseEntries extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get amountCents => integer()();
  TextColumn get description => text().withLength(min: 1, max: 240)();
  /// Numeric category identity; a real SQLite foreign key.
  IntColumn get categoryId => integer().references(ExpenseCategories, #id)();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get merchant => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get receiptPath => text().nullable()();
  /// Where the purchase happened. Any of these may be set on its own: a typed
  /// address without coordinates, or GPS coordinates with no address found.
  TextColumn get locationAddress => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fallback category: always present, cannot be renamed or deleted.
const otherCategory = 'Other';

/// Category display name and metadata; expenses reference its stable ID.
@DataClassName('ExpenseCategory')
class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 30).unique()();
  TextColumn get iconKey => text()();
  TextColumn get colorKey => text()();
  IntColumn get position => integer()();
}

/// Categories created for a new database, as (name, iconKey, colorKey).
const defaultCategories = <(String, String, String)>[
  ('Groceries', 'grocery', 'green'),
  ('Food', 'restaurant', 'coral'),
  ('Transport', 'car', 'blue'),
  ('Shopping', 'shopping', 'purple'),
  ('Bills', 'bills', 'amber'),
  ('Health', 'health', 'pink'),
  (otherCategory, 'other', 'grey'),
];

@DriftDatabase(tables: [ExpenseEntries, ExpenseCategories])
class PebbleDatabase extends _$PebbleDatabase {
  PebbleDatabase(super.executor);
  PebbleDatabase.open()
      : super(driftDatabase(
          name: 'pebble',
          native: const DriftNativeOptions(databaseDirectory: appDataDirectory),
        ));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(expenseCategories);
            await _seedCategories();
          }
          if (from < 3) {
            await m.addColumn(expenseEntries, expenseEntries.locationAddress);
            await m.addColumn(expenseEntries, expenseEntries.latitude);
            await m.addColumn(expenseEntries, expenseEntries.longitude);
          }
          if (from < 4) {
            await _ensureLegacyCategories();
            await _migrateCategoryIds();
          }
        },
      );

  /// Seed all defaults for a new database or when upgrading from schema v1.
  Future<void> _seedCategories() async {
    var position = 0;
    for (final (name, icon, color) in defaultCategories) {
      await into(expenseCategories).insert(ExpenseCategoriesCompanion.insert(
        name: name, iconKey: icon, colorKey: color, position: position++));
    }
  }

  /// Restore any names from legacy expense rows that aren't already in the
  /// categories table. This runs before deleting the old name column.
  Future<void> _ensureLegacyCategories() async {
    final existing = await select(expenseCategories).get();
    final known = existing.map((c) => c.name).toSet();
    var position = existing.fold<int>(-1,
      (max, c) => c.position > max ? c.position : max) + 1;
    if (!known.contains(otherCategory)) {
      await into(expenseCategories).insert(ExpenseCategoriesCompanion.insert(
        name: otherCategory, iconKey: 'other', colorKey: 'grey',
        position: position++));
      known.add(otherCategory);
    }
    final rows = await customSelect('SELECT DISTINCT category FROM expense_entries').get();
    for (final row in rows) {
      final name = row.read<String>('category').trim();
      if (name.isEmpty || name.length > 30 || known.contains(name)) continue;
      await into(expenseCategories).insert(ExpenseCategoriesCompanion.insert(
        name: name, iconKey: 'other', colorKey: 'grey',
        position: position++));
      known.add(name);
    }
  }

  /// Rebuild in Drift's upgrade transaction because category_id is NOT NULL
  /// and SQLite can't replace the old category TEXT field with a FK in place.
  /// All non-category expense fields, including receipt paths, are preserved.
  Future<void> _migrateCategoryIds() async {
    await customStatement('''
      CREATE TABLE expense_entries_v4 (
        id TEXT NOT NULL PRIMARY KEY,
        date INTEGER NOT NULL,
        amount_cents INTEGER NOT NULL,
        description TEXT NOT NULL,
        category_id INTEGER NOT NULL REFERENCES expense_categories(id),
        payment_method TEXT,
        merchant TEXT,
        notes TEXT,
        receipt_path TEXT,
        location_address TEXT,
        latitude REAL,
        longitude REAL,
        created_at INTEGER NOT NULL
      )
    ''');
    await customStatement('''
      INSERT INTO expense_entries_v4 (
        id, date, amount_cents, description, category_id,
        payment_method, merchant, notes, receipt_path,
        location_address, latitude, longitude, created_at
      )
      SELECT
        e.id, e.date, e.amount_cents, e.description,
        COALESCE(
          (SELECT c.id FROM expense_categories c WHERE c.name = TRIM(e.category)),
          (SELECT fallback.id FROM expense_categories fallback WHERE fallback.name = 'Other')
        ),
        e.payment_method, e.merchant, e.notes, e.receipt_path,
        e.location_address, e.latitude, e.longitude, e.created_at
      FROM expense_entries e
    ''');
    await customStatement('DROP TABLE expense_entries');
    await customStatement('ALTER TABLE expense_entries_v4 RENAME TO expense_entries');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS expense_entries_category_id_idx
      ON expense_entries(category_id)
    ''');
  }

  /// Categories in display order, with [otherCategory] always last.
  Stream<List<ExpenseCategory>> watchCategories() {
    return (select(expenseCategories)
          ..orderBy([
            (t) => OrderingTerm(expression: t.name.equals(otherCategory)),
            (t) => OrderingTerm(expression: t.position),
          ]))
        .watch();
  }

  Future<int> addCategory({required String name, required String iconKey, required String colorKey}) async {
    final max = expenseCategories.position.max();
    final last = await (selectOnly(expenseCategories)..addColumns([max]))
        .map((row) => row.read(max))
        .getSingle();
    return into(expenseCategories).insert(ExpenseCategoriesCompanion.insert(
      name: name, iconKey: iconKey, colorKey: colorKey, position: (last ?? -1) + 1));
  }

  /// Rename and restyle without rewriting any expense rows.
  Future<void> updateCategory(int id,
      {required String name, required String iconKey, required String colorKey}) {
    return transaction(() async {
      final current = await (select(expenseCategories)..where((t) => t.id.equals(id))).getSingle();
      if (current.name == otherCategory && name != otherCategory) {
        throw StateError('The $otherCategory category cannot be renamed.');
      }
      await (update(expenseCategories)..where((t) => t.id.equals(id))).write(
        ExpenseCategoriesCompanion(
          name: Value(name), iconKey: Value(iconKey), colorKey: Value(colorKey)));
    });
  }

  /// Reassign before deleting to keep the FK constraint satisfied.
  Future<void> deleteCategory(int id) {
    return transaction(() async {
      final current = await (select(expenseCategories)..where((t) => t.id.equals(id))).getSingle();
      if (current.name == otherCategory) {
        throw StateError('The $otherCategory category cannot be deleted.');
      }
      final fallbackId = await categoryIdForName(otherCategory);
      await (update(expenseEntries)..where((t) => t.categoryId.equals(id)))
        .write(ExpenseEntriesCompanion(categoryId: Value(fallbackId)));
      await (delete(expenseCategories)..where((t) => t.id.equals(id))).go();
    });
  }

  /// A stale/deleted name resolves to Other, never an invalid FK.
  Future<int> categoryIdForName(String name) async {
    final selected = await (select(expenseCategories)
      ..where((c) => c.name.equals(name))).getSingleOrNull();
    if (selected != null) return selected.id;
    final fallback = await (select(expenseCategories)
      ..where((c) => c.name.equals(otherCategory))).getSingle();
    return fallback.id;
  }

  Stream<List<ExpenseEntry>> watchExpenses() {
    return (select(expenseEntries)
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<int> saveEntry(ExpenseEntriesCompanion entry) {
    return into(expenseEntries).insertOnConflictUpdate(entry);
  }

  Future<int> removeEntry(String id) {
    return (delete(expenseEntries)..where((row) => row.id.equals(id))).go();
  }
}
