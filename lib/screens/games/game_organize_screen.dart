import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/auth/auth_provider.dart';
import 'package:move_young/services/games/games_provider.dart';
import 'package:move_young/services/games/cloud_games_provider.dart';
import 'package:move_young/services/external/weather_provider.dart';
import 'package:move_young/services/fields/fields_provider.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:move_young/widgets/friends/friend_picker_widget.dart';
import 'package:move_young/screens/main_scaffold.dart';
import 'package:move_young/widgets/common/success_checkmark_overlay.dart';
import 'package:move_young/providers/infrastructure/firebase_providers.dart';

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
  bool _isLoading = false;
  int _maxPlayers = 10;
  bool _showSuccess = false;

  // Scroll controller for auto-scrolling
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _createGameButtonKey = GlobalKey();

  // Fields data
  List<Map<String, dynamic>> _availableFields = [];
  Map<String, dynamic>? _selectedField;
  bool _isLoadingFields = false;
  bool _isPublic = true;

  // Weather data
  Map<String, String> _weatherData = {};
  // Booked times for selected field/date
  final Set<String> _bookedTimes = {};

  // Friend invites (selected friend UIDs)
  final Set<String> _selectedFriendUids = <String>{};
  // Locked invited users when editing an existing game
  final Set<String> _lockedInvitedUids = <String>{};

  // Original values for change detection when editing
  String? _originalSport;
  DateTime? _originalDate;
  String? _originalTime;
  int _originalMaxPlayers = 10;
  Map<String, dynamic>? _originalField;

  void _showSignInInlinePrompt() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('please_sign_in'.tr()),
        backgroundColor: AppColors.red,
      ),
    );
  }

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

    // Check if new friends were invited (exclude locked ones)
    final newInvites = _selectedFriendUids
        .where((uid) => !_lockedInvitedUids.contains(uid))
        .toSet();

    return _selectedSport != _originalSport ||
        _selectedDate != _originalDate ||
        _selectedTime != _originalTime ||
        _maxPlayers != _originalMaxPlayers ||
        _selectedField?['name'] != _originalField?['name'] ||
        newInvites.isNotEmpty; // New check for friend invitations
  }

  // Load fields for the selected sport
  Future<void> _loadFields() async {
    if (_selectedSport == null) return;

    if (mounted) {
      setState(() {
        _isLoadingFields = true;
        _availableFields = [];
      });
    }

    try {
      final fieldsActions = ref.read(fieldsActionsProvider);

      // Only support soccer and basketball and keep 's-Hertogenbosch'
      final sportType =
          _selectedSport == 'basketball' ? 'basketball' : 'soccer';

      final rawFields = await fieldsActions.fetchFields(
        areaName: 's-Hertogenbosch',
        sportType: sportType,
        bypassCache: true, // Force fresh fetch to debug
      );

      // Debug: Check what we got back
      print(
          '🔍 Fetched ${rawFields.length} raw fields for sport: $sportType in area: s-Hertogenbosch');
      if (rawFields.isNotEmpty) {
        print('🔍 First field data: ${rawFields.first}');
      }

      // Normalize Overpass keys for UI consistency
      final fields = rawFields
          .map<Map<String, dynamic>>((f) {
            final name = f['name'] ?? 'Unnamed Field';
            final address = f['addr:street'] ?? f['address'];
            final lat = f['lat'] ?? f['latitude'];
            final lon = f['lon'] ?? f['longitude'];
            final lit = f['lit'] ?? f['lighting'];
            return {
              'id': f['id'],
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

      print('🔍 Normalized to ${fields.length} fields with valid coordinates');

      if (mounted) {
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
      }
    } catch (e) {
      // Log the error so we can see Overpass or parsing failures
      // ignore: avoid_print
      print('❌ Failed to load fields: $e');
      if (mounted) {
        setState(() {
          _availableFields = [];
          _isLoadingFields = false;
        });
      }
    }
  }

  // Load weather data for the selected date
  Future<void> _loadWeather() async {
    if (_selectedDate == null) {
      debugPrint('🌤️ Weather: No selected date');
      return;
    }

    try {
      final weatherActions = ref.read(weatherActionsProvider);
      debugPrint(
          '🌤️ Weather: Fetching for date ${_selectedDate!}, lat 51.6978, lon 5.3037');

      // Use a default location for 's-Hertogenbosch
      final weatherData = await weatherActions.fetchWeatherForDate(
        date: _selectedDate!,
        latitude: 51.6978, // 's-Hertogenbosch coordinates
        longitude: 5.3037,
      );

      debugPrint('🌤️ Weather: Received ${weatherData.length} hours of data');

      if (mounted) {
        setState(() {
          _weatherData = weatherData;
        });
      }
    } catch (e) {
      debugPrint('🌤️ Weather: Error - $e');
      // Set default weather data on error
      if (mounted) {
        setState(() {
          _weatherData = {};
        });
      }
    }
  }

  Future<void> _updateGame() async {
    // If no changes in edit mode, show info and exit early
    if (widget.initialGame != null && !_hasChanges) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No changes were made'),
            backgroundColor: AppColors.grey,
          ),
        );
      }
      return;
    }
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

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

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
      final String newLocation = _selectedField?['name'] ?? current.location;
      final String? newAddress = _selectedField?['address'] ?? current.address;
      final double? newLat =
          _selectedField?['latitude']?.toDouble() ?? current.latitude;
      final double? newLon =
          _selectedField?['longitude']?.toDouble() ?? current.longitude;
      final String? newFieldId =
          _selectedField?['id']?.toString() ?? current.fieldId;

      // Update game through provider
      final updatedGame = current.copyWith(
        dateTime: combinedDateTime,
        location: newLocation,
        address: newAddress,
        latitude: newLat,
        longitude: newLon,
        fieldId: newFieldId,
      );

      await ref.read(gamesActionsProvider).updateGame(updatedGame);

      // Send invites to newly selected friends
      final userId = ref.read(currentUserIdProvider);
      if (userId != null && _selectedFriendUids.isNotEmpty) {
        // Filter out already-invited friends (locked ones)
        final newInvites = _selectedFriendUids
            .where((uid) => !_lockedInvitedUids.contains(uid))
            .toList();

        if (newInvites.isNotEmpty) {
          try {
            await ref
                .read(cloudGamesActionsProvider)
                .sendGameInvitesToFriends(current.id, newInvites);
            debugPrint(
                '✅ Successfully sent invites to ${newInvites.length} friends');
          } catch (e, stackTrace) {
            // Log error but don't fail game update
            debugPrint('❌ Failed to send game invites: $e');
            debugPrint('Stack trace: $stackTrace');
            // Show error to user so they know invites weren't sent
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Game updated but failed to send invites: ${e.toString().replaceAll('Exception: ', '')}',
                          style:
                              AppTextStyles.body.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }

      if (mounted) {
        ref.read(hapticsActionsProvider)?.mediumImpact();
        setState(() => _showSuccess = true);
        Future.delayed(const Duration(milliseconds: 750), () {
          if (mounted) setState(() => _showSuccess = false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('game_updated_successfully'.tr()),
            backgroundColor: AppColors.green,
          ),
        );
        // Navigate to My Games → Organized and highlight the updated game
        final ctrl = MainScaffoldController.maybeOf(context);
        ctrl?.openMyGames(
            initialTab: 1, highlightGameId: updatedGame.id, popToRoot: true);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'game_creation_failed'.tr();
        final es = e.toString();
        final isSlotUnavailable = es.contains('new_slot_unavailable') ||
            es.contains('time_slot_unavailable');

        if (isSlotUnavailable) {
          errorMsg = 'time_slot_unavailable'.tr();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.block,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMsg,
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
          HapticFeedback.mediumImpact();
        } else {
          if (es.contains('not_authorized')) {
            errorMsg = 'not_authorized'.tr();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppColors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
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
    debugPrint('🔍 _loadBookedSlots() called');
    if (_selectedField == null || _selectedDate == null) {
      debugPrint(
          '🔍 _loadBookedSlots() early return: field=${_selectedField?.toString()}, date=${_selectedDate?.toString()}');
      return;
    }
    try {
      // Compute dateKey = yyyy-MM-dd
      final d = _selectedDate!;
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      final dateKey = '$y-$m-$day';

      // Compute fieldKey (prefer id, else lat_lon with underscores, else sanitized name)
      String fieldKey = '';
      final id = _selectedField?['id']?.toString();
      if (id != null && id.trim().isNotEmpty) {
        fieldKey = id.trim();
      } else if (_selectedField?['latitude'] != null &&
          _selectedField?['longitude'] != null) {
        final lat = (_selectedField?['latitude'] as num).toDouble();
        final lon = (_selectedField?['longitude'] as num).toDouble();
        final latFixed = lat.toStringAsFixed(5).replaceAll('.', '_');
        final lonFixed = lon.toStringAsFixed(5).replaceAll('.', '_');
        fieldKey = '${latFixed}_${lonFixed}';
      } else {
        final name = (_selectedField?['name']?.toString() ?? '').toLowerCase();
        final sanitized = name
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'_+'), '_')
            .trim();
        fieldKey = sanitized.isEmpty ? 'unknown_field' : sanitized;
      }

      final db = ref.read(firebaseDatabaseProvider);
      final path = 'slots/$dateKey/$fieldKey';
      debugPrint(
          '🔍 Loading booked slots: dateKey=$dateKey, fieldKey=$fieldKey, path=$path');
      debugPrint(
          '🔍 Selected field: ${_selectedField?['name']}, id=${_selectedField?['id']}, lat=${_selectedField?['latitude']}, lon=${_selectedField?['longitude']}');

      final times = <String>{};
      try {
        final snapshot = await db.ref(path).get();

        if (snapshot.exists && snapshot.value is Map) {
          final map = Map<dynamic, dynamic>.from(snapshot.value as Map);
          debugPrint('🔍 Found ${map.keys.length} booked slots in Firebase');
          for (final k in map.keys) {
            var t = k.toString();
            if (t.length == 4) {
              t = '${t.substring(0, 2)}:${t.substring(2)}';
            }
            final normalizedTime = t.trim();
            times.add(normalizedTime);
            debugPrint(
                '🔍 Found booked time: $normalizedTime (raw: ${k.toString()})');
          }
        } else {
          debugPrint(
              '🔍 No slots found at path: $path (exists=${snapshot.exists})');
        }
      } catch (e) {
        debugPrint(
            '🔍 Firebase slots read failed (may be permission denied): $e');
        // Continue to fallback
      }

      // Fallback: infer from games if slots node is empty
      if (times.isEmpty) {
        debugPrint('🔍 Slots empty, trying fallback from games...');
        try {
          final gamesService = ref.read(gamesServiceProvider);
          final myGames = await gamesService.getMyGames();
          final joinable = await gamesService.getJoinableGames();
          final all = <dynamic>[]
            ..addAll(myGames)
            ..addAll(joinable);
          debugPrint(
              '🔍 Checking ${all.length} games (${myGames.length} my, ${joinable.length} joinable)');

          String sanitizeName(String s) => s
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
              .replaceAll(RegExp(r'_+'), '_')
              .trim();

          bool sameField(dynamic g) {
            final gLat = (g.latitude);
            final gLon = (g.longitude);
            final hasCoords = gLat != null && gLon != null;
            final gKey = hasCoords
                ? '${gLat.toStringAsFixed(5).replaceAll('.', '_')}_${gLon.toStringAsFixed(5).replaceAll('.', '_')}'
                : sanitizeName(g.location);
            if (gKey == fieldKey) return true;
            if (hasCoords &&
                _selectedField?['latitude'] != null &&
                _selectedField?['longitude'] != null) {
              final sLat = (_selectedField?['latitude'] as num).toDouble();
              final sLon = (_selectedField?['longitude'] as num).toDouble();
              if ((gLat - sLat).abs() < 1e-5 && (gLon - sLon).abs() < 1e-5) {
                return true;
              }
            }
            return sanitizeName(g.location) ==
                sanitizeName(_selectedField?['name']?.toString() ?? '');
          }

          for (final g in all) {
            final gDateKey =
                '${g.dateTime.year.toString().padLeft(4, '0')}-${g.dateTime.month.toString().padLeft(2, '0')}-${g.dateTime.day.toString().padLeft(2, '0')}';
            if (gDateKey != dateKey) continue;
            if (!sameField(g)) continue;
            final hh = g.dateTime.hour.toString().padLeft(2, '0');
            final mm = g.dateTime.minute.toString().padLeft(2, '0');
            final timeStr = '$hh:$mm';
            times.add(timeStr);
            debugPrint(
                '🔍 Fallback found booked time: $timeStr from game ${g.id} at ${g.location}');
          }
          debugPrint('🔍 Fallback found ${times.length} booked times total');
        } catch (e) {
          debugPrint('🔍 Fallback error: $e');
        }
      }
      if (mounted) {
        debugPrint('🔍 Setting _bookedTimes to: ${times.toList()}');
        setState(() {
          _bookedTimes
            ..clear()
            ..addAll(times);
        });
        debugPrint('🔍 _bookedTimes after setState: ${_bookedTimes.toList()}');
      }
    } catch (e) {
      debugPrint('🔍 Error loading booked slots: $e');
    }
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
      // Inline prompt near time section
      setState(() {
        // No-op state change; rely on UI hint rendering below
      });
      _scrollToCreateGameButton();
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

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
      final userId = ref.read(currentUserIdProvider);
      final userDisplayName = ref.read(currentUserDisplayNameProvider);

      if (userId == null) {
        // Inline prompt via bottom sheet is already handled on Home; here avoid global snack
        _showSignInInlinePrompt();
        return;
      }

      final game = Game(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sport: _selectedSport!,
        dateTime: combinedDateTime,
        location: _selectedField?['name'] ?? 'Unknown Field',
        address: _selectedField?['address'],
        latitude: _selectedField?['latitude']?.toDouble(),
        longitude: _selectedField?['longitude']?.toDouble(),
        fieldId: _selectedField?['id']?.toString(),
        maxPlayers: _maxPlayers,
        description: '',
        organizerId: userId,
        organizerName: userDisplayName,
        createdAt: DateTime.now(),
        isPublic: _isPublic,
        currentPlayers: 1,
        players: [userId], // Creator is counted as the first player
      );

      final createdId = await ref.read(gamesActionsProvider).createGame(game);

      if (mounted) {
        ref.read(hapticsActionsProvider)?.mediumImpact();
        setState(() => _showSuccess = true);
        Future.delayed(const Duration(milliseconds: 750), () {
          if (mounted) setState(() => _showSuccess = false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('game_created_successfully'.tr()),
            backgroundColor: AppColors.green,
          ),
        );

        // Send in-app invites to selected friends (if signed in)
        if (_selectedFriendUids.isNotEmpty) {
          try {
            await ref.read(cloudGamesActionsProvider).sendGameInvitesToFriends(
                createdId, _selectedFriendUids.toList());
            debugPrint(
                '✅ Successfully sent invites to ${_selectedFriendUids.length} friends');
          } catch (e, stackTrace) {
            // Log error but don't fail game creation
            debugPrint('❌ Failed to send game invites: $e');
            debugPrint('Stack trace: $stackTrace');
            // Show error to user so they know invites weren't sent
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Game created but failed to send invites: ${e.toString().replaceAll('Exception: ', '')}',
                          style:
                              AppTextStyles.body.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }

        // Navigate to My Games → Organized and highlight the created game
        final ctrl = MainScaffoldController.maybeOf(context);
        ctrl?.openMyGames(
            initialTab: 1, highlightGameId: createdId, popToRoot: true);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'game_creation_failed'.tr();
        final es = e.toString();
        final isSlotUnavailable = es.contains('new_slot_unavailable') ||
            es.contains('time_slot_unavailable');

        if (isSlotUnavailable) {
          errorMsg = 'time_slot_unavailable'.tr();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.block,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMsg,
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
          HapticFeedback.mediumImpact();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppColors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
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
    bool disabled = false,
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
                      color: disabled
                          ? AppColors.grey.withValues(alpha: 0.06)
                          : (isSelected
                              ? AppColors.blue.withValues(alpha: 0.1)
                              : (sport['color'] as Color)
                                  .withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      sport['icon'] as IconData,
                      size: 20,
                      color: disabled
                          ? AppColors.grey
                          : (isSelected
                              ? AppColors.blue
                              : sport['color'] as Color),
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
                      color: disabled
                          ? AppColors.grey
                          : (isSelected ? AppColors.blue : AppColors.blackText),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle,
                      color: disabled ? AppColors.grey : AppColors.blue,
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
    bool isDisabled = false,
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
            : (isDisabled
                ? AppColors.lightgrey.withValues(alpha: 0.18)
                : AppColors.white),
        border: isSelected
            ? Border.all(color: AppColors.blue, width: 2)
            : (isDisabled
                ? Border.all(
                    color: AppColors.grey.withValues(alpha: 0.5),
                    width: 1,
                  )
                : Border.all(
                    color: AppColors.grey.withValues(alpha: 0.3),
                    width: 1,
                  )),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.smallCard),
          onTap: isDisabled ? null : onTap,
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
                    color: isDisabled
                        ? AppColors.lightgrey.withValues(alpha: 0.25)
                        : (hasWeatherData && weatherIcon != null
                            ? (weatherColor?.withValues(alpha: 0.15) ??
                                AppColors.lightgrey.withValues(alpha: 0.15))
                            : AppColors.lightgrey.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: hasWeatherData && weatherIcon != null && !isDisabled
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
                    color: isDisabled
                        ? AppColors.grey
                        : (isSelected ? AppColors.blue : AppColors.blackText),
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

  Widget _buildVisibilityCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        height: 60, // Much smaller
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.blue.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isSelected
                ? AppColors.blue
                : AppColors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.blue : AppColors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTextStyles.body.copyWith(
                color: isSelected ? AppColors.blue : AppColors.blackText,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
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
      // Load existing invites to lock them in edit mode
      _loadLockedInvites();
    }
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: Text('organize_a_game'.tr()),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SuccessCheckmarkOverlay(
          show: _showSuccess,
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

                                          final bool isEdit =
                                              widget.initialGame != null;
                                          return Padding(
                                            padding: EdgeInsets.only(
                                              right: index < _sports.length - 1
                                                  ? AppWidths.small
                                                  : 0,
                                            ),
                                            child: SizedBox(
                                              width:
                                                  70, // Slightly wider for bigger icons
                                              child: IgnorePointer(
                                                ignoring: isEdit,
                                                child: _buildSportCard(
                                                  sport: sport,
                                                  isSelected: isSelected,
                                                  disabled: isEdit,
                                                  onTap: () {
                                                    HapticFeedback
                                                        .lightImpact();
                                                    setState(() {
                                                      _selectedSport =
                                                          sport['key'];
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
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

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
                                            style: AppTextStyles.body.copyWith(
                                                color: AppColors.grey),
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
                                                    HapticFeedback
                                                        .lightImpact();
                                                    setState(() {
                                                      _selectedField = field;
                                                      // Clear previous field's busy times and selected time
                                                      _bookedTimes.clear();
                                                      _selectedTime = null;
                                                    });
                                                    _loadBookedSlots();
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
                                                activeTrackColor:
                                                    (widget.initialGame != null)
                                                        ? AppColors.grey
                                                            .withValues(
                                                                alpha: 0.4)
                                                        : AppColors.blue,
                                                inactiveTrackColor: (widget
                                                            .initialGame !=
                                                        null)
                                                    ? AppColors.grey
                                                        .withValues(alpha: 0.2)
                                                    : AppColors.blue
                                                        .withValues(alpha: 0.2),
                                                thumbColor:
                                                    (widget.initialGame != null)
                                                        ? AppColors.grey
                                                        : AppColors.blue,
                                                overlayColor: (widget
                                                            .initialGame !=
                                                        null)
                                                    ? AppColors.grey
                                                        .withValues(alpha: 0.1)
                                                    : AppColors.blue
                                                        .withValues(alpha: 0.1),
                                                valueIndicatorColor:
                                                    (widget.initialGame != null)
                                                        ? AppColors.grey
                                                        : AppColors.blue,
                                              ),
                                              child: Slider(
                                                value: _maxPlayers.toDouble(),
                                                min: 2,
                                                max: 10,
                                                divisions: 8,
                                                label: _maxPlayers.toString(),
                                                onChangeStart: (_) {
                                                  ref
                                                      .read(
                                                          hapticsActionsProvider)
                                                      ?.selectionClick();
                                                },
                                                onChanged:
                                                    (widget.initialGame != null)
                                                        ? null
                                                        : (v) {
                                                            setState(() {
                                                              _maxPlayers =
                                                                  v.round();
                                                            });
                                                          },
                                                onChangeEnd: (_) {
                                                  ref
                                                      .read(
                                                          hapticsActionsProvider)
                                                      ?.lightImpact();
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
                                                date.year ==
                                                    DateTime.now().year;

                                            return Padding(
                                              padding: EdgeInsets.only(
                                                right: index <
                                                        _availableDates.length -
                                                            1
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
                                            if (index == 0) {
                                              debugPrint(
                                                  '🔍 UI: First time slot check - time=$time, isBooked=$isBooked, _bookedTimes=${_bookedTimes.toList()}');
                                            }
                                            // Only show weather if data is available
                                            final hasWeatherData =
                                                _weatherData.isNotEmpty;
                                            final weatherCondition =
                                                hasWeatherData
                                                    ? _weatherData[time]
                                                    : null;

                                            final weatherIcon = hasWeatherData &&
                                                    weatherCondition != null
                                                ? ref
                                                    .read(
                                                        weatherActionsProvider)
                                                    .getWeatherIcon(
                                                        time, weatherCondition)
                                                : null;
                                            final weatherColor = hasWeatherData &&
                                                    weatherCondition != null
                                                ? ref
                                                    .read(
                                                        weatherActionsProvider)
                                                    .getWeatherColor(
                                                        weatherCondition)
                                                : null;

                                            return Padding(
                                              padding: EdgeInsets.only(
                                                right: index <
                                                        _availableTimes.length -
                                                            1
                                                    ? AppWidths.regular
                                                    : 0,
                                              ),
                                              child: Opacity(
                                                opacity: isBooked ? 0.5 : 1.0,
                                                child: _buildWeatherTimeCard(
                                                  time: time,
                                                  isSelected: isSelected,
                                                  isDisabled: isBooked,
                                                  hasWeatherData:
                                                      hasWeatherData,
                                                  weatherCondition:
                                                      weatherCondition,
                                                  weatherIcon: weatherIcon,
                                                  weatherColor: weatherColor,
                                                  onTap: () {
                                                    if (isBooked) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.block,
                                                                color: Colors
                                                                    .white,
                                                                size: 20,
                                                              ),
                                                              const SizedBox(
                                                                  width: 12),
                                                              Expanded(
                                                                child: Text(
                                                                  'time_slot_unavailable'
                                                                      .tr(),
                                                                  style: AppTextStyles
                                                                      .body
                                                                      .copyWith(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          backgroundColor:
                                                              AppColors.red,
                                                          duration:
                                                              const Duration(
                                                                  seconds: 3),
                                                          behavior:
                                                              SnackBarBehavior
                                                                  .floating,
                                                        ),
                                                      );
                                                      HapticFeedback
                                                          .mediumImpact();
                                                      return;
                                                    }
                                                    HapticFeedback
                                                        .lightImpact();
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

                            // Visibility Selection (create only, after time is chosen)
                            if (_selectedTime != null &&
                                widget.initialGame == null) ...[
                              PanelHeader('choose_visibility'.tr()),
                              Padding(
                                padding: AppPaddings.symmHorizontalReg,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildVisibilityCard(
                                            title: 'public'.tr(),
                                            icon: Icons.public,
                                            isSelected: _isPublic,
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              setState(() => _isPublic = true);
                                            },
                                          ),
                                        ),
                                        const SizedBox(
                                            width: AppWidths.regular),
                                        Expanded(
                                          child: _buildVisibilityCard(
                                            title: 'private'.tr(),
                                            icon: Icons.lock,
                                            isSelected: !_isPublic,
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              setState(() => _isPublic = false);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Invite Friends Section (optional, after time is chosen)
                            if (_selectedTime != null) ...[
                              PanelHeader('invite_friends_label'.tr()),
                              Padding(
                                padding: AppPaddings.symmHorizontalReg,
                                child: FriendPicker(
                                  currentUid:
                                      ref.read(currentUserIdProvider) ?? '',
                                  initiallySelected: _selectedFriendUids,
                                  lockedUids: widget.initialGame != null
                                      ? _lockedInvitedUids
                                      : const <String>{},
                                  onToggle: (uid, selected) {
                                    // Prevent toggling locked invites in edit mode
                                    if (widget.initialGame != null &&
                                        _lockedInvitedUids.contains(uid)) {
                                      return;
                                    }
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
                                          style:
                                              AppTextStyles.cardTitle.copyWith(
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadLockedInvites() async {
    if (widget.initialGame == null) return;
    try {
      final statuses =
          await ref.read(cloudGamesActionsProvider).getGameInviteStatuses(
                widget.initialGame!.id,
              );
      if (!mounted) return;
      setState(() {
        _lockedInvitedUids
          ..clear()
          ..addAll(statuses.keys);
      });
    } catch (_) {}
  }
}
