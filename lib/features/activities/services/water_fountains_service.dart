import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:move_young/utils/type_converters.dart';
import 'package:move_young/utils/logger.dart';

class WaterFountainsService {
  const WaterFountainsService();

  Future<List<Map<String, dynamic>>?> loadWaterFountains() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/water/rivm_drinkwaterkranen_actueel.json',
      );

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final features =
          (decoded['features'] as List?)?.cast<dynamic>() ?? const <dynamic>[];

      final items = features
          .map<Map<String, dynamic>>((feature) {
            final map = Map<String, dynamic>.from(feature as Map);
            final properties = Map<String, dynamic>.from(
              map['properties'] as Map? ?? const {},
            );
            final id = (map['id'] ?? properties['@id'])?.toString();

            // Use latitude/longitude from properties (already in WGS84)
            final lat = safeToDouble(properties['latitude']);
            final lon = safeToDouble(properties['longitude']);

            if (lat == null || lon == null) {
              return const <String, dynamic>{};
            }

            // Build title from beschrijvi or plaats
            final beschrijvi = properties['beschrijvi']?.toString() ?? '';
            final plaats = properties['plaats']?.toString() ?? '';
            final title = beschrijvi.isNotEmpty
                ? beschrijvi
                : plaats.isNotEmpty
                    ? 'Watertap $plaats'
                    : 'Watertap';

            return {
              'id': id,
              'name': title,
              'title': title,
              'address': plaats.isNotEmpty ? plaats : null,
              'lat': lat,
              'lon': lon,
              'plaats': plaats,
              'type': properties['type'],
              'beschrijvi': beschrijvi,
              'tags': properties,
            };
          })
          .where((m) => m.isNotEmpty)
          .toList();

      NumberedLogger.d('Loaded ${items.length} water fountains');
      return items;
    } catch (e, stackTrace) {
      NumberedLogger.e('Failed to load water fountains: $e');
      NumberedLogger.e('Stack trace: $stackTrace');
      return null;
    }
  }
}
