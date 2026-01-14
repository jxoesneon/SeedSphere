import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/widgets/network_status_card.dart';
import 'package:gardener/core/network_status.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';

void main() {
  setUpAll(() {
    AethericGlass.useFallback = true;
  });

  group('NetworkStatusCard', () {
    testWidgets('displays optimal status correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkStatusCard(
              status: NetworkStatus.optimal,
              peerCount: 15,
              latencyMs: 45,
              region: 'US-East',
              onOptimize: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('15 peers connected'), findsOneWidget);
      expect(find.text('45ms'), findsOneWidget);
      expect(find.text('US-East'), findsOneWidget);
      expect(find.text('Optimize'), findsOneWidget);

      // Check Icon
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('displays offline status correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkStatusCard(
              status: NetworkStatus.offline,
              peerCount: 0,
              onOptimize: () {},
            ),
          ),
        ),
      );

      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('No network connection'), findsOneWidget);
      expect(find.text('Troubleshoot'), findsOneWidget);

      // Check Icon
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('displays degraded status correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkStatusCard(
              status: NetworkStatus.degraded,
              peerCount: 3,
              onOptimize: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text('Limited Connectivity'), findsOneWidget);
      expect(find.text('Only 3 peers available'), findsOneWidget);
      expect(find.text('Optimize'), findsOneWidget);

      // Check Icon
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });

    testWidgets('triggers callbacks on button tap', (tester) async {
      bool optimizePressed = false;
      bool detailsPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkStatusCard(
              status: NetworkStatus.optimal,
              peerCount: 10,
              onOptimize: () => optimizePressed = true,
              onShowDetails: () => detailsPressed = true,
            ),
          ),
        ),
      );

      // Tap Optimize (it might be "Optimize" or "Troubleshoot" depending on state, here it is "Optimize")
      await tester.tap(find.text('Optimize'));
      expect(optimizePressed, true);

      // Tap Details
      await tester.tap(find.text('Details'));
      expect(detailsPressed, true);
    });
  });
}
