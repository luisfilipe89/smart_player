import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alchemist/alchemist.dart';

/// Simplified games screen widget for golden tests
class TestGamesScreen extends StatelessWidget {
  final bool isEmpty;

  const TestGamesScreen({super.key, this.isEmpty = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Games'),
        backgroundColor: Colors.blue[600],
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
      ),
      body: isEmpty ? _buildEmptyState() : _buildGamesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No games organized',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first game',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('Organize Game'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGameCard('Soccer Match', 'Central Park', 'Tomorrow 3:00 PM',
            '8/10', Icons.sports_soccer, Colors.green),
        _buildGameCard('Basketball Game', 'Sports Center', 'Today 6:00 PM',
            '6/8', Icons.sports_basketball, Colors.orange),
        _buildGameCard('Tennis Session', 'Tennis Club', 'Friday 10:00 AM',
            '2/4', Icons.sports_tennis, Colors.blue),
        _buildGameCard('Beach Volleyball', 'Beach Court', 'Sunday 2:00 PM',
            '10/12', Icons.sports_volleyball, Colors.amber),
      ],
    );
  }

  Widget _buildGameCard(String title, String location, String time,
      String players, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
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
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  time,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('Games Screen Golden Tests', () {
    goldenTest(
      'Games screen with games list',
      fileName: 'games_screen_with_list',
      builder: () => MaterialApp(home: const TestGamesScreen(isEmpty: false)),
    );

    goldenTest(
      'Games screen empty state',
      fileName: 'games_screen_empty',
      builder: () => MaterialApp(home: const TestGamesScreen(isEmpty: true)),
    );
  });
}
