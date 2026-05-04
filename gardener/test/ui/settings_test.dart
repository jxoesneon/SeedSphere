import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/ui/settings/cortex_settings.dart';
import 'package:gardener/ui/settings/key_vault_settings.dart';
import 'package:gardener/ui/settings/playback_settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import '../test_setup.dart';

class MockP2PManager extends Mock implements P2PManager {}

void main() {
  setUpAll(() async {
    await setupSeedSphereTest();
    AethericGlass.useFallback = true;
  });

  Widget wrap(Widget child, [List overrides = const []]) => ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Material(child: child),
    ),
  );

  group('Settings Screens Render Test', () {
    testWidgets('KeyVaultSettings updates state', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrap(const KeyVaultSettings()));
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(
        find.widgetWithText(TextField, 'Real-Debrid API Key'),
        'test_rd_key',
      );
      await tester.pump();
    });

    testWidgets('PlaybackSettings interactions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrap(const PlaybackSettings()));
      await tester.pump(const Duration(seconds: 1));

      final toggle = find.text('Exclude CAM/Telesync');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
    });

    testWidgets('CortexSettings interactions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrap(const CortexSettings()));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Enable Neuro-Link'));
      await tester.pump();
    });
  });
}
