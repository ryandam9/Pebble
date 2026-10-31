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

  // Fresh-install schema. Pebble has no production data or supported
  // historical database formats, so no migration or legacy columns exist.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories();
        },
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Populate categories on a newly created database.
  Future<void> _seedCategories() async {
    var position = 0;
    for (final (name, icon, color) in defaultCategories) {
      await into(expenseCategories).insert(ExpenseCategoriesCompanion.insert(
        name: name, iconKey: icon, colorKey: color, position: position++));
    }
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
