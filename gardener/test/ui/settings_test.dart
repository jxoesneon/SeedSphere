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

  Widget wrap(Widget child) {
    return MaterialApp(theme: ThemeData.dark(), home: child);
  }

  group('Settings Screens Render Test', () {
    testWidgets('KeyVaultSettings updates state', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const KeyVaultSettings()));
      await tester.pump(const Duration(seconds: 1));

      // Enter text
      await tester.enterText(
        find.widgetWithText(TextField, 'Real-Debrid API Key'),
        'test_rd_key',
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Orion API Key'),
        'test_orion_key',
      );
      await tester.pump();
    });

    testWidgets('SwarmUplinkSettings interactions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SwarmUplinkSettings()));
      await tester.pump(const Duration(seconds: 1));

      // Toggle to Manual Mode
      await tester.tap(
        find.byKey(const Key('network_mode_manual')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(seconds: 1));

      // Verify mode changed to manual
      expect(find.text('ADVANCED CONFIGURATION'), findsOneWidget);

      // Expand Advanced Configuration
      final advancedHeader = find.text('ADVANCED CONFIGURATION');
      await tester.tap(advancedHeader, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));

      // Toggle switches
      await tester.tap(
        find.text('Connect to SeedSphere Network'),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(
        find.text('Use Custom Trackers'),
        warnIfMissed: false,
      ); // ON
      await tester.pump(const Duration(seconds: 1));

      // Enter text - using showKeyboard to be safer
      final textField = find.byType(TextField);
      await tester.showKeyboard(textField);
      tester.testTextInput.enterText('http://tracker');
      await tester.pump();

      await tester.tap(
        find.text('Use Custom Trackers'),
        warnIfMissed: false,
      ); // OFF
      await tester.pump(const Duration(milliseconds: 500));

      // Advanced toggles
      await tester.tap(
        find.text('Real-time Peer Discovery'),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Slider
      await tester.drag(find.byType(Slider), const Offset(50, 0));
      await tester.pump(const Duration(seconds: 1));
      // Checkboxes (Boost Mode)
      // Assuming 'Enable Boost Mode' text exists if it's a checkbox tile
      // Or just find by switch type if needed.
    });

    testWidgets('PlaybackSettings interactions', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const PlaybackSettings()));
      await tester.pump(const Duration(seconds: 1));

      await tester.pump();
      await tester.tap(find.text('Exclude CAM/Telesync'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Must Include (Regex)'),
        'HDR',
      );
      await tester.pump();
    });

    testWidgets('CortexSettings interactions', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const CortexSettings()));
      await tester.pump(const Duration(seconds: 1));

      await tester.pump();
      await tester.tap(find.text('Enable Neuro-Link'));
      await tester.pump();

      // Slider interaction for Personality
      await tester.pump();
      await tester.ensureVisible(
        find.text('Balanced'),
      ); // Tap a more reachable label if Verbose is intercepted
      await tester.tap(find.text('Balanced'));
      await tester.pump();
    });

    testWidgets('TorznabManager adds and removes endpoint', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const TorznabManager()));
      await tester.pump(const Duration(seconds: 1));

      // Tap Add FIRST (list is empty)
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump(const Duration(seconds: 1));

      // Enter URL and Key
      await tester.enterText(
        find.widgetWithText(TextField, 'Torznab URL'),
        'http://idx.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'API Key'),
        'apikey123',
      );
      await tester.pump();

      // Verify item text exists (TextField content)
      expect(find.text('http://idx.com'), findsOneWidget);

      // Remove item
      await tester.ensureVisible(find.text('Remove'));
      await tester.tap(find.text('Remove'));
      await tester.pump(const Duration(seconds: 1));

      // Verify item removed
      expect(find.text('http://idx.com'), findsNothing);
    });
  });
}
