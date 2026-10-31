import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pebble/data/expense_location.dart';
import 'package:pebble/data/location_service.dart';
import 'package:pebble/ui/address_search_dialog.dart';
import 'package:pebble/ui/recent_addresses.dart';

class _FakeLocations implements LocationService {
  _FakeLocations({this.canSearch = true});
  @override
  final bool canSearch;
  String? lastSearch;

  @override
  Future<List<ExpenseLocation>> search(String query) async {
    lastSearch = query;
    return [
      const ExpenseLocation(
        address: '833 Collins Street, Docklands, VIC 3008',
        latitude: -37.8213, longitude: 144.9466),
    ];
  }

  @override
  Future<ExpenseLocation> currentLocation() async =>
    const ExpenseLocation(address: 'Melbourne VIC',
      latitude: -37.81, longitude: 144.96);

  @override
  Future<void> openInMaps(ExpenseLocation location) async {}
}

Future<void> _open(WidgetTester tester, _FakeLocations fake) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
    builder: (context) => Center(child: TextButton(
      onPressed: () async {
        final location = await showDialog<ExpenseLocation>(
          context: context,
          builder: (_) => AddressSearchDialog(service: fake),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Chosen: ' + (location?.label ?? 'none')),
          ));
        }
      },
      child: const Text('Open address search'),
    )),
  ))));
  await tester.tap(find.text('Open address search'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('minimal dialog searches and selects geocoded results', (tester) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _FakeLocations();
    await _open(tester, service);
    expect(find.text('Search address'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('addressQueryInput')), '833 Collins');
    await tester.pump();
    await tester.tap(find.byKey(const Key('addressSearchButton')));
    await tester.pumpAndSettle();
    expect(service.lastSearch, '833 Collins');
    expect(find.text('833 Collins Street, Docklands, VIC 3008'), findsOneWidget);
    await tester.tap(find.text('833 Collins Street, Docklands, VIC 3008'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chosen: 833 Collins Street'), findsOneWidget);
    final recent = await const RecentAddresses().read();
    expect(recent.single.latitude, -37.8213);
  });

  testWidgets('unsupported geocoding retains typed-address fallback', (tester) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _open(tester, _FakeLocations(canSearch: false));
    expect(find.byKey(const Key('addressSearchButton')), findsNothing);
    await tester.enterText(find.byKey(const Key('addressQueryInput')), 'My cafe');
    await tester.pump();
    await tester.tap(find.byKey(const Key('useTypedAddress')));
    await tester.pumpAndSettle();
    expect(find.text('Chosen: My cafe'), findsOneWidget);
    final recent = await const RecentAddresses().read();
    expect(recent.single.hasCoordinates, isFalse);
  });

  testWidgets('current shortcut selects device-service result', (tester) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _open(tester, _FakeLocations());
    await tester.tap(find.byKey(const Key('dialogCurrentLocation')));
    await tester.pumpAndSettle();
    expect(find.text('Chosen: Melbourne VIC'), findsOneWidget);
  });

  test('recent addresses are capped, deduplicated and cleared', () async {
    final recents = const RecentAddresses();
    for (var i = 0; i < 8; i++) {
      await recents.remember(ExpenseLocation(address: 'Place ' + i.toString()));
    }
    await recents.remember(const ExpenseLocation(address: 'Place 5'));
    final stored = await recents.read();
    expect(stored.length, 5);
    expect(stored.first.label, 'Place 5');
    expect(stored.where((r) => r.address == 'Place 5'), hasLength(1));
    await recents.clear();
    expect(await recents.read(), isEmpty);
  });
}
