// lib/screens/games/games_discovery_screen.dart
import 'package:flutter/material.dart';
// Haptic already imported above in other files when needed
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/models/game.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/games_service.dart';
import 'package:move_young/services/cloud_games_service.dart';
import 'package:move_young/services/friends_service.dart' as friends;
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/services/haptics_service.dart';
import 'dart:async';
import 'package:move_young/screens/main_scaffold.dart';

class GamesDiscoveryScreen extends StatefulWidget {
  final String? highlightGameId;
  const GamesDiscoveryScreen({super.key, this.highlightGameId});

  @override
  State<GamesDiscoveryScreen> createState() => _GamesDiscoveryScreenState();
}

class _GamesDiscoveryScreenState extends State<GamesDiscoveryScreen> {
  List<Game> _games = [];
  List<Game> _invitedGames = [];
  bool _isLoading = true;
  // Removed: _isLoadingInvited used when AppBar invite action existed
  // No explicit filter UI; list renders invited games first
  String _selectedSport = 'all';
  String _searchQuery = '';
  late final TextEditingController _searchController;
  static const String _adminEmail = 'luisfccfigueiredo@gmail.com';
  final ScrollController _listController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  String? _highlightId;
  StreamSubscription<List<Game>>? _publicGamesSub;

  final List<String> _sports = [
    'all',
    'soccer',
    'basketball',
    'tennis',
    'volleyball',
    'badminton',
    'table_tennis'
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _searchQuery);
    _highlightId = widget.highlightGameId;
    _loadGames();
    _loadInvitedGames();
    _watchPublicGames();
  }

  // Try a few times to ensure the list is built before scrolling
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

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    _publicGamesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadGames() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Game> games = await GamesService.getAllGames();
      final now = DateTime.now();
      games =
          games.where((g) => g.dateTime.isAfter(now) && g.isActive).toList();
      if (_selectedSport != 'all') {
        games = games.where((g) => g.sport == _selectedSport).toList();
      }

      // Filter by search query if provided (location and organizer only)
      if (_searchQuery.isNotEmpty) {
        games = games.where((game) {
          final q = _searchQuery.toLowerCase();
          return game.location.toLowerCase().contains(q) ||
              game.organizerName.toLowerCase().contains(q);
        }).toList();
      }

      // Exclude games already joined by current user
      final String myUid = AuthService.currentUserId ?? '';
      if (myUid.isNotEmpty) {
        games = games.where((g) => !g.players.contains(myUid)).toList();
      }

      setState(() {
        _games = games;
        _isLoading = false;
      });

      // Scroll to and highlight the created game if requested
      if (_highlightId != null) {
        _scrollToHighlightedGame();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('loading_error'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  void _watchPublicGames() {
    try {
      _publicGamesSub?.cancel();
      _publicGamesSub =
          CloudGamesService.watchPublicGames(limit: 200).listen((all) {
        // Keep only upcoming & active, then apply current filters
        final now = DateTime.now();
        List<Game> games =
            all.where((g) => g.dateTime.isAfter(now) && g.isActive).toList();

        if (_selectedSport != 'all') {
          games = games.where((g) => g.sport == _selectedSport).toList();
        }

        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          games = games.where((game) {
            return game.location.toLowerCase().contains(q) ||
                game.organizerName.toLowerCase().contains(q);
          }).toList();
        }

        final String myUid = AuthService.currentUserId ?? '';
        if (myUid.isNotEmpty) {
          games = games.where((g) => !g.players.contains(myUid)).toList();
        }

        if (!mounted) return;
        setState(() {
          _games = games;
        });
      });
    } catch (_) {}
  }

  void _showJoinedSnack() {
    if (!mounted) return;
    final messenger =
        ScaffoldMessenger.maybeOf(context) ?? ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Joined! Find it under My Games > Joining'),
        backgroundColor: AppColors.green,
        action: SnackBarAction(
          label: 'view_in_my_games'.tr(),
          onPressed: () {
            MainScaffoldScope.maybeOf(context)
                ?.switchToTab(kTabJoin, popToRoot: true);
          },
        ),
      ),
    );
  }

  Future<void> _loadInvitedGames() async {
    try {
      final invited = await CloudGamesService.getInvitedGamesForCurrentUser();
      if (!mounted) return;
      // Exclude if already joined (defensive)
      final String myUid = AuthService.currentUserId ?? '';
      final filtered = myUid.isEmpty
          ? invited
          : invited.where((g) => !g.players.contains(myUid)).toList();
      setState(() {
        _invitedGames = filtered;
      });
    } catch (_) {}
  }

  Future<void> _joinGame(Game game) async {
    try {
      final currentUserId = AuthService.currentUserId ?? '';
      final currentUserName = AuthService.currentUserDisplayName;
      if (currentUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('please_sign_in_to_organize'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }

      final success =
          await GamesService.joinGame(game.id, currentUserId, currentUserName);

      if (success) {
        HapticsService.lightImpact();
        if (mounted) {
          // Optimistically remove from lists so it disappears immediately
          setState(() {
            _games.removeWhere((g) => g.id == game.id);
            _invitedGames.removeWhere((g) => g.id == game.id);
          });
          _showJoinedSnack();
          MainScaffoldScope.maybeOf(context)?.openMyGames(
            initialTab: 0,
            highlightGameId: game.id,
            popToRoot: true,
          );
        }
        _loadGames(); // Refresh the list (defensive)
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('game_full'.tr()),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('loading_error'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelGame(Game game) async {
    final isOwner =
        AuthService.isSignedIn && AuthService.currentUserId == game.organizerId;
    if (!isOwner) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('cancel'.tr()),
        content: Text('are_you_sure'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr())),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('ok'.tr())),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (AuthService.isSignedIn) {
        await CloudGamesService.deleteGame(game.id);
      }
      await GamesService.cancelGame(game.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('game_cancelled_successfully'.tr()),
            backgroundColor: AppColors.green,
          ),
        );
      }
      await _loadGames();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('game_creation_failed'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  // ignore: unused_element
  Future<void> _inviteFriendsToGame(Game game) async {
    final uid = AuthService.currentUserId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('please_sign_in_to_organize'.tr()),
            backgroundColor: AppColors.red),
      );
      return;
    }
    try {
      final friendIds = await friends.FriendsService.friendsStream(uid).first;
      final selected = <String>{};
      final names = <String, String>{};
      for (final f in friendIds) {
        names[f] = await friends.FriendsService.fetchDisplayName(f);
      }
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.container),
              boxShadow: AppShadows.md,
            ),
            padding: AppPaddings.allBig,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('select_friends'.tr(), style: AppTextStyles.h3),
                      Text('${selected.length}')
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: ListView.builder(
                      itemCount: friendIds.length,
                      itemBuilder: (context, i) {
                        final f = friendIds[i];
                        final name = names[f] ?? 'User';
                        final checked = selected.contains(f);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                selected.add(f);
                              } else {
                                selected.remove(f);
                              }
                            });
                          },
                          title: Text(name),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('cancel'.tr()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (selected.isNotEmpty) {
                            await CloudGamesService.invitePlayers(
                              game.id,
                              selected.toList(),
                              sport: game.sport,
                              dateTime: game.dateTime,
                            );
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('ok'.tr()),
                      ),
                    ),
                  ])
                ],
              ),
            ),
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('loading_error'.tr()),
            backgroundColor: AppColors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: const AppBackButton(goHome: true),
        title: Text('join_a_game'.tr()),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: AppPaddings.symmHorizontalReg,
          child: _buildBrowseTab(),
        ),
      ),
    );
  }

  Widget _buildGameCard(Game game) {
    final bool isHighlighted = game.id == _highlightId;
    final bool isInvited = _invitedGames.any((g) => g.id == game.id);
    return Card(
      margin: const EdgeInsets.only(bottom: AppHeights.reg),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: isInvited
              ? AppColors.blue.withValues(alpha: 0.3)
              : AppColors.lightgrey.withValues(alpha: 0.5),
          width: isInvited ? 2 : 1,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          gradient: null,
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: 0.25),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(AppWidths.regular),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isInvited)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(AppRadius.smallCard),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blue.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mail, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Invited',
                          style: AppTextStyles.small.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            _getSportColor(game.sport).withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppRadius.smallCard),
                      ),
                      child: Icon(
                        _getSportIcon(game.sport),
                        color: _getSportColor(game.sport),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppWidths.regular),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game.sport.toUpperCase(),
                            style: AppTextStyles.smallCardTitle.copyWith(
                              color: _getSportColor(game.sport),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            game.location,
                            style: AppTextStyles.cardTitle,
                          ),
                          Text(
                            '${game.formattedDate} at ${game.formattedTime}',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: game.hasSpace
                            ? AppColors.green.withValues(alpha: 0.1)
                            : AppColors.red.withValues(alpha: 0.1),
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
                  ],
                ),
                const SizedBox(height: AppHeights.reg),
                if (game.description.isNotEmpty) ...[
                  Text(
                    game.description,
                    style: AppTextStyles.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppHeights.reg),
                ],
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 16,
                      color: AppColors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        (_invitedGames.any((g) => g.id == game.id))
                            ? 'Invited by ${game.organizerName}'
                            : (AuthService.isSignedIn &&
                                    AuthService.currentUserId ==
                                        game.organizerId)
                                ? 'Organized by me'
                                : 'Organized by ${game.organizerName}',
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppWidths.regular),
                    if (AuthService.isSignedIn &&
                        AuthService.currentUser?.uid == game.organizerId)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          HapticsService.selectionClick();
                          Navigator.of(context).pushNamed(
                            '/organize-game',
                            arguments: game,
                          );
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text('edit'.tr(), style: AppTextStyles.small),
                      ),
                  ],
                ),
                const SizedBox(height: AppHeights.reg),
                SizedBox(
                  width: double.infinity,
                  child: FutureBuilder<String?>(
                    future: CloudGamesService.getInviteStatusForCurrentUser(
                        game.id),
                    builder: (context, statusSnap) {
                      final isOwnerOrAdmin = AuthService.isSignedIn &&
                          (AuthService.currentUserId == game.organizerId ||
                              (AuthService.currentUser?.email?.toLowerCase() ==
                                  _adminEmail));
                      if (isOwnerOrAdmin) {
                        return ElevatedButton(
                          onPressed: () => _cancelGame(game),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'cancel_game'.tr(),
                            style: AppTextStyles.cardTitle.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        );
                      }

                      final String myUid = AuthService.currentUserId ?? '';
                      final bool isJoined = myUid.isNotEmpty &&
                          game.players.any((p) => p == myUid);
                      final String? inviteStatus = statusSnap.data;
                      final bool isInvitedPending = inviteStatus == 'pending';
                      final bool isLeft = inviteStatus == 'left';

                      if (isInvitedPending) {
                        return Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final ok =
                                      await CloudGamesService.acceptInvite(
                                          game.id);
                                  if (ok) {
                                    _showJoinedSnack();
                                    MainScaffoldScope.maybeOf(context)
                                        ?.openMyGames(
                                      initialTab: 0,
                                      highlightGameId: game.id,
                                      popToRoot: true,
                                    );
                                  } else if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('loading_error'.tr()),
                                        backgroundColor: AppColors.red,
                                      ),
                                    );
                                  }
                                  await _loadInvitedGames();
                                  await _loadGames();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.card),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text('accept'.tr()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final ok =
                                      await CloudGamesService.declineInvite(
                                          game.id);
                                  if (ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('declined'.tr()),
                                        backgroundColor: AppColors.grey,
                                      ),
                                    );
                                    await _loadInvitedGames();
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.red,
                                  side: const BorderSide(color: AppColors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.card),
                                  ),
                                ),
                                child: Text('decline'.tr()),
                              ),
                            ),
                          ],
                        );
                      }

                      if (isLeft) {
                        return Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.lightgrey,
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.smallCard),
                                ),
                                child: Text(
                                  'You left this invited game',
                                  style: AppTextStyles.small,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final ok =
                                      await CloudGamesService.acceptInvite(
                                          game.id);
                                  if (ok) {
                                    _showJoinedSnack();
                                  } else if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('loading_error'.tr()),
                                        backgroundColor: AppColors.red,
                                      ),
                                    );
                                  }
                                  await _loadInvitedGames();
                                  await _loadGames();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.card),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text('Rejoin'),
                              ),
                            ),
                          ],
                        );
                      }

                      if (isJoined) {
                        return ElevatedButton(
                          onPressed: () async {
                            if (myUid.isEmpty) return;
                            final ok = await CloudGamesService.leaveGame(
                                game.id, myUid);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? 'You left the game'
                                      : 'Failed to leave'),
                                  backgroundColor:
                                      ok ? AppColors.grey : AppColors.red,
                                ),
                              );
                            }
                            await _loadGames();
                            await _loadInvitedGames();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                            ),
                            elevation: 0,
                          ),
                          child: Text('cancel_game'.tr()),
                        );
                      }

                      return ElevatedButton(
                        onPressed: game.hasSpace ? () => _joinGame(game) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              game.hasSpace ? AppColors.blue : AppColors.grey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          game.hasSpace ? 'join_game'.tr() : 'game_full'.tr(),
                          style: AppTextStyles.cardTitle.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Removed AppBar invite action; badge shown on Home tile instead

  // --- Tabs content builders ---
  Widget _buildBrowseTab() {
    return Column(
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
                  PanelHeader('find_games'.tr()),
                  Padding(
                    padding: AppPaddings.symmHorizontalReg,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: AppHeights.superSmall),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: 'search_games'.tr(),
                                  filled: true,
                                  fillColor: AppColors.lightgrey,
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: (_searchQuery.isEmpty)
                                      ? null
                                      : IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchQuery = '';
                                            });
                                            _loadGames();
                                          },
                                        ),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.image),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() => _searchQuery = value);
                                  _loadGames();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppHeights.reg),
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _sports.length,
                            itemBuilder: (context, index) {
                              final sport = _sports[index];
                              final isSelected = _selectedSport == sport;
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: index < _sports.length - 1
                                      ? AppWidths.regular
                                      : 0,
                                ),
                                child: FilterChip(
                                  label: Text(sport == 'all'
                                      ? 'all_sports'.tr()
                                      : sport.tr()),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() => _selectedSport = sport);
                                    _loadGames();
                                  },
                                  selectedColor:
                                      AppColors.blue.withValues(alpha: 0.2),
                                  checkmarkColor: AppColors.blue,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppHeights.reg),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: AppPaddings.symmHorizontalReg,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : (_games.isEmpty && _invitedGames.isEmpty)
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.sports_soccer,
                                        size: 64,
                                        color: AppColors.grey,
                                      ),
                                      const SizedBox(height: AppHeights.reg),
                                      Text(
                                        'no_games_found'.tr(),
                                        style: AppTextStyles.title.copyWith(
                                          color: AppColors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: AppHeights.small),
                                      Text(
                                        'no_games_found_description'.tr(),
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: () async {
                                    await _loadGames();
                                    await _loadInvitedGames();
                                  },
                                  child: Builder(builder: (context) {
                                    // Merge lists with invited first
                                    final List<Game> merged = [
                                      ..._invitedGames,
                                      ..._games.where((g) => !_invitedGames
                                          .any((i) => i.id == g.id)),
                                    ];
                                    return ListView.builder(
                                      controller: _listController,
                                      padding: EdgeInsets.zero,
                                      itemCount: merged.length,
                                      itemBuilder: (context, index) {
                                        final game = merged[index];
                                        final key = _itemKeys.putIfAbsent(
                                            game.id, () => GlobalKey());
                                        return KeyedSubtree(
                                          key: key,
                                          child: _buildGameCard(game),
                                        );
                                      },
                                    );
                                  }),
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // (removed: invited tab UI; now handled via Invited filter in browse)

  Color _getSportColor(String sport) {
    switch (sport) {
      case 'soccer':
        return Colors.green;
      case 'basketball':
        return Colors.orange;
      default:
        return AppColors.blue;
    }
  }

  IconData _getSportIcon(String sport) {
    switch (sport) {
      case 'soccer':
        return Icons.sports_soccer;
      case 'basketball':
        return Icons.sports_basketball;
      default:
        return Icons.sports;
    }
  }
}
