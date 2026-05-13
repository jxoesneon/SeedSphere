import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/screens/expert_screen.dart';
import 'package:gardener/ui/screens/swarm_dashboard.dart';
import 'package:gardener/ui/settings/playback_settings.dart';
import 'package:gardener/ui/settings/cortex_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:gardener/p2p/p2p_manager.dart';
import '../test_setup.dart';

class MockP2PManager extends Mock implements P2PManager {
  @override
  final sseConnected = ValueNotifier<bool>(true);
  @override
  final peerCount = ValueNotifier<int>(5);
  @override
  final hasEstablishedConnection = ValueNotifier<bool>(true);
  @override
  Stream<Map<String, dynamic>> get eventStream => const Stream.empty();
  @override
  String? get gardenerId => 'test-id';
  @override
  Map<String, String> get diagnosticMetadata => {'status': 'ok'};
}

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() async {
    await setupSeedSphereTest();
  });

  Widget wrap(Widget child, {List overrides = const []}) => ProviderScope(
    overrides: [
      p2pManagerProvider.overrideWith((ref) => MockP2PManager()),
      ...overrides,
    ],
    child: MaterialApp(home: child),
  );

  testWidgets('SwarmDashboard renders', (tester) async {
    final mockClient = MockHttpClient();
    // Simulate a successful response for the session check and popular streams to prevent hanging
    when(() => mockClient.get(any())).thenAnswer((_) async => http.Response('{"ok":true}', 200));

    await tester.pumpWidget(wrap(SwarmDashboard(client: mockClient)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SwarmDashboard), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('ExpertScreen renders', (tester) async {
    await tester.pumpWidget(wrap(const ExpertScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AppBar), findsWidgets);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('PlaybackSettings renders', (tester) async {
    await tester.pumpWidget(wrap(const PlaybackSettings()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.movie_filter_rounded), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('CortexSettings renders', (tester) async {
    await tester.pumpWidget(wrap(const CortexSettings()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CortexSettings), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
