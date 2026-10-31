import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pebble/data/pebble_database.dart';
import 'package:pebble/data/pebble_store.dart';
import 'package:pebble/ui/screens/insights_screen.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('en_AU'));

  testWidgets('period menu changes how many months the chart shows', (tester) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = PebbleStore(PebbleDatabase(NativeDatabase.memory()))..start();
    addTearDown(store.dispose);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: InsightsScreen(store: store))));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    String monthLabel(int monthsAgo) =>
        DateFormat('MMM').format(DateTime(now.year, now.month - monthsAgo));

    expect(find.text('Last 6 months'), findsOneWidget);
    expect(find.text(monthLabel(5)), findsOneWidget);
    expect(find.text(monthLabel(11)), findsNothing);

    await tester.tap(find.text('Last 6 months'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 12 months').last);
    await tester.pumpAndSettle();

    expect(find.text('Last 12 months'), findsOneWidget);
    expect(find.text(monthLabel(11)), findsOneWidget);

    await tester.tap(find.text('Last 12 months'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 3 months').last);
    await tester.pumpAndSettle();

    expect(find.text('Last 3 months'), findsOneWidget);
    expect(find.text(monthLabel(2)), findsOneWidget);
    expect(find.text(monthLabel(3)), findsNothing);
  });

  testWidgets('three storage tiles share the width and the chart is taller', (tester) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = PebbleStore(PebbleDatabase(NativeDatabase.memory()))..start();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: InsightsScreen(store: store),
    )));
    await tester.pumpAndSettle();

    final chart = find.byKey(const Key('monthlySpendingChart'));
    expect(chart, findsOneWidget);
    expect(tester.getSize(chart).height, greaterThanOrEqualTo(225));

    final storage = find.byKey(const Key('insightsStorageTiles'));
    await tester.scrollUntilVisible(
      storage, 200, scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final names = [
      'insightsStorageDatabase',
      'insightsStorageReceipts',
      'insightsStoragePrivate',
    ];
    final tiles = [for (final name in names) find.byKey(Key(name))];
    for (final tile in tiles) {
      expect(tile, findsOneWidget);
      expect(tester.getSize(tile).height, greaterThanOrEqualTo(140));
    }
    final widths = [for (final tile in tiles) tester.getSize(tile).width];
    expect(widths.reduce((a, b) => a > b ? a : b) -
      widths.reduce((a, b) => a < b ? a : b), lessThan(1));
  });

}
