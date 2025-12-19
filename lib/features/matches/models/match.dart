import 'dart:convert';

/// Represents a match that users can join or organize.
///
/// A Match contains all information about a sporting event including:
/// - Location and timing details
/// - Player capacity and current participants
/// - Organizer information
/// - Match settings (public/private, active status, skill levels, etc.)
///
/// Matches support a bench/waitlist system where players beyond maxPlayers
/// are placed on the bench and can be promoted when spots become available.
class Match {
  /// Unique identifier for the match
  final String id;

  /// Sport type (e.g., 'football', 'basketball', 'tennis')
  final String sport;

  /// Date and time when the match takes place (in local timezone)
  final DateTime dateTime;

  /// Human-readable location name (e.g., "Central Park Field 1")
  final String location;

  /// Street address if available
  final String? address;

  /// Latitude coordinate for map display
  final double? latitude;

  /// Longitude coordinate for map display
  final double? longitude;

  /// Canonical field identifier (e.g., OpenStreetMap ID) for field matching
  final String? fieldId;

  /// Maximum number of players allowed in the match
  final int maxPlayers;

  /// Current number of players who have joined
  final int currentPlayers;

  /// Description of the match provided by the organizer
  final String description;

  /// User ID of the match organizer
  final String organizerId;

  /// Display name of the match organizer
  final String organizerName;

  /// Timestamp when the match was created
  final DateTime createdAt;

  /// Timestamp when the match was last updated (null if never updated)
  final DateTime? updatedAt;

  /// User ID who last updated the match (null if never updated)
  final String? updatedBy;

  /// Version number for optimistic locking (null if not using versioning)
  final int? version;

  /// Whether the match is currently active (cancelled matches are inactive)
  final bool isActive;

  /// Whether the match is publicly visible and joinable
  final bool isPublic;

  /// URL to an image representing the match or field
  final String? imageUrl;

  /// List of skill levels this match is suitable for
  /// (e.g., ['beginner', 'intermediate', 'advanced'])
  final List<String> skillLevels;

  /// Equipment requirements or notes (e.g., 'Bring your own ball')
  final String? equipment;

  /// Optional cost per player in the local currency
  final double? cost;

  /// Contact information (phone or email) for the organizer
  final String? contactInfo;

  /// List of player user IDs who have joined the match
  /// First [maxPlayers] are active players, rest are on the bench
  final List<String> players;

  Match({
    required this.id,
    required this.sport,
    required this.dateTime,
    required this.location,
    this.address,
    this.latitude,
    this.longitude,
    this.fieldId,
    required this.maxPlayers,
    this.currentPlayers = 0,
    required this.description,
    required this.organizerId,
    required this.organizerName,
    required this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.version,
    this.isActive = true,
    this.isPublic = true,
    this.imageUrl,
    this.skillLevels = const [],
    this.equipment,
    this.cost,
    this.contactInfo,
    this.players = const [],
  });

  /// Creates a copy of this match with updated fields.
  ///
  /// Only the provided fields will be updated; all others remain the same.
  Match copyWith({
    String? id,
    String? sport,
    DateTime? dateTime,
    String? location,
    String? address,
    double? latitude,
    double? longitude,
    String? fieldId,
    int? maxPlayers,
    int? currentPlayers,
    String? description,
    String? organizerId,
    String? organizerName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    int? version,
    bool? isActive,
    bool? isPublic,
    String? imageUrl,
    List<String>? skillLevels,
    String? equipment,
    double? cost,
    String? contactInfo,
    List<String>? players,
  }) {
    return Match(
      id: id ?? this.id,
      sport: sport ?? this.sport,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      fieldId: fieldId ?? this.fieldId,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      currentPlayers: currentPlayers ?? this.currentPlayers,
      description: description ?? this.description,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
      isActive: isActive ?? this.isActive,
      isPublic: isPublic ?? this.isPublic,
      imageUrl: imageUrl ?? this.imageUrl,
      skillLevels: skillLevels ?? this.skillLevels,
      equipment: equipment ?? this.equipment,
      cost: cost ?? this.cost,
      contactInfo: contactInfo ?? this.contactInfo,
      players: players ?? this.players,
    );
  }

