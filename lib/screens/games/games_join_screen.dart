// lib/screens/games/games_join_screen_migrated.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/auth/auth_provider.dart';
import 'package:move_young/services/games/games_provider.dart';
import 'package:move_young/services/games/cloud_games_provider.dart' as cloud;

class GamesJoinScreen extends ConsumerStatefulWidget {
  final String? highlightGameId;
  const GamesJoinScreen({super.key, this.highlightGameId});

  @override
  ConsumerState<GamesJoinScreen> createState() => _GamesJoinScreenState();
}

class _GamesJoinScreenState extends ConsumerState<GamesJoinScreen> {
  String _selectedSport = 'all';
  String _searchQuery = '';
  late final TextEditingController _searchController;
  final Map<String, GlobalKey> _itemKeys = {};
  String? _highlightId;

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

    // Schedule scroll to highlighted game after first frame
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToHighlightedGame());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  void _refreshData() {
    // Refresh providers to get latest data
    ref.invalidate(cloud.joinableGamesProvider);
    ref.invalidate(cloud.invitedGamesProvider);
  }

  Future<void> _joinGame(Game game) async {
    try {
      await ref.read(gamesActionsProvider).joinGame(game.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined ${game.sport} game successfully!'),
            backgroundColor: AppColors.green,
          ),
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join game: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _acceptInvite(Game game) async {
    try {
      await ref.read(cloud.cloudGamesActionsProvider).acceptGameInvite(game.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accepted invite to ${game.sport} game!'),
            backgroundColor: AppColors.green,
          ),
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept invite: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineInvite(Game game) async {
    try {
      await ref
          .read(cloud.cloudGamesActionsProvider)
          .declineGameInvite(game.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Declined invite to ${game.sport} game'),
            backgroundColor: AppColors.grey,
          ),
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline invite: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  List<Game> _filterGames(List<Game> games) {
    var filtered = games.where((game) {
      // Filter by sport
      if (_selectedSport != 'all' && game.sport != _selectedSport) {
        return false;
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return game.location.toLowerCase().contains(query) ||
            game.organizerName.toLowerCase().contains(query) ||
            game.sport.toLowerCase().contains(query);
      }

      return true;
    }).toList();

    return filtered;
  }

  Widget _buildSportFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _sports.length,
        itemBuilder: (context, index) {
          final sport = _sports[index];
          final isSelected = _selectedSport == sport;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(sport == 'all' ? 'All Sports' : sport.toUpperCase()),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedSport = sport;
                });
              },
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primary,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: AppPaddings.allMedium,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search games...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.container),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildGameCard(Game game, {bool isInvite = false}) {
    final key = _itemKeys.putIfAbsent(game.id, () => GlobalKey());
    final currentUserId = ref.watch(currentUserIdProvider);
    final isJoined = game.players.contains(currentUserId);

    return KeyedSubtree(
      key: key,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppHeights.reg),
        child: Padding(
          padding: AppPaddings.allMedium,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getSportIcon(game.sport),
                    color: _getSportColor(game.sport),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      game.location,
                      style: AppTextStyles.cardTitle,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: game.hasSpace
                          ? AppColors.green.withValues(alpha: 0.1)
                          : AppColors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.container),
                    ),
                    child: Text(
                      '${game.currentPlayers}/${game.maxPlayers}',
                      style: AppTextStyles.small.copyWith(
                        color: game.hasSpace ? AppColors.green : AppColors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${game.formattedDate} • ${game.formattedTime}',
                style: AppTextStyles.cardTitle,
              ),
              const SizedBox(height: 4),
              Text(
                'Organized by ${game.organizerName}',
                style: AppTextStyles.small.copyWith(color: AppColors.grey),
              ),
              const SizedBox(height: 12),
              if (isInvite) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptInvite(game),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _declineInvite(game),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                          side: const BorderSide(color: AppColors.red),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                  ],
                ),
              ] else if (isJoined) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.container),
                  ),
                  child: Text(
                    'You\'re already joined!',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: AppColors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else if (game.hasSpace) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _joinGame(game),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Join Game'),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.container),
                  ),
                  child: Text(
                    'Game is full',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: AppColors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: AppPaddings.allSuperBig,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports, size: 64, color: AppColors.grey),
            const SizedBox(height: AppHeights.reg),
            Text(
              'No games found',
              style: AppTextStyles.title.copyWith(color: AppColors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppHeights.small),
            Text(
              'Try adjusting your filters or check back later',
              style: AppTextStyles.cardTitle.copyWith(color: AppColors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSportIcon(String sport) {
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
      default:
        return Icons.sports;
    }
  }

  Color _getSportColor(String sport) {
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
      default:
        return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('join_games'.tr()),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: const AppBackButton(),
      ),
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          _buildSportFilter(),
          _buildSearchBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refreshData(),
              child: Column(
                children: [
                  // Invited Games Section
                  Consumer(
                    builder: (context, ref, child) {
                      final invitedGamesAsync =
                          ref.watch(cloud.invitedGamesProvider);
                      return invitedGamesAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (invitedGames) {
                          if (invitedGames.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: AppPaddings.allMedium,
                                child: Text(
                                  'Game Invites',
                                  style: AppTextStyles.title,
                                ),
                              ),
                              ...invitedGames.map((game) =>
                                  _buildGameCard(game, isInvite: true)),
                            ],
                          );
                        },
                      );
                    },
                  ),

                  // Joinable Games Section
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final joinableGamesAsync =
                            ref.watch(cloud.joinableGamesProvider);
                        return joinableGamesAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stack) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Error loading games: $error'),
                                ElevatedButton(
                                  onPressed: _refreshData,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                          data: (joinableGames) {
                            final filteredGames = _filterGames(joinableGames);

                            if (filteredGames.isEmpty) {
                              return _buildEmptyState();
                            }

                            return ListView.builder(
                              padding: AppPaddings.allMedium,
                              itemCount: filteredGames.length,
                              itemBuilder: (context, index) {
                                final game = filteredGames[index];
                                return _buildGameCard(game);
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
          ),
        ],
      ),
    );
  }
}
