import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import '../helpers/golden_test_helper.dart';

/// Test wrapper for OfflineBanner - simplified without connectivity
class TestOfflineBanner extends StatelessWidget {
  final bool isConnected;
  final Widget child;

  const TestOfflineBanner({
    super.key,
    required this.isConnected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Simplified version showing the banner state
    return Stack(
      children: [
        child,
        Container(
          width: double.infinity,
          height: 60,
          color: isConnected ? Colors.green : Colors.red,
          child: SafeArea(
            bottom: false,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isConnected ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isConnected ? 'Back online' : 'No internet connection',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
}

void main() {
  group('OfflineBanner Golden Tests', () {
    testGoldens('OfflineBanner shows online state (green)', (tester) async {
      await tester.pumpWidgetBuilder(
        const TestOfflineBanner(
          isConnected: true,
          child: Scaffold(
            body: Center(
              child: Text('Content with online banner'),
            ),
          ),
        ),
        surfaceSize: goldenSurfaceSize(),
        wrapper: goldenMaterialAppWrapper,
      );

      await screenMatchesGolden(tester, 'offline_banner_online');
    });

    testGoldens('OfflineBanner shows offline state (red)', (tester) async {
      await tester.pumpWidgetBuilder(
        const TestOfflineBanner(
          isConnected: false,
          child: Scaffold(
            body: Center(
              child: Text('Content with offline banner'),
            ),
          ),
        ),
        surfaceSize: goldenSurfaceSize(),
        wrapper: goldenMaterialAppWrapper,
      );

      await screenMatchesGolden(tester, 'offline_banner_offline');
    });
  });
}
