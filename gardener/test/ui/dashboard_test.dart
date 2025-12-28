import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/screens/swarm_dashboard.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
    AethericGlass.useFallback = true;
  });

  group('SwarmDashboard Tests', () {
    testWidgets('Dashboard renders main sections', (WidgetTester tester) async {
      // Create a mock app with routes because Dashboard navigates
      await tester.pumpWidget(MaterialApp(
        home: const SwarmDashboard(),
        routes: {
          '/settings': (_) => const Scaffold(body: Text('Settings Screen')),
        },
      ));

      await tester.pumpAndSettle();

      // Verify Headers and Stats
      expect(find.text('SWARM NODE'), findsOneWidget);
      expect(find.text('PEERS'), findsOneWidget);
      expect(find.text('LATENCY'), findsOneWidget);

      // Verify Content
      expect(find.text('Cosmos Laundromat'), findsOneWidget);
      expect(find.textContaining('1240 Seeds'),
          findsOneWidget); // Part of "$type • $seeds Seeds" might need finding by subtext or full string construction

      // Interact
      await tester.enterText(find.byType(TextField), 'Test Search');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings_input_antenna_rounded));
      await tester.pumpAndSettle();

      // Expect Settings Menu
      expect(find.text('NODE CONFIGURATION'), findsOneWidget);
      expect(find.text('Swarm Uplink'), findsOneWidget);

      // Since it navigates to SwarmSettingsMenu, and that is a real widget,
      // we should verify something from SwarmSettingsMenu appears if the route builder was real.
      // But in the test I passed `home: SwarmDashboard()`, so it uses the real `SwarmSettingsMenu` unless I mocked the navigator.
      // Line 47: Navigator.push(MaterialPageRoute(builder: (_) => const SwarmSettingsMenu()));
      // So it will try to render SwarmSettingsMenu. That is good for coverage!
    });
  });
}
