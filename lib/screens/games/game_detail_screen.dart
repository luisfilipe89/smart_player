import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/calendar/calendar_service.dart';
import 'package:move_young/services/system/haptics_provider.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  final Game game;
  const GameDetailScreen({super.key, required this.game});

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  bool _isInCalendar = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkCalendarStatus();
  }

  Future<void> _checkCalendarStatus() async {
    final isInCalendar = await CalendarService.isGameInCalendar(widget.game.id);
    if (mounted) {
      setState(() {
        _isInCalendar = isInCalendar;
      });
    }
  }

  IconData _iconForSport(String sport) {
    switch (sport) {
      case 'soccer':
        return Icons.sports_soccer;
      case 'basketball':
        return Icons.sports_basketball;
      case 'tennis':
        return Icons.sports_tennis;
      default:
        return Icons.sports;
    }
  }

  Color _colorForSport(String sport) {
    switch (sport) {
      case 'soccer':
        return Colors.green;
      case 'basketball':
        return Colors.orange;
      case 'tennis':
        return AppColors.blue;
      default:
        return AppColors.blue;
    }
  }

  Future<void> _toggleCalendar() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    ref.read(hapticsActionsProvider)?.selectionClick();

    try {
      if (_isInCalendar) {
        // Remove from calendar
        final success =
            await CalendarService.removeGameFromCalendar(widget.game.id);
        if (mounted) {
          setState(() {
            _isInCalendar = !success;
            _isLoading = false;
          });
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
        final eventId = await CalendarService.addGameToCalendar(widget.game);
        if (mounted) {
          setState(() {
            _isInCalendar = eventId != null;
            _isLoading = false;
          });
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('calendar_event_added_error'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sportColor = _colorForSport(widget.game.sport);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game.sport.toUpperCase()),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          // Add calendar button in app bar
          IconButton(
            tooltip: 'add_to_calendar'.tr(),
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isInCalendar ? Icons.event_available : Icons.event,
                    color: _isInCalendar ? AppColors.green : AppColors.primary,
                  ),
            onPressed: _toggleCalendar,
          ),
        ],
      ),
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: AppPaddings.symmHorizontalReg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppHeights.reg),
              Row(
                children: [
                  Hero(
                    tag: 'game-${widget.game.id}-icon',
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sportColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_iconForSport(widget.game.sport),
                          size: 28, color: sportColor),
                    ),
                  ),
                  const SizedBox(width: AppWidths.regular),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.game.location, style: AppTextStyles.h3),
                        const SizedBox(height: 2),
                        Text(
                            '${widget.game.getFormattedDateLocalized((key) => key.tr())} • ${widget.game.formattedTime}',
                            style: AppTextStyles.bodyMuted),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppHeights.huge),
              if (widget.game.description.isNotEmpty)
                Text(widget.game.description, style: AppTextStyles.body),
            ],
          ),
        ),
      ),
    );
  }
}
