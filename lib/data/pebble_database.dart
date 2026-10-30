import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'storage.dart';

part 'pebble_database.g.dart';

class ExpenseEntries extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get amountCents => integer()();
  TextColumn get description => text().withLength(min: 1, max: 240)();
  TextColumn get category => text().withDefault(const Constant(otherCategory))();
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

/// A user-editable spending category. Expenses refer to it by [name].
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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
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
        },
      );

  /// Inserts the defaults, plus any category names existing expenses already use.
  Future<void> _seedCategories() async {
    final names = <String>{};
    var position = 0;
    await batch((b) {
      for (final (name, icon, color) in defaultCategories) {
        names.add(name);
        b.insert(expenseCategories, ExpenseCategoriesCompanion.insert(
          name: name, iconKey: icon, colorKey: color, position: position++));
      }
    });
    final used = await (selectOnly(expenseEntries, distinct: true)
          ..addColumns([expenseEntries.category]))
        .map((row) => row.read(expenseEntries.category)!)
        .get();
    for (final name in used) {
      final trimmed = name.trim();
      if (trimmed.isEmpty || trimmed.length > 30 || names.contains(trimmed)) continue;
      names.add(trimmed);
      await into(expenseCategories).insert(ExpenseCategoriesCompanion.insert(
        name: trimmed, iconKey: 'other', colorKey: 'grey', position: position++));
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

  /// Updates a category; a rename is applied to its expenses in the same transaction.
  Future<void> updateCategory(int id, {required String name, required String iconKey, required String colorKey}) {
    return transaction(() async {
      final current = await (select(expenseCategories)..where((t) => t.id.equals(id))).getSingle();
      if (current.name == otherCategory && name != otherCategory) {
        throw StateError('The $otherCategory category cannot be renamed.');
      }
      await (update(expenseCategories)..where((t) => t.id.equals(id))).write(
        ExpenseCategoriesCompanion(name: Value(name), iconKey: Value(iconKey), colorKey: Value(colorKey)));
      if (current.name != name) {
        await (update(expenseEntries)..where((t) => t.category.equals(current.name)))
            .write(ExpenseEntriesCompanion(category: Value(name)));
      }
    });
  }

  /// Deletes a category and moves its expenses to [otherCategory].
  Future<void> deleteCategory(int id) {
    return transaction(() async {
      final current = await (select(expenseCategories)..where((t) => t.id.equals(id))).getSingle();
      if (current.name == otherCategory) {
        throw StateError('The $otherCategory category cannot be deleted.');
      }
      await (update(expenseEntries)..where((t) => t.category.equals(current.name)))
          .write(const ExpenseEntriesCompanion(category: Value(otherCategory)));
      await (delete(expenseCategories)..where((t) => t.id.equals(id))).go();
    });
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
