import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pebble/data/pebble_database.dart';
import 'package:pebble/data/pebble_store.dart';
import 'package:pebble/ui/screens/editor_screen.dart';
import 'package:pebble/ui/bento.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => initializeDateFormatting('en_AU'));

  testWidgets('Bento editor keeps primary action pinned and all fields available', (tester) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = PebbleStore(PebbleDatabase(NativeDatabase.memory()))..start();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: EditorScreen(
      store: store, onSwitchTab: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bentoAmountHero')), findsOneWidget);
    expect(find.byKey(const Key('amountInput')), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    // New category sits at the end of the horizontal category strip.
    await tester.drag(find.byType(ListView).last, const Offset(-1100, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('newCategoryTile')), findsOneWidget);
    expect(find.byKey(const Key('paymentMethodInput')), findsOneWidget);
    expect(find.byType(BentoSaveButton), findsOneWidget);
    expect(find.ancestor(
      of: find.byKey(const Key('bentoSaveButton')),
      matching: find.byType(ListView),
    ), findsNothing);
  });
}
