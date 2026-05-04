import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:gardener/ui/widgets/activity_chart.dart';
import 'package:gardener/ui/widgets/signal_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('AethericGlass rendering', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AethericGlass(
            child: Text('Glass Content'),
          ),
        ),
      ),
    );
    expect(find.text('Glass Content'), findsOneWidget);
  });

  testWidgets('ActivityChart rendering', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActivityChart(
            dataPoints: [1.0, 2.0, 3.0, 0.5, 4.0],
            title: 'Network Traffic',
          ),
        ),
      ),
    );
    expect(find.text('NETWORK TRAFFIC'), findsOneWidget); // It calls toUpperCase()
  });

  testWidgets('SignalCard rendering', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SignalCard(
              title: 'Bootstrap Node',
              subtitle: 'Online',
              seeders: 100,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Bootstrap Node'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
  });
}
