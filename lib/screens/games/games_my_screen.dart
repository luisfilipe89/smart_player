import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/services/auth/auth_provider.dart';
import 'package:move_young/services/games/games_provider.dart';
import 'package:move_young/services/games/cloud_games_provider.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/screens/games/games_join_screen.dart';
import 'package:move_young/screens/games/game_organize_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:move_young/services/friends/friends_provider.dart';
import 'package:move_young/services/external/weather_provider.dart';
import 'package:move_young/utils/error_extensions.dart';
import 'package:move_young/widgets/common/error_retry_widget.dart';

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
  final Set<String> _expanded = <String>{};
  // Weather forecast cache per gameId: time("HH:00") -> condition
  final Map<String, Map<String, String>> _weatherByGameId = {};
  final Set<String> _weatherLoading = <String>{};
  String? _highlightId;

  @override
  void initState() {
    super.initState();
    _tab =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
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
              return FutureBuilder<List<Map<String, String?>>>(
                future: Future.wait(
                  limited.map((uid) async {
                    final friendsActions = ref.read(friendsActionsProvider);
                    final profile =
                        await friendsActions.fetchMinimalProfile(uid);
                    return profile;
                  }),
                ),
                builder: (context, snapshot) {
                  final profiles =
                      snapshot.data ?? const <Map<String, String?>>[];
                  if (profiles.isEmpty) return const SizedBox.shrink();

                  const double radius = 18;
                  const double diameter = radius * 2;
                  const double overlap = 6;
                  const int maxVisible = 8;

                  final int total = merged.length;
                  final int visibleCount = profiles.length > maxVisible
                      ? maxVisible
                      : profiles.length;
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
                              border: const Border.fromBorderSide(BorderSide(
                                  color: AppColors.primary, width: 1)),
                            ),
                            child: CircleAvatar(
                              radius: radius,
                              backgroundColor: AppColors.superlightgrey,
                              backgroundImage:
                                  (photo != null && photo.isNotEmpty)
                                      ? NetworkImage(photo)
                                      : null,
                              child: (photo == null || photo.isEmpty)
                                  ? (initials == '?'
                                      ? const Icon(Icons.person,
                                          size: 18, color: AppColors.blackopac)
                                      : Text(initials,
                                          style: AppTextStyles.small))
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

                  final double width =
                      (visibleCount + (remaining > 0 ? 1 : 0)) *
                              (diameter - overlap) +
                          overlap +
                          2;

                  return SizedBox(
                      width: width,
                      height: diameter,
                      child: Stack(children: items));
                },
              );
            },
          ),
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

  Future<void> _messageOrganizer(Game game) async {
    final info = game.contactInfo?.trim();
    if (info == null || info.isEmpty) return;
    if (info.contains('@')) {
      final uri = Uri(scheme: 'mailto', path: info, queryParameters: {
        'subject': 'About our game at ${game.location}',
        'body':
            'Hi ${game.organizerName},\n\nRegarding the game on ${game.formattedDate} at ${game.formattedTime}...'
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

  Future<void> _shareGameLink(Game game) async {
    final String when = '${game.formattedDate} • ${game.formattedTime}';
    final String players = '${game.currentPlayers}/${game.maxPlayers}';
    final String location =
        (game.address?.isNotEmpty ?? false) ? game.address! : game.location;
    final String message =
        'Join my ${game.sport} game!\nWhen: $when\nWhere: $location\nPlayers: $players\nGame ID: ${game.id}';
    await Share.share(message, subject: 'Game invite');
  }

  void _toggleExpanded(String gameId) {
    setState(() {
      if (_expanded.contains(gameId)) {
        _expanded.remove(gameId);
      } else {
        _expanded.add(gameId);
      }
    });
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
                content: Text('No location information available for directions'),
                backgroundColor: AppColors.orange,
              ),
            );
          }
          return;
        }
        
        // Build search URL
        final query = Uri.encodeComponent(searchQuery);
        uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
      }
      
      // Try launching URL - if platform channel fails, use direct Android intent as fallback
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          tabs: [
            Tab(text: '${'registered_games'.tr()} (${joinedGames.length})'),
            Tab(text: '${'organized_games'.tr()} (${createdGames.length})'),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameTile(Game game) {
    final key = _itemKeys.putIfAbsent(game.id, () => GlobalKey());
    final currentUserId = ref.watch(currentUserIdProvider);
    final isMine = currentUserId == game.organizerId;
    final expanded = _expanded.contains(game.id);

    return KeyedSubtree(
      key: key,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: AppHeights.reg),
        color: AppColors.white,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: game.isActive ? AppColors.green : AppColors.red,
                width: 6,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Hero(
                  tag: 'game-${game.id}-icon',
                  child: Icon(_iconForSport(game.sport),
                      color: _colorForSport(game.sport)),
                ),
                title: Text(game.location, style: AppTextStyles.cardTitle),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${game.formattedDate} • ${game.formattedTime}',
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // Show "Cancelled" badge for cancelled games
                        if (!game.isActive) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: 0.08),
                              border: const Border.fromBorderSide(BorderSide(
                                  color: AppColors.lightgrey, width: 1)),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.smallCard),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                        color: AppColors.red,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text('Canceled',
                                    style: AppTextStyles.small.copyWith(
                                        color: AppColors.red,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ] else ...[
                          if (game.isFull)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.red.withValues(alpha: 0.1),
                                border: const Border.fromBorderSide(BorderSide(
                                    color: AppColors.lightgrey, width: 1)),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.smallCard),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                          color: AppColors.red,
                                          shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Text('Full',
                                      style: AppTextStyles.small.copyWith(
                                          color: AppColors.red,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
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
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: urgent
                                      ? Colors.amber.withValues(alpha: 0.12)
                                      : AppColors.blue.withValues(alpha: 0.1),
                                  border: const Border.fromBorderSide(
                                      BorderSide(
                                          color: AppColors.lightgrey,
                                          width: 1)),
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.smallCard),
                                ),
                                child: Text('Starts in ${hours}h ${minutes}m',
                                    style: AppTextStyles.small.copyWith(
                                        color: urgent
                                            ? Colors.amber.shade800
                                            : AppColors.blue,
                                        fontWeight: FontWeight.bold)),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: game.hasSpace
                            ? AppColors.green.withValues(alpha: 0.1)
                            : AppColors.red.withValues(alpha: 0.1),
                        border: const Border.fromBorderSide(
                            BorderSide(color: AppColors.lightgrey, width: 1)),
                        borderRadius:
                            BorderRadius.circular(AppRadius.smallCard),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            game.isPublic ? Icons.lock_open : Icons.lock,
                            size: 14,
                            color:
                                game.hasSpace ? AppColors.green : AppColors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            game.benchCount > 0
                                ? '${game.maxPlayers}/${game.maxPlayers} + ${game.benchCount} bench'
                                : '${game.currentPlayers}/${game.maxPlayers}',
                            style: AppTextStyles.small.copyWith(
                              color: game.hasSpace
                                  ? AppColors.green
                                  : AppColors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: expanded ? 'collapse' : 'expand',
                      onPressed: () => _toggleExpanded(game.id),
                      icon: AnimatedRotation(
                        turns: expanded ? 0 : -0.25,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.expand_more),
                      ),
                    ),
                  ],
                ),
                onTap: isMine ? null : () => _toggleExpanded(game.id),
              ),
              Padding(
                padding: AppPaddings.allMedium,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: expanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.image),
                              child: SizedBox(
                                height: 140,
                                width: double.infinity,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (game.imageUrl != null &&
                                        game.imageUrl!.isNotEmpty)
                                      CachedNetworkImage(
                                        imageUrl: game.imageUrl!,
                                        fit: BoxFit.cover,
                                        fadeInDuration:
                                            const Duration(milliseconds: 250),
                                        placeholder: (context, url) =>
                                            Container(
                                                color:
                                                    AppColors.superlightgrey),
                                        errorWidget: (context, url, error) =>
                                            Image.asset(
                                                'assets/images/general_public.jpg',
                                                fit: BoxFit.cover),
                                      )
                                    else
                                      Image.asset(
                                          'assets/images/general_public.jpg',
                                          fit: BoxFit.cover),
                                    Container(
                                        color: Colors.black
                                            .withValues(alpha: 0.08)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.only(top: 2, bottom: 0),
                              child: Row(
                                children: [
                                  // Weather icon with a subtle divider to separate from avatars
                                  Builder(builder: (context) {
                                    _ensureWeatherForGame(game);
                                    String time =
                                        game.formattedTime.padLeft(5, '0');
                                    if (!time.endsWith(':00')) {
                                      time = '${time.substring(0, 2)}:00';
                                    }
                                    final forecasts = _weatherByGameId[game.id];
                                    final weatherActions =
                                        ref.read(weatherActionsProvider);
                                    final String cond = forecasts?[time] ??
                                        weatherActions
                                            .getWeatherCondition(time);
                                    final IconData icon = weatherActions
                                        .getWeatherIcon(time, cond);
                                    final Color color =
                                        weatherActions.getWeatherColor(cond);
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 16, color: color),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 1,
                                          height: 16,
                                          color: AppColors.blue
                                              .withValues(alpha: 0.3),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                    );
                                  }),
                                  Expanded(
                                      child: _buildParticipantsStrip(game)),
                                  const SizedBox(width: 8),
                                  if (isMine)
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => GameOrganizeScreen(
                                                initialGame: game),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 32),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                        textStyle: AppTextStyles.small,
                                        foregroundColor: AppColors.primary,
                                        side: const BorderSide(
                                            color: AppColors.primary),
                                      ),
                                      child: const Icon(Icons.edit, size: 16),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                textStyle: AppTextStyles.small,
                                iconSize: 16,
                              ),
                              icon: Icon(
                                  game.isActive
                                      ? Icons.logout
                                      : Icons.delete_outline,
                                  size: 16),
                              label: Text(game.isActive ? 'Leave' : 'Remove'),
                            ),
                          ),
                          const SizedBox(width: 6),
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
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'game_cancelled_successfully'
                                                  .tr()),
                                          backgroundColor: AppColors.green,
                                        ),
                                      );
                                    }
                                    // No need to call _refreshData() - streams will update automatically
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
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
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                textStyle: AppTextStyles.small,
                                iconSize: 16,
                                elevation: 0,
                              ),
                              icon: Icon(
                                  game.isActive
                                      ? Icons.cancel
                                      : Icons.delete_outline,
                                  size: 16),
                              label: Text(
                                  game.isActive ? 'cancel'.tr() : 'Remove'),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openDirections(game),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 6),
                              textStyle: AppTextStyles.small,
                              iconSize: 16,
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                            ),
                            icon: const Icon(Icons.directions, size: 16),
                            label: Text('directions'.tr()),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _shareGameLink(game),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 6),
                              textStyle: AppTextStyles.small,
                              iconSize: 16,
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                            ),
                            icon:
                                const Icon(Icons.ios_share_outlined, size: 16),
                            label: const Text('Share'),
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
                ),
              ),
            ],
          ),
        ),
      ),
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
}
