import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:intl/date_symbol_data_local.dart';
import 'package:pebble/data/expense_location.dart';
import 'package:pebble/data/location_service.dart';
import 'package:pebble/data/pebble_database.dart';
import 'package:pebble/data/pebble_store.dart';
import 'package:pebble/ui/expense_map_preview.dart';
import 'package:pebble/ui/location_field.dart';
import 'package:pebble/ui/screens/editor_screen.dart';

class FakeLocationService implements LocationService {
  FakeLocationService({this.canSearch = true});
  @override
  final bool canSearch;
  final opened = <ExpenseLocation>[];
  ExpenseLocation current = const ExpenseLocation(
    address: '833 Collins St, Docklands, VIC 3008', latitude: -37.8213, longitude: 144.9466);
  Object? currentError;

  @override
  Future<ExpenseLocation> currentLocation() async {
    if (currentError != null) throw currentError!;
    return current;
  }

  @override
  Future<List<ExpenseLocation>> search(String query) async => [
    ExpenseLocation(address: '1 $query St, Melbourne, VIC 3000', latitude: -37.81, longitude: 144.96),
  ];

  @override
  Future<void> openInMaps(ExpenseLocation location) async => opened.add(location);
}

void main() {
  setUpAll(() async => initializeDateFormatting('en_AU'));

  group('map links', () {
    const both = ExpenseLocation(address: '833 Collins St', latitude: -37.8213, longitude: 144.9466);

    test('Android uses a labelled geo: link, then the web', () {
      final uris = mapUris(both, android: true, ios: false);
      expect(uris.first.toString(), 'geo:-37.8213,144.9466?q=-37.8213%2C144.9466(833%20Collins%20St)');
      expect(uris.last.host, 'www.google.com');
      expect(uris.last.queryParameters['query'], '-37.8213,144.9466');
    });

    test('a typed address without coordinates searches by text', () {
      final uris = mapUris(const ExpenseLocation(address: 'Woolworths Docklands'), android: true, ios: false);
      expect(uris.first.toString(), 'geo:0,0?q=Woolworths%20Docklands');
      expect(uris.last.queryParameters['query'], 'Woolworths Docklands');
    });

    test('desktop opens the web map only', () {
      expect(mapUris(both, android: false, ios: false), hasLength(1));
    });
  });

  test('placemarks format as a short Australian address', () {
    const place = geo.Placemark(
      name: '833', subThoroughfare: '833', thoroughfare: 'Collins Street',
      locality: 'Docklands', administrativeArea: 'VIC', postalCode: '3008', country: 'Australia');
    expect(formatPlacemark(place), '833 Collins Street, Docklands, VIC 3008');
  });

  test('location label falls back to coordinates', () {
    expect(const ExpenseLocation(latitude: -37.8, longitude: 144.9).label, '-37.80000, 144.90000');
    expect(const ExpenseLocation(address: ' ').isEmpty, isTrue);
  });

  testWidgets('the location tile shows the address below the map, not over it', (tester) async {
    Future<void> show(ExpenseLocation location) => tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: LocationField(
        bento: true, value: location, onChanged: (_) {}, service: FakeLocationService())))));

    await show(const ExpenseLocation(address: '833 Collins St', latitude: -37.8213, longitude: 144.9466));
    expect(tester.getTopLeft(find.text('833 Collins St')).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(ExpenseMapPreview)).dy));

    await show(const ExpenseLocation(address: 'Woolworths Docklands'));
    expect(find.text('Woolworths Docklands'), findsOneWidget);
    expect(find.byType(ExpenseMapPreview), findsNothing);
  });

  group('expense editor', () {
    Future<(PebbleStore, FakeLocationService)> openEditor(WidgetTester tester, {FakeLocationService? service}) async {
      tester.view.physicalSize = const Size(430, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = PebbleStore(PebbleDatabase(NativeDatabase.memory()))..start();
      addTearDown(store.dispose);
      final fake = service ?? FakeLocationService();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) =>
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<int>(builder: (_) =>
            EditorScreen(store: store, onSwitchTab: (_) {}, locationService: fake))),
          child: const Text('open'),
        )))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (store, fake);
    }

    Finder scrollable() => find.byType(Scrollable).first;

    /// Scrolls [key] into view, clear of the bottom navigation bar.
    Future<void> reveal(WidgetTester tester, String key) async {
      await tester.scrollUntilVisible(find.byKey(Key(key)), 150, scrollable: scrollable());
      await tester.drag(scrollable(), const Offset(0, -200));
      await tester.pumpAndSettle();
    }

    Future<void> fillAndSave(WidgetTester tester) async {
      await tester.scrollUntilVisible(find.byKey(const Key('amountInput')), -150, scrollable: scrollable());
      await tester.enterText(find.byKey(const Key('amountInput')), '12.50');
      await tester.scrollUntilVisible(find.byKey(const Key('descriptionInput')), 150, scrollable: scrollable());
      await tester.enterText(find.byKey(const Key('descriptionInput')), 'Lunch');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bentoSaveButton')));
      await tester.pumpAndSettle();
    }

    testWidgets('current location is saved with the expense and opens in maps', (tester) async {
      final (store, fake) = await openEditor(tester);
      await reveal(tester, 'currentLocationButton');
      await tester.tap(find.byKey(const Key('currentLocationButton')));
      await tester.pumpAndSettle();
      expect(find.text('833 Collins St, Docklands, VIC 3008'), findsOneWidget);

      await tester.ensureVisible(find.text('Open in Maps'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open in Maps'));
      await tester.pumpAndSettle();
      expect(fake.opened.single.latitude, -37.8213);

      await fillAndSave(tester);
      final saved = ExpenseLocation.of(store.expenses.single)!;
      expect(saved.address, '833 Collins St, Docklands, VIC 3008');
      expect((saved.latitude, saved.longitude), (-37.8213, 144.9466));
    });

    testWidgets('searching picks a result; remove clears it', (tester) async {
      final (_, _) = await openEditor(tester);
      await reveal(tester, 'searchAddressButton');
      await tester.tap(find.byKey(const Key('searchAddressButton')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('addressQueryInput')), 'Flinders');
      await tester.pump();
      await tester.tap(find.byKey(const Key('addressSearchButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 Flinders St, Melbourne, VIC 3000'));
      await tester.pumpAndSettle();
      expect(find.text('1 Flinders St, Melbourne, VIC 3000'), findsOneWidget);

      await tester.ensureVisible(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('currentLocationButton')), findsOneWidget);
    });

    testWidgets('without search, the typed address is saved as is', (tester) async {
      final (store, _) = await openEditor(tester, service: FakeLocationService(canSearch: false));
      await reveal(tester, 'searchAddressButton');
      await tester.tap(find.byKey(const Key('searchAddressButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('addressSearchButton')), findsNothing);
      await tester.enterText(find.byKey(const Key('addressQueryInput')), 'Woolworths Docklands');
      await tester.pump();
      await tester.tap(find.byKey(const Key('useTypedAddress')));
      await tester.pumpAndSettle();

      await fillAndSave(tester);
      final saved = ExpenseLocation.of(store.expenses.single)!;
      expect(saved.address, 'Woolworths Docklands');
      expect(saved.hasCoordinates, isFalse);
    });

    testWidgets('a location error is shown to the user', (tester) async {
      final service = FakeLocationService()
        ..currentError = const LocationException('Location is turned off. Turn it on in your device settings.');
      await openEditor(tester, service: service);
      await reveal(tester, 'currentLocationButton');
      await tester.tap(find.byKey(const Key('currentLocationButton')));
      await tester.pumpAndSettle();
      expect(find.text('Location is turned off. Turn it on in your device settings.'), findsOneWidget);
    });
  });
}
