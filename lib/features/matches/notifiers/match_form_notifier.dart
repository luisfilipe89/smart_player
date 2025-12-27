import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/matches/models/match.dart';
import 'package:move_young/features/matches/notifiers/match_form_state.dart';
import 'package:move_young/features/activities/services/fields_provider.dart';
import 'package:move_young/features/matches/services/field_data_processor.dart';
import 'package:move_young/services/external/weather_provider.dart';
import 'package:move_young/services/system/location_provider.dart';
import 'package:move_young/features/matches/services/cloud_matches_provider.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/utils/geolocation_utils.dart';
import 'package:move_young/utils/type_converters.dart';
import 'package:move_young/utils/logger.dart';

/// Notifier for managing match form state
/// Handles all form state, field loading, weather fetching, and validation
class MatchFormNotifier extends StateNotifier<MatchFormState> {
  final Ref _ref;
  final Match? _initialMatch;
  Timer? _searchDebounce;

  MatchFormNotifier(this._ref, this._initialMatch)
      : super(_initialMatch != null
            ? MatchFormState.fromMatch(_initialMatch)
            : MatchFormState.initial()) {
    if (_initialMatch != null) {
      _initializeFromMatch();
    }
  }

  Future<void> _initializeFromMatch() async {
    if (_initialMatch == null) return;

    // Load fields for the selected sport
    if (state.sport != null) {
      await _loadFields();
    }

    // Load weather and booked slots if field and date are already set (for editing)
    if (state.field != null && state.date != null) {
      _loadWeather();
      _loadBookedSlots();
    }

    // Load existing invites
    _loadLockedInvites();
  }

  /// Select sport and load fields
  void selectSport(String sport) {
    state = state.copyWith(sport: sport);
    // Clear booked slots and weather when sport changes (different sports might share fields but have different availability)
    state = state.copyWith(bookedTimes: {}, weatherData: {});
    _loadFields();
  }

  /// Select date and load weather/booked slots
  void selectDate(DateTime? date) {
    state = state.copyWith(date: date);
    if (date != null) {
      _loadWeather();
      _loadBookedSlots();
    } else {
      state = state.copyWith(weatherData: {}, bookedTimes: {});
    }
  }

  /// Select time
  void selectTime(String time) {
    state = state.copyWith(time: time);
  }

  /// Select field
  void selectField(Map<String, dynamic> field) {
    // Clear booked slots and weather immediately to prevent showing stale data from previous field
    state = state.copyWith(field: field, bookedTimes: {}, weatherData: {});
    // Reload booked slots and weather when field changes (if date is already selected)
    if (state.date != null) {
      _loadBookedSlots();
      _loadWeather();
    }
  }

  /// Set max players
  void setMaxPlayers(int maxPlayers) {
    state = state.copyWith(maxPlayers: maxPlayers);
  }

  /// Toggle public/private
  void setVisibility(bool isPublic) {
    state = state.copyWith(isPublic: isPublic);
  }

