import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:move_young/features/matches/models/match.dart';
import 'package:move_young/features/matches/notifiers/match_form_notifier.dart';

/// Widget for selecting maximum number of players
class MatchFormMaxPlayersSlider extends ConsumerWidget {
  final Match? initialMatch;
  final MatchFormNotifier notifier;

  const MatchFormMaxPlayersSlider({
    super.key,
    required this.initialMatch,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchFormNotifierProvider(initialMatch));
    final isEdit = initialMatch != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(0, -6),
          child: Row(
            children: [
              const Icon(
                Icons.group_outlined,
                color: AppColors.grey,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: isEdit
                        ? AppColors.grey.withValues(alpha: 0.4)
                        : AppColors.blue,
                    inactiveTrackColor: isEdit
                        ? AppColors.grey.withValues(alpha: 0.2)
                        : AppColors.blue.withValues(alpha: 0.2),
                    thumbColor: isEdit ? AppColors.grey : AppColors.blue,
                    overlayColor: isEdit
                        ? AppColors.grey.withValues(alpha: 0.1)
                        : AppColors.blue.withValues(alpha: 0.1),
                    valueIndicatorColor:
                        isEdit ? AppColors.grey : AppColors.blue,
                  ),
                  child: Slider(
                    value: state.maxPlayers.toDouble(),
                    min: 2,
                    max: 10,
                    divisions: 8,
                    label: state.maxPlayers.toString(),
                    onChangeStart: (_) {
                      ref.read(hapticsActionsProvider)?.selectionClick();
                    },
                    onChanged: isEdit
                        ? null
                        : (v) {
                            notifier.setMaxPlayers(v.round());
                          },
                    onChangeEnd: (_) {
                      ref.read(hapticsActionsProvider)?.lightImpact();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: Center(
                  child: Text(
                    state.maxPlayers.toString(),
                    style: AppTextStyles.body,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
