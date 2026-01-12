import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/ui/settings/swarm_uplink_settings.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockP2PManager extends Mock implements P2PManager {
  @override
  final ValueNotifier<int> peerCount = ValueNotifier(0);
  @override
  final ValueNotifier<bool> sseConnected = ValueNotifier(false);
  @override
  Stream<Map<String, dynamic>> get eventStream => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockP2PManager mockP2P;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AethericGlass.useFallback = true;
    mockP2P = MockP2PManager();
    mockP2P.peerCount.value = 5;
    when(() => mockP2P.start()).thenAnswer((_) async {});
    // Delay optimize to verify loading state
    when(() => mockP2P.optimize()).thenAnswer((_) async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
  });

  Widget createSubject() {
    return ProviderScope(
      overrides: [p2pManagerProvider.overrideWithValue(mockP2P)],
      child: const MaterialApp(home: SwarmUplinkSettings()),
    );
  }

  testWidgets('SwarmUplinkSettings renders correctly', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('SWARM UPLINK'), findsOneWidget);
    // NetworkStatusCard text for 5 peers
    expect(find.textContaining('5 peers connected'), findsOneWidget);
    expect(find.text('NETWORK MODE'), findsOneWidget);
    expect(find.text('DIAGNOSTICS'), findsOneWidget);
  });

  testWidgets('Optimize Network triggers P2P action', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Optimize Network'));
    await tester.pump(); // Start frame
    await tester.pump(
      const Duration(milliseconds: 50),
    ); // Advance time but not enough to finish

    // Verify loading state
    expect(find.text('OPTIMIZING...'), findsOneWidget);

    // Finish
    await tester.pumpAndSettle();
    verify(() => mockP2P.optimize()).called(1);

    expect(find.text('Optimize Network'), findsOneWidget); // Reset
  });

  testWidgets('Switching to Manual Mode reveals advanced settings', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Initial state: Advanced Configuration hidden
    expect(find.text('ADVANCED CONFIGURATION'), findsNothing);

    // Switch to Manual
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();

    // Advanced Config visible but collapsed
    expect(find.text('ADVANCED CONFIGURATION'), findsOneWidget);
    expect(find.text('Bootstrap Nodes'), findsNothing);

    // Expand Advanced Config
    await tester.tap(find.text('ADVANCED CONFIGURATION'));
    await tester.pumpAndSettle();

    // Check content
    expect(find.text('Bootstrap Nodes'), findsOneWidget);
    expect(find.text('Tracker Sources'), findsOneWidget);
  });
}
