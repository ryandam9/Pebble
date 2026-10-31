import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble/core/design.dart';
import 'package:pebble/core/pebble_typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses Plus Jakarta Sans for data and Fraunces for editorial titles', () {
    expect(PebbleTypography.body, 'PlusJakartaSans');
    expect(PebbleTypography.editorial, 'Fraunces');
    final title = pebbleTheme().textTheme.headlineLarge;
    expect(title?.fontFamily, PebbleTypography.editorial);
    expect(PebbleTypography.tabularFigures, isNotEmpty);
  });

  test('the Flutter bundle contains all four offline font files', () async {
    const names = [
      'PlusJakartaSans-Regular.ttf',
      'PlusJakartaSans-Italic.ttf',
      'Fraunces-Regular.ttf',
      'Fraunces-Italic.ttf',
    ];
    for (final name in names) {
      final bytes = await rootBundle.load('assets/fonts/' + name);
      expect(bytes.lengthInBytes, greaterThan(100000),
          reason: 'Missing or truncated offline font: ' + name);
    }
  });
}
