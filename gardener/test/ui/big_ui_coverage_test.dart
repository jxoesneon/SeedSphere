import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/screens/home_screen.dart';
import 'package:gardener/ui/screens/swarm_dashboard.dart';
import 'package:gardener/ui/screens/auth_screen.dart';
import 'package:gardener/ui/settings/addon_settings.dart';
import 'package:gardener/ui/settings/provider_settings.dart';
import 'package:gardener/ui/settings/key_vault_settings.dart';
import 'package:gardener/ui/widgets/settings/settings_scaffold.dart';
import 'package:gardener/ui/widgets/settings/settings_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../test_setup.dart';

void main() {
  setUp(() async {
    await setupSeedSphereTest();
  });

  testWidgets('Gardener UI - Core Screen Coverage', (tester) async {
    // 1. Home
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: HomeScreen())));
    expect(find.text('SEEDSPHERE 2.0'), findsOneWidget);

    // 2. Dashboard
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: SwarmDashboard())));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SwarmDashboard), findsOneWidget);

    // 3. Auth
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: AuthScreen(onAuthenticated: () {}),
      ),
    ));
    expect(find.text('SEEDSPHERE'), findsOneWidget);
  });

  testWidgets('Gardener UI - Settings Coverage', (tester) async {
    // 1. Addon Settings
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: AddonSettings())));
    await tester.pump(const Duration(seconds: 1)); 
    expect(find.text('ADDON CONFIGURATION'), findsOneWidget);
    
    // 2. Provider Settings
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: ProviderSettings())));
    expect(find.text('CONTENT PROVIDERS'), findsOneWidget);

    // 3. Key Vault Settings
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: KeyVaultSettings())));
    expect(find.text('KEY VAULT'), findsOneWidget);

    // 4. Low-level widgets
    await tester.pumpWidget(MaterialApp(
      home: SettingsScaffold(
        title: 'Test',
        child: SettingsSection(
          title: 'Section',
          children: [const Text('Child')],
        ),
      ),
    ));
    expect(find.text('SECTION'), findsOneWidget);
    expect(find.text('Child'), findsOneWidget);
  });
}
