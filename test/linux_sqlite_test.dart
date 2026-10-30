import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pebble/data/expense_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('SQLite FFI persists an expense across repository instances', () async {
    final directory = await Directory.systemTemp.createTemp('pebble-linux-sqlite-');
    final path = p.join(directory.path, 'test.sqlite');
    try {
      final first = SqliteExpenseStore(databasePath: path);
      final id = await first.add(Expense(
        date: DateTime(2026, 10, 30),
        amountCents: 4875,
        description: 'Groceries',
        category: 'Food',
        merchant: 'Woolworths',
      ));
      expect(id, greaterThan(0));
      await first.close();

      final reopened = SqliteExpenseStore(databasePath: path);
      final entries = await reopened.all();
      expect(entries, hasLength(1));
      expect(entries.single.amountCents, 4875);
      expect(entries.single.description, 'Groceries');
      expect(entries.single.merchant, 'Woolworths');
      await reopened.delete(entries.single.id!);
      expect(await reopened.all(), isEmpty);
      await reopened.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
