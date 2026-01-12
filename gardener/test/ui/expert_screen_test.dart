import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/ui/screens/expert_screen.dart';
import 'package:gardener/ui/widgets/activity_chart.dart';
import 'package:gardener/ui/widgets/live_log.dart';
import 'package:gardener/ui/widgets/scraper_spectrum.dart';
import 'package:gardener/ui/widgets/density_chart.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:mocktail/mocktail.dart';

class MockP2PManager extends Mock implements P2PManager {}

void main() {
  late MockP2PManager mockP2P;
  late StreamController<Map<String, dynamic>> eventController;

  setUp(() {
    mockP2P = MockP2PManager();
    eventController = StreamController<Map<String, dynamic>>.broadcast();

    when(() => mockP2P.peerCount).thenReturn(ValueNotifier<int>(10));
    when(() => mockP2P.eventStream).thenAnswer((_) => eventController.stream);
    when(() => mockP2P.diagnosticMetadata).thenReturn({
      'status': 'Connected',
      'peerId': 'test-peer-id',
      'addresses': '/ip4/127.0.0.1/tcp/4001',
    });
    when(() => mockP2P.gardenerId).thenReturn('test-gardener-id');
  });

  tearDown(() {
    eventController.close();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [p2pManagerProvider.overrideWithValue(mockP2P)],
      child: const MaterialApp(home: ExpertScreen()),
    );
  }

  group('ExpertScreen Widgets', () {
    testWidgets('ExpertScreen renders all core components', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(); // Allow ticker to start

      expect(find.text('Swarm Intelligence'), findsOneWidget);
      expect(find.byType(ActivityChart), findsNWidgets(2));
      expect(find.byType(ScraperSpectrum), findsOneWidget);
      expect(find.byType(DensityChart), findsOneWidget);
      expect(find.byType(LiveLog), findsOneWidget);
    });

    testWidgets('ExpertScreen displays diagnostic metadata', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('test-peer-id'), findsOneWidget);
      expect(find.text('/ip4/127.0.0.1/tcp/4001'), findsOneWidget);
      expect(find.text('test-gardener-id'), findsOneWidget);
    });

    testWidgets('ActivityChart renders with data points', (tester) async {
      final data = [0.0, 50.0, 100.0, 50.0, 0.0];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityChart(dataPoints: data, title: 'TEST CHART'),
          ),
        ),
      );

      expect(find.text('TEST CHART'), findsOneWidget);
      // LineChart is complex to verify deeply in widget test, but we check it exists
      expect(find.byType(ActivityChart), findsOneWidget);
    });

    testWidgets('LiveLog displays incoming logs', (tester) async {
      final logs = ['Log 1', 'Log 2'];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LiveLog(logs: logs)),
        ),
      );

      expect(find.text('SYSTEM LOG'), findsOneWidget);
      expect(find.text('Log 1'), findsOneWidget);
      expect(find.text('Log 2'), findsOneWidget);
    });

    testWidgets('ScraperSpectrum renders scraper states', (tester) async {
      final scrapers = [
        ScraperState(name: 'YTS', status: ScraperStatus.done, yieldCount: 5),
        ScraperState(name: 'Torrentio', status: ScraperStatus.searching),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ScraperSpectrum(scrapers: scrapers)),
        ),
      );

      expect(find.text('NEURAL RESONANCE'), findsOneWidget);
      expect(find.text('1 / 2 ACTIVE'), findsOneWidget);
      expect(find.text('YT'), findsOneWidget); // Abbreviated
      expect(find.text('TO'), findsOneWidget); // Abbreviated
      expect(find.text('5'), findsOneWidget); // Yield count
    });

    testWidgets('DensityChart displays peer count', (tester) async {
      final history = [10.0, 12.0, 15.0];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DensityChart(peerHistory: history, title: 'DENSITY'),
          ),
        ),
      );

      expect(find.text('DENSITY'), findsOneWidget);
      expect(find.text('15 PEERS'), findsOneWidget);
    });

    testWidgets('ExpertScreen updates on P2P events', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Trigger a log event
      eventController.add({'type': 'log', 'message': 'New test log message'});
      await tester.pump();

      expect(find.textContaining('New test log message'), findsOneWidget);

      // Trigger a scraper event
      eventController.add({
        'type': 'scraper_event',
        'scraper': 'YTS',
        'event': 'done',
        'count': 42,
      });
      await tester.pump();

      expect(find.text('42'), findsOneWidget);
    });
  });
}
