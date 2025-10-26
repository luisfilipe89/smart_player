import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/auth/auth_provider.dart';
import 'package:move_young/services/games/games_provider.dart';
import 'package:move_young/services/friends/friends_provider.dart';
import 'package:move_young/services/external/weather_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GameOrganizeScreen extends ConsumerStatefulWidget {
  final Game? initialGame;
  const GameOrganizeScreen({super.key, this.initialGame});

  @override
  ConsumerState<GameOrganizeScreen> createState() => _GameOrganizeScreenState();
}

class _GameOrganizeScreenState extends ConsumerState<GameOrganizeScreen> {
  String? _selectedSport;
  DateTime? _selectedDate;
  String? _selectedTime;
  int _maxPlayers = 10;

  // Scroll controller for auto-scrolling
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _createGameButtonKey = GlobalKey();

  // Fields data
  Map<String, dynamic>? _selectedField;
  bool _isPublic = true;

  // Friend selection
  final Set<String> _selectedFriends = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Available sports with their icons
  final List<Map<String, dynamic>> _sports = [
    {
      'key': 'soccer',
      'icon': Icons.sports_soccer,
      'color': const Color(0xFF4CAF50),
    },
    {
      'key': 'basketball',
      'icon': Icons.sports_basketball,
      'color': const Color(0xFFFF9800),
    },
    {
      'key': 'tennis',
      'icon': Icons.sports_tennis,
      'color': const Color(0xFF8BC34A),
    },
    {
      'key': 'volleyball',
      'icon': Icons.sports_volleyball,
      'color': const Color(0xFFE91E63),
    },
    {
      'key': 'badminton',
      'icon': Icons.sports_tennis,
      'color': const Color(0xFF9C27B0),
    },
    {
      'key': 'table_tennis',
      'icon': Icons.sports_tennis,
      'color': const Color(0xFF673AB7),
    },
    {
      'key': 'swimming',
      'icon': Icons.pool,
      'color': const Color(0xFF03A9F4),
    },
  ];

  @override
  void initState() {
    super.initState();

    // Initialize with existing game data if editing
    if (widget.initialGame != null) {
      final game = widget.initialGame!;
      _selectedSport = game.sport;
      _selectedDate = game.dateTime;
      _selectedTime = _formatTime(game.dateTime);
      _maxPlayers = game.maxPlayers;
      _isPublic = game.isPublic;

      // Load field data if available
      if (game.fieldId != null && game.fieldId!.isNotEmpty) {
        // Set selected field based on game data
        _selectedField = {
          'id': game.fieldId,
          'name': game.location, // Use location as field name for now
          'location': game.location,
        };
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _createGame() async {
    if (_selectedSport == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    try {
      final currentUserAsync = ref.read(currentUserProvider);
      if (currentUserAsync.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to create a game'),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }
      final currentUser = currentUserAsync.value!;

      // Parse time
      final timeParts = _selectedTime!.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final gameDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        hour,
        minute,
      );

      final game = Game(
        id: widget.initialGame?.id ?? '',
        sport: _selectedSport!,
        dateTime: gameDateTime,
        location: _selectedField?['name'] ?? 'Unknown Location',
        fieldId: _selectedField?['id'],
        maxPlayers: _maxPlayers,
        currentPlayers: 1, // Organizer is automatically included
        description: '',
        organizerId: currentUser.uid,
        organizerName: currentUser.displayName ?? 'Unknown',
        createdAt: DateTime.now(),
        address: _selectedField?['address'],
        latitude: _selectedField?['lat'],
        longitude: _selectedField?['lon'],
        skillLevels: [],
        equipment: '',
        cost: 0.0,
        contactInfo: '',
        imageUrl: _selectedField?['image'],
        players: [currentUser.uid],
        isActive: true,
        isPublic: _isPublic,
      );

      if (widget.initialGame != null) {
        // Update existing game
        await ref.read(gamesActionsProvider).updateGame(game);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game updated successfully'),
              backgroundColor: AppColors.green,
            ),
          );
        }
      } else {
        // Create new game
        await ref.read(gamesActionsProvider).createGame(game);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game created successfully'),
              backgroundColor: AppColors.green,
            ),
          );
        }
      }

