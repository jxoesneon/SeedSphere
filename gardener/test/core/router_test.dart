import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/core/router.dart';
import 'package:gardener/ui/screens/home_screen.dart';

import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Router configuration is valid', (WidgetTester tester) async {
    // We just verify the router object has routes
    expect(router.configuration.routes.length, greaterThan(0));

    // We can verify route matching by constructing the widget
    // Note: We need fallback for Glass
    AethericGlass.useFallback = true;
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );

    // Initial route is / -> HomeScreen
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
