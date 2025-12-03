import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:move_young/features/games/models/game.dart';
import 'package:move_young/features/games/notifiers/game_form_notifier.dart';

/// Widget for selecting a sport type
class GameFormSportSelector extends ConsumerWidget {
  final Game? initialGame;
  final GameFormNotifier notifier;

  const GameFormSportSelector({
    super.key,
    required this.initialGame,
    required this.notifier,
  });

  // Available sports with their icons
  static final List<Map<String, dynamic>> sports = [
    {
      'key': 'soccer',
      'icon': Icons.sports_soccer,
      'color': const Color(0xFF4CAF50),
    },
    {
      'key': 'basketball',
      'icon': Icons.sports_basketball,
      'color': const Color(0xFFFF9800),
    },
    {
      'key': 'volleyball',
      'icon': Icons.sports_volleyball,
      'color': const Color(0xFFE91E63),
    },
    {
      'key': 'table_tennis',
      'icon': Icons.sports_tennis,
      'color': const Color(0xFF00BCD4),
    },
    {
      'key': 'skateboard',
      'icon': Icons.skateboarding,
      'color': const Color(0xFFF9A825),
    },
    {
      'key': 'boules',
      'icon': Icons.scatter_plot,
      'color': const Color(0xFF795548),
    },
    {
      'key': 'swimming',
      'icon': Icons.pool,
      'color': const Color(0xFF2196F3),
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameFormNotifierProvider(initialGame));
    final isEdit = initialGame != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(0, -6),
          child: SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sports.length,
              itemBuilder: (context, index) {
                final sport = sports[index];
                final isSelected = state.sport == sport['key'];

                return Padding(
                  padding: EdgeInsets.only(
                    right: index < sports.length - 1 ? AppWidths.small : 0,
                  ),
                  child: SizedBox(
                    width: 70,
                    child: IgnorePointer(
                      ignoring: isEdit,
                      child: _buildSportCard(
                        sport: sport,
                        isSelected: isSelected,
                        disabled: isEdit,
                        onTap: () {
                          ref.read(hapticsActionsProvider)?.lightImpact();
                          notifier.selectSport(sport['key'] as String);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSportCard({
    required Map<String, dynamic> sport,
    required bool isSelected,
    required bool disabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.smallCard),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.lightgrey.withValues(alpha: 0.18)
              : (isSelected
                  ? AppColors.blue.withValues(alpha: 0.1)
                  : AppColors.white),
          borderRadius: BorderRadius.circular(AppRadius.smallCard),
          border: Border.all(
            color: disabled
                ? AppColors.grey.withValues(alpha: 0.5)
                : (isSelected
                    ? AppColors.blue
                    : AppColors.grey.withValues(alpha: 0.3)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              sport['icon'] as IconData,
              size: 32,
              color: disabled
                  ? AppColors.grey
                  : (isSelected
                      ? AppColors.blue
                      : (sport['color'] as Color)),
            ),
            const SizedBox(height: 4),
            Text(
              sport['key'].toString().tr(),
              style: AppTextStyles.superSmall.copyWith(
                color: disabled
                    ? AppColors.grey
                    : (isSelected ? AppColors.blue : AppColors.blackText),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

