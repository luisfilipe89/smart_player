import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/features/matches/models/match.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/features/matches/services/match_provider.dart';
import 'package:move_young/features/matches/services/cloud_matches_provider.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:move_young/utils/navigation_utils.dart';
import 'package:move_young/features/matches/screens/match_detail_screen.dart';
import 'dart:async';
import 'package:move_young/navigation/main_scaffold.dart';
import 'package:move_young/widgets/app_back_button.dart';
import 'package:move_young/widgets/error_retry_widget.dart';
import 'package:move_young/widgets/cached_data_indicator.dart';
import 'package:move_young/utils/logger.dart';
import 'package:move_young/features/matches/notifiers/match_join_screen_notifier.dart';
import 'package:move_young/features/matches/notifiers/match_join_screen_state.dart';
import 'package:move_young/utils/snackbar_helper.dart';

class MatchesJoinScreen extends ConsumerStatefulWidget {
  final String? highlightMatchId;
  const MatchesJoinScreen({super.key, this.highlightMatchId});

  @override
  ConsumerState<MatchesJoinScreen> createState() => _MatchesJoinScreenState();
}

class _MatchesJoinScreenState extends ConsumerState<MatchesJoinScreen> {
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
    // Load matches when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenState =
          ref.read(matchesJoinScreenNotifierProvider(widget.highlightMatchId));
      _searchController.text = screenState.searchQuery;
      ref
          .read(matchesJoinScreenNotifierProvider(widget.highlightMatchId)
              .notifier)
          .loadMatches();
    });
    // Schedule scroll to highlighted match after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToHighlightedMatch();
    });
    // Invited matches now come from stream provider, no need to load manually
  }

  // Try a few times to ensure the list is built before scrolling
  void _scrollToHighlightedMatch({int attempts = 0}) {
    final screenState =
        ref.read(matchesJoinScreenNotifierProvider(widget.highlightMatchId));
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
              .read(matchesJoinScreenNotifierProvider(widget.highlightMatchId)
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

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  // Invited matches now come from stream provider - no manual loading needed

  Future<void> _joinMatch(Match match) async {
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
          .read(cloudMatchesActionsProvider)
          .getMatchInviteStatuses(match.id);
      final String? previousStatus = inviteStatuses[currentUserId];
      final bool isRejoin = previousStatus == 'left';
      final bool wasDeclined = previousStatus == 'declined';
      final bool isPublicUninvited = !isRejoin && !wasDeclined;

      // Navigate immediately BEFORE joining to avoid transient state
      // This ensures smooth transition for all join types
      if (mounted) {
        final ctrl = MainScaffoldController.maybeOf(context);
        if (isRejoin || isPublicUninvited) {
          ctrl?.openMyMatches(
            initialTab: 0, // Joining tab (index 0)
            highlightMatchId: match.id,
            popToRoot: true,
          );
        }
      }

      await ref.read(cloudMatchesActionsProvider).joinMatch(match.id);

      ref.read(hapticsActionsProvider)?.lightImpact();
      if (mounted) {
        // Optimistically remove from lists so it disappears immediately
        ref
            .read(matchesJoinScreenNotifierProvider(widget.highlightMatchId)
                .notifier)
            .removeMatch(match.id);

        // Show success message
        if (isRejoin) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rejoined ${match.sport} match!'),
              backgroundColor: AppColors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (wasDeclined) {
          // User previously declined, show simple message without link
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joined ${match.sport} match!'),
              backgroundColor: AppColors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // For public uninvited matches, show simple message since we already navigated
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joined ${match.sport} match!'),
              backgroundColor: AppColors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      if (mounted) {
        await ref
            .read(matchesJoinScreenNotifierProvider(widget.highlightMatchId)
                .notifier)
            .loadMatches(); // Refresh the list (defensive)
      }
      // Invited matches will update automatically via stream provider
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Failed to join match';
        final es = e.toString();
        final isUserBusy = es.contains('user_already_busy');

        if (isUserBusy) {
          errorMsg = 'user_already_busy'.tr();
          SnackBarHelper.showBlocked(context, errorMsg);
          ref.read(hapticsActionsProvider)?.mediumImpact();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelMatch(Match match) async {
    final currentUserId = ref.read(currentUserIdProvider);
    final isOwner = currentUserId != null && currentUserId == match.organizerId;
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
      await ref.read(matchesActionsProvider).deleteMatch(match.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('match_cancelled_successfully'.tr()),
            backgroundColor: AppColors.green,
          ),
        );
      }
      await ref
          .read(matchesJoinScreenNotifierProvider(widget.highlightMatchId)
              .notifier)
          .loadMatches();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('match_cancellation_failed'.tr()),
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
        title: Text('join_a_match'.tr()),
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

  Widget _buildMatchCard(Match match, MatchesJoinScreenState screenState) {
    // Watch this specific match for real-time updates (when organizer edits)
    final matchStream = ref.watch(matchByIdProvider(match.id));
    // Watch invited matches stream for real-time updates
    final invitedMatchesAsync = ref.watch(invitedMatchesProvider);
    // Watch invite statuses for this match in real-time (for immediate updates)
    final inviteStatusesAsync =
        ref.watch(matchInviteStatusesProvider(match.id));

    final invitedMatches = invitedMatchesAsync.valueOrNull ?? [];
    final String? myUid = ref.read(currentUserIdProvider);
    final filteredInvited = myUid == null
        ? invitedMatches
        : invitedMatches.where((g) => !g.players.contains(myUid)).toList();

    // Get the most up-to-date match: use the version from invitedMatches stream if available
    // (it has real-time updates including cancellations), otherwise use matchById stream,
    // finally fall back to the passed parameter
    final Match? matchFromInvitedStream =
        filteredInvited.where((g) => g.id == match.id).firstOrNull;

    final Match currentMatch;
    if (matchFromInvitedStream != null) {
      // Use the match from invitedMatches stream (most up-to-date, includes cancellation status)
      currentMatch = matchFromInvitedStream;
    } else {
      // Not an invited match, use matchById stream or fallback
      currentMatch = matchStream.valueOrNull ?? match;
    }

    final bool isHighlighted = currentMatch.id == screenState.highlightId;

    // Check invite status from multiple sources for immediate detection
    Map<String, String> inviteStatuses = inviteStatusesAsync.valueOrNull ?? {};
    final bool streamHasData = inviteStatusesAsync.hasValue;
    final bool invitedMatchesHasData = invitedMatchesAsync.hasValue;

    // Check cached invite status (populated when loading matches - fastest)
    final String? cachedInviteStatus =
        screenState.matchInviteStatuses[currentMatch.id];
    final bool hasCachedPendingInvite = cachedInviteStatus == 'pending';

    // Merge cached status into inviteStatuses map for immediate UI updates
    // (e.g., when user declines, we update cache immediately before stream updates)
    if (myUid != null && cachedInviteStatus != null) {
      inviteStatuses = Map<String, String>.from(inviteStatuses);
      inviteStatuses[myUid] = cachedInviteStatus;
    }

    // Check if match is in invitedMatches list (this is often faster/more reliable)
    final bool isInInvitedMatches =
        filteredInvited.any((g) => g.id == currentMatch.id);

    // Determine if user is invited - prioritize cached status, then invitedMatches list, then stream
    final String? myInviteStatus = myUid != null ? inviteStatuses[myUid] : null;
    final bool hasPendingInviteFromStatus = myInviteStatus == 'pending';

    // If we have cached status or invitedMatches has data, user is definitely invited
    // Otherwise, check invite status from stream
    final bool isInvited = hasCachedPendingInvite ||
        isInInvitedMatches ||
        hasPendingInviteFromStatus;

    // Only fetch if stream hasn't emitted AND we don't have cached status
    final bool needsSyncFetch =
        !streamHasData && cachedInviteStatus == null && myUid != null;

    final sportColor = _getSportColor(currentMatch.sport);
    final accentColor = currentMatch.isActive
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
                builder: (_) => MatchDetailScreen(match: match),
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
                      tag: 'match-${currentMatch.id}-icon',
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: sportColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getSportIcon(currentMatch.sport),
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
                                  currentMatch.sport.toUpperCase(),
                                  style: AppTextStyles.smallCardTitle.copyWith(
                                    color: _getSportColor(currentMatch.sport),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Show "Cancelled" (red) badge
                              if (!currentMatch.isActive)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: _buildStatusBadge(
                                    label: 'Cancelled',
                                    color: AppColors.red,
                                    icon: Icons.cancel,
                                    showDot: false,
                                  ),
                                ),
                              // Show "Modified" badge for active matches that have been edited
                              if (currentMatch.isActive &&
                                  currentMatch.isModified)
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
                            currentMatch.location,
                            style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${currentMatch.getFormattedDateLocalized((key) => key.tr())} at ${currentMatch.formattedTime}',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(
                      label: currentMatch.benchCount > 0
                          ? '${currentMatch.maxPlayers}/${currentMatch.maxPlayers} + ${currentMatch.benchCount} bench'
                          : '${currentMatch.currentPlayers}/${currentMatch.maxPlayers}',
                      color: currentMatch.hasSpace
                          ? AppColors.green
                          : AppColors.red,
                      icon:
                          currentMatch.isPublic ? Icons.lock_open : Icons.lock,
                      showDot: false,
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
                const SizedBox(height: AppHeights.reg),
                if (currentMatch.description.isNotEmpty) ...[
                  Text(
                    currentMatch.description,
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
                            ? 'Invited by ${currentMatch.organizerName}'
                            : (ref.read(currentUserIdProvider) != null &&
                                    ref.read(currentUserIdProvider) ==
                                        currentMatch.organizerId)
                                ? 'Organized by me'
                                : 'Organized by ${currentMatch.organizerName}',
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppWidths.regular),
                    if (ref.read(currentUserIdProvider) != null &&
                        ref.read(currentUserIdProvider) ==
                            currentMatch.organizerId)
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
                            '/organize-match',
                            arguments: currentMatch,
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
                              .read(cloudMatchesActionsProvider)
                              .getUserInviteStatusForMatch(currentMatch.id),
                          builder: (context, snapshot) {
                            // Use isInInvitedMatches as initial state to avoid showing "Join match"
                            // when user is actually invited but stream hasn't updated yet
                            if (!snapshot.hasData) {
                              // Still loading - merge cached status if available for immediate UI updates
                              // myUid is guaranteed to be non-null here due to needsSyncFetch check
                              final cachedStatus = screenState
                                  .matchInviteStatuses[currentMatch.id];
                              final loadingInviteStatuses =
                                  Map<String, String>.from(inviteStatuses);
                              if (cachedStatus != null) {
                                // myUid is non-null because needsSyncFetch requires it
                                loadingInviteStatuses[myUid] = cachedStatus;
                              }
                              return _buildMatchActions(
                                currentMatch,
                                inviteStatuses: loadingInviteStatuses,
                                isInvitedPending: isInInvitedMatches,
                                streamHasData: false,
                              );
                            }
                            // Check user's invite status directly from their matchInvites path
                            final userInviteStatus = snapshot.data;
                            final cachedStatus = screenState
                                .matchInviteStatuses[currentMatch.id];
                            final syncIsInvited =
                                (userInviteStatus == 'pending') ||
                                    isInInvitedMatches ||
                                    (cachedStatus == 'pending');

                            // Update cached status and inviteStatuses map with the fetched status
                            // Note: This is handled by the notifier when loading matches
                            // We can't update it here directly, but the stream will update

                            // myUid is guaranteed to be non-null here due to needsSyncFetch check
                            final updatedInviteStatuses =
                                Map<String, String>.from(inviteStatuses);
                            if (userInviteStatus != null) {
                              updatedInviteStatuses[myUid] = userInviteStatus;
                            }

                            return _buildMatchActions(
                              currentMatch,
                              inviteStatuses: updatedInviteStatuses,
                              isInvitedPending: syncIsInvited,
                              streamHasData: true,
                            );
                          },
                        )
                      : _buildMatchActions(
                          currentMatch,
                          inviteStatuses: inviteStatuses,
                          isInvitedPending: isInvited,
                          streamHasData: streamHasData || invitedMatchesHasData,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchActions(
    Match match, {
    Map<String, String>? inviteStatuses,
    bool? isInvitedPending,
    bool streamHasData = false,
  }) {
    final currentUserId = ref.read(currentUserIdProvider);
    final isOwnerOrAdmin = currentUserId != null &&
        (currentUserId == match.organizerId ||
            (ref.read(currentUserProvider).valueOrNull?.email?.toLowerCase() ==
                _adminEmail));

    // If the match was cancelled, show a disabled red indicator
    if (!match.isActive) {
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
        onPressed: () => _cancelMatch(match),
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
          'cancel_match'.tr(),
        ),
      );
    }

    final String? myUid = ref.read(currentUserIdProvider);
    final bool isJoined = myUid != null && match.players.contains(myUid);

    // Use passed invite statuses if available, otherwise watch the provider
    // If stream hasn't emitted yet and we don't have passed data, fetch synchronously
    Map<String, String> finalInviteStatuses;
    if (inviteStatuses != null && inviteStatuses.isNotEmpty) {
      finalInviteStatuses = inviteStatuses;
    } else if (streamHasData) {
      // Stream has data, use it
      finalInviteStatuses =
          ref.watch(matchInviteStatusesProvider(match.id)).valueOrNull ?? {};
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

      final invitedMatchesAsync = ref.watch(invitedMatchesProvider);
      final invitedMatches = invitedMatchesAsync.valueOrNull ?? [];
      final filteredInvited = myUid == null
          ? invitedMatches
          : invitedMatches.where((g) => !g.players.contains(myUid)).toList();
      final bool isInInvitedMatches =
          filteredInvited.any((g) => g.id == match.id);

      finalIsInvitedPending = hasPendingInvite || isInInvitedMatches;
    }

    // Check if user previously left this match (for rejoin option)
    final bool hasLeftMatch =
        myUid != null && finalInviteStatuses[myUid] == 'left';

    // Check if user previously declined this invite (for join option)
    final bool hasDeclinedInvite =
        myUid != null && finalInviteStatuses[myUid] == 'declined';

    NumberedLogger.d(
        'Match ${match.id}: isInvitedPending=$finalIsInvitedPending, isJoined=$isJoined, hasLeftMatch=$hasLeftMatch, hasDeclinedInvite=$hasDeclinedInvite');

    if (finalIsInvitedPending && !isJoined) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                // Navigate immediately BEFORE accepting to avoid transient state
                final ctrl = MainScaffoldController.maybeOf(context);
                ctrl?.openMyMatches(
                  initialTab: 0, // Joining tab (index 0)
                  highlightMatchId: match.id,
                  popToRoot: true,
                );

                try {
                  await ref
                      .read(cloudMatchesActionsProvider)
                      .acceptMatchInvite(match.id);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Joined ${match.sport} match!'),
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
                      .read(matchesJoinScreenNotifierProvider(
                              widget.highlightMatchId)
                          .notifier)
                      .loadMatches();
                  // Invited matches will update automatically via stream provider
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
                      .read(cloudMatchesActionsProvider)
                      .declineMatchInvite(match.id);
                  if (mounted) {
                    // Update cached invite status immediately for instant UI update
                    // Note: The invite status will be updated when matches are reloaded
                    // For now, we'll reload matches to get the updated status
                    ref
                        .read(matchesJoinScreenNotifierProvider(
                                widget.highlightMatchId)
                            .notifier)
                        .loadMatches();
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
                // Invited matches will update automatically via stream provider
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
            await ref.read(cloudMatchesActionsProvider).leaveMatch(match.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('You left the match'),
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
                .read(matchesJoinScreenNotifierProvider(widget.highlightMatchId)
                    .notifier)
                .loadMatches();
          }
          // Invited matches will update automatically via stream provider
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
        child: Text('leave_match'.tr()),
      );
    }

    // Show "Rejoin" button if user previously left this match
    if (hasLeftMatch) {
      return ElevatedButton(
        onPressed: match.hasSpace ? () => _joinMatch(match) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: match.hasSpace ? Colors.orange : AppColors.grey,
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
          match.hasSpace ? 'rejoin_match'.tr() : 'match_full'.tr(),
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
            onPressed: match.hasSpace ? () => _joinMatch(match) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: match.hasSpace ? AppColors.blue : AppColors.grey,
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
              match.hasSpace ? 'join_match'.tr() : 'match_full'.tr(),
            ),
          ),
        ],
      );
    }

    // Only show "Join match" button if the match is public and user is not invited
    // Private matches require an invitation
    if (!match.isPublic && !finalIsInvitedPending) {
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
              'Private match - invitation only',
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
      onPressed: match.hasSpace ? () => _joinMatch(match) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: match.hasSpace ? AppColors.blue : AppColors.grey,
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
        match.hasSpace ? 'join_match'.tr() : 'match_full'.tr(),
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
                  PanelHeader('find_matches'.tr()),
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
                                  hintText: 'search_matches'.tr(),
                                  filled: true,
                                  fillColor: AppColors.lightgrey,
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: Consumer(
                                    builder: (context, ref, child) {
                                      final screenState = ref.watch(
                                          matchesJoinScreenNotifierProvider(
                                              widget.highlightMatchId));
                                      if (screenState.searchQuery.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          ref
                                              .read(
                                                  matchesJoinScreenNotifierProvider(
                                                          widget
                                                              .highlightMatchId)
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
                                      .read(matchesJoinScreenNotifierProvider(
                                              widget.highlightMatchId)
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
                                  matchesJoinScreenNotifierProvider(
                                      widget.highlightMatchId));
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
                                        .read(matchesJoinScreenNotifierProvider(
                                                widget.highlightMatchId)
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
                            matchesJoinScreenNotifierProvider(
                                widget.highlightMatchId));
                        final invitedMatchesAsync =
                            ref.watch(invitedMatchesProvider);
                        final invitedMatches =
                            invitedMatchesAsync.valueOrNull ?? [];
                        final String? myUid = ref.read(currentUserIdProvider);
                        final filteredInvited = myUid == null
                            ? invitedMatches
                            : invitedMatches
                                .where((g) => !g.players.contains(myUid))
                                .toList();

                        return screenState.isLoading
                            ? const _MatchesSkeleton()
                            : screenState.hasError
                                ? ErrorRetryWidget(
                                    message: screenState.errorMessage ??
                                        'loading_error'.tr(),
                                    onRetry: () => ref
                                        .read(matchesJoinScreenNotifierProvider(
                                                widget.highlightMatchId)
                                            .notifier)
                                        .loadMatches(),
                                    icon: Icons.error_outline,
                                  )
                                : (screenState.matches.isEmpty &&
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
                                              'no_matches_found'.tr(),
                                              style:
                                                  AppTextStyles.title.copyWith(
                                                color: AppColors.grey,
                                              ),
                                            ),
                                            const SizedBox(
                                                height: AppHeights.small),
                                            Text(
                                              'no_matches_found_description'
                                                  .tr(),
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
                                                  matchesJoinScreenNotifierProvider(
                                                          widget
                                                              .highlightMatchId)
                                                      .notifier)
                                              .loadMatches();
                                          // Invited matches will update automatically via stream provider
                                        },
                                        child: Builder(builder: (context) {
                                          final currentState = ref.watch(
                                              matchesJoinScreenNotifierProvider(
                                                  widget.highlightMatchId));
                                          // Merge lists with invited first, then sort non-invited matches chronologically
                                          final List<Match> nonInvited =
                                              currentState.matches
                                                  .where((g) => !filteredInvited
                                                      .any((i) => i.id == g.id))
                                                  .toList();
                                          // Sort non-invited matches by date (earliest first)
                                          nonInvited.sort((a, b) =>
                                              a.dateTime.compareTo(b.dateTime));
                                          final List<Match> merged = [
                                            ...filteredInvited,
                                            ...nonInvited,
                                          ];
                                          return ListView.builder(
                                            controller: _listController,
                                            padding: EdgeInsets.zero,
                                            itemCount: merged.length,
                                            itemBuilder: (context, index) {
                                              final match = merged[index];
                                              final key = _itemKeys.putIfAbsent(
                                                  match.id, () => GlobalKey());
                                              return KeyedSubtree(
                                                key: key,
                                                child: _buildMatchCard(
                                                    match, currentState),
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
}

class _MatchesSkeleton extends StatelessWidget {
  const _MatchesSkeleton();
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
