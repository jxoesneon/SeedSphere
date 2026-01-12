import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/ui/widgets/settings/expandable_section.dart';
import 'package:gardener/ui/widgets/signal_card.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';

// Mock Dependencies
class MockP2PManager extends Mock implements P2PManager {}

void main() {
  late MockP2PManager mockP2PManager;

  setUpAll(() {
    AethericGlass.useFallback = true;
  });

  setUp(() {
    mockP2PManager = MockP2PManager();
  });

  group('ExpandableSection', () {
    testWidgets('renders collapsed state correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpandableSection(
              title: 'Advanced Settings',
              icon: Icons.settings,
              collapsedSummary: 'Manage internal settings',
              child: Text('Hidden Content'),
            ),
          ),
        ),
      );

      expect(find.text('ADVANCED SETTINGS'), findsOneWidget);
      expect(find.text('Manage internal settings'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    });

    testWidgets('expands and shows content on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                ExpandableSection(
                  title: 'Section',
                  icon: Icons.info,
                  child: Text('Hidden Content'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ExpandableSection));
      await tester.pumpAndSettle();

      expect(find.text('Hidden Content'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
    });

    testWidgets('renders badge when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpandableSection(
              title: 'Badge Test',
              icon: Icons.star,
              badge: 'New',
              child: Container(),
            ),
          ),
        ),
      );

      expect(find.text('New'), findsOneWidget);
    });
  });

  group('SignalCard', () {
    testWidgets('renders basic info correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [p2pManagerProvider.overrideWithValue(mockP2PManager)],
          child: MaterialApp(
            home: Scaffold(
              body: SignalCard(
                title: 'Big Buck Bunny',
                subtitle: '2008 • 1080p',
                seeders: 42,
                source: 'YTS',
                magnet: 'magnet:?xt=urn:btih:test',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Big Buck Bunny'), findsOneWidget);
      expect(find.text('2008 • 1080p'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('YTS'), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
    });

    testWidgets('renders pending state when magnet is missing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [p2pManagerProvider.overrideWithValue(mockP2PManager)],
          child: MaterialApp(
            home: Scaffold(
              body: SignalCard(
                title: 'Pending Movie',
                seeders: 0,
                id: 'tt1234567',
              ),
            ),
          ),
        ),
      );

      expect(find.text('PENDING'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
    });

    testWidgets('opens details sheet on tap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [p2pManagerProvider.overrideWithValue(mockP2PManager)],
          child: MaterialApp(
            home: Scaffold(
              body: SignalCard(
                title: 'Tap Me',
                seeders: 10,
                magnet: 'magnet:?xt=urn:btih:tap',
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SignalCard));
      await tester.pumpAndSettle();

      // Verify Sheet Content
      expect(find.text('COPY MAGNET'), findsOneWidget);
      expect(find.text('LAUNCH'), findsOneWidget);
    });
  });
}
