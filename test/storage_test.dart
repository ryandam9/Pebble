import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pebble/data/storage.dart';

void main() {
  late Directory root;
  late Directory documents;
  late Directory support;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pebble_storage_test');
    documents = await Directory(p.join(root.path, 'Documents')).create();
    support = await Directory(p.join(root.path, 'support')).create();
  });
  tearDown(() => root.delete(recursive: true));

  File docFile(String path) => File(p.join(documents.path, path));
  File supportFile(String path) => File(p.join(support.path, path));

  test('moves the database, its companions and Pebble receipts only', () async {
    await docFile(databaseFileName).writeAsString('db');
    await docFile('$databaseFileName-wal').writeAsString('wal');
    await Directory(p.join(documents.path, receiptsFolder)).create();
    await docFile('receipts/1761800000000000_1761800000000001.jpg').writeAsString('img');
    await docFile('receipts/tax return.pdf').writeAsString('mine');
    await docFile('notes.txt').writeAsString('unrelated');

    await moveLegacyData(from: documents, to: support);

    expect(await supportFile(databaseFileName).readAsString(), 'db');
    expect(await supportFile('$databaseFileName-wal').readAsString(), 'wal');
    expect(await supportFile('receipts/1761800000000000_1761800000000001.jpg').readAsString(), 'img');
    expect(docFile(databaseFileName).existsSync(), isFalse);
    // The user's own files stay where they are.
    expect(await docFile('receipts/tax return.pdf').readAsString(), 'mine');
    expect(await docFile('notes.txt').readAsString(), 'unrelated');
    expect(supportFile('receipts/tax return.pdf').existsSync(), isFalse);
  });

  test('never overwrites a database already in the new location', () async {
    await docFile(databaseFileName).writeAsString('old');
    await supportFile(databaseFileName).writeAsString('current');

    await moveLegacyData(from: documents, to: support);

    expect(await supportFile(databaseFileName).readAsString(), 'current');
    expect(await docFile(databaseFileName).readAsString(), 'old');
  });

  test('removes the old receipts folder once it is empty', () async {
    await Directory(p.join(documents.path, receiptsFolder)).create();
    await docFile('receipts/1_2.png').writeAsString('img');

    await moveLegacyData(from: documents, to: support);

    expect(Directory(p.join(documents.path, receiptsFolder)).existsSync(), isFalse);
    expect(supportFile('receipts/1_2.png').existsSync(), isTrue);
  });
}
