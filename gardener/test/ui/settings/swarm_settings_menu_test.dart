import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/ui/settings/swarm_settings_menu.dart';
import 'package:gardener/ui/settings/swarm_uplink_settings.dart';
import 'package:gardener/ui/settings/key_vault_settings.dart';
import 'package:gardener/ui/settings/cortex_settings.dart';
import 'package:gardener/ui/settings/playback_settings.dart';
import 'package:gardener/ui/settings/provider_settings.dart';
import 'package:gardener/ui/settings/optimization_settings.dart';
import 'package:gardener/ui/settings/debug_logs_screen.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gardener/ui/widgets/compact_settings_card.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockP2PManager extends Mock implements P2PManager {
  @override
  final ValueNotifier<int> peerCount = ValueNotifier(0);
  @override
  final ValueNotifier<bool> sseConnected = ValueNotifier(false);
  @override
  final ValueNotifier<bool> hasEstablishedConnection = ValueNotifier(false);
  @override
  Stream<Map<String, dynamic>> get eventStream => const Stream.empty();
  @override
  String? get gardenerId => 'mock-id';
  @override
  Future<void> start() async {}
  @override
  Future<void> optimize() async {}
  @override
  Map<String, String> get diagnosticMetadata => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ConfigManager().init();
    AethericGlass.useFallback = true;
  });

  Widget createSubject(MockP2PManager mockP2P) {
    return ProviderScope(
      overrides: [p2pManagerProvider.overrideWithValue(mockP2P)],
      child: const MaterialApp(home: SwarmSettingsMenu()),
    );
  }

  group('SwarmSettingsMenu Tests', () {
    late MockP2PManager mockP2P;

    setUp(() {
      mockP2P = MockP2PManager();
    });

    testWidgets('Renders all settings categories', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject(mockP2P));
      await tester.pumpAndSettle();

      expect(find.text('ENGINE ROOM'), findsOneWidget);
      expect(find.text('EXPERIENCE'), findsOneWidget);
      expect(find.text('SYSTEM'), findsOneWidget);

      expect(find.text('Swarm Uplink'), findsOneWidget);
      expect(find.text('Content Sources'), findsOneWidget);
      expect(find.text('Key Vault'), findsOneWidget);
      expect(find.text('Indexer Mesh'), findsOneWidget);
      expect(find.text('Cortex Neuro-Link'), findsOneWidget);
      expect(find.text('Playback Protocols'), findsOneWidget);
      expect(find.text('Optimization'), findsOneWidget);
      expect(find.text('Debug Console'), findsOneWidget);
    });

    testWidgets('Navigates to Swarm Uplink', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject(mockP2P));
      await tester.pumpAndSettle();

      final finder = find.widgetWithText(CompactSettingsCard, 'Swarm Uplink');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(find.byType(SwarmUplinkSettings), findsOneWidget);
    });

    testWidgets('Navigates to Key Vault', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject(mockP2P));
      await tester.pumpAndSettle();

      final finder = find.widgetWithText(CompactSettingsCard, 'Key Vault');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(find.byType(KeyVaultSettings), findsOneWidget);
    });

    testWidgets('Navigates to Cortex', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject(mockP2P));
      await tester.pumpAndSettle();

      final finder = find.widgetWithText(
        CompactSettingsCard,
        'Cortex Neuro-Link',
      );
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(find.byType(CortexSettings), findsOneWidget);
    });

    testWidgets('Navigates to Playback', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject(mockP2P));
      await tester.pumpAndSettle();

      final finder = find.widgetWithText(
        CompactSettingsCard,
        'Playback Protocols',
      );
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(find.byType(PlaybackSettings), findsOneWidget);
    });

    testWidgets('Navigates to Providers', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject(mockP2P));
      await tester.pumpAndSettle();

      final finder = find.widgetWithText(
        CompactSettingsCard,
        'Content Sources',
      );
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(find.byType(ProviderSettings), findsOneWidget);
    });

    testWidgets('Navigates to Optimization', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject(mockP2P));
      await tester.pumpAndSettle();

      final finder = find.widgetWithText(CompactSettingsCard, 'Optimization');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(OptimizationSettings), findsOneWidget);
    });

    testWidgets('Navigates to Debug Logs', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject(mockP2P));
      await tester.pumpAndSettle();

      final finder = find.widgetWithText(CompactSettingsCard, 'Debug Console');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(DebugLogsScreen), findsOneWidget);
    });
  });
}
