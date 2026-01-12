import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/debug_logger.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/ui/settings/debug_logs_screen.dart';
import 'package:mockito/mockito.dart';

// Mock P2PManager
class MockP2PManager extends Mock implements P2PManager {
  @override
  Map<String, String> get diagnosticMetadata => {'status': 'mock'};

  @override
  ValueNotifier<int> get peerCount => ValueNotifier(0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockP2PManager mockP2P;

  setUp(() {
    DebugLogger.clear();
    mockP2P = MockP2PManager();
  });

  tearDown(() {
    DebugLogger.clear();
  });

  Widget createSubject() {
    return ProviderScope(
      overrides: [p2pManagerProvider.overrideWithValue(mockP2P)],
      child: const MaterialApp(home: DebugLogsScreen()),
    );
  }

  testWidgets('DebugLogsScreen shows "NO LOGS RECORDED" initially', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('NO LOGS RECORDED'), findsOneWidget);
  });

  testWidgets('DebugLogsScreen renders logs', (tester) async {
    // Add logs
    DebugLogger.info('Test Info Message', category: 'GENERAL');
    DebugLogger.error('Test Error Message', error: 'Some Error');

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('Test Info Message'), findsOneWidget);
    expect(find.text('Test Error Message'), findsOneWidget);
    expect(find.text('ERROR: Some Error'), findsOneWidget);

    // Check filtered rendering (GENERAL tag)
    expect(find.text('GENERAL'), findsWidgets);
  });

  testWidgets('Category filtering works', (tester) async {
    DebugLogger.info('Network Log', category: 'NET');
    DebugLogger.info('UI Log', category: 'UI');

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('Network Log'), findsOneWidget);
    expect(find.text('UI Log'), findsOneWidget);

    // Tap 'NET' filter
    await tester.tap(find.widgetWithText(ChoiceChip, 'NET'));
    await tester.pumpAndSettle();

    expect(find.text('Network Log'), findsOneWidget);
    expect(find.text('UI Log'), findsNothing);

    // Tap 'ALL' filter
    await tester.tap(find.text('ALL'));
    await tester.pumpAndSettle();

    expect(find.text('Network Log'), findsOneWidget);
    expect(find.text('UI Log'), findsOneWidget);
  });

  testWidgets('Clear logs button works', (tester) async {
    DebugLogger.info('Log to clear');
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('Log to clear'), findsOneWidget);

    // Tap clear button (trash icon)
    await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Log to clear'), findsNothing);
    expect(find.text('NO LOGS RECORDED'), findsOneWidget);
  });
}
