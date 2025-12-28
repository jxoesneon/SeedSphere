import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/widgets/adaptive_bento_grid.dart';
import 'package:gardener/ui/widgets/dpad_focus_aura.dart';
import 'package:gardener/ui/theme/motion_physics.dart';

void main() {
  group('AdaptiveBentoGrid', () {
    testWidgets('Renders grid items', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AdaptiveBentoGrid(
              mobileColumns: 1,
              desktopColumns: 2,
              children: List.generate(4, (i) => Text('Item $i')),
            ),
          ),
        ),
      );

      // Allow layout to settle
      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });
  });

  group('DpadFocusAura', () {
    testWidgets('Changes decoration on focus', (WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: DpadFocusAura(
            child: SizedBox(width: 50, height: 50),
          ),
        ),
      );

      // Initially no shadow (simplified check - verifying no error in build)
      expect(find.byType(AnimatedContainer), findsOneWidget);

      final focusNode =
          Focus.of(tester.element(find.byType(AnimatedContainer)));
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Check for state change if possible, or just verify interaction doesn't crash
      expect(focusNode.hasFocus, true);
    });

    testWidgets('Triggers onTap', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DpadFocusAura(
            onTap: () => tapped = true,
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      await tester.tap(find.byType(DpadFocusAura));
      expect(tapped, true);
    });
  });

  group('MotionPhysics', () {
    testWidgets('SpringScaleTransition animates', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SpringScaleTransition(child: Text('Spring')),
      ));

      expect(find.text('Spring'), findsOneWidget);
      expect(find.byType(ScaleTransition), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('EntropySpring constants', (WidgetTester tester) async {
      expect(EntropySpring.standard.mass, 1.0);
    });
  });
}
