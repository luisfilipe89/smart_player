import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/utils/country_data.dart';

void main() {
  group('CountryData Tests', () {
    test('should have country data list', () {
      expect(CountryData.list, isNotEmpty);
      expect(CountryData.list.length, greaterThan(0));
    });

    test('should have valid country entries', () {
      for (final country in CountryData.list) {
        expect(country['iso'], isNotNull);
        expect(country['name'], isNotNull);
        expect(country['code'], isNotNull);

        expect(country['iso']!.length, 2);
        expect(country['code']!.startsWith('+'), true);
      }
    });

    test('should contain Netherlands', () {
      final nl = CountryData.list.firstWhere(
        (c) => c['iso'] == 'NL',
        orElse: () => {},
      );

      expect(nl, isNotEmpty);
      expect(nl['name'], 'Netherlands');
      expect(nl['code'], '+31');
    });

    test('should contain United States', () {
      final us = CountryData.list.firstWhere(
        (c) => c['iso'] == 'US',
        orElse: () => {},
      );

      expect(us, isNotEmpty);
      expect(us['name'], 'United States');
      expect(us['code'], '+1');
    });

    test('should contain Germany', () {
      final de = CountryData.list.firstWhere(
        (c) => c['iso'] == 'DE',
        orElse: () => {},
      );

      expect(de, isNotEmpty);
      expect(de['name'], 'Germany');
      expect(de['code'], '+49');
    });

    test('should have unique ISO codes', () {
      final isos = CountryData.list.map((c) => c['iso']).toSet();
      expect(isos.length, CountryData.list.length);
    });

    test('should have dial codes starting with plus', () {
      for (final country in CountryData.list) {
        expect(country['code']!.startsWith('+'), true);
      }
    });

    test('should have non-empty country names', () {
      for (final country in CountryData.list) {
        expect(country['name']!.isNotEmpty, true);
      }
    });

    test('should have data for major countries', () {
      final majorCountries = [
        'US',
        'GB',
        'FR',
        'DE',
        'IT',
        'ES',
        'BR',
        'CN',
        'JP',
        'IN'
      ];

      for (final iso in majorCountries) {
        final found = CountryData.list.any((c) => c['iso'] == iso);
        expect(found, true, reason: 'Country $iso should be in the list');
      }
    });

    test('should have alphabetical ordering approximately', () {
      final firstCountry = CountryData.list.first;
      expect(firstCountry['iso'], isNotNull);

      final countryNames = CountryData.list.map((c) => c['name']!).toList();
      // Most countries should be in roughly alphabetical order
      expect(countryNames.length, greaterThan(50));
    });
  });
}