  /// Update field search query with debouncing
  void updateFieldSearch(String query) {
    state = state.copyWith(fieldSearchQuery: query);

    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _applyFieldSearchFilter();
    });
  }

  /// Apply search filter to fields
  void _applyFieldSearchFilter() {
    final query = state.fieldSearchQuery.toLowerCase().trim();
    List<Map<String, dynamic>> filtered;

    if (query.isEmpty) {
      filtered = List.from(state.availableFields);
    } else {
      filtered = state.availableFields.where((field) {
        final name = (field['name'] as String?)?.toLowerCase().trim() ?? '';
        final addressSuperShort =
            (field['addressSuperShort'] as String?)?.toLowerCase().trim() ?? '';
        final addressSuperShortFull =
            (field['addressSuperShortFull'] as String?)?.toLowerCase().trim() ??
                '';
        return name.contains(query) ||
            addressSuperShort.contains(query) ||
            addressSuperShortFull.contains(query);
      }).toList();
    }

    state = state.copyWith(filteredFields: filtered);
  }

  /// Load fields for selected sport
  Future<void> _loadFields() async {
    if (state.sport == null) return;

    state = state.copyWith(
      isLoadingFields: true,
      availableFields: [],
      filteredFields: [],
    );

    try {
      final fieldsActions = _ref.read(fieldsActionsProvider);

      final sportType = switch (state.sport) {
        'basketball' => 'basketball',
        'volleyball' => 'beachvolleyball',
        'table_tennis' => 'table_tennis',
        'skateboard' => 'skateboard',
        'boules' => 'boules',
        'swimming' => 'swimming',
        _ => 'soccer',
      };

      final rawFields = await fieldsActions.fetchFields(
        sportType: sportType,
        bypassCache: true,
      );

      NumberedLogger.d(
        'Fetched ${rawFields.length} raw fields for sport: $sportType',
      );

      final fields = FieldDataProcessor.normalizeFields(rawFields);

      NumberedLogger.d(
        'Normalized to ${fields.length} fields with valid coordinates',
      );

      // Match preselected field if editing
      Map<String, dynamic>? matchedField = state.field;
      if (state.field != null) {
        final match =
            FieldDataProcessor.findMatchingField(state.field!, fields);
        if (match.isNotEmpty) {
          matchedField = match;
          NumberedLogger.i(
            'Matched preselected field: ${match['name']} (id: ${match['id']})',
          );
        }
      }

      state = state.copyWith(
        availableFields: fields,
        isLoadingFields: false,
        field: matchedField,
      );

      _applyFieldSearchFilter();

      // Update distances in background
      _updateFieldDistances(fields);
    } catch (e) {
      NumberedLogger.e('Failed to load fields: $e');
      state = state.copyWith(
        availableFields: [],
        filteredFields: [],
        isLoadingFields: false,
      );
    }
  }

  /// Update field distances and sort by distance
  Future<void> _updateFieldDistances(List<Map<String, dynamic>> fields) async {
    state = state.copyWith(isCalculatingDistances: true);

    try {
      final locationActions = _ref.read(locationActionsProvider);
      final userPosition = await locationActions.getCurrentPosition();

      final fieldsWithDistances = await Future.wait(
        fields.map((field) async {
          final lat = safeToDouble(field['latitude']);
          final lon = safeToDouble(field['longitude']);

          if (lat == null || lon == null) {
            return field;
          }

          final distance = calculateDistanceMeters(
            startLat: userPosition.latitude,
            startLon: userPosition.longitude,
            endLat: lat,
            endLon: lon,
          );

          return {
            ...field,
            'distance': distance,
          };
        }),
      );

      // Sort by distance
      fieldsWithDistances.sort((a, b) {
        final distA = (a['distance'] as num?)?.toDouble() ?? double.infinity;
        final distB = (b['distance'] as num?)?.toDouble() ?? double.infinity;
        return distA.compareTo(distB);
      });

      // Update selected field to match the updated field from availableFields
      // This ensures reference equality works for UI selection highlighting
      Map<String, dynamic>? updatedSelectedField = state.field;
      if (state.field != null) {
        final match = FieldDataProcessor.findMatchingField(
          state.field!,
          fieldsWithDistances,
        );
        if (match.isNotEmpty) {
          updatedSelectedField = match;
        }
      }

      state = state.copyWith(
        availableFields: fieldsWithDistances,
        field: updatedSelectedField,
        isCalculatingDistances: false,
      );

      _applyFieldSearchFilter();
    } catch (e) {
      NumberedLogger.e('Failed to calculate field distances: $e');
      // If location fails (e.g., in emulator), still show fields without distance sorting
      // This prevents the app from breaking when location is unavailable
      // Still try to update selected field reference even if distances failed
      Map<String, dynamic>? updatedSelectedField = state.field;
      if (state.field != null) {
        final match = FieldDataProcessor.findMatchingField(
          state.field!,
          fields,
        );
        if (match.isNotEmpty) {
          updatedSelectedField = match;
        }
      }
      state = state.copyWith(
        availableFields: fields, // Show fields without distance
        field: updatedSelectedField,
        isCalculatingDistances: false,
      );
      _applyFieldSearchFilter();
    }
  }

  /// Load weather data for selected field and date
  Future<void> _loadWeather() async {
    if (state.field == null || state.date == null) {
      NumberedLogger.d(
          '🌤️ Weather: Skipping load - field=${state.field != null}, date=${state.date != null}');
      state = state.copyWith(weatherData: {});
      return;
    }

    final lat = safeToDouble(state.field!['latitude']);
    final lon = safeToDouble(state.field!['longitude']);

    if (lat == null || lon == null) {
      NumberedLogger.d(
          '🌤️ Weather: Skipping load - missing coordinates (lat=$lat, lon=$lon)');
      state = state.copyWith(weatherData: {});
      return;
    }

    NumberedLogger.d(
        '🌤️ Weather: Starting load for date=${state.date}, lat=$lat, lon=$lon');
    state = state.copyWith(isLoadingWeather: true);

    try {
      final weatherActions = _ref.read(weatherActionsProvider);
      final weather = await weatherActions.fetchWeatherForDate(
        date: state.date!,
        latitude: lat,
        longitude: lon,
      );

      NumberedLogger.d('🌤️ Weather: Loaded ${weather.length} hours of data');
      state = state.copyWith(
        weatherData: weather,
        isLoadingWeather: false,
      );
    } catch (e) {
      NumberedLogger.e('🌤️ Weather: Failed to load weather: $e');
      state = state.copyWith(
        weatherData: {},
        isLoadingWeather: false,
      );
    }
  }

  /// Load booked time slots for selected field and date
  Future<void> _loadBookedSlots() async {
    if (state.field == null || state.date == null) {
      state = state.copyWith(bookedTimes: {});
      return;
    }

    try {
      final cloudMatchesService = _ref.read(cloudMatchesServiceProvider);
      final bookedSlots = await cloudMatchesService.getBookedSlots(
        date: state.date!,
        field: state.field!,
      );

      state = state.copyWith(bookedTimes: bookedSlots);
    } catch (e) {
      NumberedLogger.e('Failed to load booked slots: $e');
      state = state.copyWith(bookedTimes: {});
    }
  }

  /// Load locked invites (for editing existing matches)
  Future<void> _loadLockedInvites() async {
    if (_initialMatch == null) return;

    try {
      final currentUserId = _ref.read(currentUserIdProvider);
      final isHistoricMatch = _initialMatch!.dateTime.isBefore(DateTime.now());

      if (isHistoricMatch) {
        // For historic matches: load all participants as friend invites
        final Set<String> allParticipants = <String>{};
        for (final playerId in _initialMatch!.players) {
          if (playerId != currentUserId) {
            allParticipants.add(playerId);
          }
        }

        // Try to get invited users
        try {
          final cloudMatchesActions = _ref.read(cloudMatchesActionsProvider);
          final statuses = await cloudMatchesActions
              .getMatchInviteStatuses(_initialMatch!.id);
          for (final uid in statuses.keys) {
            if (uid != currentUserId) {
              allParticipants.add(uid);
            }
          }
        } catch (_) {
          // If we can't load invite statuses, that's okay
        }

        state = state.copyWith(
          lockedInvitedUids: {},
          selectedFriendUids: allParticipants,
        );
      } else {
        // For future matches: load invite statuses as locked invites
        final cloudMatchesActions = _ref.read(cloudMatchesActionsProvider);
        final statuses =
            await cloudMatchesActions.getMatchInviteStatuses(_initialMatch!.id);

        state = state.copyWith(
          lockedInvitedUids: statuses.keys.toSet(),
          selectedFriendUids: statuses.keys.toSet(),
        );
      }
    } catch (e) {
      NumberedLogger.e('Failed to load locked invites: $e');
    }
  }

  /// Update selected friend UIDs
  void updateSelectedFriends(Set<String> friendUids) {
    state = state.copyWith(selectedFriendUids: friendUids);
  }

  /// Set loading state
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  /// Set success state
  void setSuccess(bool showSuccess) {
    state = state.copyWith(showSuccess: showSuccess);
  }

  /// Reset form to initial state (useful when creating a new match)
  void reset() {
    state = MatchFormState.initial();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

/// Provider for MatchFormNotifier
final matchFormNotifierProvider =
    StateNotifierProvider.family<MatchFormNotifier, MatchFormState, Match?>(
  (ref, initialMatch) => MatchFormNotifier(ref, initialMatch),
);
