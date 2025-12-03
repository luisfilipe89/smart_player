import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/features/games/models/game.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/features/games/services/games_provider.dart';
import 'package:move_young/features/games/services/cloud_games_provider.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:move_young/utils/navigation_utils.dart';
import 'package:move_young/features/games/screens/game_detail_screen.dart';
import 'dart:async';
import 'package:move_young/navigation/main_scaffold.dart';
import 'package:move_young/widgets/app_back_button.dart';
import 'package:move_young/widgets/error_retry_widget.dart';
import 'package:move_young/widgets/cached_data_indicator.dart';
import 'package:move_young/utils/logger.dart';
import 'package:move_young/features/games/notifiers/games_join_screen_notifier.dart';
import 'package:move_young/features/games/notifiers/games_join_screen_state.dart';

class GamesJoinScreen extends ConsumerStatefulWidget {
  final String? highlightGameId;
  const GamesJoinScreen({super.key, this.highlightGameId});

  @override
  ConsumerState<GamesJoinScreen> createState() => _GamesJoinScreenState();
}

class _GamesJoinScreenState extends ConsumerState<GamesJoinScreen> {
  late final TextEditingController _searchController;
  static const String _adminEmail = 'luisfccfigueiredo@gmail.com';
  final ScrollController _listController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};

  final List<String> _sports = [
    'all',
    'soccer',
    'basketball',
    'volleyball',
    'table_tennis',
    'skateboard',
    'boules'
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Load games when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenState =
          ref.read(gamesJoinScreenNotifierProvider(widget.highlightGameId));
      _searchController.text = screenState.searchQuery;
      ref
          .read(
              gamesJoinScreenNotifierProvider(widget.highlightGameId).notifier)
          .loadGames();
    });
    // Schedule scroll to highlighted game after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToHighlightedGame();
    });
    // Invited games now come from stream provider, no need to load manually
  }

  // Try a few times to ensure the list is built before scrolling
  void _scrollToHighlightedGame({int attempts = 0}) {
    final screenState =
        ref.read(gamesJoinScreenNotifierProvider(widget.highlightGameId));
    if (!mounted || screenState.highlightId == null) return;
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
              .read(gamesJoinScreenNotifierProvider(widget.highlightGameId)
                  .notifier)
              .clearHighlightId();
        }
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
    super.dispose();
  }

  // Invited games now come from stream provider - no manual loading needed

  Future<void> _joinGame(Game game) async {
    try {
      final currentUserId = ref.read(currentUserIdProvider) ?? '';
      if (currentUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('please_sign_in_to_organize'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }

      // Check if this is a rejoin (user previously left) or previously declined
      final inviteStatuses = await ref
          .read(cloudGamesActionsProvider)
          .getGameInviteStatuses(game.id);
      final String? previousStatus = inviteStatuses[currentUserId];
      final bool isRejoin = previousStatus == 'left';
      final bool wasDeclined = previousStatus == 'declined';
      final bool isPublicUninvited = !isRejoin && !wasDeclined;

      // Navigate immediately BEFORE joining to avoid transient state
      // This ensures smooth transition for all join types
      if (mounted) {
        final ctrl = MainScaffoldController.maybeOf(context);
        if (isRejoin || isPublicUninvited) {
          ctrl?.openMyGames(
            initialTab: 0, // Joining tab (index 0)
            highlightGameId: game.id,
            popToRoot: true,
          );
        }
      }

      await ref.read(cloudGamesActionsProvider).joinGame(game.id);

      ref.read(hapticsActionsProvider)?.lightImpact();
      if (mounted) {
        // Optimistically remove from lists so it disappears immediately
        ref
            .read(gamesJoinScreenNotifierProvider(widget.highlightGameId)
                .notifier)
            .removeGame(game.id);

        // Show success message
        if (isRejoin) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rejoined ${game.sport} game!'),
              backgroundColor: AppColors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (wasDeclined) {
          // User previously declined, show simple message without link
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joined ${game.sport} game!'),
              backgroundColor: AppColors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // For public uninvited games, show simple message since we already navigated
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joined ${game.sport} game!'),
              backgroundColor: AppColors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      if (mounted) {
        await ref
            .read(gamesJoinScreenNotifierProvider(widget.highlightGameId)
                .notifier)
            .loadGames(); // Refresh the list (defensive)
      }
      // Invited games will update automatically via stream provider
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join game'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelGame(Game game) async {
    final currentUserId = ref.read(currentUserIdProvider);
    final isOwner = currentUserId != null && currentUserId == game.organizerId;
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
      await ref.read(gamesActionsProvider).deleteGame(game.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('game_cancelled_successfully'.tr()),
            backgroundColor: AppColors.green,
          ),
        );
      }
      await ref
          .read(
              gamesJoinScreenNotifierProvider(widget.highlightGameId).notifier)
          .loadGames();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('game_cancellation_failed'.tr()),
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
        leadingWidth: 48,
        leading: const AppBackButton(goHome: true),
        title: Text('join_a_game'.tr()),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.white,
      body: CachedDataIndicator(
        child: SafeArea(
          child: Padding(
            padding: AppPaddings.symmHorizontalReg,
            child: _buildBrowseTab(),
          ),
        ),
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

  Widget _buildGameCard(Game game, GamesJoinScreenState screenState) {
    // Watch this specific game for real-time updates (when organizer edits)
    final gameStream = ref.watch(gameByIdProvider(game.id));
    // Watch invited games stream for real-time updates
    final invitedGamesAsync = ref.watch(invitedGamesProvider);
    // Watch invite statuses for this game in real-time (for immediate updates)
    final inviteStatusesAsync = ref.watch(gameInviteStatusesProvider(game.id));

    final invitedGames = invitedGamesAsync.valueOrNull ?? [];
    final String? myUid = ref.read(currentUserIdProvider);
    final filteredInvited = myUid == null
        ? invitedGames
        : invitedGames.where((g) => !g.players.contains(myUid)).toList();

    // Get the most up-to-date game: use the version from invitedGames stream if available
    // (it has real-time updates including cancellations), otherwise use gameById stream,
    // finally fall back to the passed parameter
    final Game? gameFromInvitedStream =
        filteredInvited.where((g) => g.id == game.id).firstOrNull;

    final Game currentGame;
    if (gameFromInvitedStream != null) {
      // Use the game from invitedGames stream (most up-to-date, includes cancellation status)
      currentGame = gameFromInvitedStream;
    } else {
      // Not an invited game, use gameById stream or fallback
      currentGame = gameStream.valueOrNull ?? game;
    }

    final bool isHighlighted = currentGame.id == screenState.highlightId;

    // Check invite status from multiple sources for immediate detection
    Map<String, String> inviteStatuses = inviteStatusesAsync.valueOrNull ?? {};
    final bool streamHasData = inviteStatusesAsync.hasValue;
    final bool invitedGamesHasData = invitedGamesAsync.hasValue;

    // Check cached invite status (populated when loading games - fastest)
    final String? cachedInviteStatus =
        screenState.gameInviteStatuses[currentGame.id];
    final bool hasCachedPendingInvite = cachedInviteStatus == 'pending';

    // Merge cached status into inviteStatuses map for immediate UI updates
    // (e.g., when user declines, we update cache immediately before stream updates)
    if (myUid != null && cachedInviteStatus != null) {
      inviteStatuses = Map<String, String>.from(inviteStatuses);
      inviteStatuses[myUid] = cachedInviteStatus;
    }

    // Check if game is in invitedGames list (this is often faster/more reliable)
    final bool isInInvitedGames =
        filteredInvited.any((g) => g.id == currentGame.id);

    // Determine if user is invited - prioritize cached status, then invitedGames list, then stream
    final String? myInviteStatus = myUid != null ? inviteStatuses[myUid] : null;
    final bool hasPendingInviteFromStatus = myInviteStatus == 'pending';

    // If we have cached status or invitedGames has data, user is definitely invited
    // Otherwise, check invite status from stream
    final bool isInvited = hasCachedPendingInvite ||
        isInInvitedGames ||
        hasPendingInviteFromStatus;

    // Only fetch if stream hasn't emitted AND we don't have cached status
    final bool needsSyncFetch =
        !streamHasData && cachedInviteStatus == null && myUid != null;

    final sportColor = _getSportColor(currentGame.sport);
    final accentColor = currentGame.isActive
        ? (isInvited ? AppColors.blue : AppColors.green)
        : AppColors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: AppHeights.superbig),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          // Rounded accent gradient on the left
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              accentColor.withValues(alpha: 0.15),
              accentColor.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.08],
          ),
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
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                    spreadRadius: 0,
                  ),
                ],
        ),
        child: InkWell(
          onTap: () {
            ref.read(hapticsActionsProvider)?.selectionClick();
            Navigator.of(context).push(
              NavigationUtils.sharedAxisRoute(
                builder: (_) => GameDetailScreen(game: game),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isInvited)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: _buildStatusBadge(
                      label: 'Invited',
                      color: AppColors.blue,
                      icon: Icons.mail,
                      showDot: false,
                    ),
                  ),
                Row(
                  children: [
                    Hero(
                      tag: 'game-${currentGame.id}-icon',
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: sportColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getSportIcon(currentGame.sport),
                          color: sportColor,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppWidths.regular),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  currentGame.sport.toUpperCase(),
                                  style: AppTextStyles.smallCardTitle.copyWith(
                                    color: _getSportColor(currentGame.sport),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Show "Cancelled" (red) badge
                              if (!currentGame.isActive)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: _buildStatusBadge(
                                    label: 'Cancelled',
                                    color: AppColors.red,
                                    icon: Icons.cancel,
                                    showDot: false,
                                  ),
                                ),
                              // Show "Modified" badge for active games that have been edited
                              if (currentGame.isActive &&
                                  currentGame.isModified)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: _buildStatusBadge(
                                    label: 'modified'.tr(),
                                    color: AppColors.blue,
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            currentGame.location,
                            style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                          Text(
                            '${currentGame.getFormattedDateLocalized((key) => key.tr())} at ${currentGame.formattedTime}',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(
                      label: currentGame.benchCount > 0
                          ? '${currentGame.maxPlayers}/${currentGame.maxPlayers} + ${currentGame.benchCount} bench'
                          : '${currentGame.currentPlayers}/${currentGame.maxPlayers}',
                      color: currentGame.hasSpace
                          ? AppColors.green
                          : AppColors.red,
                      icon: currentGame.isPublic ? Icons.lock_open : Icons.lock,
                      showDot: false,
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
                const SizedBox(height: AppHeights.reg),
                if (currentGame.description.isNotEmpty) ...[
                  Text(
                    currentGame.description,
                    style: AppTextStyles.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppHeights.reg),
                ],
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: AppColors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isInvited
                            ? 'Invited by ${currentGame.organizerName}'
                            : (ref.read(currentUserIdProvider) != null &&
                                    ref.read(currentUserIdProvider) ==
                                        currentGame.organizerId)
                                ? 'Organized by me'
                                : 'Organized by ${currentGame.organizerName}',
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppWidths.regular),
                    if (ref.read(currentUserIdProvider) != null &&
                        ref.read(currentUserIdProvider) ==
                            currentGame.organizerId)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          ref.read(hapticsActionsProvider)?.selectionClick();
                          Navigator.of(context).pushNamed(
                            '/organize-game',
                            arguments: currentGame,
                          );
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text('edit'.tr(), style: AppTextStyles.small),
                      ),
                  ],
                ),
                const SizedBox(height: AppHeights.small),
                SizedBox(
                  width: double.infinity,
                  child: needsSyncFetch
                      ? FutureBuilder<String?>(
                          future: ref
                              .read(cloudGamesActionsProvider)
                              .getUserInviteStatusForGame(currentGame.id),
                          builder: (context, snapshot) {
                            // Use isInInvitedGames as initial state to avoid showing "Join game"
                            // when user is actually invited but stream hasn't updated yet
                            if (!snapshot.hasData) {
                              // Still loading - merge cached status if available for immediate UI updates
                              // myUid is guaranteed to be non-null here due to needsSyncFetch check
                              final cachedStatus = screenState
                                  .gameInviteStatuses[currentGame.id];
                              final loadingInviteStatuses =
                                  Map<String, String>.from(inviteStatuses);
                              if (cachedStatus != null) {
                                // myUid is non-null because needsSyncFetch requires it
                                loadingInviteStatuses[myUid] = cachedStatus;
                              }
                              return _buildGameActions(
                                currentGame,
                                inviteStatuses: loadingInviteStatuses,
                                isInvitedPending: isInInvitedGames,
                                streamHasData: false,
                              );
                            }
                            // Check user's invite status directly from their gameInvites path
                            final userInviteStatus = snapshot.data;
                            final cachedStatus =
                                screenState.gameInviteStatuses[currentGame.id];
                            final syncIsInvited =
                                (userInviteStatus == 'pending') ||
                                    isInInvitedGames ||
                                    (cachedStatus == 'pending');

                            // Update cached status and inviteStatuses map with the fetched status
                            // Note: This is handled by the notifier when loading games
                            // We can't update it here directly, but the stream will update

                            // myUid is guaranteed to be non-null here due to needsSyncFetch check
                            final updatedInviteStatuses =
                                Map<String, String>.from(inviteStatuses);
                            if (userInviteStatus != null) {
                              updatedInviteStatuses[myUid] = userInviteStatus;
                            }

                            return _buildGameActions(
                              currentGame,
                              inviteStatuses: updatedInviteStatuses,
                              isInvitedPending: syncIsInvited,
                              streamHasData: true,
                            );
                          },
                        )
                      : _buildGameActions(
                          currentGame,
                          inviteStatuses: inviteStatuses,
                          isInvitedPending: isInvited,
                          streamHasData: streamHasData || invitedGamesHasData,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameActions(
    Game game, {
    Map<String, String>? inviteStatuses,
    bool? isInvitedPending,
    bool streamHasData = false,
  }) {
    final currentUserId = ref.read(currentUserIdProvider);
    final isOwnerOrAdmin = currentUserId != null &&
        (currentUserId == game.organizerId ||
            (ref.read(currentUserProvider).valueOrNull?.email?.toLowerCase() ==
                _adminEmail));

    // If the game was cancelled, show a disabled red indicator
    if (!game.isActive) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red.withValues(alpha: 0.2),
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Text(
          'Cancelled',
          style: AppTextStyles.cardTitle.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (isOwnerOrAdmin) {
      return ElevatedButton(
        onPressed: () => _cancelGame(game),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: AppTextStyles.small.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Text(
          'cancel_game'.tr(),
        ),
      );
    }

    final String? myUid = ref.read(currentUserIdProvider);
    final bool isJoined = myUid != null && game.players.contains(myUid);

    // Use passed invite statuses if available, otherwise watch the provider
    // If stream hasn't emitted yet and we don't have passed data, fetch synchronously
    Map<String, String> finalInviteStatuses;
    if (inviteStatuses != null && inviteStatuses.isNotEmpty) {
      finalInviteStatuses = inviteStatuses;
    } else if (streamHasData) {
      // Stream has data, use it
      finalInviteStatuses =
          ref.watch(gameInviteStatusesProvider(game.id)).valueOrNull ?? {};
    } else {
      // Stream hasn't emitted yet, use empty map and rely on isInvitedPending flag
      finalInviteStatuses = {};
    }

    // Use passed isInvitedPending if available, otherwise check from streams
    bool finalIsInvitedPending;
    if (isInvitedPending != null) {
      finalIsInvitedPending = isInvitedPending;
    } else {
      // Fallback: check from streams
      final String? myInviteStatus =
          myUid != null ? finalInviteStatuses[myUid] : null;
      final bool hasPendingInvite = myInviteStatus == 'pending';

      final invitedGamesAsync = ref.watch(invitedGamesProvider);
      final invitedGames = invitedGamesAsync.valueOrNull ?? [];
      final filteredInvited = myUid == null
          ? invitedGames
          : invitedGames.where((g) => !g.players.contains(myUid)).toList();
      final bool isInInvitedGames = filteredInvited.any((g) => g.id == game.id);

      finalIsInvitedPending = hasPendingInvite || isInInvitedGames;
    }

    // Check if user previously left this game (for rejoin option)
    final bool hasLeftGame =
        myUid != null && finalInviteStatuses[myUid] == 'left';

    // Check if user previously declined this invite (for join option)
    final bool hasDeclinedInvite =
        myUid != null && finalInviteStatuses[myUid] == 'declined';

    NumberedLogger.d(
        'Game ${game.id}: isInvitedPending=$finalIsInvitedPending, isJoined=$isJoined, hasLeftGame=$hasLeftGame, hasDeclinedInvite=$hasDeclinedInvite');

    if (finalIsInvitedPending && !isJoined) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                // Navigate immediately BEFORE accepting to avoid transient state
                final ctrl = MainScaffoldController.maybeOf(context);
                ctrl?.openMyGames(
                  initialTab: 0, // Joining tab (index 0)
                  highlightGameId: game.id,
                  popToRoot: true,
                );

                try {
                  await ref
                      .read(cloudGamesActionsProvider)
                      .acceptGameInvite(game.id);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Joined ${game.sport} game!'),
                        backgroundColor: AppColors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to join: $e'),
                        backgroundColor: AppColors.red,
                      ),
                    );
                  }
                }
                if (mounted) {
                  await ref
                      .read(gamesJoinScreenNotifierProvider(
                              widget.highlightGameId)
                          .notifier)
                      .loadGames();
                  // Invited games will update automatically via stream provider
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: AppTextStyles.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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
                try {
                  await ref
                      .read(cloudGamesActionsProvider)
                      .declineGameInvite(game.id);
                  if (mounted) {
                    // Update cached invite status immediately for instant UI update
                    // Note: The invite status will be updated when games are reloaded
                    // For now, we'll reload games to get the updated status
                    ref
                        .read(gamesJoinScreenNotifierProvider(
                                widget.highlightGameId)
                            .notifier)
                        .loadGames();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('declined'.tr()),
                        backgroundColor: AppColors.grey,
                      ),
                    );
                  }
                } catch (e) {
                  // Silent fail
                }
                // Invited games will update automatically via stream provider
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red, width: 1.5),
                minimumSize: const Size(0, 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: AppTextStyles.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('decline'.tr()),
            ),
          ),
        ],
      );
    }

    if (isJoined) {
      return ElevatedButton(
        onPressed: () async {
          try {
            await ref.read(cloudGamesActionsProvider).leaveGame(game.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('You left the game'),
                  backgroundColor: AppColors.grey,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to leave'),
                  backgroundColor: AppColors.red,
                ),
              );
            }
          }
          if (mounted) {
            await ref
                .read(gamesJoinScreenNotifierProvider(widget.highlightGameId)
                    .notifier)
                .loadGames();
          }
          // Invited games will update automatically via stream provider
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: AppTextStyles.small.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Text('leave_game'.tr()),
      );
    }

    // Show "Rejoin" button if user previously left this game
    if (hasLeftGame) {
      return ElevatedButton(
        onPressed: game.hasSpace ? () => _joinGame(game) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: game.hasSpace ? Colors.orange : AppColors.grey,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: AppTextStyles.small.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Text(
          game.hasSpace ? 'rejoin_game'.tr() : 'game_full'.tr(),
        ),
      );
    }

    // Show "You declined" message with join button if user previously declined this invite
    if (hasDeclinedInvite && !isJoined) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.smallCard),
              border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close, size: 16, color: AppColors.red),
                const SizedBox(width: 6),
                Text(
                  'You declined the invite',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: game.hasSpace ? () => _joinGame(game) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: game.hasSpace ? AppColors.blue : AppColors.grey,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: AppTextStyles.small.copyWith(
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              game.hasSpace ? 'join_game'.tr() : 'game_full'.tr(),
            ),
          ),
        ],
      );
    }

    // Only show "Join game" button if the game is public and user is not invited
    // Private games require an invitation
    if (!game.isPublic && !finalIsInvitedPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.lightgrey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: AppColors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 16, color: AppColors.grey),
            const SizedBox(width: 8),
            Text(
              'Private game - invitation only',
              style: AppTextStyles.small.copyWith(
                color: AppColors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton(
      onPressed: game.hasSpace ? () => _joinGame(game) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: game.hasSpace ? AppColors.blue : AppColors.grey,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: AppTextStyles.small.copyWith(
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 0,
      ),
      child: Text(
        game.hasSpace ? 'join_game'.tr() : 'game_full'.tr(),
      ),
    );
  }

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
                                  suffixIcon: Consumer(
                                    builder: (context, ref, child) {
                                      final screenState = ref.watch(
                                          gamesJoinScreenNotifierProvider(
                                              widget.highlightGameId));
                                      if (screenState.searchQuery.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          ref
                                              .read(
                                                  gamesJoinScreenNotifierProvider(
                                                          widget
                                                              .highlightGameId)
                                                      .notifier)
                                              .setSearchQuery('');
                                        },
                                      );
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.image),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (value) {
                                  ref
                                      .read(gamesJoinScreenNotifierProvider(
                                              widget.highlightGameId)
                                          .notifier)
                                      .setSearchQuery(value);
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
                              final screenState = ref.watch(
                                  gamesJoinScreenNotifierProvider(
                                      widget.highlightGameId));
                              final isSelected =
                                  screenState.selectedSport == sport;
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
                                    ref
                                        .read(gamesJoinScreenNotifierProvider(
                                                widget.highlightGameId)
                                            .notifier)
                                        .setSelectedSport(sport);
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
                      child: Builder(builder: (context) {
                        final screenState = ref.watch(
                            gamesJoinScreenNotifierProvider(
                                widget.highlightGameId));
                        final invitedGamesAsync =
                            ref.watch(invitedGamesProvider);
                        final invitedGames =
                            invitedGamesAsync.valueOrNull ?? [];
                        final String? myUid = ref.read(currentUserIdProvider);
                        final filteredInvited = myUid == null
                            ? invitedGames
                            : invitedGames
                                .where((g) => !g.players.contains(myUid))
                                .toList();

                        return screenState.isLoading
                            ? const _GamesSkeleton()
                            : screenState.hasError
                                ? ErrorRetryWidget(
                                    message: screenState.errorMessage ??
                                        'loading_error'.tr(),
                                    onRetry: () => ref
                                        .read(gamesJoinScreenNotifierProvider(
                                                widget.highlightGameId)
                                            .notifier)
                                        .loadGames(),
                                    icon: Icons.error_outline,
                                  )
                                : (screenState.games.isEmpty &&
                                        filteredInvited.isEmpty)
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.sports_soccer,
                                                size: 64,
                                                color: AppColors.grey),
                                            const SizedBox(
                                                height: AppHeights.reg),
                                            Text(
                                              'no_games_found'.tr(),
                                              style:
                                                  AppTextStyles.title.copyWith(
                                                color: AppColors.grey,
                                              ),
                                            ),
                                            const SizedBox(
                                                height: AppHeights.small),
                                            Text(
                                              'no_games_found_description'.tr(),
                                              style:
                                                  AppTextStyles.body.copyWith(
                                                color: AppColors.grey,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      )
                                    : RefreshIndicator(
                                        onRefresh: () async {
                                          await ref
                                              .read(
                                                  gamesJoinScreenNotifierProvider(
                                                          widget
                                                              .highlightGameId)
                                                      .notifier)
                                              .loadGames();
                                          // Invited games will update automatically via stream provider
                                        },
                                        child: Builder(builder: (context) {
                                          final currentState = ref.watch(
                                              gamesJoinScreenNotifierProvider(
                                                  widget.highlightGameId));
                                          // Merge lists with invited first, then sort non-invited games chronologically
                                          final List<Game> nonInvited =
                                              currentState
                                                  .games
                                                  .where((g) => !filteredInvited
                                                      .any((i) => i.id == g.id))
                                                  .toList();
                                          // Sort non-invited games by date (earliest first)
                                          nonInvited.sort((a, b) =>
                                              a.dateTime.compareTo(b.dateTime));
                                          final List<Game> merged = [
                                            ...filteredInvited,
                                            ...nonInvited,
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
                                                child: _buildGameCard(
                                                    game, currentState),
                                              );
                                            },
                                          );
                                        }),
                                      );
                      }),
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

class _GamesSkeleton extends StatelessWidget {
  const _GamesSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: AppHeights.reg),
      itemBuilder: (context, index) {
        return Container(
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.superlightgrey,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        );
      },
    );
  }
}
