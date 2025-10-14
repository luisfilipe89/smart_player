import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/models/game.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/services/cloud_games_service.dart';
import 'package:move_young/theme/_theme.dart';

class GamesMyScreen extends StatefulWidget {
  final String? highlightGameId;
  const GamesMyScreen({super.key, this.highlightGameId});

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

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = AuthService.currentUserId;
      List<Game> joined = [];
      if (uid != null && uid.isNotEmpty) {
        joined = await CloudGamesService.getUserJoinedGames(uid);
      }
      final created = await CloudGamesService.getUserGames();

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
    } catch (_) {
      setState(() => _loading = false);
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
            Tab(text: 'registered_games'.tr()),
            Tab(text: 'organized_games'.tr()),
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
                                  children: [_emptyStateRegistered(context)])
                              : ListView.builder(
                                  padding: AppPaddings.allMedium,
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
                                  children: [_emptyStateOrganized(context)])
                              : ListView.builder(
                                  padding: AppPaddings.allMedium,
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
    final key = _itemKeys.putIfAbsent(game.id, () => GlobalKey());
    final isMine = AuthService.currentUserId == game.organizerId;
    return KeyedSubtree(
      key: key,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppHeights.reg),
        child: ListTile(
          leading: Icon(Icons.sports_soccer, color: AppColors.blue),
          title: Text(game.location, style: AppTextStyles.cardTitle),
          subtitle: Text('${game.formattedDate} • ${game.formattedTime}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(width: 8),
              isMine ? const Icon(Icons.edit) : const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () {},
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
            onPressed: () => Navigator.of(context).pushNamed('/discover-games'),
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
            onPressed: () => Navigator.of(context).pushNamed('/organize-game'),
            child: Text('go_organize_a_game'.tr()),
          ),
        ],
      ),
    );
  }
}
