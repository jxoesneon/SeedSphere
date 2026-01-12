import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/ui/settings/provider_settings.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ConfigManager().init();
    AethericGlass.useFallback = true;
  });

  Widget createSubject() {
    return const MaterialApp(home: ProviderSettings());
  }

  testWidgets('ProviderSettings renders all sections', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('CONTENT PROVIDERS'), findsOneWidget);
    expect(find.text('MOVIES & TV'), findsOneWidget);
    expect(find.text('ANIME'), findsOneWidget);
    expect(find.text('GENERAL'), findsOneWidget);

    expect(find.textContaining('Active Providers:'), findsOneWidget);
  });

  testWidgets('Toggling provider updates config', (tester) async {
    // Reset config
    ConfigManager().enableTorrentio = true;

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Toggle Torrentio (Movies & TV is expanded by default)
    await tester.tap(find.text('Torrentio'));
    await tester.pump();

    expect(ConfigManager().enableTorrentio, false);

    await tester.tap(find.text('Torrentio'));
    await tester.pump();
    expect(ConfigManager().enableTorrentio, true);
  });

  testWidgets('Interacting with Anime section', (tester) async {
    // Resize viewport
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    final animeHeaderFinder = find.text('ANIME');
    expect(animeHeaderFinder, findsOneWidget);

    // Expand Anime section
    await tester.tap(animeHeaderFinder);
    await tester.pumpAndSettle();

    final nyaaFinder = find.text('Nyaa');
    expect(nyaaFinder, findsOneWidget);

    final initial = ConfigManager().enableNyaa; // Capture before tap

    await tester.ensureVisible(nyaaFinder);
    await tester.tap(nyaaFinder);
    await tester.pump();

    expect(ConfigManager().enableNyaa, !initial);
  });
}
