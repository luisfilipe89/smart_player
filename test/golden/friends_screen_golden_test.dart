import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import '../helpers/golden_test_helper.dart';

/// Simplified friends screen widget for golden tests
class TestFriendsScreen extends StatelessWidget {
  final bool isEmpty;

  const TestFriendsScreen({super.key, this.isEmpty = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Colors.blue[600],
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {},
          ),
        ],
      ),
      body: isEmpty ? _buildEmptyState() : _buildFriendsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No friends yet',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add friends to start connecting',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add),
            label: const Text('Add Friends'),
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

  Widget _buildFriendsList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFriendTile('John Doe', 'Online', true),
        _buildFriendTile('Jane Smith', 'Away', false),
        _buildFriendTile('Bob Johnson', 'Last seen 5m ago', false),
        _buildFriendTile('Alice Brown', 'Online', true),
        _buildFriendTile('Charlie Wilson', 'Last seen 2h ago', false),
      ],
    );
  }

  Widget _buildFriendTile(String name, String status, bool isOnline) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOnline ? Colors.green : Colors.grey,
          radius: 28,
          child: Text(
            name[0],
            style: const TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(status),
        trailing: isOnline
            ? Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              )
            : null,
      ),
    );
  }
}

void main() {
  group('Friends Screen Golden Tests', () {
    testGoldens('Friends screen with friends list', (tester) async {
      await tester.pumpWidgetBuilder(
        const TestFriendsScreen(isEmpty: false),
        surfaceSize: goldenSurfaceSize(),
        wrapper: (child) => MaterialApp(home: child),
      );

      await screenMatchesGolden(tester, 'friends_screen_with_list');
    });

    testGoldens('Friends screen empty state', (tester) async {
      await tester.pumpWidgetBuilder(
        const TestFriendsScreen(isEmpty: true),
        surfaceSize: goldenSurfaceSize(),
        wrapper: (child) => MaterialApp(home: child),
      );

      await screenMatchesGolden(tester, 'friends_screen_empty');
    });
  });
}
