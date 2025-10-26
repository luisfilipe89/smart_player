import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alchemist/alchemist.dart';
import '../helpers/golden_test_helper.dart';

/// Simplified game card widget for golden tests
class TestGameCard extends StatelessWidget {
  final String title;
  final String location;
  final String time;
  final String players;
  final IconData icon;
  final Color color;

  const TestGameCard({
    super.key,
    required this.title,
    required this.location,
    required this.time,
    required this.players,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    players,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(time, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('Game Card Golden Tests', () {
    goldenTest(
      'game card with soccer match',
      fileName: 'game_card_soccer_test',
      builder: () => goldenMaterialAppWrapper(
        const TestGameCard(
          title: 'Soccer Game',
          location: 'Central Park Field',
          time: 'Tomorrow at 2:00 PM',
          players: '5/10',
          icon: Icons.sports_soccer,
          color: Colors.green,
        ),
      ),
    );

    goldenTest(
      'game card with basketball game',
      fileName: 'game_card_basketball_test',
      builder: () => goldenMaterialAppWrapper(
        const TestGameCard(
          title: 'Basketball Game',
          location: 'Sports Complex',
          time: 'Today at 6:00 PM',
          players: '3/8',
          icon: Icons.sports_basketball,
          color: Colors.orange,
        ),
      ),
    );
  });
}
