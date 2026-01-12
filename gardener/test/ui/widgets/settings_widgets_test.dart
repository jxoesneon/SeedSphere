import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/widgets/settings/settings_toggle.dart';
import 'package:gardener/ui/widgets/settings/settings_slider.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';

void main() {
  setUpAll(() {
    AethericGlass.useFallback = true;
  });

  group('SettingsToggle', () {
    testWidgets('renders correctly with title and description', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsToggle(
              title: 'Enable Swarm',
              description: 'Join the hive mind',
              value: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Enable Swarm'), findsOneWidget);
      expect(find.text('Join the hive mind'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('toggles switch when tapped', (tester) async {
      bool currentValue = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SettingsToggle(
                  title: 'Toggle Me',
                  description: 'Desc',
                  value: currentValue,
                  onChanged: (val) {
                    setState(() => currentValue = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      final switchFinder = find.byType(Switch);
      expect(tester.widget<Switch>(switchFinder).value, false);

      await tester.tap(find.byType(SettingsToggle));
      await tester.pump();

      expect(currentValue, true);
      expect(tester.widget<Switch>(switchFinder).value, true);
    });
  });

  group('SettingsSlider', () {
    testWidgets('renders with label and value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSlider(
              label: 'Bandwidth',
              value: 50.0,
              min: 0,
              max: 100,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Bandwidth: 50'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('updates value on drag', (tester) async {
      double currentValue = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SettingsSlider(
                  label: 'Value',
                  value: currentValue,
                  min: 0,
                  max: 100,
                  onChanged: (val) {
                    setState(() => currentValue = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pump();

      expect(currentValue, greaterThan(0));
    });

    testWidgets('renders discrete labels correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSlider(
              label: 'Quality',
              value: 1080.0,
              min: 720,
              max: 2160,
              discreteLabels: {720: 'HD', 1080: 'FHD', 2160: '4K'},
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('HD'), findsOneWidget);
      expect(find.text('FHD'), findsOneWidget);
      expect(find.text('4K'), findsOneWidget);
    });
  });
}
