import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/ui/settings/optimization_settings.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:gardener/ui/widgets/settings/settings_dropdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ConfigManager().init();
    AethericGlass.useFallback = true;
  });

  Widget createSubject() {
    return const MaterialApp(home: OptimizationSettings());
  }

  testWidgets('OptimizationSettings renders headers and basic info', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('OPTIMIZATION'), findsOneWidget);
    expect(find.text('VALIDATION & PROBING'), findsOneWidget);
    expect(find.text('SWARM SCRAPING'), findsOneWidget);
    expect(find.textContaining('Tune performance'), findsOneWidget);
  });

  testWidgets('Validation mode dropdown works', (tester) async {
    // Reset
    ConfigManager().validationMode = 'basic';
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Verify initial
    expect(find.text('Basic (DNS + HTTP Head)'), findsOneWidget);

    // Open dropdown
    await tester.tap(find.byType(SettingsDropdown<String>));
    await tester.pumpAndSettle();

    // Select Aggressive
    await tester.tap(find.text('Aggressive (Full Probe)').last);
    await tester.pumpAndSettle();

    expect(ConfigManager().validationMode, 'aggressive');
  });

  testWidgets('Toggle Probe Providers works', (tester) async {
    // Start with false (default is false in SharedPreferences mock if key missing? No, code says ?? false)
    ConfigManager().probeProviders = false;

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    final toggleFinder = find.text('Probe Providers');

    await tester.tap(toggleFinder); // Taps text inside SettingsToggle
    await tester.pumpAndSettle();

    expect(ConfigManager().probeProviders, true);
  });

  testWidgets('Input fields update config', (tester) async {
    ConfigManager().probeTimeoutMs = 500;

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    final fieldFinder = find.widgetWithText(TextField, 'Probe Timeout (ms)');

    await tester.enterText(fieldFinder, '999');
    await tester.pump();

    // OnChanged calls _saveInt immediately
    expect(ConfigManager().probeTimeoutMs, 999);
  });

  testWidgets('Swarm conditional UI works', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    ConfigManager().swarmEnabled = false;

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Sub-settings hidden
    expect(find.text('Missing Only'), findsNothing);

    // Submit toggle enable
    await tester.tap(find.text('Enable Swarm'));
    await tester.pumpAndSettle(); // Animation

    expect(ConfigManager().swarmEnabled, true);

    // Sub-settings visible
    final missingOnlyFinder = find.text('Missing Only');
    expect(missingOnlyFinder, findsOneWidget);

    // Interact with sub-setting
    await tester.ensureVisible(missingOnlyFinder);
    await tester.tap(missingOnlyFinder);
    await tester.pumpAndSettle();

    expect(ConfigManager().swarmMissingOnly, false);
  });
}
