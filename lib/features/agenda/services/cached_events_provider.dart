import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/agenda/models/event_model.dart';
import 'package:move_young/features/agenda/services/events_provider.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/utils/logger.dart';

/// Cached events provider that loads events and caches them by language
/// This provider automatically loads events when user logs in
final cachedEventsProvider = FutureProvider.family<List<Event>, String>((ref, lang) async {
  final eventsService = ref.watch(eventsServiceProvider);
  final events = await eventsService.loadEvents(lang: lang);
  NumberedLogger.d('Cached events for language $lang: ${events.length} events');
  return events;
});

/// Provider that watches auth state and preloads events in background
/// This triggers background loading when user logs in
/// Reading this provider will trigger the cache to be populated
final eventsPreloadProvider = Provider((ref) {
  final userAsync = ref.watch(currentUserProvider);
  
  userAsync.whenData((user) {
    if (user != null) {
      // Preload events for both languages in background (non-blocking)
      // Reading the cachedEventsProvider will trigger loading and caching
      Future.microtask(() {
        try {
          // Read both language providers to trigger background loading
          // This will populate the cache without blocking
          unawaited(ref.read(cachedEventsProvider('en').future));
          unawaited(ref.read(cachedEventsProvider('nl').future));
          NumberedLogger.d('Preloading events for both languages in background');
        } catch (e) {
          NumberedLogger.w('Error preloading events: $e');
        }
      });
    }
  });
  
  return null; // This provider doesn't return a value, it just triggers side effects
});

