import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/features/matches/models/match.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/features/matches/services/match_provider.dart';
import 'package:move_young/features/matches/services/cloud_matches_provider.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/features/matches/screens/match_join_screen.dart';
import 'package:move_young/features/matches/screens/match_organize_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:move_young/services/external/weather_provider.dart';
import 'package:move_young/utils/error_extensions.dart';
import 'package:move_young/widgets/error_retry_widget.dart';
import 'package:move_young/widgets/tab_with_count.dart';
import 'package:move_young/widgets/app_back_button.dart';
import 'package:move_young/widgets/cached_data_indicator.dart';
import 'package:move_young/features/maps/screens/gmaps_screen.dart';
import 'package:move_young/services/calendar/calendar_service.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:move_young/utils/logger.dart';
import 'package:move_young/features/matches/notifiers/match_my_screen_notifier.dart';
import 'dart:async';

class MatchesMyScreen extends ConsumerStatefulWidget {
  final String? highlightMatchId;
  final int initialTab;
  const MatchesMyScreen(
      {super.key, this.highlightMatchId, this.initialTab = 0});

  @override
  ConsumerState<MatchesMyScreen> createState() => _MatchesMyScreenState();
}

class _MatchesMyScreenState extends ConsumerState<MatchesMyScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, GlobalKey> _itemKeys = {};
  late final TabController _tab;
  // Periodic stream for time countdown - created once to avoid memory leaks
  late final Stream<int> _periodicMinuteStream;

  @override
  void initState() {
    super.initState();
    _tab =
        TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    // Create periodic stream once in initState to avoid creating new streams on every rebuild
    // Use broadcast stream to allow multiple listeners (one per match tile)
    _periodicMinuteStream = Stream.periodic(
      const Duration(minutes: 1),
      (i) => i,
    ).asBroadcastStream();

    // Auto-refresh when user switches to the Joining tab (index 0)
    _tab.addListener(() {
      if (!_tab.indexIsChanging && _tab.index == 0) {
        _refreshData();
      }
    });

    // Schedule scroll to highlighted match after first frame
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToHighlightedMatch());

    // Pre-load calendar statuses for all matches when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(
          matchesMyScreenNotifierProvider(widget.highlightMatchId).notifier);
      notifier.preloadCalendarStatuses();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _scrollToHighlightedMatch({int attempts = 0}) {
    final screenState =
        ref.read(matchesMyScreenNotifierProvider(widget.highlightMatchId));
    if (!mounted || screenState.highlightId == null) {
      return;
    }
    final key = _itemKeys[screenState.highlightId!];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          ref
              .read(matchesMyScreenNotifierProvider(widget.highlightMatchId)
                  .notifier)
              .clearHighlightId();
        }
      });
      return;
    }
    if (attempts < 6) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToHighlightedMatch(attempts: attempts + 1);
      });
    }
  }

  void _refreshData() {
    // Providers will update automatically via Firebase real-time streams
  }

  // ---- Helpers restored ----
  Widget _buildParticipantsStrip(Match match) {
    final List<String> basePlayerUids = List<String>.from(match.players);

    return SizedBox(
      height: 44,
      child: ref.watch(matchInviteStatusesProvider(match.id)).when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (inviteStatuses) {
              final List<String> invited = inviteStatuses.keys.toList();
              // Keep invitees included visually even if they haven't joined yet
              final List<String> merged =
                  <String>{...basePlayerUids, ...invited}.toList();
              if (merged.isEmpty) {
                return const SizedBox.shrink();
              }

              // Fetch minimal profiles for merged set
              final List<String> limited = merged.take(12).toList();

              // Build profiles from cache immediately (synchronous)
              final screenState = ref.watch(
                  matchesMyScreenNotifierProvider(widget.highlightMatchId));
              final List<Map<String, String?>> profiles = limited
                  .map((uid) =>
                      screenState.profileCache[uid] ??
                      {
                        'uid': uid,
                        'displayName': null,
                      })
                  .toList();

              // Trigger background loading for missing profiles
              final List<String> missing = limited
                  .where((uid) =>
                      !screenState.profileCache.containsKey(uid) &&
                      !screenState.profileLoading.contains(uid))
                  .toList();

              if (missing.isNotEmpty) {
                // Load in background without blocking UI
                // Defer to avoid modifying provider during build
                Future.microtask(() {
                  ref
                      .read(matchesMyScreenNotifierProvider(
                              widget.highlightMatchId)
                          .notifier)
                      .loadMissingProfiles(missing);
                });
              }

              if (profiles.isEmpty) {
                return const SizedBox.shrink();
              }

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
                          child: initials == '?'
                              ? const Icon(Icons.person,
                                  size: 18, color: AppColors.blackopac)
                              : Text(initials, style: AppTextStyles.small),
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
                              color: match.isPlayerOnBench(uid)
                                  ? Colors.blue
                                  : Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              match.isPlayerOnBench(uid)
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

  String _initialsFromName(String name) {
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    final firstPart = parts.first;
    if (firstPart.isEmpty) {
      return '?';
    }
    final first = firstPart[0];
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  Future<String?> _ensureWeatherForMatch(Match match) async {
    if (match.latitude == null || match.longitude == null) {
      return null;
    }
    await ref
        .read(matchesMyScreenNotifierProvider(widget.highlightMatchId).notifier)
        .ensureWeatherForMatch(match);
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
      case 'volleyball':
        return Icons.sports_volleyball;
      case 'table_tennis':
      case 'tennis':
      case 'badminton':
        return Icons.sports_tennis;
      case 'skateboard':
        return Icons.skateboarding;
      case 'boules':
        return Icons.scatter_plot;
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

  bool _isUserJoined(Match match) {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null || uid.isEmpty) {
      return false;
    }
    return match.players.any((p) => p == uid);
  }

  Future<void> _leaveMatch(Match match) async {
    try {
      await ref.read(matchesActionsProvider).leaveMatch(match.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You left the match'),
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

  Future<void> _removeFromJoined(Match match) async {
    try {
      // Just remove from joinedMatches index
      // Streams will update automatically to reflect the change
      await ref.read(cloudMatchesActionsProvider).removeFromMyJoined(match.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from My Matches'),
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

  Future<void> _removeFromCreated(Match match) async {
    try {
      // Just remove from createdMatches index
      // Streams will update automatically to reflect the change
      await ref.read(cloudMatchesActionsProvider).removeFromMyCreated(match.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from My Matches'),
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

  /// Archive a historic match by removing it from the appropriate index
  /// Determines if user is organizer or participant and calls the appropriate method
  Future<void> _archiveHistoricMatch(Match match) async {
    final currentUserId = ref.read(currentUserIdProvider);
    final isOrganizer = currentUserId == match.organizerId;

    if (isOrganizer) {
      await _removeFromCreated(match);
    } else {
      await _removeFromJoined(match);
    }
  }

  Future<void> _messageOrganizer(Match match) async {
    final info = match.contactInfo?.trim();
    if (info == null || info.isEmpty) {
      return;
    }
    if (info.contains('@')) {
      final uri = Uri(scheme: 'mailto', path: info, queryParameters: {
        'subject': 'About our match at ${match.location}',
        'body':
            'Hi ${match.organizerName},\n\nRegarding the match on ${match.getFormattedDateLocalized((key) => key.tr())} at ${match.formattedTime}...'
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
    await Share.share('Organizer: ${match.organizerName} — $info');
  }

  Future<void> _addToCalendar(Match match) async {
    final screenState =
        ref.read(matchesMyScreenNotifierProvider(widget.highlightMatchId));
    if (screenState.calendarLoading.contains(match.id)) {
      return; // Already processing
    }

    try {
      ref.read(hapticsActionsProvider)?.selectionClick();

      // Check if match is already in calendar
      final isInCalendar = await CalendarService.isMatchInCalendar(match.id);

      if (isInCalendar) {
        // Remove from calendar
        final success = await CalendarService.removeMatchFromCalendar(match.id);
        if (mounted) {
          ref
              .read(matchesMyScreenNotifierProvider(widget.highlightMatchId)
                  .notifier)
              .updateCalendarStatus(match.id, !success);
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
        final eventId = await CalendarService.addMatchToCalendar(match);
        if (mounted) {
          ref
              .read(matchesMyScreenNotifierProvider(widget.highlightMatchId)
                  .notifier)
              .updateCalendarStatus(match.id, eventId != null);
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
      NumberedLogger.e('Error adding match to calendar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('calendar_event_added_error'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _organizeSimilarMatch(Match match) async {
    ref.read(hapticsActionsProvider)?.selectionClick();

    // Navigate to MatchOrganizeScreen with the historic match as initialMatch
    // This will pre-fill sport, field, max players, and participants
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchOrganizeScreen(initialMatch: match),
      ),
    );
  }

  Future<void> _openReportSheet(Match match) async {
    // Extract field information from match
    final fieldId = match.fieldId?.trim() ?? '';
    final fallbackId = fieldId.isNotEmpty
        ? fieldId
        : (match.latitude != null && match.longitude != null
            ? 'loc:${match.latitude!.toStringAsFixed(5)}:${match.longitude!.toStringAsFixed(5)}'
            : 'match:${match.id}');

    final fieldName = match.location.trim().isNotEmpty
        ? match.location.trim()
        : 'unnamed_location'.tr();

    final fieldAddress = match.address?.trim();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FieldReportSheet(
        fieldId: fallbackId,
        fieldName: fieldName,
        fieldAddress: fieldAddress,
      ),
    );

    if (!mounted || result != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('field_report_submitted'.tr()),
        backgroundColor: AppColors.green,
      ),
    );
  }

  Future<void> _openDirections(Match match) async {
    try {
      Uri uri;

      // Prefer coordinates if available for accurate directions
      if (match.latitude != null && match.longitude != null) {
        uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${match.latitude},${match.longitude}&travelmode=walking',
        );
      } else {
        // Fallback: Use address or location name
        String searchQuery = '';

        // Strategy 1: Use address if available
        if (match.address != null && match.address!.isNotEmpty) {
          searchQuery = match.address!;
        }
        // Strategy 2: Use location name
        else if (match.location.isNotEmpty) {
          searchQuery = match.location;

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
          NumberedLogger.w('launchUrl returned false for: $uri');
          _openUrlViaAndroidIntent(uri.toString());
        }
      } catch (launchError) {
        NumberedLogger.e('Error launching URL via url_launcher: $launchError');
        NumberedLogger.d('URI was: $uri');
        // Fallback: Use direct Android intent
        _openUrlViaAndroidIntent(uri.toString());
      }
    } catch (e) {
      NumberedLogger.e('Error opening directions: $e');
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
    NumberedLogger.d('Using fallback method to open URL: $url');
    try {
      const platform = MethodChannel('app.sportappdenbosch/intent');
      await platform.invokeMethod('launchUrl', {'url': url});
      NumberedLogger.i('Successfully launched URL via Android intent: $url');
    } catch (e) {
      NumberedLogger.e('Error launching URL via Android intent: $e');
      // Last resort: try share_plus (user can select Google Maps from share menu)
      try {
        await Share.share(url);
      } catch (shareError) {
        NumberedLogger.e('Error sharing URL: $shareError');
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
    final myMatchesAsync = ref.watch(myMatchesProvider);
    final historicMatchesAsync = ref.watch(historicMatchesProvider);
    final screenNotifier = ref.read(
        matchesMyScreenNotifierProvider(widget.highlightMatchId).notifier);

    // Pre-load calendar statuses when matches are loaded
    // This ensures calendar status is persisted when user exits and re-enters app
    // Also reloads when matches change (e.g., new matches added)
    if (myMatchesAsync.hasValue || historicMatchesAsync.hasValue) {
      final matchesLoaded = (myMatchesAsync.valueOrNull?.length ?? 0) +
          (historicMatchesAsync.valueOrNull?.length ?? 0);
      if (matchesLoaded > 0) {
        // Check if we need to update cache (either empty or matches have changed)
        final allMatchIds = <String>{};
        final myMatches = myMatchesAsync.valueOrNull;
        if (myMatches != null) {
          for (final match in myMatches) {
            allMatchIds.add(match.id);
          }
        }
        final historicMatches = historicMatchesAsync.valueOrNull;
        if (historicMatches != null) {
          for (final match in historicMatches) {
            allMatchIds.add(match.id);
          }
        }

        // If cache is empty or missing some matches, reload
        if (screenNotifier.needsCalendarPreload(allMatchIds)) {
          // Trigger preload without blocking UI - delay until after build completes
          Future(() => screenNotifier.preloadCalendarStatuses());
        }
      }
    }

    // Calculate joined/created matches from provider data
    final joinedMatches = myMatchesAsync.valueOrNull
            ?.where((g) => ref.read(currentUserIdProvider) != g.organizerId)
            .toList() ??
        [];
    final createdMatches = myMatchesAsync.valueOrNull
            ?.where((g) => ref.read(currentUserIdProvider) == g.organizerId)
            .toList() ??
        [];
    // Sort organized matches by upcoming time (earliest first)
    createdMatches.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // Historic matches (already sorted by date descending in the provider)
    final historicMatches = historicMatchesAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leadingWidth: 48,
        leading: const AppBackButton(goHome: true),
        title: Text('my_matches'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey,
          indicatorColor: AppColors.primary,
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          tabs: [
            TabWithCount(
              label: 'registered_matches'.tr(),
              count: joinedMatches.length,
            ),
            TabWithCount(
              label: 'organized_matches'.tr(),
              count: createdMatches.length,
            ),
            TabWithCount(
              label: 'historic_matches'.tr(),
              count: historicMatches.length,
            ),
          ],
        ),
      ),
      body: CachedDataIndicator(
        child: SafeArea(
          child: Padding(
            padding: AppPaddings.symmHorizontalReg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Expanded(
                  child: myMatchesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => ErrorRetryWidget(
                      message: myMatchesAsync.errorMessage ??
                          'Failed to load matches',
                      onRetry: _refreshData,
                    ),
                    data: (matches) => Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius:
                            BorderRadius.circular(AppRadius.container),
                        boxShadow: AppShadows.md,
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppRadius.container),
                        child: TabBarView(
                          controller: _tab,
                          children: [
                            // Registered Matches (joined)
                            RefreshIndicator(
                              onRefresh: () async => _refreshData(),
                              child: (joinedMatches.isEmpty)
                                  ? ListView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.only(
                                          bottom: AppHeights.reg),
                                      children: [
                                        _emptyStateRegistered(context)
                                      ],
                                    )
                                  : ListView.builder(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: AppPaddings.allMedium.add(
                                        const EdgeInsets.only(
                                            bottom: AppHeights.reg),
                                      ),
                                      itemCount: joinedMatches.length,
                                      itemBuilder: (_, i) =>
                                          _buildMatchTile(joinedMatches[i]),
                                    ),
                            ),
                            // Organized Matches (created)
                            RefreshIndicator(
                              onRefresh: () async => _refreshData(),
                              child: (createdMatches.isEmpty)
                                  ? ListView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.only(
                                          bottom: AppHeights.reg),
                                      children: [_emptyStateOrganized(context)],
                                    )
                                  : ListView.builder(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: AppPaddings.allMedium.add(
                                        const EdgeInsets.only(
                                            bottom: AppHeights.reg),
                                      ),
                                      itemCount: createdMatches.length,
                                      itemBuilder: (_, i) =>
                                          _buildMatchTile(createdMatches[i]),
                                    ),
                            ),
                            // Historic Matches (past matches where user participated)
                            RefreshIndicator(
                              onRefresh: () async => _refreshData(),
                              child: historicMatchesAsync.when(
                                loading: () => const Center(
                                    child: CircularProgressIndicator()),
                                error: (error, stack) => ErrorRetryWidget(
                                  message: historicMatchesAsync.errorMessage ??
                                      'Failed to load historic matches',
                                  onRetry: _refreshData,
                                ),
                                data: (matches) => (matches.isEmpty)
                                    ? ListView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: const EdgeInsets.only(
                                            bottom: AppHeights.reg),
                                        children: [
                                          _emptyStateHistoric(context)
                                        ],
                                      )
                                    : ListView.builder(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: AppPaddings.allMedium.add(
                                          const EdgeInsets.only(
                                              bottom: AppHeights.reg),
                                        ),
                                        itemCount: matches.length,
                                        itemBuilder: (_, i) =>
                                            _buildHistoricMatchTile(matches[i]),
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

  /// Build a historic match tile with swipe-to-archive functionality
  Widget _buildHistoricMatchTile(Match match) {
    final key = _itemKeys.putIfAbsent(match.id, () => GlobalKey());

    // Build the match card (without margin)
    final matchCard = KeyedSubtree(
      key: key,
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero, // No margin here - handled by Container
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: _buildMatchTileContent(match),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppHeights.reg),
      child: Dismissible(
        key: Key('historic_match_${match.id}'),
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
          _archiveHistoricMatch(match);
        },
        child: matchCard,
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

  /// Build the content of a match tile (the inner container with border and column)
  Widget _buildMatchTileContent(Match match) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final isMine = currentUserId == match.organizerId;
    final sportColor = _colorForSport(match.sport);
    final accentColor = match.isActive ? AppColors.green : AppColors.red;

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
              tag: 'match-${match.id}-icon',
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sportColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForSport(match.sport),
                  color: sportColor,
                  size: 22,
                ),
              ),
            ),
            title: Text(
              match.location,
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${match.getFormattedDateLocalized((key) => key.tr())} • ${match.formattedTime}',
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
                    // Show "Cancelled" badge for cancelled matches
                    if (!match.isActive) ...[
                      _buildStatusBadge(
                        label: 'Canceled',
                        color: AppColors.red,
                      ),
                    ] else ...[
                      if (match.isFull)
                        _buildStatusBadge(
                          label: 'Full',
                          color: AppColors.red,
                        ),
                      if (match.isModified)
                        _buildStatusBadge(
                          label: 'modified'.tr(),
                          color: AppColors.blue,
                        ),
                      StreamBuilder<int>(
                        stream: _periodicMinuteStream,
                        initialData: 0,
                        builder: (context, snapshot) {
                          final remaining = match.timeUntilMatch;
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
              label: match.benchCount > 0
                  ? '${match.maxPlayers}/${match.maxPlayers} + ${match.benchCount} bench'
                  : '${match.currentPlayers}/${match.maxPlayers}',
              color: match.hasSpace ? AppColors.green : AppColors.red,
              icon: match.isPublic ? Icons.lock_open : Icons.lock,
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
                  // Defer weather loading until after build completes
                  Future(() => _ensureWeatherForMatch(match));
                  String time = match.formattedTime.padLeft(5, '0');
                  if (!time.endsWith(':00')) {
                    time = '${time.substring(0, 2)}:00';
                  }
                  final screenState = ref.watch(
                      matchesMyScreenNotifierProvider(widget.highlightMatchId));
                  final cachedWeather = screenState.weatherByMatchId[match.id];
                  final forecasts = cachedWeather?.isExpired == false
                      ? cachedWeather!.data
                      : null;
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
                  child: _buildParticipantsStrip(match),
                ),
                // Edit button for organizer - placed next to participants
                if (isMine && !match.dateTime.isBefore(DateTime.now())) ...[
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
                          builder: (_) =>
                              MatchOrganizeScreen(initialMatch: match),
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
                // Only show action buttons (edit, cancel, directions, share) for upcoming matches
                if (!match.dateTime.isBefore(DateTime.now())) ...[
                  Row(
                    children: [
                      if (!isMine && _isUserJoined(match)) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => match.isActive
                                ? _leaveMatch(match)
                                : _removeFromJoined(match),
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
                                match.isActive
                                    ? Icons.logout
                                    : Icons.delete_outline,
                                size: 16),
                            label:
                                Text(match.isActive ? 'leave'.tr() : 'Remove'),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (isMine) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // If match is already cancelled, just remove it from view
                              if (!match.isActive) {
                                await _removeFromCreated(match);
                                return;
                              }

                              // Otherwise, cancel it (which marks inactive AND removes from createdMatches)
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
                                      .read(matchesActionsProvider)
                                      .deleteMatch(match.id);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'match_cancelled_successfully'
                                                .tr()),
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
                                            'match_cancellation_failed'.tr()),
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
                                match.isActive
                                    ? Icons.cancel
                                    : Icons.delete_outline,
                                size: 16),
                            label:
                                Text(match.isActive ? 'cancel'.tr() : 'Remove'),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openDirections(match),
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
                            final screenState = ref.watch(
                                matchesMyScreenNotifierProvider(
                                    widget.highlightMatchId));
                            final screenNotifier = ref.read(
                                matchesMyScreenNotifierProvider(
                                        widget.highlightMatchId)
                                    .notifier);
                            // Check cached status first
                            final cachedStatus =
                                screenState.calendarStatusByMatchId[match.id];
                            final isLoading =
                                screenState.calendarLoading.contains(match.id);

                            // If preload is in progress and status is unknown, show as checking
                            final isActuallyLoading = isLoading ||
                                (cachedStatus == null &&
                                    screenState.calendarPreloadInProgress);

                            // If not cached and not loading, and preload is not in progress, trigger async check
                            // Wait for preload to complete first to avoid duplicate checks
                            if (cachedStatus == null &&
                                !isLoading &&
                                !screenState.calendarPreloadInProgress) {
                              // Only trigger individual check if preload hasn't populated it yet
                              // This handles edge cases where a match was added after preload completed
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final currentState = ref.read(
                                    matchesMyScreenNotifierProvider(
                                        widget.highlightMatchId));
                                if (mounted &&
                                    !currentState.calendarStatusByMatchId
                                        .containsKey(match.id) &&
                                    !currentState.calendarPreloadInProgress) {
                                  // Trigger async check but don't wait
                                  screenNotifier
                                      .getCalendarStatus(match.id)
                                      .catchError((e) {
                                    NumberedLogger.e(
                                        'Error in getCalendarStatus for ${match.id}: $e');
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
                                  : () => _addToCalendar(match),
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
                  if ((match.contactInfo?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _messageOrganizer(match),
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
                // Show "Report an issue" and "Organize Similar Match" buttons for historic matches (past matches)
                if (match.dateTime.isBefore(DateTime.now())) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _organizeSimilarMatch(match),
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
                          label: Text('organize_similar_match'.tr()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openReportSheet(match),
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

  Widget _buildMatchTile(Match match) {
    final key = _itemKeys.putIfAbsent(match.id, () => GlobalKey());

    // Build the match card (without margin) - matching Historic tab style
    final matchCard = KeyedSubtree(
      key: key,
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero, // No margin here - handled by Container
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: _buildMatchTileContent(match),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppHeights.reg),
      child: matchCard,
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
          Text('no_joined_matches_yet'.tr(),
              style: AppTextStyles.title.copyWith(color: AppColors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: AppHeights.small),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MatchesJoinScreen(),
                ),
              );
            },
            child: Text('go_join_a_match'.tr()),
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
          Text('no_organized_matches_yet'.tr(),
              style: AppTextStyles.title.copyWith(color: AppColors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: AppHeights.small),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MatchOrganizeScreen(),
                ),
              );
            },
            child: Text('go_organize_a_match'.tr()),
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
          Text('no_historic_matches_yet'.tr(),
              style: AppTextStyles.title.copyWith(color: AppColors.grey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
