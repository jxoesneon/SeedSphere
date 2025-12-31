import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/screens/home_screen.dart';

import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('HomeScreen renders', (WidgetTester tester) async {
    // Enable fallback mode for glassmorphism in tests
    AethericGlass.useFallback = true;

    // Provide size for glassmorphism
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('SEEDSPHERE 2.0'), findsOneWidget);
    expect(find.text('THE FEDERATED FRONTIER'), findsOneWidget);
    expect(find.text('ENTER SWARM'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('HomeScreen handles initialToken', (WidgetTester tester) async {
    // Enable fallback
    AethericGlass.useFallback = true;
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(initialToken: 'TEST_TOKEN')),
    );
    await tester
        .pumpAndSettle(); // Wait for post frame callback and async logic

    // Expect a SnackBar or visual indication
    // Since http calls fail in test environment by default, we expect "Error" or "Linking..."
    // Just verifying that the logic triggered is enough coverage for now.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Linking device'), findsOneWidget);
  });
}
