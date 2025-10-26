import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/services/external/weather_service_instance.dart';

void main() {
  group('Weather Service Structure Tests', () {
    test('WeatherServiceInstance should exist', () {
      expect(WeatherServiceInstance, isNotNull);
    });

    test('Weather condition constants should exist', () {
      expect(WeatherServiceInstance.sunny, 'sunny');
      expect(WeatherServiceInstance.cloudy, 'cloudy');
      expect(WeatherServiceInstance.rainy, 'rainy');
      expect(WeatherServiceInstance.lightRain, 'light_rain');
      expect(WeatherServiceInstance.moderateRain, 'moderate_rain');
      expect(WeatherServiceInstance.heavyRain, 'heavy_rain');
      expect(WeatherServiceInstance.drizzle, 'drizzle');
      expect(WeatherServiceInstance.night, 'night');
      expect(WeatherServiceInstance.partlyCloudy, 'partly_cloudy');
      expect(WeatherServiceInstance.overcast, 'overcast');
      expect(WeatherServiceInstance.thunderstorm, 'thunderstorm');
      expect(WeatherServiceInstance.snow, 'snow');
      expect(WeatherServiceInstance.fog, 'fog');
    });
  });
}
