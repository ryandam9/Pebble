import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pebble/data/pebble_database.dart';
import 'package:pebble/data/pebble_store.dart';
import 'package:pebble/ui/scanned_text_dialog.dart';
import 'package:pebble/ui/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('en_AU'));

  Future<PebbleStore> storeWith(Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    final store = PebbleStore(PebbleDatabase(NativeDatabase.memory()),
      preferences: await SharedPreferences.getInstance())..start();
    addTearDown(store.dispose);
    return store;
  }

  test('"show scanned text" is off by default and is remembered', () async {
    final store = await storeWith({});
    expect(store.showScannedText, isFalse);
    await store.setShowScannedText(true);

    final reopened = await storeWith({'showScannedText': true});
    expect(reopened.showScannedText, isTrue);
    expect((await SharedPreferences.getInstance()).getBool('showScannedText'), isTrue);
  });

  testWidgets('settings switch turns "show scanned text" on', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await storeWith({});
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SettingsScreen(store: store))));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('showScannedTextSwitch')));
    await tester.pumpAndSettle();
    expect(store.showScannedText, isTrue);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('showScannedTextSwitch'))).value, isTrue);
  });

  testWidgets('dialog shows the full scanned text', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => TextButton(
      onPressed: () => showScannedTextDialog(context, 'COLES\nTotal \$\n12.50'),
      child: const Text('open'),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Scanned text'), findsOneWidget);
    expect(find.text('3 lines'), findsOneWidget);
    expect(tester.widget<SelectableText>(find.byKey(const Key('scannedTextBody'))).data,
      'COLES\nTotal \$\n12.50');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Scanned text'), findsNothing);
  });

  testWidgets('a long scan keeps the dialog to 60% of the screen and scrolls', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final longText = List.generate(200, (i) => 'LINE ${i + 1}  9.99').join('\n');
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => TextButton(
      onPressed: () => showScannedTextDialog(context, longText),
      child: const Text('open'),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The visible dialog card; AlertDialog itself spans the whole screen.
    final dialog = tester.getSize(find.descendant(of: find.byType(AlertDialog), matching: find.byType(Material)).first);
    expect(dialog.height, lessThanOrEqualTo(800 * 0.6));
    expect(find.byType(Scrollbar), findsOneWidget);
    // Lines are short, but the scrollbar sits at the dialog's right edge.
    final content = tester.getRect(find.ancestor(of: find.byType(Scrollbar), matching: find.byType(Column)).first);
    expect(tester.getRect(find.byType(Scrollbar)).right, content.right);
    expect(find.text('Close'), findsOneWidget);
  });
}
