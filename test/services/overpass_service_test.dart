import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/services/external/overpass_service_instance.dart';

void main() {
  group('Overpass Service Structure Tests', () {
    test('OverpassServiceInstance class should exist', () {
      expect(OverpassServiceInstance, isNotNull);
    });

    test('OverpassServiceInstance should be a class', () {
      expect(OverpassServiceInstance, isA<Type>());
    });
  });
}
