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

  List<ExpenseEntry> expenses = const [];
  bool isReady = false;
  String? loadError;

  void start() {
    _subscription ??= database.watchExpenses().listen(
      (rows) {
        expenses = rows;
        isReady = true;
        loadError = null;
        notifyListeners();
      },
      onError: (Object error) {
        loadError = error.toString();
        isReady = true;
        notifyListeners();
      },
    );
  }

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
    database.close();
    super.dispose();
  }
}
