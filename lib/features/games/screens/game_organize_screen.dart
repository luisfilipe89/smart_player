import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:move_young/features/games/models/game.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/features/games/services/games_provider.dart';
import 'package:move_young/features/games/services/cloud_games_provider.dart';
import 'package:move_young/services/external/weather_provider.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:move_young/features/friends/services/friends_provider.dart';
import 'package:move_young/navigation/main_scaffold.dart';
import 'package:move_young/widgets/success_checkmark_overlay.dart';
import 'package:move_young/features/maps/screens/gmaps_screen.dart';
import 'package:move_young/services/calendar/calendar_service.dart';
import 'package:move_young/widgets/app_back_button.dart';
import 'package:move_young/utils/time_slot_utils.dart';
import 'package:move_young/features/games/services/game_form_validator.dart';
import 'package:move_young/utils/snackbar_helper.dart';
import 'package:move_young/utils/type_converters.dart';
import 'package:move_young/utils/geolocation_utils.dart';
import 'package:move_young/utils/logger.dart';
import 'package:move_young/features/games/notifiers/game_form_notifier.dart';
import 'package:move_young/features/games/notifiers/game_form_state.dart';
import 'package:move_young/features/games/widgets/game_form_sport_selector.dart';
import 'package:move_young/features/games/widgets/game_form_max_players_slider.dart';
import 'package:move_young/features/games/widgets/game_form_date_selector.dart';

class GameOrganizeScreen extends ConsumerStatefulWidget {
  final Game? initialGame;
  const GameOrganizeScreen({super.key, this.initialGame});

  @override
  ConsumerState<GameOrganizeScreen> createState() => _GameOrganizeScreenState();
}

class _GameOrganizeScreenState extends ConsumerState<GameOrganizeScreen> {
  // Scroll controller for auto-scrolling
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _createGameButtonKey = GlobalKey();

  // Search for fields (still local for TextEditingController)
  final TextEditingController _fieldSearchController = TextEditingController();

  // Track if we've reset the form for new game creation
  bool _hasResetForNewGame = false;

