import 'package:flutter/material.dart';
import 'core/design.dart';
import 'data/pebble_database.dart';
import 'data/pebble_store.dart';
import 'ui/pebble_root.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
