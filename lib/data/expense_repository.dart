import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class Expense {
  const Expense({
    this.id,
    required this.date,
    required this.amountCents,
    required this.description,
    required this.category,
    this.merchant = '',
    this.paymentMethod = 'Card',
    this.notes = '',
    this.receiptPath,
  });

  final int? id;
  final DateTime date;
  final int amountCents;
  final String description;
  final String category;
  final String merchant;
  final String paymentMethod;
  final String notes;
  final String? receiptPath;

  Map<String, Object?> toMap() => {
    'date': date.toIso8601String(),
    'amount_cents': amountCents,
    'description': description,
    'category': category,
    'merchant': merchant,
    'payment_method': paymentMethod,
    'notes': notes,
    'receipt_path': receiptPath,
  };

  factory Expense.fromMap(Map<String, Object?> map) => Expense(
    id: map['id'] as int,
    date: DateTime.parse(map['date'] as String),
    amountCents: map['amount_cents'] as int,
    description: map['description'] as String,
    category: map['category'] as String,
    merchant: (map['merchant'] as String?) ?? '',
    paymentMethod: (map['payment_method'] as String?) ?? 'Card',
    notes: (map['notes'] as String?) ?? '',
    receiptPath: map['receipt_path'] as String?,
  );
}

abstract class ExpenseStore {
  Future<List<Expense>> all();
  Future<int> add(Expense expense);
  Future<void> delete(int id);
}

class SqliteExpenseStore implements ExpenseStore {
  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'pebble.sqlite'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
          description TEXT NOT NULL,
          category TEXT NOT NULL,
          merchant TEXT NOT NULL DEFAULT '',
          payment_method TEXT NOT NULL DEFAULT 'Card',
          notes TEXT NOT NULL DEFAULT '',
          receipt_path TEXT
        )
      '''),
    );
    return _db!;
  }

  @override
  Future<List<Expense>> all() async {
    final rows = await (await _database).query(
      'expenses',
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  @override
  Future<int> add(Expense expense) async =>
      (await _database).insert('expenses', expense.toMap());

  @override
  Future<void> delete(int id) async {
    await (await _database).delete(
      'expenses', where: 'id = ?', whereArgs: [id],
    );
  }
}
