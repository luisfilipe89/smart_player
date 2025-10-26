import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:move_young/models/external/event_model.dart';

Future<List<Event>> loadEventsFromJson() async {
  try {
    // Try to load from Firebase first with timeout
    final db = FirebaseDatabase.instance.ref('events/latest');
    final snapshot = await db.get().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        developer.log('Firebase connection timeout after 5 seconds');
        throw TimeoutException('Firebase connection timeout');
      },
    );

    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<String, dynamic>;
      if (data['events'] != null) {
        final events = (data['events'] as List).map((json) {
          final bool isRecurring =
              _isRecurringDateTime(json['date_time'] ?? '');
          return Event.fromJson({...json, 'isRecurring': isRecurring});
        }).toList();
        return events;
      }
    }
  } catch (e, stackTrace) {
    developer.log('Error loading from Firebase: $e',
        name: 'loadEventsFromJson', error: e, stackTrace: stackTrace);
    // Continue to fallback to local file
  }

  // Fallback to local file
  final String response =
      await rootBundle.loadString('assets/events/upcoming_events.json');
  final List<dynamic> data = json.decode(response);

  return data.map((json) {
    final String dateTime = json['date_time'] ?? '';
    final bool isRecurring = _isRecurringDateTime(dateTime);

    return Event.fromJson({
      ...json,
      'isRecurring': isRecurring,
    });
  }).toList();
}

bool _isRecurringDateTime(String input) {
  final lower = input.toLowerCase();
  return !(lower.contains('1x') ||
      lower.contains('eenmalig') ||
      lower.contains('op inschrijving'));
}
