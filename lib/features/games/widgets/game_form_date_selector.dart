import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:move_young/utils/date_formatter.dart';
import 'package:move_young/features/games/models/game.dart';
import 'package:move_young/features/games/notifiers/game_form_notifier.dart';

/// Widget for selecting a date
class GameFormDateSelector extends ConsumerWidget {
  final Game? initialGame;
  final GameFormNotifier notifier;
  final VoidCallback? onDateSelected;

  const GameFormDateSelector({
    super.key,
    required this.initialGame,
    required this.notifier,
    this.onDateSelected,
  });

  /// Generate list of dates for the next two weeks
  static List<DateTime> get availableDates {
    final today = DateTime.now();
    final dates = <DateTime>[];
    for (int i = 0; i < 14; i++) {
      dates.add(DateTime(today.year, today.month, today.day + i));
    }
    return dates;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameFormNotifierProvider(initialGame));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(0, -6),
          child: SizedBox(
            height: 65,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: availableDates.length,
              itemBuilder: (context, index) {
                final date = availableDates[index];
                final isSelected = state.date == date;
                final isToday = date.day == DateTime.now().day &&
                    date.month == DateTime.now().month &&
                    date.year == DateTime.now().year;

                return Padding(
                  padding: EdgeInsets.only(
                    right: index < availableDates.length - 1
                        ? AppWidths.regular
                        : 0,
                  ),
                  child: _buildDateCard(
                    date: date,
                    isSelected: isSelected,
                    isToday: isToday,
                    onTap: () {
                      ref.read(hapticsActionsProvider)?.lightImpact();
                      if (isSelected) {
                        notifier.selectDate(null);
                      } else {
                        notifier.selectDate(date);
                        onDateSelected?.call();
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateCard({
    required DateTime date,
    required bool isSelected,
    required bool isToday,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        border: isSelected
            ? Border.all(color: AppColors.blue, width: 2)
            : Border.all(
                color: AppColors.grey.withValues(alpha: 0.3),
                width: 1,
              ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Month abbreviation
                Builder(
                  builder: (context) => Text(
                    getMonthAbbr(date, context),
                    style: AppTextStyles.superSmall.copyWith(
                      color: isSelected
                          ? AppColors.blue
                          : isToday
                              ? AppColors.blue
                              : AppColors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 7,
                    ),
                  ),
                ),
                // Day of month
                Text(
                  date.day.toString(),
                  style: AppTextStyles.smallCardTitle.copyWith(
                    color: isSelected
                        ? AppColors.blue
                        : isToday
                            ? AppColors.blue
                            : AppColors.blackText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // Day of week abbreviation
                Builder(
                  builder: (context) => Text(
                    getDayOfWeekAbbr(date, context),
                    style: AppTextStyles.superSmall.copyWith(
                      color: isSelected
                          ? AppColors.blue
                          : isToday
                              ? AppColors.blue
                              : AppColors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 8,
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
}
