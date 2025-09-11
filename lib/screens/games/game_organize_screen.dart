import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/models/game.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/overpass_service.dart';
import 'package:move_young/services/weather_service.dart';
import 'package:move_young/services/games_service.dart';
import 'package:move_young/services/auth_service.dart';

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

  // Fields data
  List<Map<String, dynamic>> _availableFields = [];
  Map<String, dynamic>? _selectedField;
  bool _isLoadingFields = false;

  // Weather data
  Map<String, String> _weatherData = {};
  // Booked times for selected field/date
  final Set<String> _bookedTimes = {};

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

  // Load fields for the selected sport
  Future<void> _loadFields() async {
    if (_selectedSport == null) return;

    setState(() {
      _isLoadingFields = true;
      _availableFields = [];
      _selectedField = null;
    });

    try {
      // Map sport keys to OSM sport types
      final sportType = _selectedSport == 'soccer' ? 'soccer' : 'basketball';

      final fields = await OverpassService.fetchFields(
        areaName: "'s-Hertogenbosch",
        sportType: sportType,
      );

      setState(() {
        _availableFields = fields;
        _isLoadingFields = false;
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

    print(
        '🌤️ Loading weather for date: ${_selectedDate!.toIso8601String().split('T')[0]}');

    try {
      // Use a default location for 's-Hertogenbosch
      final weatherData = await WeatherService.fetchWeatherForDate(
        date: _selectedDate!,
        latitude: 51.6978, // 's-Hertogenbosch coordinates
        longitude: 5.3037,
      );

      print('🌤️ Weather data received: ${weatherData.length} hours');
      setState(() {
        _weatherData = weatherData;
      });
    } catch (e) {
      print('🌤️ Weather loading error: $e');
      // Set default weather data on error
      setState(() {
        _weatherData = {};
      });
    }
  }

  Future<void> _loadBookedSlots() async {
    if (_selectedField == null || _selectedDate == null) return;
    try {
      final name = (_selectedField?['name'] as String?) ?? '';
      if (name.isEmpty) return;
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
        maxPlayers: 10, // Default max players
        description: 'Game organized by user',
        organizerId: organizerId,
        organizerName: organizerName,
        createdAt: DateTime.now(),
        currentPlayers: 1,
        players: [organizerId], // Creator is counted as the first player
      );

      // Save game to SQLite database
      debugPrint('Creating game with data: ${game.toJson()}');
      await GamesService.createGame(game);
      debugPrint('Game created and saved: ${game.id}');

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('game_created_successfully'.tr()),
            backgroundColor: AppColors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Game creation error: $e');
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
      width: 70,
      height: 55, // Reduced height
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        color: AppColors.white,
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
                        ? (weatherColor?.withOpacity(0.15) ??
                            AppColors.lightgrey.withOpacity(0.15))
                        : AppColors.lightgrey.withOpacity(0.15),
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
      _selectedField = {
        'name': g.location,
        'address': g.address,
        'latitude': g.latitude,
        'longitude': g.longitude,
      };
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
                                      color:
                                          AppColors.grey.withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.card),
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
                                          final field = _availableFields[index];
                                          final isSelected =
                                              _selectedField == field;

                                          return Padding(
                                            padding: EdgeInsets.only(
                                              right: index <
                                                      _availableFields.length -
                                                          1
                                                  ? AppWidths.regular
                                                  : 0,
                                            ),
                                            child: _buildFieldCard(
                                              field: field,
                                              isSelected: isSelected,
                                              onTap: () {
                                                HapticFeedback.lightImpact();
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

                        // Date Selection Section (only show if field is selected)
                        if (_selectedField != null) ...[
                          PanelHeader(
                            'choose_date'.tr(),
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
                                              HapticFeedback.lightImpact();
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
                                        final weatherCondition = hasWeatherData
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
                                          child: _buildWeatherTimeCard(
                                            time: time,
                                            isSelected: isSelected,
                                            hasWeatherData: hasWeatherData,
                                            weatherCondition: weatherCondition,
                                            weatherIcon: weatherIcon,
                                            weatherColor: weatherColor,
                                            onTap: () {
                                              if (isBooked) return;
                                              HapticFeedback.lightImpact();
                                              setState(() {
                                                _selectedTime = time;
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

                        // Create Game Button (match header width via same padding)
                        Padding(
                          padding: AppPaddings.allReg,
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isFormComplete && !_isLoading
                                  ? _createGame
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFormComplete
                                    ? AppColors.blue
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
                                      'create_game'.tr(),
                                      style: AppTextStyles.cardTitle.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
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
