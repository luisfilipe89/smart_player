// lib/screens/games/games_discovery_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/models/game.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/services/games_service.dart';

class GamesDiscoveryScreen extends StatefulWidget {
  const GamesDiscoveryScreen({super.key});

  @override
  State<GamesDiscoveryScreen> createState() => _GamesDiscoveryScreenState();
}

class _GamesDiscoveryScreenState extends State<GamesDiscoveryScreen> {
  List<Game> _games = [];
  bool _isLoading = true;
  String _selectedSport = 'all';
  String _searchQuery = '';

  final List<String> _sports = ['all', 'soccer', 'basketball'];

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Game> games;
      if (_selectedSport == 'all') {
        games = await GamesService.getUpcomingGames();
      } else {
        games = await GamesService.searchGamesBySport(_selectedSport);
      }

      // Filter by search query if provided
      if (_searchQuery.isNotEmpty) {
        games = games.where((game) {
          return game.location
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              game.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              game.organizerName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase());
        }).toList();
      }

      setState(() {
        _games = games;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load games'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _joinGame(Game game) async {
    try {
      // TODO: Get current user ID from user service
      const currentUserId = 'current_user_id';
      const currentUserName = 'Current User';

      final success =
          await GamesService.joinGame(game.id, currentUserId, currentUserName);

      if (success) {
        HapticFeedback.lightImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully joined the game!'),
              backgroundColor: AppColors.green,
            ),
          );
        }
        _loadGames(); // Refresh the list
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to join game. Game might be full.'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining game'),
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
        title: Text('discover_games'.tr()),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(AppWidths.regular),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'search_games'.tr(),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    filled: true,
                    fillColor: AppColors.superlightgrey,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _loadGames();
                  },
                ),
                const SizedBox(height: AppHeights.reg),

                // Sport Filter
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
                          label: Text(
                              sport == 'all' ? 'all_sports'.tr() : sport.tr()),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedSport = sport;
                            });
                            _loadGames();
                          },
                          selectedColor: AppColors.blue.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.blue,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Games List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _games.isEmpty
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
                        onRefresh: _loadGames,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppWidths.regular),
                          itemCount: _games.length,
                          itemBuilder: (context, index) {
                            final game = _games[index];
                            return _buildGameCard(game);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(Game game) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppHeights.reg),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to game details screen
        },
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppWidths.regular),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Sport Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getSportColor(game.sport).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.smallCard),
                    ),
                    child: Icon(
                      _getSportIcon(game.sport),
                      color: _getSportColor(game.sport),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppWidths.regular),

                  // Game Info
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

                  // Players Count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: game.hasSpace
                          ? AppColors.green.withValues(alpha: 0.1)
                          : AppColors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.smallCard),
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

              const SizedBox(height: AppHeights.reg),

              // Description
              if (game.description.isNotEmpty) ...[
                Text(
                  game.description,
                  style: AppTextStyles.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppHeights.reg),
              ],

              // Organizer Info
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: AppColors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Organized by ${game.organizerName}',
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppHeights.reg),

              // Join Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
