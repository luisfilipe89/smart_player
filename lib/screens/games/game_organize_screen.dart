import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:move_young/services/haptics_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/models/game.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/overpass_service.dart';
import 'package:move_young/services/weather_service.dart';
import 'package:move_young/services/games_service.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/screens/main_scaffold.dart';
import 'package:move_young/services/friends_service.dart';
import 'package:move_young/services/cloud_games_service.dart';

class GameOrganizeScreen extends StatefulWidget {
  final Game? initialGame;
  const GameOrganizeScreen({super.key, this.initialGame});

  @override
  State<GameOrganizeScreen> createState() => _GameOrganizeScreenState();
}

class _GameOrganizeScreenState extends State<GameOrganizeScreen> {
  String? _selectedSport;
  DateTime? _selectedDate;
  String? _selectedTime;
  bool _isLoading = false;
  int _maxPlayers = 10;

  // Scroll controller for auto-scrolling
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _createGameButtonKey = GlobalKey();

  // Fields data
  List<Map<String, dynamic>> _availableFields = [];
  Map<String, dynamic>? _selectedField;
  bool _isLoadingFields = false;

  // Weather data
  Map<String, String> _weatherData = {};
  // Booked times for selected field/date
  final Set<String> _bookedTimes = {};

  // Friend invites (selected friend UIDs)
  final Set<String> _selectedFriendUids = <String>{};