  /// Converts the match to JSON format for local storage (SQLite).
  ///
  /// Uses integer representation for booleans and JSON-encoded strings
  /// for lists to be compatible with SQLite storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sport': sport,
      'dateTime': dateTime.toIso8601String(),
      'location': location,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'fieldId': fieldId,
      'maxPlayers': maxPlayers,
      'currentPlayers': currentPlayers,
      'description': description,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
      'version': version,
      'isActive': isActive ? 1 : 0, // Convert bool to int for SQLite
      'isPublic': isPublic ? 1 : 0,
      'imageUrl': imageUrl,
      'skillLevels': jsonEncode(skillLevels), // Convert list to JSON string
      'equipment': equipment,
      'cost': cost,
      'contactInfo': contactInfo,
      'players': jsonEncode(players), // Convert list to JSON string
    };
  }

  /// Converts the match to JSON format for cloud storage (Firebase).
  ///
  /// Uses native types (booleans, lists) for easier querying in Firebase.
  /// Includes both local and UTC timestamps for cross-timezone correctness.
  Map<String, dynamic> toCloudJson() {
    return {
      'id': id,
      'sport': sport,
      // Store both local ISO and UTC ISO for cross-timezone correctness
      'dateTime': dateTime.toIso8601String(),
      'dateTimeUtc': dateTime.toUtc().toIso8601String(),
      'location': location,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'fieldId': fieldId,
      'maxPlayers': maxPlayers,
      'currentPlayers': currentPlayers,
      'description': description,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'updatedBy': updatedBy,
      'version': version,
      'isActive': isActive,
      'isPublic': isPublic,
      'imageUrl': imageUrl,
      'skillLevels': skillLevels,
      'equipment': equipment,
      'cost': cost,
      'contactInfo': contactInfo,
      'players': players,
    };
  }

  /// Creates a Match instance from JSON data.
  ///
  /// Supports both local (SQLite) and cloud (Firebase) JSON formats.
  /// Handles type conversions and prefers UTC timestamps when available
  /// to avoid cross-timezone issues.
  factory Match.fromJson(Map<String, dynamic> json) {
    // Support both local (SQLite) and cloud (Firebase) shapes
    final dynamic createdAtRaw = json['createdAt'];
    final DateTime createdAtParsed = createdAtRaw is int
        ? DateTime.fromMillisecondsSinceEpoch(createdAtRaw)
        : DateTime.tryParse(createdAtRaw?.toString() ?? '') ?? DateTime.now();

    final dynamic isActiveRaw = json['isActive'];
    final bool isActiveParsed =
        isActiveRaw is bool ? isActiveRaw : ((isActiveRaw ?? 1) == 1);
    final dynamic isPublicRaw = json['isPublic'];
    final bool isPublicParsed =
        isPublicRaw is bool ? isPublicRaw : ((isPublicRaw ?? 1) == 1);

    final dynamic updatedAtRaw = json['updatedAt'];
    final DateTime? updatedAtParsed = updatedAtRaw == null
        ? null
        : (updatedAtRaw is int
            ? DateTime.fromMillisecondsSinceEpoch(updatedAtRaw)
            : DateTime.tryParse(updatedAtRaw.toString()));
    final int? versionParsed = json['version'] == null
        ? null
        : int.tryParse(json['version'].toString());

    // Players can be a List (cloud) or JSON string (local)
    final dynamic playersRaw = json['players'];
    List<String> playersParsed = const <String>[];
    if (playersRaw is List) {
      playersParsed = playersRaw.map((e) => e.toString()).toList();
    } else if (playersRaw is String && playersRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(playersRaw);
        if (decoded is List) {
          playersParsed = decoded.map((e) => e.toString()).toList();
        }
      } catch (e) {
        // Silently ignore JSON decode errors for players - use empty list as fallback
        // This can happen with corrupted data, but we don't want to crash the app
      }
    }

    // Skill levels can be List (cloud) or encoded string (local)
    final dynamic skillsRaw = json['skillLevels'];
    List<String> skillsParsed = const <String>[];
    if (skillsRaw is List) {
      skillsParsed = skillsRaw.map((e) => e.toString()).toList();
    } else if (skillsRaw is String && skillsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(skillsRaw);
        if (decoded is List) {
          skillsParsed = decoded.map((e) => e.toString()).toList();
        }
      } catch (e) {
        // Silently ignore JSON decode errors for skillLevels - use empty list as fallback
        // This can happen with corrupted data, but we don't want to crash the app
      }
    }

    // Prefer UTC field if present to avoid cross-timezone shifts
    final String? dtUtcStr = json['dateTimeUtc']?.toString();
    final DateTime dtParsed;
    if (dtUtcStr != null && dtUtcStr.isNotEmpty) {
      final parsed = DateTime.tryParse(dtUtcStr);
      dtParsed = parsed != null ? parsed.toLocal() : DateTime.now();
    } else {
      dtParsed = DateTime.tryParse(json['dateTime']?.toString() ??
              DateTime.now().toIso8601String()) ??
          DateTime.now();
    }

    return Match(
      id: json['id']?.toString() ?? '',
      sport: json['sport']?.toString() ?? '',
      dateTime: dtParsed,
      location: json['location']?.toString() ?? '',
      address: json['address']?.toString(),
      latitude: (json['latitude'] is num)
          ? (json['latitude'] as num).toDouble()
          : double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: (json['longitude'] is num)
          ? (json['longitude'] as num).toDouble()
          : double.tryParse(json['longitude']?.toString() ?? ''),
      fieldId: json['fieldId']?.toString(),
      maxPlayers: int.tryParse(json['maxPlayers']?.toString() ?? '') ?? 0,
      currentPlayers:
          int.tryParse(json['currentPlayers']?.toString() ?? '') ?? 0,
      description: json['description']?.toString() ?? '',
      organizerId: json['organizerId']?.toString() ?? '',
      organizerName: json['organizerName']?.toString() ?? '',
      createdAt: createdAtParsed,
      updatedAt: updatedAtParsed,
      updatedBy: json['updatedBy']?.toString(),
      version: versionParsed,
      isActive: isActiveParsed,
      isPublic: isPublicParsed,
      imageUrl: json['imageUrl']?.toString(),
      skillLevels: skillsParsed,
      equipment: json['equipment']?.toString(),
      cost: (json['cost'] is num)
          ? (json['cost'] as num).toDouble()
          : double.tryParse(json['cost']?.toString() ?? ''),
      contactInfo: json['contactInfo']?.toString(),
      players: playersParsed,
    );
  }

  /// Whether the match has reached maximum capacity
  bool get isFull => currentPlayers >= maxPlayers;

  /// Whether the match has available spots for new players
  bool get hasSpace => currentPlayers < maxPlayers;

  /// Number of available spots remaining
  int get availableSpots => maxPlayers - currentPlayers;

  /// Gets the list of active players (first [maxPlayers] in the players list)
  List<String> get activePlayers => players.take(maxPlayers).toList();

  /// Gets the list of players on the bench/waitlist (beyond [maxPlayers])
  List<String> get benchPlayers =>
      players.length > maxPlayers ? players.skip(maxPlayers).toList() : [];

  /// Number of active players currently in the match
  int get activeCount => activePlayers.length;

  /// Number of players on the bench/waitlist
  int get benchCount => benchPlayers.length;

  /// Checks if a specific player is on the bench.
  ///
  /// Returns `true` if the player is in the players list but beyond
  /// the [maxPlayers] threshold.
  bool isPlayerOnBench(String playerId) {
    final index = players.indexOf(playerId);
    return index >= 0 && index >= maxPlayers;
  }

  /// Checks if a specific player is an active participant.
  ///
  /// Returns `true` if the player is in the first [maxPlayers] positions.
  bool isPlayerActive(String playerId) {
    final index = players.indexOf(playerId);
    return index >= 0 && index < maxPlayers;
  }

  /// Gets the player's position in the match (1-indexed).
  ///
  /// Returns the position number (1, 2, 3, etc.) or `null` if the
  /// player is not in the match.
  int? getPlayerPosition(String playerId) {
    final index = players.indexOf(playerId);
    return index >= 0 ? index + 1 : null;
  }

  /// Whether the match is scheduled in the future
  bool get isUpcoming => dateTime.isAfter(DateTime.now());

  /// Gets a formatted date string (non-localized, for backwards compatibility).
  ///
  /// Returns "Today", "Tomorrow", or "DD/MM/YYYY" format.
  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final matchDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (matchDate == today) {
      return 'Today';
    } else if (matchDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// Gets a formatted date string with localization support.
  ///
  /// Uses the provided [translate] function to localize "today" and "tomorrow".
  /// Falls back to "DD/MM/YYYY" format for other dates.
  String getFormattedDateLocalized(String Function(String) translate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final matchDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (matchDate == today) {
      return translate('today');
    } else if (matchDate == today.add(const Duration(days: 1))) {
      return translate('tomorrow');
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// Gets a formatted time string in "HH:MM" format
  String get formattedTime {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Gets the duration until the match starts
  Duration get timeUntilMatch {
    return dateTime.difference(DateTime.now());
  }

  /// Checks if the match has been modified after creation.
  ///
  /// Returns `true` if [updatedAt] exists and differs from [createdAt]
  /// by more than 1 second (to account for timestamp precision).
  bool get isModified {
    if (updatedAt == null) return false;
    // Compare at millisecond precision to detect any edits
    return updatedAt!.difference(createdAt).inMilliseconds.abs() > 1000;
  }
}
