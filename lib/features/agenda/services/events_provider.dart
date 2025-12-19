import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/agenda/services/events_service_instance.dart';
import 'package:move_young/providers/infrastructure/firebase_providers.dart';

/// Provider for EventsServiceInstance with dependency injection
final eventsServiceProvider = Provider<EventsServiceInstance>((ref) {
  final firebaseDatabase = ref.watch(firebaseDatabaseProvider);
  return EventsServiceInstance(firebaseDatabase);
});






