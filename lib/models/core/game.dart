import 'dart:convert';

class Game {
  final String id;
  final String sport;
  final DateTime dateTime;
  final String location;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? fieldId; // canonical field identifier (e.g., OSM id)
  final int maxPlayers;
  final int currentPlayers;
  final String description;
  final String organizerId;
  final String organizerName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;
  final int? version;
  final bool isActive;
  final bool isPublic;
  final String? imageUrl;
  final List<String>
      skillLevels; // e.g., ['beginner', 'intermediate', 'advanced']
  final String? equipment; // e.g., 'Bring your own ball'
  final double? cost; // Optional cost per player
  final String? contactInfo; // Phone or email for contact
  final List<String> players; // List of player IDs who joined the game

  Game({
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

  // Create a copy with updated fields
  Game copyWith({
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
    return Game(
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

  // Convert to JSON for storage/API
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

  // Cloud-optimized JSON (Firebase): proper types for easier querying
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

  // Create from JSON
  factory Game.fromJson(Map<String, dynamic> json) {
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
      } catch (_) {}
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
      } catch (_) {}
    }

    // Prefer UTC field if present to avoid cross-timezone shifts
    final String? dtUtcStr = json['dateTimeUtc']?.toString();
    final DateTime dtParsed = dtUtcStr != null && dtUtcStr.isNotEmpty
        ? DateTime.parse(dtUtcStr).toLocal()
        : (DateTime.tryParse(json['dateTime']?.toString() ??
                DateTime.now().toIso8601String()) ??
            DateTime.now());

    return Game(
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

  // Helper methods
  bool get isFull => currentPlayers >= maxPlayers;
  bool get hasSpace => currentPlayers < maxPlayers;
  int get availableSpots => maxPlayers - currentPlayers;

  // Bench/Waitlist system helpers
  // Active players are the first maxPlayers in the list
  List<String> get activePlayers => players.take(maxPlayers).toList();

  // Bench players are those beyond maxPlayers
  List<String> get benchPlayers =>
      players.length > maxPlayers ? players.skip(maxPlayers).toList() : [];

  int get activeCount => activePlayers.length;
  int get benchCount => benchPlayers.length;

  // Check if a specific player is on the bench
  bool isPlayerOnBench(String playerId) {
    final index = players.indexOf(playerId);
    return index >= 0 && index >= maxPlayers;
  }

  // Check if a specific player is active
  bool isPlayerActive(String playerId) {
    final index = players.indexOf(playerId);
    return index >= 0 && index < maxPlayers;
  }

  // Get player position (1-indexed)
  int? getPlayerPosition(String playerId) {
    final index = players.indexOf(playerId);
    return index >= 0 ? index + 1 : null;
  }

  // Check if game is in the future
  bool get isUpcoming => dateTime.isAfter(DateTime.now());

  // Get formatted date string
  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final gameDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (gameDate == today) {
      return 'Today';
    } else if (gameDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  // Get formatted time string
  String get formattedTime {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Get duration until game starts
  Duration get timeUntilGame {
    return dateTime.difference(DateTime.now());
  }
}
