import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/screens/home_screen.dart';

import 'package:gardener/ui/widgets/aetheric_glass.dart';

void main() {
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
}
