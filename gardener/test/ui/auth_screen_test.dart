import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/ui/screens/auth_screen.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('AuthScreen renders correct UI', (WidgetTester tester) async {
    // Disable Shaders for test
    AethericGlass.useFallback = true;

    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthScreen())),
    );

    // Verify Title
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('SeedSphere'), findsOneWidget);

    // Verify Inputs
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Enter your email'), findsOneWidget);

    // Verify Buttons
    expect(find.text('Send Magic Link'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
}