  // Original values for change detection when editing
  String? _originalSport;
  DateTime? _originalDate;
  String? _originalTime;
  int _originalMaxPlayers = 10;
  Map<String, dynamic>? _originalField;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Auto-scroll to Create Game button
  void _scrollToCreateGameButton() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_createGameButtonKey.currentContext != null) {
        Scrollable.ensureVisible(
          _createGameButtonKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1, // Show button near the top of the screen
        );
      }
    });
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
      'icon': Icons.sports_handball,
      'color': const Color(0xFF9C27B0),
    },
    {
      'key': 'table_tennis',
      'icon': Icons.sports_tennis,
      'color': const Color(0xFF00BCD4),
    },
  ];

  // Generate list of dates for the next two weeks
  List<DateTime> get _availableDates {
    final today = DateTime.now();
    final dates = <DateTime>[];
    for (int i = 0; i < 14; i++) {
      dates.add(DateTime(today.year, today.month, today.day + i));
    }
    return dates;
  }

  List<String> get _availableTimes {
    final now = DateTime.now();
    final allTimes = [
      '09:00',
      '10:00',
      '11:00',
      '12:00',
      '13:00',
      '14:00',
      '15:00',
      '16:00',
      '17:00',
      '18:00',
      '19:00',
      '20:00',
      '21:00',
    ];

    // If no date is selected, return all times
    if (_selectedDate == null) return allTimes;

    // Check if selected date is today
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
    );

    if (selectedDate == today) {
      // Filter out past times for today
      final currentHour = now.hour;
      final currentMinute = now.minute;

      return allTimes.where((time) {
        final timeParts = time.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);

        // If the time is in the future, include it
        if (hour > currentHour ||
            (hour == currentHour && minute > currentMinute)) {
          return true;
        }
        return false;
      }).toList();
    }

    // For future dates, return all times
    return allTimes;
  }

  bool get _isFormComplete {
    return _selectedSport != null &&
        _selectedField != null &&
        _selectedDate != null &&
        _selectedTime != null;
  }

  // Check if any changes have been made to the game
  bool get _hasChanges {
    if (widget.initialGame == null) return false;

    return _selectedSport != _originalSport ||
        _selectedDate != _originalDate ||
        _selectedTime != _originalTime ||
        _maxPlayers != _originalMaxPlayers ||
        _selectedField?['name'] != _originalField?['name'];
  }

  // Load fields for the selected sport
  Future<void> _loadFields() async {
    if (_selectedSport == null) return;

    setState(() {
      _isLoadingFields = true;
      _availableFields = [];
    });

    try {
      // Only support soccer and basketball and keep 's-Hertogenbosch'
      final sportType =
          _selectedSport == 'basketball' ? 'basketball' : 'soccer';

      final rawFields = await OverpassService.fetchFields(
        areaName: "'s-Hertogenbosch",
        sportType: sportType,
      );

      // Normalize Overpass keys for UI consistency
      final fields = rawFields
          .map<Map<String, dynamic>>((f) {
            final name = f['name'] ?? 'Unnamed Field';
            final address = f['addr:street'] ?? f['address'];
            final lat = f['lat'] ?? f['latitude'];
            final lon = f['lon'] ?? f['longitude'];
            final lit = f['lit'] ?? f['lighting'];
            return {
              'name': name,
              'address': address,
              'latitude': lat,
              'longitude': lon,
              'surface': f['surface'],
              'lighting':
                  (lit == true) || (lit?.toString().toLowerCase() == 'yes'),
            };
          })
          .where((m) => m['latitude'] != null && m['longitude'] != null)
          .toList();

      setState(() {
        _availableFields = fields;
        _isLoadingFields = false;

        // If a field was preselected (e.g., editing a game), map it to the
        // corresponding instance from the freshly loaded list so identity
        // comparison (_selectedField == field) works for highlighting.
        if (_selectedField != null) {
          final String selName = (_selectedField?['name'] as String?) ?? '';
          final match = fields.firstWhere(
            (f) => (f['name'] as String?) == selName,
            orElse: () => {},
          );
          if (match.isNotEmpty) {
            _selectedField = match;
          }
        }
      });
    } catch (e) {
      setState(() {
        _availableFields = [];
        _isLoadingFields = false;
      });
    }
  }

  // Load weather data for the selected date
  Future<void> _loadWeather() async {
    if (_selectedDate == null) return;

    debugPrint(
        '🌤️ Loading weather for date: ${_selectedDate!.toIso8601String().split('T')[0]}');

    try {
      // Use a default location for 's-Hertogenbosch
      final weatherData = await WeatherService.fetchWeatherForDate(
        date: _selectedDate!,
        latitude: 51.6978, // 's-Hertogenbosch coordinates
        longitude: 5.3037,
      );

      debugPrint('🌤️ Weather data received: ${weatherData.length} hours');
      setState(() {
        _weatherData = weatherData;
      });
    } catch (e) {
      debugPrint('🌤️ Weather loading error: $e');
      // Set default weather data on error
      setState(() {
        _weatherData = {};
      });
    }
  }

  Future<void> _updateGame() async {
    // Final guard: block past date/time
    if (_selectedDate != null && _selectedTime != null) {
      final now = DateTime.now();
      final parts = _selectedTime!.split(':');
      final dt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      if (!dt.isAfter(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('please_select_future_time'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }
    }

    if (_selectedSport == null ||
        _selectedField == null ||
        _selectedDate == null ||
        _selectedTime == null ||
        widget.initialGame == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('form_fill_all_fields'.tr()),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Parse the selected time and combine with selected date
      final timeParts = _selectedTime!.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final combinedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        hour,
        minute,
      );

      final current = widget.initialGame!;
      final updated = current.copyWith(
        sport: _selectedSport!,
        dateTime: combinedDateTime,
        location: _selectedField?['name'] ?? current.location,
        address: _selectedField?['address'] ?? current.address,
        latitude: _selectedField?['latitude']?.toDouble() ?? current.latitude,
        longitude:
            _selectedField?['longitude']?.toDouble() ?? current.longitude,
        maxPlayers: _maxPlayers,
      );

      // Update local first
      await GamesService.updateGame(updated);
      // Best-effort cloud sync if signed in
      if (AuthService.isSignedIn) {
        try {
          await CloudGamesService.updateGame(updated);
        } catch (_) {}
      }

      if (mounted) {
        HapticsService.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('game_updated_successfully'.tr()),
            backgroundColor: AppColors.green,
          ),
        );
        // Navigate to My Games (Organizing tab) and highlight the updated game
        MainScaffoldScope.maybeOf(context)?.openMyGames(
          initialTab: 1,
          highlightGameId: updated.id,
          popToRoot: true,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'game_creation_failed'.tr()}: $e'),
            backgroundColor: AppColors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBookedSlots() async {
    if (_selectedField == null || _selectedDate == null) return;
    try {
      final name = (_selectedField?['name'] as String?) ?? '';
      if (name.isEmpty) return;
      // Combine local bookings (source of truth locally). Cloud inclusion can be added here in future.
      final games =
          await GamesService.getGamesForFieldOnDate(name, _selectedDate!);
      final times = <String>{};
      for (final g in games) {
        final hh = g.dateTime.hour.toString().padLeft(2, '0');
        final mm = g.dateTime.minute.toString().padLeft(2, '0');
        times.add('$hh:$mm');
      }
      if (mounted) {
        setState(() {
          _bookedTimes
            ..clear()
            ..addAll(times);
        });
      }
    } catch (_) {}
  }

  // Localized day of week and month abbreviations
  String _getDayOfWeekAbbr(DateTime date) {
    // EEE => Mon, Tue (localized). Some locales add a trailing '.' → strip it
    final s = DateFormat('EEE', context.locale.toString()).format(date);
    return s.replaceAll('.', '').toUpperCase();
  }

  String _getMonthAbbr(DateTime date) {
    // MMM => Jan, Feb (localized). Some locales add a trailing '.' → strip it
    final s = DateFormat('MMM', context.locale.toString()).format(date);
    return s.replaceAll('.', '').toUpperCase();
  }

  Future<void> _createGame() async {
    // Final guard: block past date/time
    if (_selectedDate != null && _selectedTime != null) {
      final now = DateTime.now();
      final parts = _selectedTime!.split(':');
      final dt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      if (!dt.isAfter(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('please_select_future_time'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }
    }
    if (_selectedSport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('please_select_sport'.tr()),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('please_select_date'.tr()),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('please_select_time'.tr()),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Parse the selected time and combine with selected date
      final timeParts = _selectedTime!.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final combinedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        hour,
        minute,
      );

      // Create a game object with selected field data
      final organizerId = AuthService.currentUserId ?? 'anonymous';
      final organizerName = AuthService.currentUserDisplayName;

      final game = Game(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sport: _selectedSport!,
        dateTime: combinedDateTime,
        location: _selectedField?['name'] ?? 'Unknown Field',
        address: _selectedField?['address'],
        latitude: _selectedField?['latitude']?.toDouble(),
        longitude: _selectedField?['longitude']?.toDouble(),
        maxPlayers: _maxPlayers,
        description: '',
        organizerId: organizerId,
        organizerName: organizerName,
        createdAt: DateTime.now(),
        currentPlayers: 1,
        players: [organizerId], // Creator is counted as the first player
      );

      // Save game to SQLite database (cloud-first ID already handled in service)
      debugPrint('Creating game with data: ${game.toJson()}');
      final createdId = await GamesService.createGame(game);
      // If cloud created a new id, keep local object id for navigation highlight
      final effectiveGame =
          game.id == createdId ? game : game.copyWith(id: createdId);

      debugPrint('Game created and saved: ${game.id}');

      if (mounted) {
        HapticsService.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('game_created_successfully'.tr()),
            backgroundColor: AppColors.green,
          ),
        );
        // Send in-app invites to selected friends (if signed in)
        if (AuthService.isSignedIn && _selectedFriendUids.isNotEmpty) {
          await CloudGamesService.invitePlayers(
            effectiveGame.id,
            _selectedFriendUids.toList(),
            sport: effectiveGame.sport,
            dateTime: effectiveGame.dateTime,
          );
        }
        if (mounted) {
          MainScaffoldScope.maybeOf(context)?.openMyGames(
            initialTab: 1,
            highlightGameId: effectiveGame.id,
            popToRoot: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Game creation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('max_active_organized_games')
                  ? 'max_active_organized_games'.tr()
                  : e.toString().contains('only_one_game_per_day')
                      ? 'only_one_game_per_day'.tr()
                      : '${'game_creation_failed'.tr()}: $e',
            ),
            backgroundColor: AppColors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSportCard({
    required Map<String, dynamic> sport,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: isSelected
            ? Border.all(color: AppColors.blue, width: 2)
            : Border.all(
                color: AppColors.grey.withValues(alpha: 0.3),
                width: 1,
              ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Sport Icon - smaller for compact design
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.blue.withValues(alpha: 0.1)
                          : (sport['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      sport['icon'] as IconData,
                      size: 20,
                      color:
                          isSelected ? AppColors.blue : sport['color'] as Color,
                    ),
                  ),
                ),

                const SizedBox(height: 2),

                // Sport Name - smaller text
                Expanded(
                  flex: 1,
                  child: Text(
                    sport['key'].toString().tr(),
                    style: AppTextStyles.superSmall.copyWith(
                      color: isSelected ? AppColors.blue : AppColors.blackText,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Selection indicator - smaller
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle,
                      color: AppColors.blue,
                      size: 10,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateCard({
    required DateTime date,
    required bool isSelected,
    required bool isToday,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        border: isSelected
            ? Border.all(color: AppColors.blue, width: 2)
            : Border.all(
                color: AppColors.grey.withValues(alpha: 0.3),
                width: 1,
              ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Month abbreviation
                Text(
                  _getMonthAbbr(date),
                  style: AppTextStyles.superSmall.copyWith(
                    color: isSelected
                        ? AppColors.blue
                        : isToday
                            ? AppColors.blue
                            : AppColors.grey,
                    fontWeight: FontWeight.w600,
                    fontSize: 7,
                  ),
                ),
                // Day of month
                Text(
                  date.day.toString(),
                  style: AppTextStyles.smallCardTitle.copyWith(
                    color: isSelected ? AppColors.blue : AppColors.blackText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Day of week
                Text(
                  _getDayOfWeekAbbr(date),
                  style: AppTextStyles.superSmall.copyWith(
                    color: isSelected
                        ? AppColors.blue
                        : isToday
                            ? AppColors.blue
                            : AppColors.grey,
                    fontWeight: FontWeight.w600,
                    fontSize: 7,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherTimeCard({
    required String time,
    required bool isSelected,
    required bool hasWeatherData,
    required String? weatherCondition,
    required IconData? weatherIcon,
    required Color? weatherColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        color: isSelected
            ? AppColors.blue.withValues(alpha: 0.06)
            : AppColors.white,
        border: isSelected
            ? Border.all(color: AppColors.blue, width: 2)
            : Border.all(
                color: AppColors.grey.withValues(alpha: 0.3),
                width: 1,
              ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.smallCard),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Weather Icon Section
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: hasWeatherData && weatherIcon != null
                        ? (weatherColor?.withValues(alpha: 0.15) ??
                            AppColors.lightgrey.withValues(alpha: 0.15))
                        : AppColors.lightgrey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: hasWeatherData && weatherIcon != null
                        ? Icon(
                            weatherIcon,
                            color: weatherColor ?? AppColors.grey,
                            size: 16,
                          )
                        : Icon(
                            Icons.wb_sunny_outlined,
                            color: AppColors.grey,
                            size: 16,
                          ),
                  ),
                ),

                const SizedBox(height: 4),

                // Time Section
                Text(
                  time,
                  style: AppTextStyles.smallCardTitle.copyWith(
                    color: isSelected ? AppColors.blue : AppColors.blackText,
                    fontSize: 14, // Reduced font size
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldCard({
    required Map<String, dynamic> field,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final surface = field['surface'] ?? 'Unknown';
    final lighting = field['lighting'] ?? false;
    final address = field['address'] ?? '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        width: 200,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isSelected
                ? AppColors.blue
                : AppColors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(AppWidths.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field['name'] ?? 'Unknown Field',
              style: AppTextStyles.smallCardTitle.copyWith(
                color: isSelected ? AppColors.blue : AppColors.blackText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              surface,
              style: AppTextStyles.superSmall.copyWith(
                color: AppColors.grey,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  lighting ? Icons.lightbulb : Icons.lightbulb_outline,
                  size: 12,
                  color: lighting ? Colors.amber : AppColors.grey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address,
                    style: AppTextStyles.superSmall.copyWith(
                      color: AppColors.grey,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pre-fill form if initial game provided and fields not set yet
    if (widget.initialGame != null && _selectedSport == null) {
      final g = widget.initialGame!;
      _selectedSport = g.sport;
      _selectedDate =
          DateTime(g.dateTime.year, g.dateTime.month, g.dateTime.day);
      _selectedTime = g.formattedTime;
      _maxPlayers = g.maxPlayers;
      _selectedField = {
        'name': g.location,
        'address': g.address,
        'latitude': g.latitude,
        'longitude': g.longitude,
      };

      // Store original values for change detection
      _originalSport = g.sport;
      _originalDate =
          DateTime(g.dateTime.year, g.dateTime.month, g.dateTime.day);
      _originalTime = g.formattedTime;
      _originalMaxPlayers = g.maxPlayers;
      _originalField = {
        'name': g.location,
        'address': g.address,
        'latitude': g.latitude,
        'longitude': g.longitude,
      };

      // Load fields for the selected sport
      _loadFields();
    }
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: Text('organize_game'.tr()),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: AppPaddings.symmHorizontalReg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.container),
                    boxShadow: AppShadows.md,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.container),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PanelHeader(
                            'choose_sport'.tr(),
                          ),

                          // Sport Selection - Horizontal Scrollable List
                          Padding(
                            padding: AppPaddings.symmHorizontalReg,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.translate(
                                  offset: const Offset(0, -6),
                                  child: SizedBox(
                                    height: 80,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _sports.length,
                                      itemBuilder: (context, index) {
                                        final sport = _sports[index];
                                        final isSelected =
                                            _selectedSport == sport['key'];

                                        return Padding(
                                          padding: EdgeInsets.only(
                                            right: index < _sports.length - 1
                                                ? AppWidths.small
                                                : 0,
                                          ),
                                          child: SizedBox(
                                            width:
                                                70, // Slightly wider for bigger icons
                                            child: _buildSportCard(
                                              sport: sport,
                                              isSelected: isSelected,
                                              onTap: () {
                                                HapticFeedback.lightImpact();
                                                setState(() {
                                                  _selectedSport = sport['key'];
                                                  _selectedField = null;
                                                  _selectedDate = null;
                                                  _selectedTime = null;
                                                  _availableFields = [];
                                                  _weatherData = {};
                                                });
                                                _loadFields();
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          //const SizedBox(height: AppHeights.reg),

                          // Available Fields Section (only show if sport is selected)
                          if (_selectedSport != null) ...[
                            PanelHeader(
                              'choose_field'.tr(),
                            ),
                            Padding(
                              padding: AppPaddings.symmHorizontalReg,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isLoadingFields)
                                    const Center(
                                        child: CircularProgressIndicator())
                                  else if (_availableFields.isEmpty)
                                    Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: AppColors.grey
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.card),
                                        border: Border.all(
                                          color: AppColors.grey
                                              .withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'no_fields_available'.tr(),
                                          style: AppTextStyles.body
                                              .copyWith(color: AppColors.grey),
                                        ),
                                      ),
                                    )
                                  else
                                    Transform.translate(
                                      offset: const Offset(0, -6),
                                      child: SizedBox(
                                        height: 120,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _availableFields.length,
                                          itemBuilder: (context, index) {
                                            final field =
                                                _availableFields[index];
                                            final isSelected =
                                                _selectedField == field;

                                            return Padding(
                                              padding: EdgeInsets.only(
                                                right: index <
                                                        _availableFields
                                                                .length -
                                                            1
                                                    ? AppWidths.regular
                                                    : 0,
                                              ),
                                              child: _buildFieldCard(
                                                field: field,
                                                isSelected: isSelected,
                                                onTap: () {
                                                  HapticsService.lightImpact();
                                                  setState(() {
                                                    _selectedField = field;
                                                  });
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            //const SizedBox(height: AppHeights.huge),
                          ],

                          // Max Players Slider (right after field)
                          if (_selectedField != null) ...[
                            PanelHeader('max_players'.tr()),
                            Padding(
                              padding: AppPaddings.symmHorizontalReg,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Transform.translate(
                                    offset: const Offset(0, -6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.group_outlined,
                                            color: AppColors.grey, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderTheme.of(context)
                                                .copyWith(
                                              activeTrackColor: AppColors.blue,
                                              inactiveTrackColor: AppColors.blue
                                                  .withValues(alpha: 0.2),
                                              thumbColor: AppColors.blue,
                                              overlayColor: AppColors.blue
                                                  .withValues(alpha: 0.1),
                                              valueIndicatorColor:
                                                  AppColors.blue,
                                            ),
                                            child: Slider(
                                              value: _maxPlayers.toDouble(),
                                              min: 2,
                                              max: 10,
                                              divisions: 8,
                                              label: _maxPlayers.toString(),
                                              onChanged: (v) {
                                                setState(() {
                                                  _maxPlayers = v.round();
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 40,
                                          child: Center(
                                            child: Text('$_maxPlayers',
                                                style: AppTextStyles.body),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Date Selection Section (only show if field is selected)
                            //const SizedBox(height: AppHeights.reg),
                            Transform.translate(
                              offset: const Offset(0, -8),
                              child: PanelHeader(
                                'choose_date'.tr(),
                              ),
                            ),
                            Padding(
                              padding: AppPaddings.symmHorizontalReg,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Transform.translate(
                                    offset: const Offset(0, -6),
                                    child: SizedBox(
                                      height: 65,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _availableDates.length,
                                        itemBuilder: (context, index) {
                                          final date = _availableDates[index];
                                          final isSelected =
                                              _selectedDate == date;
                                          final isToday = date.day ==
                                                  DateTime.now().day &&
                                              date.month ==
                                                  DateTime.now().month &&
                                              date.year == DateTime.now().year;

                                          return Padding(
                                            padding: EdgeInsets.only(
                                              right: index <
                                                      _availableDates.length - 1
                                                  ? AppWidths.regular
                                                  : 0,
                                            ),
                                            child: _buildDateCard(
                                              date: date,
                                              isSelected: isSelected,
                                              isToday: isToday,
                                              onTap: () {
                                                HapticsService.lightImpact();
                                                setState(() {
                                                  if (isSelected) {
                                                    // If clicking on the already selected date, unselect it
                                                    _selectedDate = null;
                                                    _weatherData = {};
                                                  } else {
                                                    // Select the new date
                                                    _selectedDate = date;
                                                  }
                                                });
                                                // Load weather + booked slots
                                                if (_selectedDate != null) {
                                                  _loadWeather();
                                                  _loadBookedSlots();
                                                  // Auto-scroll to Create Game button after selecting date
                                                  _scrollToCreateGameButton();
                                                }
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            //const SizedBox(height: AppHeights.huge),
                          ],

                          // Time Selection Section (only show if date is selected)
                          if (_selectedDate != null) ...[
                            PanelHeader(
                              'choose_time'.tr(),
                            ),
                            Padding(
                              padding: AppPaddings.symmHorizontalReg,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Transform.translate(
                                    offset: const Offset(0, -6),
                                    child: SizedBox(
                                      height: 80,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _availableTimes.length,
                                        itemBuilder: (context, index) {
                                          final time = _availableTimes[index];
                                          final isSelected =
                                              _selectedTime == time;
                                          final isBooked =
                                              _bookedTimes.contains(time);
                                          // Only show weather if data is available
                                          final hasWeatherData =
                                              _weatherData.isNotEmpty;
                                          final weatherCondition =
                                              hasWeatherData
                                                  ? _weatherData[time]
                                                  : null;
                                          final weatherIcon = hasWeatherData &&
                                                  weatherCondition != null
                                              ? WeatherService.getWeatherIcon(
                                                  time, weatherCondition)
                                              : null;
                                          final weatherColor = hasWeatherData &&
                                                  weatherCondition != null
                                              ? WeatherService.getWeatherColor(
                                                  weatherCondition)
                                              : null;

                                          return Padding(
                                            padding: EdgeInsets.only(
                                              right: index <
                                                      _availableTimes.length - 1
                                                  ? AppWidths.regular
                                                  : 0,
                                            ),
                                            child: Opacity(
                                              opacity: isBooked ? 0.5 : 1.0,
                                              child: _buildWeatherTimeCard(
                                                time: time,
                                                isSelected: isSelected,
                                                hasWeatherData: hasWeatherData,
                                                weatherCondition:
                                                    weatherCondition,
                                                weatherIcon: weatherIcon,
                                                weatherColor: isBooked
                                                    ? AppColors.lightgrey
                                                    : weatherColor,
                                                onTap: () {
                                                  if (isBooked) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(SnackBar(
                                                            content: Text(
                                                                'time_slot_unavailable'
                                                                    .tr())));
                                                    return;
                                                  }
                                                  HapticFeedback.lightImpact();
                                                  setState(() {
                                                    _selectedTime = time;
                                                  });
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            //const SizedBox(height: AppHeights.huge),
                          ],

                          // Invite Friends Section (optional, after time is chosen)
                          if (_selectedTime != null &&
                              AuthService.currentUserId != null) ...[
                            PanelHeader('invite_friends_label'.tr()),
                            Padding(
                              padding: AppPaddings.symmHorizontalReg,
                              child: _FriendPicker(
                                currentUid: AuthService.currentUserId!,
                                initiallySelected: _selectedFriendUids,
                                onToggle: (uid, selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedFriendUids.add(uid);
                                    } else {
                                      _selectedFriendUids.remove(uid);
                                    }
                                  });
                                },
                              ),
                            ),
                          ],

                          // Create Game Button (match header width via same padding)
                          Padding(
                            key: _createGameButtonKey,
                            padding: AppPaddings.allReg,
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isFormComplete && !_isLoading
                                    ? (widget.initialGame != null
                                        ? _updateGame
                                        : _createGame)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFormComplete
                                      ? (widget.initialGame != null
                                          ? (_hasChanges
                                              ? Colors.orange
                                              : AppColors.green)
                                          : AppColors.blue)
                                      : AppColors.grey,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.card),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        widget.initialGame != null
                                            ? 'update_game'.tr()
                                            : 'create_game'.tr(),
                                        style: AppTextStyles.cardTitle.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          // Invite friends moved to Join a Game screen
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendPicker extends StatelessWidget {
  final String currentUid;
  final Set<String> initiallySelected;
  final void Function(String uid, bool selected) onToggle;

  const _FriendPicker({
    required this.currentUid,
    required this.initiallySelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.container),
        boxShadow: AppShadows.md,
      ),
      child: StreamBuilder<List<String>>(
        stream: FriendsService.friendsStream(currentUid),
        builder: (context, snapshot) {
          final friendUids = snapshot.data ?? const <String>[];
          if (friendUids.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('no_friends_to_invite'.tr(),
                  style: AppTextStyles.small.copyWith(color: AppColors.grey)),
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            primary: false,
            itemCount: friendUids.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.lightgrey),
            itemBuilder: (context, i) {
              final uid = friendUids[i];
              return FutureBuilder<Map<String, String?>>(
                future: FriendsService.fetchMinimalProfile(uid),
                builder: (context, snap) {
                  final data = snap.data ??
                      const {'displayName': 'User', 'photoURL': null};
                  final name = data['displayName'] ?? 'User';
                  final photo = data['photoURL'];
                  final selected = initiallySelected.contains(uid);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.superlightgrey,
                      backgroundImage: (photo != null && photo.isNotEmpty)
                          ? CachedNetworkImageProvider(photo)
                          : null,
                      child: (photo == null || photo.isEmpty)
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Text(name, style: AppTextStyles.body),
                    trailing: Checkbox(
                      value: selected,
                      onChanged: (v) => onToggle(uid, v == true),
                    ),
                    onTap: () => onToggle(uid, !selected),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
