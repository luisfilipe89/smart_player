import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:move_young/models/external/event_model.dart';

Future<List<Event>> loadEventsFromJson() async {
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
