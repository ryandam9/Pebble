import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Database file name, as created by drift_flutter for `name: 'pebble'`.
const databaseFileName = 'pebble.sqlite';

/// Receipt photos live in this folder under [appDataDirectory].
const receiptsFolder = 'receipts';

/// On Linux and Windows the "documents" directory is the user's own visible
/// Documents folder, so desktop builds keep data in the app-private support
/// directory instead. On Android and iOS the documents directory is already
/// private to the app, and is kept so existing installs don't move.
bool get _useSupportDirectory => Platform.isLinux || Platform.isWindows;

/// Where Pebble keeps its database and receipt photos.
Future<Directory> appDataDirectory() async {
  if (!_useSupportDirectory) return getApplicationDocumentsDirectory();
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return directory;
}

/// Receipt files are named `<expense id>_<timestamp>.<ext>` by the store.
final _receiptName = RegExp(r'^\d+_\d+\.(?:png|jpe?g|webp)$');

/// Moves data written by earlier desktop builds out of the Documents folder.
///
/// Runs before the database opens. It only moves the database when the new
/// location has none, and only moves receipt files that match Pebble's naming,
/// so nothing else in the user's Documents folder is touched.
Future<void> migrateLegacyDesktopData() async {
  if (!_useSupportDirectory) return;
  final Directory legacy;
  try {
    legacy = await getApplicationDocumentsDirectory();
  } on Object {
    return; // No documents folder configured: nothing to migrate.
  }
  await moveLegacyData(from: legacy, to: await appDataDirectory());
}

/// Moves Pebble's database and receipt files from [from] into [to].
@visibleForTesting
Future<void> moveLegacyData({required Directory from, required Directory to}) async {
  final legacy = from;
  final target = to;
  if (p.equals(legacy.path, target.path)) return;

  final oldDb = File(p.join(legacy.path, databaseFileName));
  final newDb = File(p.join(target.path, databaseFileName));
  if (await oldDb.exists() && !await newDb.exists()) {
    // SQLite may keep companion files next to the database. The main file
    // moves last: once it exists in the new place, the move counts as done.
    for (final suffix in ['-wal', '-shm', '-journal', '']) {
      final file = File(oldDb.path + suffix);
      if (await file.exists()) await _move(file, newDb.path + suffix);
    }
  }

  final oldReceipts = Directory(p.join(legacy.path, receiptsFolder));
  if (await oldReceipts.exists()) {
    final newReceipts = Directory(p.join(target.path, receiptsFolder));
    await newReceipts.create(recursive: true);
    await for (final entity in oldReceipts.list()) {
      final name = p.basename(entity.path);
      if (entity is! File || !_receiptName.hasMatch(name)) continue;
      final destination = p.join(newReceipts.path, name);
      if (!await File(destination).exists()) await _move(entity, destination);
    }
    // Remove the old folder only if Pebble's files were all it held.
    if (await oldReceipts.list().isEmpty) await oldReceipts.delete();
  }
}

/// Rename, falling back to copy + delete when crossing file systems.
Future<void> _move(File source, String destination) async {
  try {
    await source.rename(destination);
  } on FileSystemException {
    // Copy under a temporary name first so an interrupted copy never looks
    // like a finished one (which would stop the migration being retried).
    final partial = '$destination.partial';
    await source.copy(partial);
    await File(partial).rename(destination);
    await source.delete();
  }
}
