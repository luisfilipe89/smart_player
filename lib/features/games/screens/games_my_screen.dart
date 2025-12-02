import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/features/games/models/game.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/features/games/services/games_provider.dart';
import 'package:move_young/features/games/services/cloud_games_provider.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/features/games/screens/games_join_screen.dart';
import 'package:move_young/features/games/screens/game_organize_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:move_young/features/friends/services/friends_provider.dart';
import 'package:move_young/services/external/weather_provider.dart';
import 'package:move_young/utils/error_extensions.dart';
import 'package:move_young/widgets/error_retry_widget.dart';
import 'package:move_young/widgets/tab_with_count.dart';
import 'package:move_young/widgets/app_back_button.dart';
import 'package:move_young/features/maps/screens/gmaps_screen.dart';
import 'package:move_young/services/calendar/calendar_service.dart';
import 'package:move_young/services/system/haptics_provider.dart';

class GamesMyScreen extends ConsumerStatefulWidget {
  final String? highlightGameId;
  final int initialTab;
  const GamesMyScreen({super.key, this.highlightGameId, this.initialTab = 0});

  @override
  ConsumerState<GamesMyScreen> createState() => _GamesMyScreenState();
}

class _GamesMyScreenState extends ConsumerState<GamesMyScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, GlobalKey> _itemKeys = {};
  late final TabController _tab;
  // Weather forecast cache per gameId: time("HH:00") -> condition
  final Map<String, Map<String, String>> _weatherByGameId = {};
  final Set<String> _weatherLoading = <String>{};
  // Calendar status cache per gameId: true = in calendar, false = not in calendar, null = checking
  final Map<String, bool?> _calendarStatusByGameId = {};
  final Set<String> _calendarLoading = <String>{};
  bool _calendarPreloadInProgress = false;
  // Profile cache: uid -> profile data
  final Map<String, Map<String, String?>> _profileCache = {};
  // Track which profiles are currently loading to avoid duplicate requests
  final Set<String> _profileLoading = <String>{};
  String? _highlightId;

  @override
  void initState() {
    super.initState();
    _tab =
        TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _highlightId = widget.highlightGameId;

    // Auto-refresh when user switches to the Joining tab (index 0)
    _tab.addListener(() {
      if (!_tab.indexIsChanging && _tab.index == 0) {
        _refreshData();
      }
    });

    // Schedule scroll to highlighted game after first frame
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToHighlightedGame());

    // Pre-load calendar statuses for all games when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadCalendarStatuses();
    });
  }

  /// Pre-load calendar statuses for all games from database
  Future<void> _preloadCalendarStatuses() async {
    if (!mounted || _calendarPreloadInProgress) return;

    _calendarPreloadInProgress = true;

    try {
      // Ensure CalendarService is initialized
      await CalendarService.initialize();

      // Get all games from providers
      final myGamesAsync = ref.read(myGamesProvider);
      final historicGamesAsync = ref.read(historicGamesProvider);

      // Collect all game IDs from all tabs
      final allGameIds = <String>{};

      // Get games from myGamesAsync if available
      final myGames = myGamesAsync.valueOrNull;
      if (myGames != null) {
        for (final game in myGames) {
          allGameIds.add(game.id);
        }
      }

      // Get games from historicGamesAsync if available
      final historicGames = historicGamesAsync.valueOrNull;
      if (historicGames != null) {
        for (final game in historicGames) {
          allGameIds.add(game.id);
        }
      }

      // Batch check calendar status for all games
      if (allGameIds.isEmpty) {
        _calendarPreloadInProgress = false;
        return;
      }

      // Get all games that are in calendar from database
      final gamesInCalendar = await CalendarService.getAllGamesInCalendar();
      final gamesInCalendarSet = gamesInCalendar.toSet();

      // Update cache for all games
      if (mounted) {
        setState(() {
          for (final gameId in allGameIds) {
            _calendarStatusByGameId[gameId] =
                gamesInCalendarSet.contains(gameId);
          }
          _calendarPreloadInProgress = false;
        });
        debugPrint(
            'Preloaded calendar statuses for ${allGameIds.length} games (${gamesInCalendarSet.length} in calendar)');
      } else {
        _calendarPreloadInProgress = false;
      }
    } catch (e, stackTrace) {
      debugPrint('Error preloading calendar statuses: $e');
      debugPrint('Stack trace: $stackTrace');
      // Non-critical, continue without cache
      if (mounted) {
        setState(() {
          _calendarPreloadInProgress = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _scrollToHighlightedGame({int attempts = 0}) {
    if (!mounted || _highlightId == null) return;
    final key = _itemKeys[_highlightId!];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightId = null);
      });
      return;
    }
    if (attempts < 6) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToHighlightedGame(attempts: attempts + 1);
      });
    }
  }

  void _refreshData() {
    // Providers will update automatically via Firebase real-time streams
  }

  // ---- Helpers restored ----
  Widget _buildParticipantsStrip(Game game) {
    final List<String> basePlayerUids = List<String>.from(game.players);

    return SizedBox(
      height: 44,
      child: ref.watch(gameInviteStatusesProvider(game.id)).when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (inviteStatuses) {
              final List<String> invited = inviteStatuses.keys.toList();
              // Keep invitees included visually even if they haven't joined yet
              final List<String> merged =
                  <String>{...basePlayerUids, ...invited}.toList();
              if (merged.isEmpty) return const SizedBox.shrink();

              // Fetch minimal profiles for merged set
              final List<String> limited = merged.take(12).toList();

              // Build profiles from cache immediately (synchronous)
              final List<Map<String, String?>> profiles = limited
                  .map((uid) =>
                      _profileCache[uid] ??
                      {
                        'uid': uid,
                        'displayName': null,
                        'photoURL': null,
                      })
                  .toList();

              // Trigger background loading for missing profiles
              final List<String> missing = limited
                  .where((uid) =>
                      !_profileCache.containsKey(uid) &&
                      !_profileLoading.contains(uid))
                  .toList();

              if (missing.isNotEmpty) {
                // Load in background without blocking UI
                _loadMissingProfiles(missing);
              }

              if (profiles.isEmpty) return const SizedBox.shrink();

              const double radius = 18;
              const double diameter = radius * 2;
              const double overlap = 6;
              const int maxVisible = 8;

              final int total = merged.length;
              final int visibleCount =
                  profiles.length > maxVisible ? maxVisible : profiles.length;
              final int remaining = total - visibleCount;

              final Set<String> invitedSet = invited.toSet();

              final List<Widget> items = [];
              for (int i = 0; i < visibleCount; i++) {
                final String uid = limited[i];
                final bool inPlayers = basePlayerUids.contains(uid);
                final String status = inviteStatuses[uid] ?? 'pending';
                final bool isPending = invitedSet.contains(uid) &&
                    !inPlayers &&
                    status == 'pending';
                // Joining overrides historical invite status
                final bool isAccepted = inPlayers ||
                    (invitedSet.contains(uid) && status == 'accepted');
                final bool isDeclinedOrLeft = invitedSet.contains(uid) &&
                    !inPlayers &&
                    (status == 'declined' || status == 'left');
                final name = (profiles[i]['displayName'] ?? 'User').trim();
                final photo = profiles[i]['photoURL'];
                final initials = _initialsFromName(name);
                items.add(Positioned(
                  left: i * (diameter - overlap),
                  top: 0,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: const Border.fromBorderSide(
                              BorderSide(color: AppColors.primary, width: 1)),
                        ),
                        child: CircleAvatar(
                          radius: radius,
                          backgroundColor: AppColors.superlightgrey,
                          backgroundImage: (photo != null && photo.isNotEmpty)
                              ? NetworkImage(photo)
                              : null,
                          child: (photo == null || photo.isEmpty)
                              ? (initials == '?'
                                  ? const Icon(Icons.person,
                                      size: 18, color: AppColors.blackopac)
                                  : Text(initials, style: AppTextStyles.small))
                              : null,
                        ),
                      ),
                      if (isPending)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.hourglass_bottom,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (isAccepted && !isPending)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: game.isPlayerOnBench(uid)
                                  ? Colors.blue
                                  : Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              game.isPlayerOnBench(uid)
                                  ? Icons.event_seat
                                  : Icons.check,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (isDeclinedOrLeft)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ));
              }

              if (remaining > 0) {
                items.add(Positioned(
                  left: visibleCount * (diameter - overlap),
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: const Border.fromBorderSide(
                          BorderSide(color: AppColors.primary, width: 1)),
                    ),
                    child: CircleAvatar(
                      radius: radius,
                      backgroundColor: AppColors.white,
                      child: Text('+$remaining',
                          style: AppTextStyles.small
                              .copyWith(color: AppColors.primary)),
                    ),
                  ),
                ));
              }

              final double width = (visibleCount + (remaining > 0 ? 1 : 0)) *
                      (diameter - overlap) +
                  overlap +
                  2;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  height: diameter +
                      4, // Add extra height for badges that extend outside
                  child: Stack(
                    clipBehavior: Clip.none, // Allow badges to overflow
                    children: items,
                  ),
                ),
              );
            },
          ),
    );
  }

  /// Load missing profiles in the background and update cache
  void _loadMissingProfiles(List<String> uids) {
    if (uids.isEmpty) return;

    // Mark as loading
    _profileLoading.addAll(uids);

    // Load in background
    Future.wait(
      uids.map((uid) async {
        try {
          final friendsActions = ref.read(friendsActionsProvider);
          final profile = await friendsActions.fetchMinimalProfile(uid);
          if (mounted) {
            setState(() {
              _profileCache[uid] = profile;
              _profileLoading.remove(uid);
            });
          }
        } catch (e) {
          // Cache placeholder on error to avoid retrying
          if (mounted) {
            setState(() {
              _profileCache[uid] = {
                'uid': uid,
                'displayName': null,
                'photoURL': null,
              };
              _profileLoading.remove(uid);
            });
          }
        }
      }),
    );
  }

  String _initialsFromName(String name) {
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  Future<String?> _ensureWeatherForGame(Game game) async {
    if (game.latitude == null || game.longitude == null) return null;
    final key = game.id;
    if (_weatherByGameId.containsKey(key)) return null;
    if (_weatherLoading.contains(key)) return null;
    _weatherLoading.add(key);
    try {
      final weatherActions = ref.read(weatherActionsProvider);
      final map = await weatherActions.fetchWeatherForDate(
        date: game.dateTime,
        latitude: game.latitude!,
        longitude: game.longitude!,
      );
      _weatherByGameId[key] = map;
      if (mounted) setState(() {});
    } catch (_) {}
    _weatherLoading.remove(key);
    return null;
  }

  // --- Sport-specific visuals ---
  IconData _iconForSport(String sport) {
    switch (sport.toLowerCase()) {
      case 'soccer':
      case 'football':
        return Icons.sports_soccer;
      case 'basketball':
        return Icons.sports_basketball;
      case 'tennis':
        return Icons.sports_tennis;
      case 'volleyball':
        return Icons.sports_volleyball;
      case 'badminton':
      case 'table_tennis':
        return Icons.sports_tennis;
      case 'swimming':
        return Icons.pool;
      default:
        return Icons.sports;
    }
  }

  Color _colorForSport(String sport) {
    switch (sport.toLowerCase()) {
      case 'soccer':
      case 'football':
        return Colors.green;
      case 'basketball':
        return Colors.orange;
      case 'tennis':
        return AppColors.blue;
      case 'volleyball':
        return Colors.amber;
      case 'badminton':
      case 'table_tennis':
        return AppColors.primary;
      case 'swimming':
        return Colors.lightBlue;
      default:
        return AppColors.blue;
    }
  }

  bool _isUserJoined(Game game) {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null || uid.isEmpty) return false;
    return game.players.any((p) => p == uid);
  }

  Future<void> _leaveGame(Game game) async {
    try {
      await ref.read(gamesActionsProvider).leaveGame(game.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You left the game'),
            backgroundColor: AppColors.grey,
          ),
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeFromJoined(Game game) async {
    try {
      // Just remove from joinedGames index
      // Streams will update automatically to reflect the change
      await ref.read(cloudGamesActionsProvider).removeFromMyJoined(game.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from My Games'),
            backgroundColor: AppColors.grey,
          ),
        );
        // No need to call _refreshData() - streams will update automatically
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('action_failed'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeFromCreated(Game game) async {
    try {
      // Just remove from createdGames index
      // Streams will update automatically to reflect the change
      await ref.read(cloudGamesActionsProvider).removeFromMyCreated(game.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from My Games'),
            backgroundColor: AppColors.grey,
          ),
        );
        // No need to call _refreshData() - streams will update automatically
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('action_failed'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  /// Archive a historic game by removing it from the appropriate index
  /// Determines if user is organizer or participant and calls the appropriate method
  Future<void> _archiveHistoricGame(Game game) async {
    final currentUserId = ref.read(currentUserIdProvider);
    final isOrganizer = currentUserId == game.organizerId;

    if (isOrganizer) {
      await _removeFromCreated(game);
    } else {
      await _removeFromJoined(game);
    }
  }

  Future<void> _messageOrganizer(Game game) async {
    final info = game.contactInfo?.trim();
    if (info == null || info.isEmpty) return;
    if (info.contains('@')) {
      final uri = Uri(scheme: 'mailto', path: info, queryParameters: {
        'subject': 'About our game at ${game.location}',
        'body':
            'Hi ${game.organizerName},\n\nRegarding the game on ${game.getFormattedDateLocalized((key) => key.tr())} at ${game.formattedTime}...'
      });
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    }
    final phone = info.replaceAll(RegExp(r'[^0-9+]+'), '');
    final telUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
      return;
    }
    await Share.share('Organizer: ${game.organizerName} — $info');
  }

  /// Check calendar status for a game (cached)
  Future<bool?> _getCalendarStatus(String gameId) async {
    // Return cached status if available
    if (_calendarStatusByGameId.containsKey(gameId)) {
      return _calendarStatusByGameId[gameId];
    }

    // Check if already loading
    if (_calendarLoading.contains(gameId)) {
      return null; // Still loading
    }

    // Start loading
    if (!mounted) return null;

    setState(() {
      _calendarLoading.add(gameId);
      _calendarStatusByGameId[gameId] = null; // Mark as checking
    });

    try {
      // Ensure CalendarService is initialized
      await CalendarService.initialize();

      final isInCalendar = await CalendarService.isGameInCalendar(gameId);
      if (mounted) {
        setState(() {
          _calendarStatusByGameId[gameId] = isInCalendar;
          _calendarLoading.remove(gameId);
        });
      }
      return isInCalendar;
    } catch (e, stackTrace) {
      debugPrint('Error checking calendar status: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _calendarStatusByGameId[gameId] = false; // Default to false on error
          _calendarLoading.remove(gameId);
        });
      }
      return false;
    }
  }

  Future<void> _addToCalendar(Game game) async {
    if (_calendarLoading.contains(game.id)) return; // Already processing

    try {
      ref.read(hapticsActionsProvider)?.selectionClick();

      // Set loading state
      if (mounted) {
        setState(() {
          _calendarLoading.add(game.id);
        });
      }

      // Check if game is already in calendar
      final isInCalendar = await CalendarService.isGameInCalendar(game.id);

      if (isInCalendar) {
        // Remove from calendar
        final success = await CalendarService.removeGameFromCalendar(game.id);
        if (mounted) {
          setState(() {
            _calendarStatusByGameId[game.id] = !success; // Update cache
            _calendarLoading.remove(game.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'calendar_event_removed'.tr()
                    : 'calendar_event_removed_error'.tr(),
              ),
              backgroundColor: success ? AppColors.green : AppColors.red,
            ),
          );
        }
      } else {
        // Add to calendar
        final eventId = await CalendarService.addGameToCalendar(game);
        if (mounted) {
          setState(() {
            _calendarStatusByGameId[game.id] = eventId != null; // Update cache
            _calendarLoading.remove(game.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                eventId != null
                    ? 'calendar_event_added'.tr()
                    : 'calendar_event_added_error'.tr(),
              ),
              backgroundColor:
                  eventId != null ? AppColors.green : AppColors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding game to calendar: $e');
      if (mounted) {
        setState(() {
          _calendarLoading.remove(game.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('calendar_event_added_error'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _organizeSimilarGame(Game game) async {
    ref.read(hapticsActionsProvider)?.selectionClick();

    // Navigate to GameOrganizeScreen with the historic game as initialGame
    // This will pre-fill sport, field, max players, and participants
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameOrganizeScreen(initialGame: game),
      ),
    );
  }

  Future<void> _openReportSheet(Game game) async {
    // Extract field information from game
    final fieldId = game.fieldId?.trim() ?? '';
    final fallbackId = fieldId.isNotEmpty
        ? fieldId
        : (game.latitude != null && game.longitude != null
            ? 'loc:${game.latitude!.toStringAsFixed(5)}:${game.longitude!.toStringAsFixed(5)}'
            : 'game:${game.id}');

    final fieldName = game.location.trim().isNotEmpty
        ? game.location.trim()
        : 'unnamed_location'.tr();

    final fieldAddress = game.address?.trim();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FieldReportSheet(
        fieldId: fallbackId,
        fieldName: fieldName,
        fieldAddress: fieldAddress,
      ),
    );

    if (!mounted || result != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('field_report_submitted'.tr()),
        backgroundColor: AppColors.green,
      ),
    );
  }

  Future<void> _openDirections(Game game) async {
    try {
      Uri uri;

      // Prefer coordinates if available for accurate directions
      if (game.latitude != null && game.longitude != null) {
        uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${game.latitude},${game.longitude}&travelmode=walking',
        );
      } else {
        // Fallback: Use address or location name
        String searchQuery = '';

        // Strategy 1: Use address if available
        if (game.address != null && game.address!.isNotEmpty) {
          searchQuery = game.address!;
        }
        // Strategy 2: Use location name
        else if (game.location.isNotEmpty) {
          searchQuery = game.location;

          // Strategy 3: Enhance with area name if we know it's in 's-Hertogenbosch
          // This helps Google Maps find the location better
          if (!searchQuery.toLowerCase().contains("'s-hertogenbosch") &&
              !searchQuery.toLowerCase().contains('den bosch')) {
            searchQuery = "$searchQuery, 's-Hertogenbosch";
          }
        } else {
          // No location data available
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('No location information available for directions'),
                backgroundColor: AppColors.orange,
              ),
            );
          }
          return;
        }

        // Build search URL
        final query = Uri.encodeComponent(searchQuery);
        uri =
            Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
      }

      // Try launching URL - if platform channel fails, use direct Android intent as fallback
      try {
        final launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          debugPrint('launchUrl returned false for: $uri');
          _openUrlViaAndroidIntent(uri.toString());
        }
      } catch (launchError) {
        debugPrint('Error launching URL via url_launcher: $launchError');
        debugPrint('URI was: $uri');
        // Fallback: Use direct Android intent
        _openUrlViaAndroidIntent(uri.toString());
      }
    } catch (e) {
      debugPrint('Error opening directions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('could_not_open_maps'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  /// Fallback method to open URL when url_launcher fails
  Future<void> _openUrlViaAndroidIntent(String url) async {
    debugPrint('Using fallback method to open URL: $url');
    try {
      const platform = MethodChannel('app.sportappdenbosch/intent');
      await platform.invokeMethod('launchUrl', {'url': url});
      debugPrint('Successfully launched URL via Android intent: $url');
    } catch (e) {
      debugPrint('Error launching URL via Android intent: $e');
      // Last resort: try share_plus (user can select Google Maps from share menu)
      try {
        await Share.share(url);
      } catch (shareError) {
        debugPrint('Error sharing URL: $shareError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('could_not_open_maps'.tr()),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers for reactive data
    final myGamesAsync = ref.watch(myGamesProvider);
    final historicGamesAsync = ref.watch(historicGamesProvider);

    // Pre-load calendar statuses when games are loaded
    // This ensures calendar status is persisted when user exits and re-enters app
    // Also reloads when games change (e.g., new games added)
    if (myGamesAsync.hasValue || historicGamesAsync.hasValue) {
      final gamesLoaded = (myGamesAsync.valueOrNull?.length ?? 0) +
          (historicGamesAsync.valueOrNull?.length ?? 0);
      if (gamesLoaded > 0) {
        // Check if we need to update cache (either empty or games have changed)
        final allGameIds = <String>{};
        final myGames = myGamesAsync.valueOrNull;
        if (myGames != null) {
          for (final game in myGames) {
            allGameIds.add(game.id);
          }
        }
        final historicGames = historicGamesAsync.valueOrNull;
        if (historicGames != null) {
          for (final game in historicGames) {
            allGameIds.add(game.id);
          }
        }

        // If cache is empty or missing some games, reload
        final needsReload = _calendarStatusByGameId.isEmpty ||
            allGameIds.any((id) => !_calendarStatusByGameId.containsKey(id));

        if (needsReload) {
          // Trigger preload without blocking UI
          _preloadCalendarStatuses();
        }
      }
    }

    // Calculate joined/created games from provider data
    final joinedGames = myGamesAsync.valueOrNull
            ?.where((g) => ref.read(currentUserIdProvider) != g.organizerId)
            .toList() ??
        [];
    final createdGames = myGamesAsync.valueOrNull
            ?.where((g) => ref.read(currentUserIdProvider) == g.organizerId)
            .toList() ??
        [];
    // Sort organized games by upcoming time (earliest first)
    createdGames.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // Historic games (already sorted by date descending in the provider)
    final historicGames = historicGamesAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(goHome: true),
        title: Text('my_games'.tr()),
        backgroundColor: AppColors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey,
          indicatorColor: AppColors.primary,
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          tabs: [
            TabWithCount(
              label: 'registered_games'.tr(),
              count: joinedGames.length,
            ),
            TabWithCount(
              label: 'organized_games'.tr(),
              count: createdGames.length,
            ),
            TabWithCount(
              label: 'historic_games'.tr(),
              count: historicGames.length,
            ),
          ],
        ),
      ),
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: AppPaddings.symmHorizontalReg,
          child: myGamesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => ErrorRetryWidget(
              message: myGamesAsync.errorMessage ?? 'Failed to load games',
              onRetry: _refreshData,
            ),
            data: (games) => Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.container),
                boxShadow: AppShadows.md,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.container),
                child: TabBarView(
                  controller: _tab,
                  children: [
                    // Registered Games (joined)
                    RefreshIndicator(
                      onRefresh: () async => _refreshData(),
                      child: (joinedGames.isEmpty)
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.only(bottom: AppHeights.reg),
                              children: [_emptyStateRegistered(context)],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: AppPaddings.allMedium.add(
                                const EdgeInsets.only(bottom: AppHeights.reg),
                              ),
                              itemCount: joinedGames.length,
                              itemBuilder: (_, i) =>
                                  _buildGameTile(joinedGames[i]),
                            ),
                    ),
                    // Organized Games (created)
                    RefreshIndicator(
                      onRefresh: () async => _refreshData(),
                      child: (createdGames.isEmpty)
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.only(bottom: AppHeights.reg),
                              children: [_emptyStateOrganized(context)],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: AppPaddings.allMedium.add(
                                const EdgeInsets.only(bottom: AppHeights.reg),
                              ),
                              itemCount: createdGames.length,
                              itemBuilder: (_, i) =>
                                  _buildGameTile(createdGames[i]),
                            ),
                    ),
                    // Historic Games (past games where user participated)
                    RefreshIndicator(
                      onRefresh: () async => _refreshData(),
                      child: historicGamesAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => ErrorRetryWidget(
                          message: historicGamesAsync.errorMessage ??
                              'Failed to load historic games',
                          onRetry: _refreshData,
                        ),
                        data: (games) => (games.isEmpty)
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(
                                    bottom: AppHeights.reg),
                                children: [_emptyStateHistoric(context)],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: AppPaddings.allMedium.add(
                                  const EdgeInsets.only(bottom: AppHeights.reg),
                                ),
                                itemCount: games.length,
                                itemBuilder: (_, i) =>
                                    _buildHistoricGameTile(games[i]),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build a historic game tile with swipe-to-archive functionality
  Widget _buildHistoricGameTile(Game game) {
    final key = _itemKeys.putIfAbsent(game.id, () => GlobalKey());

    // Build the game card (without margin)
    final gameCard = KeyedSubtree(
      key: key,
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero, // No margin here - handled by Container
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: _buildGameTileContent(game),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppHeights.reg),
      child: Dismissible(
        key: Key('historic_game_${game.id}'),
        direction: DismissDirection.horizontal,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: AppColors.darkgrey,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              const Icon(Icons.archive, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'Archive',
                style: AppTextStyles.cardTitle.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.darkgrey,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Archive',
                style: AppTextStyles.cardTitle.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.archive, color: Colors.white, size: 24),
            ],
          ),
        ),
        onDismissed: (direction) {
          _archiveHistoricGame(game);
        },
        child: gameCard,
      ),
    );
  }

  /// Build a standardized badge widget
  Widget _buildStatusBadge({
    required String label,
    required Color color,
    IconData? icon,
    bool showDot = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12), // Pill shape
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot && icon == null)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            )
          else if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.small.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the content of a game tile (the inner container with border and column)
  Widget _buildGameTileContent(Game game) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final isMine = currentUserId == game.organizerId;
    final sportColor = _colorForSport(game.sport);
    final accentColor = game.isActive ? AppColors.green : AppColors.red;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        // Rounded accent bar on the left instead of straight border
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            accentColor.withValues(alpha: 0.15),
            accentColor.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.08],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
            leading: Hero(
              tag: 'game-${game.id}-icon',
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sportColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForSport(game.sport),
                  color: sportColor,
                  size: 22,
                ),
              ),
            ),
            title: Text(
              game.location,
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${game.getFormattedDateLocalized((key) => key.tr())} • ${game.formattedTime}',
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Show "Cancelled" badge for cancelled games
                    if (!game.isActive) ...[
                      _buildStatusBadge(
                        label: 'Canceled',
                        color: AppColors.red,
                      ),
                    ] else ...[
                      if (game.isFull)
                        _buildStatusBadge(
                          label: 'Full',
                          color: AppColors.red,
                        ),
                      if (game.isModified)
                        _buildStatusBadge(
                          label: 'modified'.tr(),
                          color: AppColors.blue,
                        ),
                      StreamBuilder<int>(
                        stream: Stream.periodic(
                            const Duration(minutes: 1), (i) => i),
                        initialData: 0,
                        builder: (context, snapshot) {
                          final remaining = game.timeUntilGame;
                          // Only show when 2 hours or less remaining
                          if (remaining.isNegative ||
                              remaining > const Duration(hours: 2)) {
                            return const SizedBox.shrink();
                          }
                          final bool urgent =
                              remaining < const Duration(hours: 1);
                          final hours = remaining.inHours;
                          final minutes = remaining.inMinutes % 60;
                          return _buildStatusBadge(
                            label: 'Starts in ${hours}h ${minutes}m',
                            color:
                                urgent ? Colors.amber.shade800 : AppColors.blue,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: _buildStatusBadge(
              label: game.benchCount > 0
                  ? '${game.maxPlayers}/${game.maxPlayers} + ${game.benchCount} bench'
                  : '${game.currentPlayers}/${game.maxPlayers}',
              color: game.hasSpace ? AppColors.green : AppColors.red,
              icon: game.isPublic ? Icons.lock_open : Icons.lock,
              showDot: false,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.lightgrey.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Weather icon with a subtle divider to separate from avatars
                Builder(builder: (context) {
                  _ensureWeatherForGame(game);
                  String time = game.formattedTime.padLeft(5, '0');
                  if (!time.endsWith(':00')) {
                    time = '${time.substring(0, 2)}:00';
                  }
                  final forecasts = _weatherByGameId[game.id];
                  final weatherActions = ref.read(weatherActionsProvider);
                  final String cond = forecasts?[time] ??
                      weatherActions.getWeatherCondition(time);
                  final IconData icon =
                      weatherActions.getWeatherIcon(time, cond);
                  final Color color = weatherActions.getWeatherColor(cond);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: 10),
                      Container(
                        width: 1,
                        height: 20,
                        color: AppColors.lightgrey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 10),
                    ],
                  );
                }),
                Expanded(
                  child: _buildParticipantsStrip(game),
                ),
                // Edit button for organizer - placed next to participants
                if (isMine && !game.dateTime.isBefore(DateTime.now())) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    tooltip: 'edit'.tr(),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GameOrganizeScreen(initialGame: game),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    color: AppColors.primary,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Only show action buttons (edit, cancel, directions, share) for upcoming games
                if (!game.dateTime.isBefore(DateTime.now())) ...[
                  Row(
                    children: [
                      if (!isMine && _isUserJoined(game)) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => game.isActive
                                ? _leaveGame(game)
                                : _removeFromJoined(game),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              textStyle: AppTextStyles.small.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                              iconSize: 16,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            icon: Icon(
                                game.isActive
                                    ? Icons.logout
                                    : Icons.delete_outline,
                                size: 16),
                            label:
                                Text(game.isActive ? 'leave'.tr() : 'Remove'),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (isMine) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // If game is already cancelled, just remove it from view
                              if (!game.isActive) {
                                await _removeFromCreated(game);
                                return;
                              }

                              // Otherwise, cancel it (which marks inactive AND removes from createdGames)
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('cancel'.tr()),
                                  content: Text('are_you_sure'.tr()),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text('cancel'.tr())),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text('ok'.tr())),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                try {
                                  await ref
                                      .read(gamesActionsProvider)
                                      .deleteGame(game.id);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'game_cancelled_successfully'.tr()),
                                        backgroundColor: AppColors.green,
                                      ),
                                    );
                                  }
                                  // No need to call _refreshData() - streams will update automatically
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'game_cancellation_failed'.tr()),
                                        backgroundColor: AppColors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              textStyle: AppTextStyles.small.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                              iconSize: 16,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(
                                game.isActive
                                    ? Icons.cancel
                                    : Icons.delete_outline,
                                size: 16),
                            label:
                                Text(game.isActive ? 'cancel'.tr() : 'Remove'),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openDirections(game),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            textStyle: AppTextStyles.small.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                            iconSize: 16,
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                                color: AppColors.primary, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.directions, size: 16),
                          label: Text('directions'.tr()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            // Check cached status first
                            final cachedStatus =
                                _calendarStatusByGameId[game.id];
                            final isLoading =
                                _calendarLoading.contains(game.id);

                            // If preload is in progress and status is unknown, show as checking
                            final isActuallyLoading = isLoading ||
                                (cachedStatus == null &&
                                    _calendarPreloadInProgress);

                            // If not cached and not loading, and preload is not in progress, trigger async check
                            // Wait for preload to complete first to avoid duplicate checks
                            if (cachedStatus == null &&
                                !isLoading &&
                                !_calendarPreloadInProgress) {
                              // Only trigger individual check if preload hasn't populated it yet
                              // This handles edge cases where a game was added after preload completed
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted &&
                                    !_calendarStatusByGameId
                                        .containsKey(game.id) &&
                                    !_calendarPreloadInProgress) {
                                  // Trigger async check but don't wait
                                  _getCalendarStatus(game.id).catchError((e) {
                                    debugPrint(
                                        'Error in _getCalendarStatus for ${game.id}: $e');
                                    // Ensure loading state is cleared on error
                                    if (mounted) {
                                      setState(() {
                                        _calendarStatusByGameId[game.id] =
                                            false;
                                        _calendarLoading.remove(game.id);
                                      });
                                    }
                                    return false; // Return value for catchError
                                  });
                                }
                              });
                            }

                            // Determine icon and color based on status
                            final bool isInCalendar = cachedStatus == true;
                            final IconData icon;
                            final Color foregroundColor;
                            final Color borderColor;
                            final String label;

                            if (isActuallyLoading) {
                              icon = Icons.event;
                              foregroundColor = AppColors.grey;
                              borderColor = AppColors.grey;
                              label = 'add_to_calendar'.tr();
                            } else if (isInCalendar) {
                              // In calendar: green color with checkmark icon, but same text
                              icon = Icons.event_available;
                              foregroundColor = AppColors.green;
                              borderColor = AppColors.green;
                              label = 'add_to_calendar'.tr(); // Keep same text
                            } else {
                              // Not in calendar: standard color
                              icon = Icons.event;
                              foregroundColor = AppColors.primary;
                              borderColor = AppColors.primary;
                              label = 'add_to_calendar'.tr();
                            }

                            return OutlinedButton.icon(
                              onPressed: isActuallyLoading
                                  ? null
                                  : () => _addToCalendar(game),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                textStyle: AppTextStyles.small.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                                iconSize: 16,
                                foregroundColor: foregroundColor,
                                side:
                                    BorderSide(color: borderColor, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ).copyWith(
                                // Override disabled state styling
                                foregroundColor: isActuallyLoading
                                    ? WidgetStateProperty.all(AppColors.grey)
                                    : WidgetStateProperty.all(foregroundColor),
                                side: isActuallyLoading
                                    ? WidgetStateProperty.all(const BorderSide(
                                        color: AppColors.grey, width: 1.5))
                                    : WidgetStateProperty.all(BorderSide(
                                        color: borderColor, width: 1.5)),
                              ),
                              icon: isActuallyLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(icon, size: 16),
                              label: Text(label),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  if ((game.contactInfo?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _messageOrganizer(game),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Message organizer'),
                      ),
                    ),
                  ],
                ],
                // Show "Report an issue" and "Organize Similar Game" buttons for historic games (past games)
                if (game.dateTime.isBefore(DateTime.now())) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _organizeSimilarGame(game),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            textStyle: AppTextStyles.small.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            iconSize: 18,
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                                color: AppColors.primary, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.repeat, size: 18),
                          label: Text('organize_similar_game'.tr()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openReportSheet(game),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            textStyle: AppTextStyles.small.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            iconSize: 18,
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                                color: AppColors.primary, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.report_problem_outlined,
                              size: 18),
                          label: Text('field_report_button'.tr()),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameTile(Game game) {
    final key = _itemKeys.putIfAbsent(game.id, () => GlobalKey());

    // Build the game card (without margin) - matching Historic tab style
    final gameCard = KeyedSubtree(
      key: key,
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero, // No margin here - handled by Container
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: _buildGameTileContent(game),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppHeights.reg),
      child: gameCard,
    );
  }

  Widget _emptyStateRegistered(BuildContext context) {
    return Padding(
      padding: AppPaddings.allSuperBig,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports, size: 64, color: AppColors.grey),
          const SizedBox(height: AppHeights.reg),
          Text('no_joined_games_yet'.tr(),
              style: AppTextStyles.title.copyWith(color: AppColors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: AppHeights.small),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GamesJoinScreen(),
                ),
              );
            },
            child: Text('go_join_a_game'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _emptyStateOrganized(BuildContext context) {
    return Padding(
      padding: AppPaddings.allSuperBig,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_available, size: 64, color: AppColors.grey),
          const SizedBox(height: AppHeights.reg),
          Text('no_organized_games_yet'.tr(),
              style: AppTextStyles.title.copyWith(color: AppColors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: AppHeights.small),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GameOrganizeScreen(),
                ),
              );
            },
            child: Text('go_organize_a_game'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _emptyStateHistoric(BuildContext context) {
    return Padding(
      padding: AppPaddings.allSuperBig,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 64, color: AppColors.grey),
          const SizedBox(height: AppHeights.reg),
          Text('no_historic_games_yet'.tr(),
              style: AppTextStyles.title.copyWith(color: AppColors.grey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
