import 'dart:convert';

class Game {
  final String id;
  final String sport;
  final DateTime dateTime;
  final String location;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int maxPlayers;
  final int currentPlayers;
  final String description;
  final String organizerId;
  final String organizerName;
  final DateTime createdAt;
  final bool isActive;
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
    required this.maxPlayers,
    this.currentPlayers = 0,
    required this.description,
    required this.organizerId,
    required this.organizerName,
    required this.createdAt,
    this.isActive = true,
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
    int? maxPlayers,
    int? currentPlayers,
    String? description,
    String? organizerId,
    String? organizerName,
    DateTime? createdAt,
    bool? isActive,
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
      maxPlayers: maxPlayers ?? this.maxPlayers,
      currentPlayers: currentPlayers ?? this.currentPlayers,
      description: description ?? this.description,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
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
      'maxPlayers': maxPlayers,
      'currentPlayers': currentPlayers,
      'description': description,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive ? 1 : 0, // Convert bool to int for SQLite
      'imageUrl': imageUrl,
      'skillLevels': jsonEncode(skillLevels), // Convert list to JSON string
      'equipment': equipment,
      'cost': cost,
      'contactInfo': contactInfo,
      'players': jsonEncode(players), // Convert list to JSON string
    };
  }

  // Create from JSON
  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] ?? '',
      sport: json['sport'] ?? '',
      dateTime:
          DateTime.parse(json['dateTime'] ?? DateTime.now().toIso8601String()),
      location: json['location'] ?? '',
      address: json['address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      maxPlayers: json['maxPlayers'] ?? 0,
      currentPlayers: json['currentPlayers'] ?? 0,
      description: json['description'] ?? '',
      organizerId: json['organizerId'] ?? '',
      organizerName: json['organizerName'] ?? '',
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isActive: (json['isActive'] ?? 1) == 1, // Convert int to bool for SQLite
      imageUrl: json['imageUrl'],
      skillLevels: json['skillLevels'] != null
          ? List<String>.from(jsonDecode(json['skillLevels']))
          : [],
      equipment: json['equipment'],
      cost: json['cost']?.toDouble(),
      contactInfo: json['contactInfo'],
      players: json['players'] != null
          ? List<String>.from(jsonDecode(json['players']))
          : [],
    );
  }

  // Helper methods
  bool get isFull => currentPlayers >= maxPlayers;
  bool get hasSpace => currentPlayers < maxPlayers;
  int get availableSpots => maxPlayers - currentPlayers;

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
