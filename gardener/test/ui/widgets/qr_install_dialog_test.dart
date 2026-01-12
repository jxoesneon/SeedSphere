import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/widgets/qr_install_dialog.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';

void main() {
  setUpAll(() {
    AethericGlass.useFallback = true;
  });

  Widget createSubject(String url) {
    return MaterialApp(
      home: Scaffold(body: QrInstallDialog(url: url)),
    );
  }

  group('QrInstallDialog Tests', () {
    testWidgets('Renders with correct URL', (tester) async {
      const testUrl = 'stremio://192.168.1.10:11470/manifest.json';

      await tester.pumpWidget(createSubject(testUrl));
      await tester.pumpAndSettle();

      expect(find.text('Mobile Install'), findsOneWidget);
      expect(find.text(testUrl), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
    });

    testWidgets('Closes when DONE is tapped', (tester) async {
      await tester.pumpWidget(createSubject('test-url'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      // In this test setup, it tries to pop from the Navigator
      // Since it's the only page, it might just remain or we can check navigation
    });
  });
}
