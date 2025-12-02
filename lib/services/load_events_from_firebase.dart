import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_database/firebase_database.dart';
import 'package:move_young/models/external/event_model.dart';

Future<List<Event>> loadEventsFromFirebase({String lang = 'en'}) async {
  developer.log('Loading events from Firebase...',
      name: 'loadEventsFromFirebase');
  final db = FirebaseDatabase.instance.ref('events/latest');
  final snapshot = await db.get().timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      developer.log('Firebase connection timeout after 5 seconds');
      throw TimeoutException('Firebase connection timeout');
    },
  );

  if (!snapshot.exists || snapshot.value == null) {
    developer.log('No events found in Firebase',
        name: 'loadEventsFromFirebase');
    return [];
  }

  final data = Map<String, dynamic>.from(snapshot.value as Map);
  // Prefer language-specific lists when present
  final key = (lang.toLowerCase() == 'nl') ? 'events_nl' : 'events_en';
  final raw = (data[key] as List?) ?? (data['events'] as List?);

  if (raw == null) {
    developer.log('No events data found in Firebase',
        name: 'loadEventsFromFirebase');
    return [];
  }

  final events = raw.map((json) {
    final bool isRecurring = _isRecurringDateTime(json['date_time'] ?? '');
    return Event.fromJson({...json, 'isRecurring': isRecurring});
  }).toList();

  developer.log(
      'Loaded ${events.length} ${lang.toUpperCase()} events from Firebase',
      name: 'loadEventsFromFirebase');
  return events;
}

bool _isRecurringDateTime(String input) {
  final lower = input.toLowerCase();
  return !(lower.contains('1x') ||
      lower.contains('eenmalig') ||
      lower.contains('op inschrijving'));
}
