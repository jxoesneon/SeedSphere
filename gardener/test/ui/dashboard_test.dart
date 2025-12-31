import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/screens/swarm_dashboard.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

import 'package:http/http.dart' as http;

class MockClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AethericGlass.useFallback = true;
    registerFallbackValue(Uri());
    registerFallbackValue(http.Request('GET', Uri()));
  });

  group('SwarmDashboard Tests', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      // Stub basic calls to avoid crashes
      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response('{}', 200));
      when(() => mockClient.send(any())).thenAnswer(
        (_) async => http.StreamedResponse(
          Stream.value(utf8.encode('data: {}\n\n')),
          200,
        ),
      );
    });

    testWidgets('Dashboard renders main sections', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SwarmDashboard(client: mockClient),
          routes: {
            '/settings': (_) => const Scaffold(body: Text('Settings Screen')),
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Verify Headers and Stats
      expect(find.text('SYSTEM OPTIMAL'), findsOneWidget);
      expect(find.text('CONNECTED TO 0 ACTIVE PEERS'), findsOneWidget);
      expect(find.text('POPULAR STREAMS'), findsOneWidget);

      // Verify Content
      expect(find.text('Scanning frequency bands...'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings_input_antenna_rounded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

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
