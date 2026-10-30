import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/design.dart';
import 'data/pebble_database.dart';
import 'data/pebble_store.dart';
import 'data/storage.dart';
import 'ui/pebble_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_AU');
  try {
    await migrateLegacyDesktopData();
  } catch (error) {
    // Data stays where it was; the move is retried on the next launch.
    debugPrint('Could not move Pebble data out of Documents: $error');
  }
  final store = PebbleStore(PebbleDatabase.open())..start();
  runApp(PebbleApp(store: store));
}

class PebbleApp extends StatelessWidget {
  const PebbleApp({required this.store, super.key});
  final PebbleStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pebble',
      debugShowCheckedModeBanner: false,
      theme: pebbleTheme(),
      home: PebbleRoot(store: store),
    );
  }
}