      // Navigate back
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create game: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialGame != null ? 'Edit Game' : 'Organize Game'),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: const AppBackButton(),
      ),
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: AppPaddings.allMedium,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sport Selection
              _buildSportSelection(),
              const SizedBox(height: AppHeights.reg),

              // Date Selection
              _buildDateSelection(),
              const SizedBox(height: AppHeights.reg),

              // Time Selection
              _buildTimeSelection(),
              const SizedBox(height: AppHeights.reg),

              // Field Selection
              _buildFieldSelection(),
              const SizedBox(height: AppHeights.reg),

              // Max Players
              _buildMaxPlayersSelection(),
              const SizedBox(height: AppHeights.reg),

              // Public/Private Toggle
              _buildPublicToggle(),
              const SizedBox(height: AppHeights.reg),

              // Friend Invites
              _buildFriendInvites(),
              const SizedBox(height: AppHeights.reg),

              // Create/Update Game Button
              _buildCreateGameButton(),
              const SizedBox(height: AppHeights.reg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSportSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sport *',
          style: AppTextStyles.cardTitle,
        ),
        const SizedBox(height: AppHeights.small),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _sports.map((sport) {
            final isSelected = _selectedSport == sport['key'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSport = sport['key'];
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? sport['color'] : AppColors.white,
                  border: Border.all(
                    color: isSelected ? sport['color'] : AppColors.lightgrey,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.container),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      sport['icon'],
                      color: isSelected ? AppColors.white : sport['color'],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sport['key'].toString().toUpperCase(),
                      style: AppTextStyles.cardTitle.copyWith(
                        color: isSelected ? AppColors.white : sport['color'],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date *',
          style: AppTextStyles.cardTitle,
        ),
        const SizedBox(height: AppHeights.small),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              setState(() {
                _selectedDate = date;
              });
              // Load weather data for the selected date
              if (mounted) {
                _loadWeatherForDate(date);
              }
            }
          },
          child: Container(
            padding: AppPaddings.allMedium,
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.lightgrey),
              borderRadius: BorderRadius.circular(AppRadius.container),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  _selectedDate != null
                      ? DateFormat('EEEE, MMMM d, y').format(_selectedDate!)
                      : 'Select date',
                  style: AppTextStyles.cardTitle,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time *',
          style: AppTextStyles.cardTitle,
        ),
        const SizedBox(height: AppHeights.small),
        GestureDetector(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: _selectedTime != null
                  ? TimeOfDay(
                      hour: int.parse(_selectedTime!.split(':')[0]),
                      minute: int.parse(_selectedTime!.split(':')[1]),
                    )
                  : TimeOfDay.now(),
            );
            if (time != null) {
              setState(() {
                _selectedTime =
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
              });
            }
          },
          child: Container(
            padding: AppPaddings.allMedium,
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.lightgrey),
              borderRadius: BorderRadius.circular(AppRadius.container),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  _selectedTime ?? 'Select time',
                  style: AppTextStyles.cardTitle,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Field',
          style: AppTextStyles.cardTitle,
        ),
        const SizedBox(height: AppHeights.small),
        GestureDetector(
          onTap: () async {
            _showFieldSelectionSheet();
          },
          child: Container(
            padding: AppPaddings.allMedium,
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.lightgrey),
              borderRadius: BorderRadius.circular(AppRadius.container),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedField?['name'] ?? 'Select field',
                    style: AppTextStyles.cardTitle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaxPlayersSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Max Players',
          style: AppTextStyles.cardTitle,
        ),
        const SizedBox(height: AppHeights.small),
        Row(
          children: [
            IconButton(
              onPressed:
                  _maxPlayers > 2 ? () => setState(() => _maxPlayers--) : null,
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Text(
                _maxPlayers.toString(),
                textAlign: TextAlign.center,
                style: AppTextStyles.cardTitle,
              ),
            ),
            IconButton(
              onPressed:
                  _maxPlayers < 50 ? () => setState(() => _maxPlayers++) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPublicToggle() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Public Game',
            style: AppTextStyles.cardTitle,
          ),
        ),
        Switch(
          value: _isPublic,
          onChanged: (value) => setState(() => _isPublic = value),
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildFriendInvites() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invite Friends',
          style: AppTextStyles.cardTitle,
        ),
        const SizedBox(height: AppHeights.small),
        GestureDetector(
          onTap: () {
            _showFriendSelectionSheet();
          },
          child: Container(
            padding: AppPaddings.allMedium,
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.lightgrey),
              borderRadius: BorderRadius.circular(AppRadius.container),
            ),
            child: Row(
              children: [
                Icon(Icons.person_add, color: AppColors.grey),
                const SizedBox(width: 12),
                Text(
                  _selectedFriends.isEmpty
                      ? 'Select friends to invite'
                      : '${_selectedFriends.length} friend${_selectedFriends.length == 1 ? '' : 's'} selected',
                  style:
                      AppTextStyles.cardTitle.copyWith(color: AppColors.grey),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateGameButton() {
    final isFormValid = _selectedSport != null &&
        _selectedDate != null &&
        _selectedTime != null;

    return ElevatedButton(
      key: _createGameButtonKey,
      onPressed: isFormValid ? _createGame : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        padding: AppPaddings.allMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.container),
        ),
      ),
      child: Text(
        widget.initialGame != null ? 'Update Game' : 'Create Game',
        style: AppTextStyles.cardTitle.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _loadWeatherForDate(DateTime date) async {
    try {
      // Use default Amsterdam coordinates if no field is selected
      final latitude = _selectedField?['lat']?.toDouble() ?? 52.3676;
      final longitude = _selectedField?['lon']?.toDouble() ?? 4.9041;

      final weatherActions = ref.read(weatherActionsProvider);
      if (weatherActions != null) {
        await weatherActions.fetchWeatherForDate(
          date: date,
          latitude: latitude,
          longitude: longitude,
        );
        if (mounted) {
          // Weather data loaded successfully
          // Could be used to display weather information in the UI
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load weather data: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showFieldSelectionSheet() {
    // Sample fields data - in a real app this would come from a service
    final sampleFields = [
      {
        'id': 'field1',
        'name': 'Central Park Field',
        'location': 'Central Park, Amsterdam',
        'type': 'Soccer'
      },
      {
        'id': 'field2',
        'name': 'Sports Complex Court',
        'location': 'Sports Complex, Amsterdam',
        'type': 'Basketball'
      },
      {
        'id': 'field3',
        'name': 'Tennis Club Court',
        'location': 'Tennis Club, Amsterdam',
        'type': 'Tennis'
      },
      {
        'id': 'field4',
        'name': 'Community Center',
        'location': 'Community Center, Amsterdam',
        'type': 'Multi-purpose'
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Field',
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: 16),
            ...sampleFields.map((field) => ListTile(
                  leading:
                      const Icon(Icons.location_on, color: AppColors.primary),
                  title: Text(field['name']!),
                  subtitle: Text(field['location']!),
                  trailing: _selectedField?['id'] == field['id']
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedField = field;
                    });
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedField = null;
                });
                Navigator.pop(context);
              },
              child: const Text('Clear Selection'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFriendSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Select Friends to Invite',
                    style: AppTextStyles.cardTitle,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedFriends.clear();
                      });
                    },
                    child: const Text('Clear All'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Friends list
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final friendsAsync = ref.watch(friendsListProvider);

                  return friendsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Error loading friends: $error'),
                          ElevatedButton(
                            onPressed: () =>
                                ref.invalidate(friendsListProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                    data: (friends) {
                      if (friends.isEmpty) {
                        return const Center(
                          child:
                              Text('No friends found. Add some friends first!'),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friendId = friends[index];
                          return _buildFriendSelectionItem(friendId);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendSelectionItem(String friendId) {
    final isSelected = _selectedFriends.contains(friendId);

    return FutureBuilder<Map<String, String?>>(
      future: ref.read(friendsActionsProvider).fetchMinimalProfile(friendId),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final displayName = profile?['displayName'] ?? 'Unknown User';
        final photoURL = profile?['photoURL'];

        return ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundImage: photoURL != null && photoURL.isNotEmpty
                ? CachedNetworkImageProvider(photoURL)
                : null,
            child: photoURL == null || photoURL.isEmpty
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?')
                : null,
          ),
          title: Text(displayName),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedFriends.add(friendId);
                } else {
                  _selectedFriends.remove(friendId);
                }
              });
            },
          ),
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedFriends.remove(friendId);
              } else {
                _selectedFriends.add(friendId);
              }
            });
          },
        );
      },
    );
  }
}
