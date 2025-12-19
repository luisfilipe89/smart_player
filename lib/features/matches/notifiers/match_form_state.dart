import 'package:flutter/foundation.dart';
import 'package:move_young/features/matches/models/match.dart';

/// Immutable state class for the match form
@immutable
class MatchFormState {
  // Form fields
  final String? sport;
  final DateTime? date;
  final String? time;
  final Map<String, dynamic>? field;
  final int maxPlayers;
  final bool isPublic;

  // Loading states
  final bool isLoading;
  final bool isLoadingFields;
  final bool isCalculatingDistances;
  final bool isLoadingWeather;
  final bool showSuccess;

  // Fields data
  final List<Map<String, dynamic>> availableFields;
  final List<Map<String, dynamic>> filteredFields;
  final String fieldSearchQuery;

  // Weather and booking data
  final Map<String, String> weatherData;
  final Set<String> bookedTimes;

  // Friend invites
  final Set<String> selectedFriendUids;
  final Set<String> lockedInvitedUids;

  // Original values for change detection (when editing)
  final String? originalSport;
  final DateTime? originalDate;
  final String? originalTime;
  final int originalMaxPlayers;
  final Map<String, dynamic>? originalField;

  // Initial match (for editing)
  final bool isEditing;
  final bool isCreatingSimilarMatch;

  const MatchFormState({
    this.sport,
    this.date,
    this.time,
    this.field,
    this.maxPlayers = 10,
    this.isPublic = true,
    this.isLoading = false,
    this.isLoadingFields = false,
    this.isCalculatingDistances = false,
    this.isLoadingWeather = false,
    this.showSuccess = false,
    this.availableFields = const [],
    this.filteredFields = const [],
    this.fieldSearchQuery = '',
    this.weatherData = const {},
    this.bookedTimes = const {},
    this.selectedFriendUids = const {},
    this.lockedInvitedUids = const {},
    this.originalSport,
    this.originalDate,
    this.originalTime,
    this.originalMaxPlayers = 10,
    this.originalField,
    this.isEditing = false,
    this.isCreatingSimilarMatch = false,
  });

  /// Create initial state from an existing match (for editing)
  factory MatchFormState.fromMatch(Match match) {
    final isHistoric = match.dateTime.isBefore(DateTime.now());
    final isEditing = !isHistoric;

    final fieldMap = {
      'name': match.location,
      'address': match.address,
      'latitude': match.latitude,
      'longitude': match.longitude,
      'id': match.fieldId,
    };

    return MatchFormState(
      sport: match.sport,
      date: isHistoric
          ? null
          : DateTime(
              match.dateTime.year,
              match.dateTime.month,
              match.dateTime.day,
            ),
      time: isHistoric ? null : match.formattedTime,
      field: fieldMap,
      maxPlayers: match.maxPlayers,
      isPublic: match.isPublic,
      originalSport: isEditing ? match.sport : null,
      originalDate: isEditing
          ? DateTime(
              match.dateTime.year,
              match.dateTime.month,
              match.dateTime.day,
            )
          : null,
      originalTime: isEditing ? match.formattedTime : null,
      originalMaxPlayers: isEditing ? match.maxPlayers : 10,
      originalField: isEditing ? fieldMap : null,
      isEditing: isEditing,
      isCreatingSimilarMatch: isHistoric,
    );
  }

  /// Create initial empty state (for creating new match)
  factory MatchFormState.initial() {
    return const MatchFormState();
  }

  /// Copy with method for immutable updates
  MatchFormState copyWith({
    String? sport,
    DateTime? date,
    String? time,
    Map<String, dynamic>? field,
    int? maxPlayers,
    bool? isPublic,
    bool? isLoading,
    bool? isLoadingFields,
    bool? isCalculatingDistances,
    bool? isLoadingWeather,
    bool? showSuccess,
    List<Map<String, dynamic>>? availableFields,
    List<Map<String, dynamic>>? filteredFields,
    String? fieldSearchQuery,
    Map<String, String>? weatherData,
    Set<String>? bookedTimes,
    Set<String>? selectedFriendUids,
    Set<String>? lockedInvitedUids,
    String? Function()? originalSport,
    DateTime? Function()? originalDate,
    String? Function()? originalTime,
    int Function()? originalMaxPlayers,
    Map<String, dynamic>? Function()? originalField,
    bool? isEditing,
    bool? isCreatingSimilarMatch,
  }) {
    return MatchFormState(
      sport: sport ?? this.sport,
      date: date ?? this.date,
      time: time ?? this.time,
      field: field ?? this.field,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      isPublic: isPublic ?? this.isPublic,
      isLoading: isLoading ?? this.isLoading,
      isLoadingFields: isLoadingFields ?? this.isLoadingFields,
      isCalculatingDistances:
          isCalculatingDistances ?? this.isCalculatingDistances,
      isLoadingWeather: isLoadingWeather ?? this.isLoadingWeather,
      showSuccess: showSuccess ?? this.showSuccess,
      availableFields: availableFields ?? this.availableFields,
      filteredFields: filteredFields ?? this.filteredFields,
      fieldSearchQuery: fieldSearchQuery ?? this.fieldSearchQuery,
      weatherData: weatherData ?? this.weatherData,
      bookedTimes: bookedTimes ?? this.bookedTimes,
      selectedFriendUids: selectedFriendUids ?? this.selectedFriendUids,
      lockedInvitedUids: lockedInvitedUids ?? this.lockedInvitedUids,
      originalSport:
          originalSport != null ? originalSport() : this.originalSport,
      originalDate: originalDate != null ? originalDate() : this.originalDate,
      originalTime: originalTime != null ? originalTime() : this.originalTime,
      originalMaxPlayers: originalMaxPlayers != null
          ? originalMaxPlayers()
          : this.originalMaxPlayers,
      originalField:
          originalField != null ? originalField() : this.originalField,
      isEditing: isEditing ?? this.isEditing,
      isCreatingSimilarMatch:
          isCreatingSimilarMatch ?? this.isCreatingSimilarMatch,
    );
  }

  /// Check if form is complete
  bool get isFormComplete {
    return sport != null && field != null && date != null && time != null;
  }

  /// Check if any changes have been made (for editing)
  bool get hasChanges {
    if (!isEditing) return false;

    // Check if new friends were invited (exclude locked ones)
    final newInvites = selectedFriendUids
        .where((uid) => !lockedInvitedUids.contains(uid))
        .toSet();

    return sport != originalSport ||
        date != originalDate ||
        time != originalTime ||
        maxPlayers != originalMaxPlayers ||
        field?['name'] != originalField?['name'] ||
        newInvites.isNotEmpty;
  }
}
