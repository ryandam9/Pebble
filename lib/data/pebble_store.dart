import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'pebble_database.dart';

/// Database-backed observable state. UI displays only saved rows, never sample data.
class PebbleStore extends ChangeNotifier {
  PebbleStore(this.database);

  final PebbleDatabase database;
  StreamSubscription<List<ExpenseEntry>>? _subscription;
  StreamSubscription<List<ExpenseCategory>>? _categorySubscription;
  bool _expensesLoaded = false;
  bool _categoriesLoaded = false;

  List<ExpenseEntry> expenses = const [];
  List<ExpenseCategory> categories = const [];
  bool isReady = false;
  String? loadError;

  void start() {
    _subscription ??= database.watchExpenses().listen(
      (rows) {
        expenses = rows;
        _expensesLoaded = true;
        _loaded();
      },
      onError: _failed,
    );
    _categorySubscription ??= database.watchCategories().listen(
      (rows) {
        categories = rows;
        _categoriesLoaded = true;
        _loaded();
      },
      onError: _failed,
    );
  }

  void _loaded() {
    isReady = _expensesLoaded && _categoriesLoaded;
    if (isReady) loadError = null;
    notifyListeners();
  }

  void _failed(Object error) {
    loadError = error.toString();
    isReady = true;
    notifyListeners();
  }

  List<String> get categoryNames => [for (final c in categories) c.name];

  ExpenseCategory? categoryNamed(String name) {
    for (final category in categories) {
      if (category.name == name) return category;
    }
    return null;
  }

  int expenseCountFor(String category) => expenses.where((e) => e.category == category).length;

  /// Returns an error message, or null when [name] can be used.
  /// [editingId] is the category being renamed, which may keep its own name.
  String? validateCategoryName(String name, {int? editingId}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Enter a name';
    if (trimmed.length > 30) return 'Use 30 characters or fewer';
    if (trimmed.toLowerCase() == 'all') return '"All" is reserved for the filter';
    final clash = categories.any((c) => c.id != editingId && c.name.toLowerCase() == trimmed.toLowerCase());
    return clash ? 'A category with this name already exists' : null;
  }

  Future<String> addCategory({required String name, required String iconKey, required String colorKey}) async {
    final error = validateCategoryName(name);
    if (error != null) throw ArgumentError(error);
    final trimmed = name.trim();
    await database.addCategory(name: trimmed, iconKey: iconKey, colorKey: colorKey);
    return trimmed;
  }

  Future<String> updateCategory(ExpenseCategory category,
      {required String name, required String iconKey, required String colorKey}) async {
    final error = validateCategoryName(name, editingId: category.id);
    if (error != null) throw ArgumentError(error);
    final trimmed = name.trim();
    await database.updateCategory(category.id, name: trimmed, iconKey: iconKey, colorKey: colorKey);
    return trimmed;
  }

  Future<void> deleteCategory(ExpenseCategory category) => database.deleteCategory(category.id);

  Future<String> save({
    String? id,
    required DateTime date,
    required int amountCents,
    required String description,
    required String category,
    String? paymentMethod,
    String? merchant,
    String? notes,
    XFile? image,
    String? existingReceiptPath,
    DateTime? createdAt,
  }) async {
    if (amountCents <= 0) throw ArgumentError('Amount must be greater than zero.');
    if (description.trim().isEmpty) throw ArgumentError('Description is required.');
    final key = id ?? DateTime.now().microsecondsSinceEpoch.toString();
    String? receiptPath = existingReceiptPath;
    String? newPath;
    if (image != null) {
      newPath = await _copyReceipt(image, key);
      receiptPath = newPath;
    }

    try {
      await database.saveEntry(
        ExpenseEntriesCompanion.insert(
          id: key,
          date: DateTime(date.year, date.month, date.day),
          amountCents: amountCents,
          description: description.trim(),
          category: Value(category),
          paymentMethod: Value(_optional(paymentMethod)),
          merchant: Value(_optional(merchant)),
          notes: Value(_optional(notes)),
          receiptPath: Value(receiptPath),
          createdAt: createdAt ?? DateTime.now(),
        ),
      );
    } catch (_) {
      if (newPath != null) await _deleteFile(newPath);
      rethrow;
    }
    if (newPath != null && existingReceiptPath != null && existingReceiptPath != newPath) {
      await _deleteFile(existingReceiptPath);
    }
    return key;
  }

  Future<void> deleteExpense(ExpenseEntry entry) async {
    await database.removeEntry(entry.id);
    if (entry.receiptPath != null) {
      await _deleteFile(entry.receiptPath!);
    }
  }

  Future<File?> receiptFile(String? relativePath) async {
    if (relativePath == null) return null;
    final directory = await getApplicationDocumentsDirectory();
    // Never trust user-derived absolute paths or traversal.
    if (!relativePath.startsWith('receipts/') ||
        relativePath.contains('..') ||
        p.isAbsolute(relativePath)) {
      return null;
    }
    final file = File(p.join(directory.path, relativePath));
    return file.existsSync() ? file : null;
  }

  Future<String> _copyReceipt(XFile source, String id) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'receipts'));
    await directory.create(recursive: true);
    final extension = p.extension(source.path).toLowerCase();
    final safeExt = {'.png', '.jpg', '.jpeg', '.webp'}.contains(extension)
        ? extension
        : '.jpg';
    final name = id + '_' + DateTime.now().microsecondsSinceEpoch.toString() + safeExt;
    final relative = p.join('receipts', name);
    await File(source.path).copy(p.join(root.path, relative));
    return relative;
  }

  Future<void> _deleteFile(String relative) async {
    final file = await receiptFile(relative);
    if (file != null && await file.exists()) await file.delete();
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _categorySubscription?.cancel();
    database.close();
    super.dispose();
  }
}
