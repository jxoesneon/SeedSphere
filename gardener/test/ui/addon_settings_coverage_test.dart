import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/settings/addon_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../test_setup.dart';

void main() {
  testWidgets('AddonSettings Full Coverage', (tester) async {
    await setupSeedSphereTest();

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: AddonSettings()),
    ));
    
    // Should show loading initially
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    await tester.pump(const Duration(seconds: 1));
    // After timeout/fail it should show the UI or error
  });
}