  void _showSignInInlinePrompt() {
    if (!mounted) return;
    SnackBarHelper.showError(context, 'please_sign_in');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset form state when creating a new game (initialGame is null)
    // This ensures we don't show leftover state from previous game creation
    if (widget.initialGame == null && !_hasResetForNewGame) {
      _hasResetForNewGame = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final notifier = ref.read(gameFormNotifierProvider(null).notifier);
          final currentState = ref.read(gameFormNotifierProvider(null));
          // Always reset if there's any leftover state (especially showSuccess)
          if (currentState.showSuccess ||
              currentState.sport != null ||
              currentState.date != null ||
              currentState.time != null ||
              currentState.field != null) {
            // Reset to initial state - this clears success overlay and all form data
            notifier.reset();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fieldSearchController.dispose();
    super.dispose();
  }

  // Get form state and notifier from provider
  GameFormState get _formState =>
      ref.watch(gameFormNotifierProvider(widget.initialGame));
  GameFormNotifier get _formNotifier =>
      ref.read(gameFormNotifierProvider(widget.initialGame).notifier);

  // Auto-scroll to Create Game button
  void _scrollToCreateGameButton() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_createGameButtonKey.currentContext != null) {
        Scrollable.ensureVisible(
          _createGameButtonKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1, // Show button near the top of the screen
        );
      }
    });
  }

  // Sports and dates are now in extracted widgets

  List<String> get _availableTimes {
    final now = DateTime.now();
    // Only 1-hour slots on the hour for simplicity
    final allTimes = [
      '09:00',
      '10:00',
      '11:00',
      '12:00',
      '13:00',
      '14:00',
      '15:00',
      '16:00',
      '17:00',
      '18:00',
      '19:00',
      '20:00',
      '21:00',
    ];

    // If no date is selected, return all times
    if (_formState.date == null) return allTimes;

    // Check if selected date is today
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(
      _formState.date!.year,
      _formState.date!.month,
      _formState.date!.day,
    );

    if (selectedDate == today) {
      // Filter out past times for today
      return allTimes.where((time) {
        return isTimeInFuture(time, now);
      }).toList();
    }

    // For future dates, return all times
    return allTimes;
  }

  // Check if a time slot conflicts with any booked time (considering 1-hour duration)
  // Uses shared utility for consistency
  bool _isTimeSlotBooked(String time, Set<String> bookedTimes) {
    return isTimeSlotBooked(time, bookedTimes);
  }

  // Use computed properties from state
  bool get _isFormComplete => _formState.isFormComplete;
  bool get _isCreatingSimilarGame => _formState.isCreatingSimilarGame;
  bool get _hasChanges => _formState.hasChanges;

  void _onFieldSearchChanged(String query) {
    _fieldSearchController.text = query;
    _formNotifier.updateFieldSearch(query);
  }

  // Field and weather loading are now handled by GameFormNotifier
  // Methods removed: _loadFields(), _updateFieldDistances(), _loadWeather()

  Future<void> _updateGame() async {
    // Safety check: don't update historic games (should create new game instead)
    if (_isCreatingSimilarGame) {
      // This shouldn't happen, but if it does, redirect to create
      await _createGame();
      return;
    }

    // If no changes in edit mode, show info and exit early
    if (widget.initialGame != null && !_hasChanges) {
      if (mounted) {
        SnackBarHelper.showInfo(context, 'No changes were made');
      }
      return;
    }
    // Validate required fields
    final requiredFieldsResult = GameFormValidator.validateRequiredFields(
      sport: _formState.sport,
      field: _formState.field,
      date: _formState.date,
      time: _formState.time,
    );
    if (!requiredFieldsResult.isValid) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          requiredFieldsResult.errorMessage ?? 'form_fill_all_fields',
        );
      }
      return;
    }

    if (widget.initialGame == null) {
      if (mounted) {
        SnackBarHelper.showError(context, 'form_fill_all_fields');
      }
      return;
    }

    // Validate future date/time
    final futureDateTimeResult = GameFormValidator.validateFutureDateTime(
      date: _formState.date,
      time: _formState.time,
    );
    if (!futureDateTimeResult.isValid) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          futureDateTimeResult.errorMessage ?? 'please_select_future_time',
        );
      }
      return;
    }

    _formNotifier.setLoading(true);

    try {
      // Parse the selected time and combine with selected date
      final combinedDateTime = GameFormValidator.parseDateTime(
        date: _formState.date!,
        time: _formState.time!,
      );
      if (combinedDateTime == null) {
        if (mounted) {
          _formNotifier.setLoading(false);
          SnackBarHelper.showError(context, 'invalid_time_format');
        }
        return;
      }

      final current = widget.initialGame!;
      final String newLocation = _formState.field?['name'] ?? current.location;
      final String? newAddress =
          _formState.field?['address'] ?? current.address;
      final double? newLat =
          safeToDouble(_formState.field?['latitude']) ?? current.latitude;
      final double? newLon =
          safeToDouble(_formState.field?['longitude']) ?? current.longitude;
      final String? newFieldId =
          _formState.field?['id']?.toString() ?? current.fieldId;

      // Update game through provider
      final updatedGame = current.copyWith(
        dateTime: combinedDateTime,
        location: newLocation,
        address: newAddress,
        latitude: newLat,
        longitude: newLon,
        fieldId: newFieldId,
      );

      await ref.read(gamesActionsProvider).updateGame(updatedGame);

      // Send invites to newly selected friends
      final userId = ref.read(currentUserIdProvider);
      if (userId != null &&
          _formState.selectedFriendUids.isNotEmpty &&
          mounted) {
        // Filter out already-invited friends (locked ones)
        final newInvites = _formState.selectedFriendUids
            .where((uid) => !_formState.lockedInvitedUids.contains(uid))
            .toList();

        if (newInvites.isNotEmpty) {
          // Capture messenger before async operation to avoid BuildContext warning
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref
                .read(cloudGamesActionsProvider)
                .sendGameInvitesToFriends(current.id, newInvites);
            NumberedLogger.i(
              'Successfully sent invites to ${newInvites.length} friends',
            );
          } catch (e, stackTrace) {
            // Log error but don't fail game update
            NumberedLogger.e('Failed to send game invites: $e');
            NumberedLogger.d('Stack trace: $stackTrace');
            // Show error to user so they know invites weren't sent
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Game updated but failed to send invites: ${e.toString().replaceAll('Exception: ', '')}',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }

      if (mounted) {
        ref.read(hapticsActionsProvider)?.mediumImpact();
        _formNotifier.setSuccess(true);
        Future.delayed(const Duration(milliseconds: 750), () {
          if (mounted) _formNotifier.setSuccess(false);
        });
        SnackBarHelper.showSuccess(context, 'game_updated_successfully');
        // Navigate to My Games → Organized and highlight the updated game
        final ctrl = MainScaffoldController.maybeOf(context);
        ctrl?.openMyGames(
          initialTab: 1,
          highlightGameId: updatedGame.id,
          popToRoot: true,
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'game_creation_failed'.tr();
        final es = e.toString();
        final isSlotUnavailable = es.contains('new_slot_unavailable') ||
            es.contains('time_slot_unavailable');

        if (isSlotUnavailable) {
          errorMsg = 'time_slot_unavailable'.tr();
          SnackBarHelper.showBlocked(context, errorMsg);
          ref.read(hapticsActionsProvider)?.mediumImpact();
        } else {
          if (es.contains('not_authorized')) {
            errorMsg = 'not_authorized'.tr();
          }
          SnackBarHelper.showError(
            context,
            errorMsg,
            duration: const Duration(seconds: 5),
          );
        }
      }
    } finally {
      if (mounted) {
        _formNotifier.setLoading(false);
      }
    }
  }

  // Booked slots loading is now handled by GameFormNotifier
  // Method removed: _loadBookedSlots()

  Future<void> _createGame() async {
    // Validate required fields
    final requiredFieldsResult = GameFormValidator.validateRequiredFields(
      sport: _formState.sport,
      field: _formState.field,
      date: _formState.date,
      time: _formState.time,
    );
    if (!requiredFieldsResult.isValid) {
      if (_formState.time == null) {
        // Inline prompt near time section
        _scrollToCreateGameButton();
        return;
      }
      if (mounted) {
        SnackBarHelper.showError(
          context,
          requiredFieldsResult.errorMessage ?? 'form_fill_all_fields',
        );
      }
      return;
    }

    // Validate future date/time
    final futureDateTimeResult = GameFormValidator.validateFutureDateTime(
      date: _formState.date,
      time: _formState.time,
    );
    if (!futureDateTimeResult.isValid) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          futureDateTimeResult.errorMessage ?? 'please_select_future_time',
        );
      }
      return;
    }

    _formNotifier.setLoading(true);

    try {
      // Parse the selected time and combine with selected date
      final combinedDateTime = GameFormValidator.parseDateTime(
        date: _formState.date!,
        time: _formState.time!,
      );
      if (combinedDateTime == null) {
        if (mounted) {
          _formNotifier.setLoading(false);
          SnackBarHelper.showError(context, 'invalid_time_format');
        }
        return;
      }

      // Create a game object with selected field data
      final userId = ref.read(currentUserIdProvider);
      final userDisplayName = ref.read(currentUserDisplayNameProvider);

      if (userId == null) {
        // Inline prompt via bottom sheet is already handled on Home; here avoid global snack
        _showSignInInlinePrompt();
        return;
      }

      final game = Game(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sport: _formState.sport!,
        dateTime: combinedDateTime,
        location: _formState.field?['name'] ?? 'Unknown Field',
        address: _formState.field?['address'],
        latitude: safeToDouble(_formState.field?['latitude']),
        longitude: safeToDouble(_formState.field?['longitude']),
        fieldId: _formState.field?['id']?.toString(),
        maxPlayers: _formState.maxPlayers,
        description: '',
        organizerId: userId,
        organizerName: userDisplayName,
        createdAt: DateTime.now(),
        isPublic: _formState.isPublic,
        currentPlayers: 1,
        players: [userId], // Creator is counted as the first player
      );

      final createdId = await ref.read(gamesActionsProvider).createGame(game);

      // Update game with the created ID for calendar integration
      final createdGame = game.copyWith(id: createdId);

      if (mounted) {
        // Capture context-dependent values before any navigation
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final ctrl = MainScaffoldController.maybeOf(context);
        final formNotifier = _formNotifier; // Capture notifier reference

        ref.read(hapticsActionsProvider)?.mediumImpact();
        formNotifier.setSuccess(true);
        Future.delayed(const Duration(milliseconds: 750), () {
          if (mounted) formNotifier.setSuccess(false);
        });

        // Automatically add newly created game to calendar (non-blocking)
        // This helps organizers keep track of their games
        CalendarService.addGameToCalendar(createdGame).then((eventId) {
          if (mounted && eventId != null) {
            // Calendar event added successfully - show subtle feedback
            // Don't show a separate snackbar to avoid UI clutter
            NumberedLogger.i('Game $createdId automatically added to calendar');
          } else if (mounted) {
            // Calendar add failed - log but don't show error (game creation succeeded)
            NumberedLogger.w(
                'Failed to add game $createdId to calendar (non-critical)');
          }
        }).catchError((e) {
          // Log error but don't interrupt user flow
          NumberedLogger.w('Error adding game to calendar: $e');
        });

        // Show success message using captured messenger (safe after navigation)
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('game_created_successfully'.tr()),
            backgroundColor: AppColors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate to My Games → Organized and highlight the created game
        // Use post-frame callback to ensure navigation happens safely after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ctrl != null) {
            ctrl.openMyGames(
              initialTab: 1,
              highlightGameId: createdId,
              popToRoot: true,
            );
          }
        });

        // Send in-app invites to selected friends in the background (non-blocking)
        // This ensures consistent transition timing whether friends are invited or not
        if (_formState.selectedFriendUids.isNotEmpty) {
          ref
              .read(cloudGamesActionsProvider)
              .sendGameInvitesToFriends(
                  createdId, _formState.selectedFriendUids.toList())
              .then((_) {
            NumberedLogger.i(
              'Successfully sent invites to ${_formState.selectedFriendUids.length} friends',
            );
          }).catchError((e, stackTrace) {
            // Log error but don't fail game creation or interrupt navigation
            NumberedLogger.e('Failed to send game invites: $e');
            NumberedLogger.d('Stack trace: $stackTrace');
            // Show error to user so they know invites weren't sent (if still mounted)
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.warning,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Game created but failed to send invites: ${e.toString().replaceAll('Exception: ', '')}',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'game_creation_failed'.tr();
        final es = e.toString();
        final isSlotUnavailable = es.contains('new_slot_unavailable') ||
            es.contains('time_slot_unavailable');
        final isUserBusy = es.contains('user_already_busy');

        if (isUserBusy) {
          errorMsg = 'user_already_busy'.tr();
          SnackBarHelper.showBlocked(context, errorMsg);
          ref.read(hapticsActionsProvider)?.mediumImpact();
        } else if (isSlotUnavailable) {
          errorMsg = 'time_slot_unavailable'.tr();
          SnackBarHelper.showBlocked(context, errorMsg);
          ref.read(hapticsActionsProvider)?.mediumImpact();
        } else {
          SnackBarHelper.showError(
            context,
            errorMsg,
            duration: const Duration(seconds: 5),
          );
        }
      }
    } finally {
      if (mounted) {
        _formNotifier.setLoading(false);
      }
    }
  }

  // Sport and date card builders are now in extracted widgets

  Widget _buildWeatherTimeCard({
    required String time,
    required bool isSelected,
    bool isDisabled = false,
    required bool hasWeatherData,
    required String? weatherCondition,
    required IconData? weatherIcon,
    required Color? weatherColor,
    bool isLoadingWeather = false,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        color: isSelected
            ? AppColors.blue.withValues(alpha: 0.06)
            : (isDisabled
                ? AppColors.lightgrey.withValues(alpha: 0.18)
                : AppColors.white),
        border: isSelected
            ? Border.all(color: AppColors.blue, width: 2)
            : (isDisabled
                ? Border.all(
                    color: AppColors.grey.withValues(alpha: 0.5),
                    width: 1,
                  )
                : Border.all(
                    color: AppColors.grey.withValues(alpha: 0.3),
                    width: 1,
                  )),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.smallCard),
          onTap: isDisabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Weather Icon Section - only show actual forecast data
                // This ensures we only display location-based weather predictions
                if (hasWeatherData && weatherIcon != null && !isDisabled)
                  // Show actual weather icon when forecast data is available
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: weatherColor?.withValues(alpha: 0.15) ??
                          AppColors.lightgrey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        weatherIcon,
                        color: weatherColor ?? AppColors.grey,
                        size: 16,
                      ),
                    ),
                  )
                else if (isLoadingWeather && !isDisabled)
                  // Show loading indicator while fetching weather data
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.grey.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  )
                else if (!isDisabled)
                  // No weather data available - show empty space to maintain layout
                  // This prevents showing misleading default icons
                  const SizedBox(width: 24, height: 24),

                const SizedBox(height: 4),

                // Time Section
                Text(
                  time,
                  style: AppTextStyles.smallCardTitle.copyWith(
                    color: isDisabled
                        ? AppColors.grey
                        : (isSelected ? AppColors.blue : AppColors.blackText),
                    fontSize: 14, // Reduced font size
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData? _surfaceIconForSport(String? sport) {
    switch (sport) {
      case 'soccer':
        return Icons.grass;
      case 'basketball':
        return Icons.texture;
      case 'volleyball':
        return Icons.beach_access;
      case 'skateboard':
        return Icons.texture;
      case 'boules':
        return Icons.scatter_plot;
      case 'swimming':
        return Icons.pool;
      default:
        return Icons.landscape;
    }
  }

  Widget _buildFieldCard({
    required Map<String, dynamic> field,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final dynamic rawSurface = field['surface'];
    final String? surface = rawSurface?.toString().trim();
    final lighting = field['lighting'] ?? false;
    final rawName = (field['name'] as String?)?.trim() ?? '';
    final addressSuperShort =
        (field['addressSuperShort'] as String?)?.trim() ?? '';
    final addressSuperShortFull =
        (field['addressSuperShortFull'] as String?)?.trim() ?? '';
    final distanceMeters = safeToDouble(field['distance']);
    final distanceKm = distanceMeters != null
        ? (distanceMeters / 1000).clamp(0, double.infinity)
        : null;
    final normalizedName = rawName.toLowerCase();
    final isNameMissing = rawName.isEmpty ||
        normalizedName == 'unnamed field' ||
        normalizedName == 'unknown field';
    final titleText = isNameMissing
        ? (addressSuperShort.isNotEmpty
            ? addressSuperShort
            : (addressSuperShortFull.isNotEmpty
                ? addressSuperShortFull.split(',').first.trim()
                : 'Unknown Field'))
        : rawName;
    final subtitleText = isNameMissing
        ? (addressSuperShortFull.isNotEmpty
            ? addressSuperShortFull
            : (addressSuperShort.isNotEmpty ? addressSuperShort : null))
        : (addressSuperShortFull.isNotEmpty
            ? addressSuperShortFull
            : (addressSuperShort.isNotEmpty ? addressSuperShort : null));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        width: 200,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isSelected
                ? AppColors.blue
                : AppColors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(AppWidths.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titleText,
              style: AppTextStyles.smallCardTitle.copyWith(
                color: isSelected ? AppColors.blue : AppColors.blackText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (subtitleText != null && subtitleText.isNotEmpty)
              Text(
                subtitleText,
                style: AppTextStyles.superSmall.copyWith(
                  color: AppColors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (subtitleText != null && subtitleText.isNotEmpty)
              const SizedBox(height: 4),
            if (distanceKm != null && distanceKm.isFinite)
              Text(
                formatDistance(distanceKm * 1000),
                style: AppTextStyles.superSmall.copyWith(
                  color: AppColors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (distanceKm != null && distanceKm.isFinite)
              const SizedBox(height: 4),
            if (_formState.sport != 'table_tennis')
              Builder(
                builder: (context) {
                  final icon = _surfaceIconForSport(_formState.sport);
                  final surfaceText = surface;
                  final hasSurfaceText =
                      surfaceText != null && surfaceText.isNotEmpty;
                  final displaySurfaceText =
                      hasSurfaceText ? surfaceText : 'Unknown';
                  final shouldShowText = hasSurfaceText || icon != null;
                  if (!shouldShowText) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        if (icon != null)
                          Icon(
                            icon,
                            size: 12,
                            color: AppColors.grey,
                          ),
                        if (icon != null && shouldShowText)
                          const SizedBox(width: 4),
                        if (shouldShowText)
                          Expanded(
                            child: Text(
                              displaySurfaceText,
                              style: AppTextStyles.superSmall.copyWith(
                                color: AppColors.grey,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            Row(
              children: [
                Icon(
                  lighting ? Icons.lightbulb : Icons.lightbulb_outline,
                  size: 12,
                  color: lighting ? Colors.amber : AppColors.grey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    lighting ? 'Lighting available' : 'No lighting available',
                    style: AppTextStyles.superSmall.copyWith(
                      color: AppColors.grey,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        height: 60, // Much smaller
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.blue.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isSelected
                ? AppColors.blue
                : AppColors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.blue : AppColors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTextStyles.body.copyWith(
                color: isSelected ? AppColors.blue : AppColors.blackText,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Form state is managed by GameFormNotifier - no need to pre-fill here
    // The notifier handles initialization from initialGame

    // Immediately clear success overlay if showing (for new game creation)
    if (widget.initialGame == null && _formState.showSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _formNotifier.setSuccess(false);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: Text('organize_a_game'.tr()),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SuccessCheckmarkOverlay(
          show: _formState.showSuccess,
          child: Padding(
            padding: AppPaddings.symmHorizontalReg,
            child: Column(
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
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PanelHeader('choose_sport'.tr()),

                            // Sport Selection - Horizontal Scrollable List
                            Padding(
                              padding: AppPaddings.symmHorizontalReg,
                              child: GameFormSportSelector(
                                initialGame: widget.initialGame,
                                notifier: _formNotifier,
                              ),
                            ),

                            // Available Fields Section (only show if sport is selected)
                            if (_formState.sport != null) ...[
                              Padding(
                                padding: AppPaddings.symmHorizontalReg,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'choose_field'.tr(),
                                        style: AppTextStyles.headline,
                                        textAlign: TextAlign.start,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: (_formState.isLoadingFields ||
                                              _formState
                                                  .availableFields.isEmpty)
                                          ? null
                                          : () {
                                              final mapLocations = _formState
                                                  .availableFields
                                                  .map<Map<String, dynamic>>((
                                                    field,
                                                  ) {
                                                    final lat =
                                                        field['latitude'] ??
                                                            field['lat'];
                                                    final lon =
                                                        field['longitude'] ??
                                                            field['lon'];
                                                    final latDouble =
                                                        safeToDouble(lat);
                                                    final lonDouble =
                                                        safeToDouble(lon);
                                                    if (latDouble == null ||
                                                        lonDouble == null) {
                                                      return <String,
                                                          dynamic>{};
                                                    }
                                                    return {
                                                      'id': field['id'] ??
                                                          field['fieldId'] ??
                                                          field['@id'] ??
                                                          field['osm_id'] ??
                                                          field['osmId'],
                                                      'name': (field['name']
                                                                  ?.toString()
                                                                  .trim()
                                                                  .isNotEmpty ==
                                                              true)
                                                          ? field['name']
                                                              .toString()
                                                              .trim()
                                                          : (field['address_micro_short']
                                                                      ?.toString()
                                                                      .trim()
                                                                      .isNotEmpty ==
                                                                  true)
                                                              ? field['address_micro_short']
                                                                  .toString()
                                                                  .trim()
                                                              : (field['addressMicroShort']
                                                                          ?.toString()
                                                                          .trim()
                                                                          .isNotEmpty ==
                                                                      true)
                                                                  ? field['addressMicroShort']
                                                                      .toString()
                                                                      .trim()
                                                                  : 'Unnamed Field',
                                                      'lat': latDouble,
                                                      'lon': lonDouble,
                                                      'lit':
                                                          (field['lighting'] ==
                                                                  true)
                                                              ? 'yes'
                                                              : 'no',
                                                      'surface':
                                                          field['surface'],
                                                    };
                                                  })
                                                  .where(
                                                    (loc) => loc.isNotEmpty,
                                                  )
                                                  .toList();

                                              if (mapLocations.isEmpty) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'no_fields_available'
                                                          .tr(),
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              final mapTitle =
                                                  _formState.sport ==
                                                          'basketball'
                                                      ? 'basketball_courts'.tr()
                                                      : 'football_fields'.tr();

                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      GenericMapScreen(
                                                    title: mapTitle,
                                                    locations: mapLocations,
                                                  ),
                                                ),
                                              );
                                            },
                                      icon: const Icon(Icons.map_outlined),
                                      label: Text('show_on_map'.tr()),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppHeights.small),
                              // Search field
                              Padding(
                                padding: AppPaddings.symmHorizontalReg,
                                child: SizedBox(
                                  height: 40,
                                  child: TextField(
                                    controller: _fieldSearchController,
                                    textInputAction: TextInputAction.search,
                                    style: AppTextStyles.body,
                                    onChanged: _onFieldSearchChanged,
                                    onSubmitted: (_) {
                                      // Search filter is applied via onChanged with debouncing
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'search_by_name_address'.tr(),
                                      filled: true,
                                      fillColor: AppColors.lightgrey,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        size: 20,
                                      ),
                                      suffixIcon: _formState
                                              .fieldSearchQuery.isEmpty
                                          ? null
                                          : IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 20,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32,
                                              ),
                                              onPressed: () {
                                                _fieldSearchController.clear();
                                                _formNotifier
                                                    .updateFieldSearch('');
                                              },
                                            ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.image,
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppHeights.small),
                              Padding(
                                padding: AppPaddings.symmHorizontalReg,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 8),
                                    if (_formState.isLoadingFields)
                                      const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    else if (_formState.availableFields.isEmpty)
                                      Container(
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: AppColors.grey.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.card,
                                          ),
                                          border: Border.all(
                                            color: AppColors.grey.withValues(
                                              alpha: 0.3,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'no_fields_available'.tr(),
                                            style: AppTextStyles.body.copyWith(
                                              color: AppColors.grey,
                                            ),
                                          ),
                                        ),
                                      )
                                    else if (_formState.filteredFields.isEmpty)
                                      Container(
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: AppColors.grey.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.card,
                                          ),
                                          border: Border.all(
                                            color: AppColors.grey.withValues(
                                              alpha: 0.3,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'no_fields_match_search'.tr(),
                                            style: AppTextStyles.body.copyWith(
                                              color: AppColors.grey,
                                            ),
                                          ),
                                        ),
                                      )
                                    else ...[
                                      // Show subtle loading indicator when calculating distances
                                      if (_formState.isCalculatingDistances)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    AppColors.blue,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'finding_closest_fields'.tr(),
                                                style: AppTextStyles.small
                                                    .copyWith(
                                                  color: AppColors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Transform.translate(
                                        offset: const Offset(0, -6),
                                        child: SizedBox(
                                          height: 120,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: _formState
                                                .filteredFields.length,
                                            itemBuilder: (context, index) {
                                              final field = _formState
                                                  .filteredFields[index];
                                              final isSelected =
                                                  _formState.field == field;

                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  right: index <
                                                          _formState
                                                                  .filteredFields
                                                                  .length -
                                                              1
                                                      ? AppWidths.regular
                                                      : 0,
                                                ),
                                                child: _buildFieldCard(
                                                  field: field,
                                                  isSelected: isSelected,
                                                  onTap: () {
                                                    ref
                                                        .read(
                                                            hapticsActionsProvider)
                                                        ?.lightImpact();
                                                    _formNotifier
                                                        .selectField(field);
                                                    // Weather and booked slots are automatically reloaded by notifier
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              //const SizedBox(height: AppHeights.huge),
                            ],

                            // Max Players Slider (right after field)
                            if (_formState.field != null) ...[
                              PanelHeader('max_players'.tr()),
                              Padding(
                                padding: AppPaddings.symmHorizontalReg,
                                child: GameFormMaxPlayersSlider(
                                  initialGame: widget.initialGame,
                                  notifier: _formNotifier,
                                ),
                              ),

                              // Date Selection Section (only show if field is selected)
                              Transform.translate(
                                offset: const Offset(0, -8),
                                child: PanelHeader('choose_date'.tr()),
                              ),
                              Padding(
                                padding: AppPaddings.symmHorizontalReg,
                                child: GameFormDateSelector(
                                  initialGame: widget.initialGame,
                                  notifier: _formNotifier,
                                  onDateSelected: _scrollToCreateGameButton,
                                ),
                              ),
                            ],

                            // Time Selection Section (only show if date is selected)
                            if (_formState.date != null) ...[
                              PanelHeader('choose_time'.tr()),
                              Padding(
                                padding: AppPaddings.symmHorizontalReg,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Transform.translate(
                                      offset: const Offset(0, -6),
                                      child: SizedBox(
                                        height: 80,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _availableTimes.length,
                                          itemBuilder: (context, index) {
                                            final time = _availableTimes[index];
                                            final isSelected =
                                                _formState.time == time;
                                            final isBooked = _isTimeSlotBooked(
                                                time, _formState.bookedTimes);
                                            if (index == 0) {
                                              NumberedLogger.d(
                                                'UI: First time slot check - time=$time, isBooked=$isBooked, _formState.bookedTimes=${_formState.bookedTimes.toList()}',
                                              );
                                            }
                                            // Only show weather if actual forecast data is available
                                            // This ensures we only display location-based weather predictions
                                            final hasWeatherData = _formState
                                                .weatherData.isNotEmpty;
                                            // Weather API returns hourly data (e.g., "10:00"), so map 30-minute slots
                                            // to their hour's weather data (e.g., "10:30" -> "10:00")
                                            String weatherKey = time;
                                            if (hasWeatherData &&
                                                !_formState.weatherData
                                                    .containsKey(time)) {
                                              // For 30-minute slots, use the hour's weather data
                                              final hour =
                                                  extractHourFromTimeString(
                                                      time);
                                              if (hour != null) {
                                                weatherKey = '$hour:00';
                                              }
                                            }
                                            final weatherCondition =
                                                hasWeatherData
                                                    ? _formState
                                                        .weatherData[weatherKey]
                                                    : null;

                                            final weatherIcon =
                                                hasWeatherData &&
                                                        weatherCondition != null
                                                    ? ref
                                                        .read(
                                                          weatherActionsProvider,
                                                        )
                                                        .getWeatherIcon(
                                                          time,
                                                          weatherCondition,
                                                        )
                                                    : null;
                                            final weatherColor =
                                                hasWeatherData &&
                                                        weatherCondition != null
                                                    ? ref
                                                        .read(
                                                          weatherActionsProvider,
                                                        )
                                                        .getWeatherColor(
                                                          weatherCondition,
                                                        )
                                                    : null;

                                            return Padding(
                                              padding: EdgeInsets.only(
                                                right: index <
                                                        _availableTimes.length -
                                                            1
                                                    ? AppWidths.regular
                                                    : 0,
                                              ),
                                              child: Opacity(
                                                opacity: isBooked ? 0.5 : 1.0,
                                                child: _buildWeatherTimeCard(
                                                  time: time,
                                                  isSelected: isSelected,
                                                  isDisabled: isBooked,
                                                  hasWeatherData:
                                                      hasWeatherData,
                                                  weatherCondition:
                                                      weatherCondition,
                                                  weatherIcon: weatherIcon,
                                                  weatherColor: weatherColor,
                                                  isLoadingWeather: _formState
                                                      .isLoadingWeather,
                                                  onTap: () {
                                                    if (isBooked) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.block,
                                                                color: Colors
                                                                    .white,
                                                                size: 20,
                                                              ),
                                                              const SizedBox(
                                                                width: 12,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  'time_slot_unavailable'
                                                                      .tr(),
                                                                  style: AppTextStyles
                                                                      .body
                                                                      .copyWith(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          backgroundColor:
                                                              AppColors.red,
                                                          duration:
                                                              const Duration(
                                                            seconds: 3,
                                                          ),
                                                          behavior:
                                                              SnackBarBehavior
                                                                  .floating,
                                                        ),
                                                      );
                                                      ref
                                                          .read(
                                                            hapticsActionsProvider,
                                                          )
                                                          ?.mediumImpact();
                                                      return;
                                                    }
                                                    ref
                                                        .read(
                                                          hapticsActionsProvider,
                                                        )
                                                        ?.lightImpact();
                                                    _formNotifier
                                                        .selectTime(time);
                                                    // Auto-scroll to show next options after selecting time
                                                    _scrollToCreateGameButton();
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              //const SizedBox(height: AppHeights.huge),
                            ],

                            // Visibility Selection (create only, after time is chosen)
                            if (_formState.time != null &&
                                widget.initialGame == null) ...[
                              PanelHeader('choose_visibility'.tr()),
                              Padding(
                                padding: AppPaddings.symmHorizontalReg,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildVisibilityCard(
                                            title: 'public'.tr(),
                                            icon: Icons.public,
                                            isSelected: _formState.isPublic,
                                            onTap: () {
                                              ref
                                                  .read(hapticsActionsProvider)
                                                  ?.lightImpact();
                                              _formNotifier.setVisibility(true);
                                            },
                                          ),
                                        ),
                                        const SizedBox(
                                          width: AppWidths.regular,
                                        ),
                                        Expanded(
                                          child: _buildVisibilityCard(
                                            title: 'private'.tr(),
                                            icon: Icons.lock,
                                            isSelected: !_formState.isPublic,
                                            onTap: () {
                                              ref
                                                  .read(hapticsActionsProvider)
                                                  ?.lightImpact();
                                              _formNotifier
                                                  .setVisibility(false);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Invite Friends Section (optional, after time is chosen)
                            if (_formState.time != null) ...[
                              PanelHeader('invite_friends_label'.tr()),
                              Padding(
                                padding: AppPaddings.symmHorizontalReg,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Selected friends displayed as chips
                                    if (_formState
                                        .selectedFriendUids.isNotEmpty)
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          // Render each selected friend as a chip
                                          ...(_formState.selectedFriendUids.map(
                                            (uid) => _buildFriendChip(uid),
                                          )),
                                          // "Add more" button chip
                                          _buildAddFriendChip(),
                                        ],
                                      )
                                    else
                                      // If no friends selected yet, show only the "Add" button
                                      _buildAddFriendChip(),
                                  ],
                                ),
                              ),
                            ],

                            // Create Game Button (match header width via same padding)
                            Padding(
                              key: _createGameButtonKey,
                              padding: AppPaddings.allReg,
                              child: SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed:
                                      _isFormComplete && !_formState.isLoading
                                          ? (_isCreatingSimilarGame
                                              ? _createGame
                                              : (widget.initialGame != null
                                                  ? _updateGame
                                                  : _createGame))
                                          : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isFormComplete
                                        ? (_isCreatingSimilarGame
                                            ? AppColors.blue
                                            : (widget.initialGame != null
                                                ? (_hasChanges
                                                    ? Colors.orange
                                                    : AppColors.green)
                                                : AppColors.blue))
                                        : AppColors.grey,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.card,
                                      ),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _formState.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          _isCreatingSimilarGame
                                              ? 'create_game'.tr()
                                              : (widget.initialGame != null
                                                  ? 'update_game'.tr()
                                                  : 'create_game'.tr()),
                                          style:
                                              AppTextStyles.cardTitle.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build a chip for a selected friend
  Widget _buildFriendChip(String uid) {
    return FutureBuilder<Map<String, String?>>(
      future: ref.read(friendsActionsProvider).fetchMinimalProfile(uid),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) {
          return const SizedBox.shrink(); // Loading or error
        }

        final name = snap.data?['displayName'] ?? 'Friend';
        final locked = widget.initialGame != null &&
            _formState.lockedInvitedUids.contains(uid);

        return Chip(
          avatar: CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.superlightgrey,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          label: Text(name),
          deleteIcon: Icon(locked ? Icons.lock : Icons.close, size: 16),
          onDeleted: locked
              ? null
              : () {
                  setState(() => _formState.selectedFriendUids.remove(uid));
                },
          backgroundColor: locked
              ? AppColors.grey.withValues(alpha: 0.1)
              : AppColors.blue.withValues(alpha: 0.1),
        );
      },
    );
  }

  // Build the "Add Friends" action chip
  Widget _buildAddFriendChip() {
    return ActionChip(
      avatar: const Icon(Icons.person_add, size: 18, color: AppColors.blue),
      label: Text('add_friends'.tr()),
      onPressed: () => _showFriendSelectionSheet(),
      backgroundColor: AppColors.blue.withValues(alpha: 0.1),
      labelStyle: AppTextStyles.body.copyWith(color: AppColors.blue),
    );
  }

  // Show the friend selection bottom sheet
  void _showFriendSelectionSheet() {
    ref.read(hapticsActionsProvider)?.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FriendSelectionSheet(
        currentUid: ref.read(currentUserIdProvider) ?? '',
        initiallySelected: _formState.selectedFriendUids,
        lockedUids: widget.initialGame != null
            ? _formState.lockedInvitedUids
            : const <String>{},
        onApply: (selectedUids) {
          // Apply changes when Done is pressed
          // Keep locked invites (they can't be removed)
          final newSelection = <String>{..._formState.lockedInvitedUids};
          // Add newly selected friends
          newSelection.addAll(selectedUids);
          // Update state via notifier (don't mutate the unmodifiable set directly)
          _formNotifier.updateSelectedFriends(newSelection);
        },
      ),
    );
  }

  // Locked invites loading is now handled by GameFormNotifier
  // Method removed: _loadLockedInvites()
}

// Bottom sheet widget for selecting friends with search
class _FriendSelectionSheet extends ConsumerStatefulWidget {
  final String currentUid;
  final Set<String> initiallySelected;
  final Set<String> lockedUids;
  final void Function(Set<String> selectedUids) onApply;

  const _FriendSelectionSheet({
    required this.currentUid,
    required this.initiallySelected,
    required this.lockedUids,
    required this.onApply,
  });

  @override
  ConsumerState<_FriendSelectionSheet> createState() =>
      _FriendSelectionSheetState();
}

class _FriendSelectionSheetState extends ConsumerState<_FriendSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Set<String> _selectedUids;

  @override
  void initState() {
    super.initState();
    // Initialize with current selections (including locked ones)
    _selectedUids = Set<String>.from(widget.initiallySelected);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleToggle(String uid, bool selected) {
    // Prevent toggling locked invites
    if (widget.lockedUids.contains(uid)) {
      return;
    }
    setState(() {
      if (selected) {
        _selectedUids.add(uid);
      } else {
        _selectedUids.remove(uid);
      }
    });
  }

  void _handleApply() {
    ref.read(hapticsActionsProvider)?.selectionClick();
    // Apply selections (excluding locked ones from the set we pass back)
    final newSelections =
        _selectedUids.where((uid) => !widget.lockedUids.contains(uid)).toSet();
    widget.onApply(newSelections);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        children: [
          // Header with drag handle and title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Text('invite_friends'.tr(), style: AppTextStyles.h3),
                const SizedBox(height: 16),
                // Search bar
                TextField(
                  controller: _searchController,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'search_friends'.tr(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    filled: true,
                    fillColor: AppColors.superlightgrey,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ],
            ),
          ),
          // Selected count indicator
          if (_selectedUids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_selectedUids.length} ${'selected'.tr()}',
                    style: AppTextStyles.small.copyWith(color: AppColors.grey),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          // Friend list (reuse existing FriendPicker but with search)
          Expanded(
            child: _SearchableFriendPicker(
              currentUid: widget.currentUid,
              selectedUids: _selectedUids,
              lockedUids: widget.lockedUids,
              searchQuery: _searchQuery,
              onToggle: _handleToggle,
            ),
          ),
          // Done button
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border(
                  top: BorderSide(
                    color: AppColors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'done'.tr(),
                    style: AppTextStyles.cardTitle.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Searchable friend picker widget
class _SearchableFriendPicker extends ConsumerWidget {
  final String currentUid;
  final Set<String> selectedUids;
  final Set<String> lockedUids;
  final String searchQuery;
  final void Function(String uid, bool selected) onToggle;

  const _SearchableFriendPicker({
    required this.currentUid,
    required this.selectedUids,
    required this.lockedUids,
    required this.searchQuery,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.white),
      child: ref.watch(watchFriendsListProvider).when(
            data: (friendUids) {
              if (friendUids.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'no_friends_to_invite'.tr(),
                    style: AppTextStyles.small.copyWith(color: AppColors.grey),
                  ),
                );
              }

              // Fetch all profiles upfront to avoid FutureBuilder in ListView
              return FutureBuilder<Map<String, Map<String, String?>>>(
                future: Future.wait(
                  friendUids.map(
                    (id) => ref
                        .read(friendsActionsProvider)
                        .fetchMinimalProfile(id),
                  ),
                ).then((profiles) {
                  final map = <String, Map<String, String?>>{};
                  for (int i = 0;
                      i < friendUids.length && i < profiles.length;
                      i++) {
                    map[friendUids[i]] = profiles[i];
                  }
                  return map;
                }),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snap.hasData || snap.data == null) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'no_friends_to_invite'.tr(),
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                    );
                  }

                  final profiles = snap.data!;

                  // Apply search filter
                  final filtered = searchQuery.isEmpty
                      ? friendUids
                      : friendUids.where((uid) {
                          final name = profiles[uid]?['displayName'] ?? '';
                          return name.toLowerCase().contains(
                                searchQuery.toLowerCase(),
                              );
                        }).toList();

                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'no_friends_yet'.tr(),
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.lightgrey),
                    itemBuilder: (context, i) {
                      final uid = filtered[i];
                      final data = profiles[uid] ??
                          const {'displayName': 'User', 'photoURL': null};
                      final name = data['displayName'] ?? 'User';
                      final photo = data['photoURL'];
                      final selected = selectedUids.contains(uid);
                      final locked = lockedUids.contains(uid);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.superlightgrey,
                          backgroundImage: (photo != null && photo.isNotEmpty)
                              ? CachedNetworkImageProvider(photo)
                              : null,
                          child: (photo == null || photo.isEmpty)
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                )
                              : null,
                        ),
                        title: Text(
                          name,
                          style: AppTextStyles.body.copyWith(
                            color: locked ? AppColors.grey : null,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (locked)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.lock,
                                  size: 16,
                                  color: AppColors.grey,
                                ),
                              ),
                            Checkbox(
                              value: selected || locked,
                              onChanged: locked
                                  ? null
                                  : (v) => onToggle(uid, v == true),
                            ),
                          ],
                        ),
                        onTap: locked ? null : () => onToggle(uid, !selected),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'no_friends_to_invite'.tr(),
                style: AppTextStyles.small.copyWith(color: AppColors.grey),
              ),
            ),
          ),
    );
  }
}
