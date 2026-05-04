import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/screens/expert_screen.dart';
import 'package:gardener/ui/screens/swarm_dashboard.dart';
import 'package:gardener/ui/settings/playback_settings.dart';
import 'package:gardener/ui/settings/cortex_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../test_setup.dart';

void main() {
  setUp(() async {
    await setupSeedSphereTest();
  });

  testWidgets('Gardener UI - Deep Screen Coverage', (tester) async {
    // 1. Swarm Dashboard ( Observatory )
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: SwarmDashboard())));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SwarmDashboard), findsOneWidget);
    // Tap to toggle logs
    await tester.tap(find.byKey(const ValueKey('graph')));
    await tester.pumpAndSettle();

    // 2. Expert Screen ( Swarm Intelligence )
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: ExpertScreen())));
    expect(find.byType(AppBar), findsOneWidget);

    // 3. Playback Settings
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: PlaybackSettings())));
    expect(find.byIcon(Icons.movie_filter_rounded), findsOneWidget);

    // 4. Cortex Settings
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: CortexSettings())));
    expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);
  });
}
