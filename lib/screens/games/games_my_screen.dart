import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/models/game.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/services/cloud_games_service.dart';
import 'package:move_young/services/games_service.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/screens/games/games_join_screen.dart';
import 'package:move_young/screens/games/game_organize_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:move_young/services/friends_service.dart' as friends;
import 'package:move_young/services/weather_service.dart';
import 'dart:async';

class GamesMyScreen extends StatefulWidget {
  final String? highlightGameId;
  final int initialTab;
  const GamesMyScreen({super.key, this.highlightGameId, this.initialTab = 0});

  @override
  State<GamesMyScreen> createState() => _GamesMyScreenState();
}

class _GamesMyScreenState extends State<GamesMyScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<Game> _joined = [];
  List<Game> _created = [];
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
        _load();
      }
    });
    // Schedule load after first frame to ensure Navigator/Inheriteds are ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    // Start realtime watch for Joining tab
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWatchingJoined());
  }

  @override
  void dispose() {
    _joinedSub?.cancel();
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

  // ---- Helpers restored ----
  Widget _buildParticipantsStrip(Game game) {
    final bool isOrganizer = AuthService.currentUserId == game.organizerId;
    final List<String> basePlayerUids = List<String>.from(game.players);
    return SizedBox(
      height: 44,
      child: FutureBuilder<Map<String, String>>(
        future: isOrganizer
            ? CloudGamesService.getInviteStatuses(game.id)
            : Future.value(const <String, String>{}),
        builder: (context, statusesSnap) {
          final Map<String, String> inviteStatuses =
              statusesSnap.data ?? const <String, String>{};
          final List<String> invited = inviteStatuses.keys.toList();
          // Keep invitees included visually even if they haven't joined yet
          final List<String> merged =
              <String>{...basePlayerUids, ...invited}.toList();
          if (merged.isEmpty) return const SizedBox.shrink();

          // Fetch minimal profiles for merged set
          final List<String> limited = merged.take(12).toList();
          return FutureBuilder<List<Map<String, String?>>>(
            future: Future.wait(
              limited.map(
                  (uid) => friends.FriendsService.fetchMinimalProfile(uid)),
            ),
            builder: (context, snapshot) {
              final profiles = snapshot.data ?? const <Map<String, String?>>[];
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
                final String status = inviteStatuses[uid] ?? 'pending';
                final bool isPending = invitedSet.contains(uid) &&
                    !basePlayerUids.contains(uid) &&
                    status == 'pending';
                final bool isAccepted = invitedSet.contains(uid) &&
                    (status == 'accepted' || basePlayerUids.contains(uid));
                final bool isDeclinedOrLeft = invitedSet.contains(uid) &&
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
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
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
      final map = await WeatherService.fetchWeatherForDate(
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
    final uid = AuthService.currentUserId;
    if (uid == null || uid.isEmpty) return false;
    return game.players.any((p) => p == uid);
  }

  Future<void> _leaveGame(Game game) async {
    final uid = AuthService.currentUserId;
    if (uid == null || uid.isEmpty) return;
    final ok = await CloudGamesService.leaveGame(game.id, uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'You left the game' : 'Failed to leave'),
        backgroundColor: ok ? AppColors.grey : AppColors.red,
      ),
    );
    if (ok) await _load();
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = AuthService.currentUserId;
      List<Game> joined = [];
      List<Game> created = [];

      // Fetch from cloud
      if (uid != null && uid.isNotEmpty) {
        joined = await CloudGamesService.getUserJoinedGames(uid);
        created = await CloudGamesService.getUserGames();
      }

      // Also fetch from local database (in case of sync issues)
      if (uid != null && uid.isNotEmpty) {
        try {
          final localCreated = await GamesService.getGamesByOrganizer(uid);
          created = [...created, ...localCreated];
        } catch (_) {}
      }

      // Merge and de-duplicate (keep earliest occurrence)
      final Map<String, Game> byId = {
        for (final g in [...joined, ...created]) g.id: g
      };
      final all = byId.values.where((g) => g.isActive && g.isUpcoming).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

      setState(() {
        _joined = all
            .where((g) => !(AuthService.currentUserId == g.organizerId))
            .toList();
        _created = all
            .where((g) => AuthService.currentUserId == g.organizerId)
            .toList();
        _loading = false;
      });
      if (_highlightId != null) {
        _scrollToHighlightedGame();
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // Realtime: watch current user's joined games to auto-refresh Joining tab
  StreamSubscription<List<Game>>? _joinedSub;

  void _startWatchingJoined() {
    _joinedSub?.cancel();
    final uid = AuthService.currentUserId;
    if (uid == null || uid.isEmpty) return;
    _joinedSub = CloudGamesService.watchUserJoinedGames(uid).listen((games) {
      if (!mounted) return;
      // Merge with created list and re-derive state similarly to _load
      final Map<String, Game> byId = {
        for (final g in [..._created, ...games]) g.id: g
      };
      final all = byId.values.where((g) => g.isActive && g.isUpcoming).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      setState(() {
        _joined = all
            .where((g) => !(AuthService.currentUserId == g.organizerId))
            .toList();
      });
    });
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

  Future<void> _openDirections(String target) async {
    final query = Uri.encodeComponent(target);
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('could_not_open_google_maps'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Tab(text: '${'registered_games'.tr()} (${_joined.length})'),
            Tab(text: '${'organized_games'.tr()} (${_created.length})'),
          ],
        ),
      ),
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: AppPaddings.symmHorizontalReg,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Container(
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
                          onRefresh: _load,
                          child: (_joined.isEmpty)
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(
                                      bottom: AppHeights.reg),
                                  children: [
                                    _emptyStateRegistered(context),
                                  ],
                                )
                              : ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: AppPaddings.allMedium.add(
                                    const EdgeInsets.only(
                                        bottom: AppHeights.reg),
                                  ),
                                  itemCount: _joined.length,
                                  itemBuilder: (_, i) =>
                                      _buildGameTile(_joined[i]),
                                ),
                        ),
                        // Organized Games (created)
                        RefreshIndicator(
                          onRefresh: _load,
                          child: (_created.isEmpty)
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(
                                      bottom: AppHeights.reg),
                                  children: [
                                    _emptyStateOrganized(context),
                                  ],
                                )
                              : ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: AppPaddings.allMedium.add(
                                    const EdgeInsets.only(
                                        bottom: AppHeights.reg),
                                  ),
                                  itemCount: _created.length,
                                  itemBuilder: (_, i) =>
                                      _buildGameTile(_created[i]),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildGameTile(Game game) {
    return StreamBuilder<Game?>(
      stream: CloudGamesService.watchGame(game.id),
      builder: (context, snap) {
        final Game effective = snap.data ?? game;
        return _buildGameTileBody(effective);
      },
    );
  }

  Widget _buildGameTileBody(Game game) {
    final key = _itemKeys.putIfAbsent(game.id, () => GlobalKey());
    final isMine = AuthService.currentUserId == game.organizerId;
    final expanded = _expanded.contains(game.id);
    return KeyedSubtree(
      key: key,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: AppHeights.reg),
        color: AppColors.white,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.green, width: 6),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(_iconForSport(game.sport),
                    color: _colorForSport(game.sport)),
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
                            if (remaining.isNegative ||
                                remaining > const Duration(hours: 8)) {
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
                                border: const Border.fromBorderSide(BorderSide(
                                    color: AppColors.lightgrey, width: 1)),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.smallCard),
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
                      child: Text(
                        '${game.currentPlayers}/${game.maxPlayers}',
                        style: AppTextStyles.small.copyWith(
                          color:
                              game.hasSpace ? AppColors.green : AppColors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isMine) ...[
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
                    ] else ...[
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
                                      time = time.substring(0, 2) + ':00';
                                    }
                                    final forecasts = _weatherByGameId[game.id];
                                    final String cond = forecasts?[time] ??
                                        WeatherService.getWeatherCondition(
                                            time);
                                    final IconData icon =
                                        WeatherService.getWeatherIcon(
                                            time, cond);
                                    final Color color =
                                        WeatherService.getWeatherColor(cond);
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
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (!isMine && _isUserJoined(game)) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _leaveGame(game),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.red,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                textStyle: AppTextStyles.small,
                                iconSize: 16,
                              ),
                              icon: const Icon(Icons.logout, size: 16),
                              label: const Text('Leave'),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (isMine) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
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
                                    if (AuthService.isSignedIn) {
                                      await CloudGamesService.deleteGame(
                                          game.id);
                                    }
                                    await GamesService.cancelGame(game.id);
                                    if (context.mounted) {
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
                                    await _load();
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('game_creation_failed'.tr()),
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
                              icon: const Icon(Icons.cancel, size: 16),
                              label: Text('cancel'.tr()),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openDirections(
                                (game.address?.isNotEmpty ?? false)
                                    ? game.address!
                                    : game.location),
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
                  builder: (_) => const GamesDiscoveryScreen(),
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
