import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/settings/cortex_settings.dart';
import 'package:gardener/ui/settings/key_vault_settings.dart';
import 'package:gardener/ui/settings/playback_settings.dart';
import 'package:gardener/ui/settings/swarm_uplink_settings.dart';
import 'package:gardener/ui/settings/torznab_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:gardener/ui/widgets/aetheric_glass.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
    AethericGlass.useFallback = true;
  });

  group('Settings Screens Render Test', () {
    testWidgets('KeyVaultSettings updates state', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: KeyVaultSettings()));
      await tester.pumpAndSettle();

      // Enter text
      await tester.enterText(
          find.widgetWithText(TextField, 'Real-Debrid API Key'), 'test_rd_key');
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextField, 'Orion API Key'), 'test_orion_key');
      await tester.pump();
    });

    testWidgets('SwarmUplinkSettings interactions',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SwarmUplinkSettings()));
      await tester.pumpAndSettle();

      // Toggle switches
      await tester.tap(find.text('Auto-Bootstrap'));
      await tester.pump();

      await tester.tap(find.text('Use Custom Trackers')); // ON
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'http://tracker');
      await tester.tap(find.text('Use Custom Trackers')); // OFF
      await tester.tap(find.text('Use Custom Trackers'));
      await tester.pumpAndSettle();

      // Advanced toggles
      await tester.tap(find.text('Scrape Swarm'));
      await tester.pump();
      await tester.tap(find.text('Scrape Swarm')); // Toggle back
      await tester.pump();

      // Slider
      await tester.drag(find.byType(Slider), const Offset(50, 0));
      await tester.pumpAndSettle();

      // Checkboxes (Boost Mode)
      // Assuming 'Enable Boost Mode' text exists if it's a checkbox tile
      // Or just find by switch type if needed.
    });

    testWidgets('PlaybackSettings interactions', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: PlaybackSettings()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Exclude CAM/Telesync'));
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextField, 'Must Include (Regex)'), 'HDR');
      await tester.pump();
    });

    testWidgets('CortexSettings interactions', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: CortexSettings()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable Neuro-Link'));
      await tester.pump();

      // Slider interaction for Personality
      await tester.tap(find.text('Verbose')); // Tap label
      await tester.pump();
    });

    testWidgets('TorznabManager adds and removes endpoint',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TorznabManager()));
      await tester.pumpAndSettle();

      // Tap Add FIRST (list is empty)
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      // Enter URL and Key
      await tester.enterText(
          find.widgetWithText(TextField, 'Torznab URL'), 'http://idx.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'API Key'), 'apikey123');
      await tester.pump();

      // Verify item text exists (TextField content)
      expect(find.text('http://idx.com'), findsOneWidget);

      // Remove item
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      // Verify item removed
      expect(find.text('http://idx.com'), findsNothing);
    });
  });
}
