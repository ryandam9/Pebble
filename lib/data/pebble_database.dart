import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'pebble_database.g.dart';

class ExpenseEntries extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get amountCents => integer()();
  TextColumn get description => text().withLength(min: 1, max: 240)();
  TextColumn get category => text().withDefault(const Constant('Other'))();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get merchant => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get receiptPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ExpenseEntries])
class PebbleDatabase extends _$PebbleDatabase {
  PebbleDatabase(super.executor);
  PebbleDatabase.open() : super(driftDatabase(name: 'pebble'));

  @override
  int get schemaVersion => 1;

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
