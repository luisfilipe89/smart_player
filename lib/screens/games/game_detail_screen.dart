import 'package:flutter/material.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/theme/_theme.dart';

class GameDetailScreen extends StatelessWidget {
  final Game game;
  const GameDetailScreen({super.key, required this.game});

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

  @override
  Widget build(BuildContext context) {
    final sportColor = _colorForSport(game.sport);
    return Scaffold(
      appBar: AppBar(
        title: Text(game.sport.toUpperCase()),
        backgroundColor: AppColors.white,
        elevation: 0,
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
                    tag: 'game-${game.id}-icon',
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sportColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_iconForSport(game.sport),
                          size: 28, color: sportColor),
                    ),
                  ),
                  const SizedBox(width: AppWidths.regular),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(game.location, style: AppTextStyles.h3),
                        const SizedBox(height: 2),
                        Text('${game.formattedDate} • ${game.formattedTime}',
                            style: AppTextStyles.bodyMuted),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppHeights.huge),
              if (game.description.isNotEmpty)
                Text(game.description, style: AppTextStyles.body),
            ],
          ),
        ),
      ),
    );
  }
}
