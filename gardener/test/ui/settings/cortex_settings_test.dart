import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/ui/settings/cortex_settings.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:gardener/ui/widgets/settings/settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await ConfigManager().init();
    AethericGlass.useFallback = true;
  });

  Widget createSubject() {
    return ProviderScope(
      child: MaterialApp(theme: ThemeData.dark(), home: const CortexSettings()),
    );
  }

  group('CortexSettings Tests', () {
    testWidgets('Renders with default DeepSeek free provider', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('CORTEX NEURO-LINK'), findsOneWidget);
      expect(find.textContaining('DeepSeek'), findsAtLeastNWidgets(1));
      expect(find.text('deepseek-chat'), findsOneWidget);
    });

    testWidgets('Toggles Neuro-Link', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final toggle = find.byType(Switch);
      expect(tester.widget<Switch>(toggle).value, isTrue);

      await tester.tap(toggle);
      await tester.pump();

      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(ConfigManager().neuroLinkEnabled, isFalse);
    });

    testWidgets('Switches provider and updates models', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Tap provider dropdown
      await tester.tap(find.byType(SettingsDropdown<String>).first);
      await tester.pumpAndSettle();

      // Select OpenAI
      await tester.tap(find.text('OpenAI').last);
      await tester.pumpAndSettle();

      expect(find.text('OpenAI'), findsAtLeastNWidgets(1));

      // OpenAI requires API key to show models
      expect(
        find.textContaining('Configure your OpenAI API key'),
        findsOneWidget,
      );

      final apiKeyField = find.widgetWithText(TextField, 'OpenAI API Key');
      await tester.enterText(apiKeyField, 'sk-test-key');
      await tester.pumpAndSettle();

      // Now models should be visible
      expect(find.text('gpt-5.2'), findsOneWidget);
    });

    testWidgets('Enters and saves API key for provider', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Switch to Google
      await tester.tap(find.byType(SettingsDropdown<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google').last);
      await tester.pumpAndSettle();

      final apiKeyField = find.widgetWithText(TextField, 'Google AI API Key');
      await tester.ensureVisible(apiKeyField);
      await tester.enterText(apiKeyField, 'AIza-test-key');
      await tester.pumpAndSettle();

      expect(find.text('MODEL SELECTION'), findsOneWidget);
      expect(find.text('gemini-3-pro'), findsOneWidget);
    });

    testWidgets('Adjusts Detail Level slider', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      expect(tester.widget<Slider>(slider).value, 1.0);

      await tester.drag(slider, const Offset(-200, 0));
      await tester.pump();

      expect(ConfigManager().cortexDetailLevel, 0.0);
    });

    testWidgets('Updates Performance settings', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final timeoutField = find.widgetWithText(
        TextField,
        'Request Timeout (ms)',
      );
      final cacheField = find.widgetWithText(TextField, 'Cache TTL (ms)');

      await tester.ensureVisible(timeoutField);
      await tester.enterText(timeoutField, '45000');
      await tester.pump();
      expect(ConfigManager().aiTimeoutMs, 45000);

      await tester.ensureVisible(cacheField);
      await tester.enterText(cacheField, '120000');
      await tester.pump();
      expect(ConfigManager().aiCacheTtlMs, 120000);
    });
  });
}
