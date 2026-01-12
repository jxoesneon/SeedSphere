import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/screens/home_screen.dart';
import 'package:gardener/ui/screens/auth_screen.dart';
import 'package:gardener/ui/screens/swarm_dashboard.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gardener/ui/widgets/qr_install_dialog.dart';

class MockP2PManager extends Mock implements P2PManager {
  @override
  final ValueNotifier<int> peerCount = ValueNotifier(0);
  @override
  final ValueNotifier<bool> sseConnected = ValueNotifier(false);
  @override
  final ValueNotifier<bool> hasEstablishedConnection = ValueNotifier(false);
  @override
  Stream<Map<String, dynamic>> get eventStream => const Stream.empty();
  @override
  String? get gardenerId => 'mock-id';
  @override
  Future<void> start() async {}
  @override
  Future<void> optimize() async {}
  @override
  Map<String, String> get diagnosticMetadata => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AethericGlass.useFallback = true;
  });

  Widget createSubject() {
    return const ProviderScope(child: MaterialApp(home: HomeScreen()));
  }

  group('HomeScreen Tests', () {
    testWidgets('Renders main branding', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('SEEDSPHERE 2.0'), findsOneWidget);
      expect(find.text('THE FEDERATED FRONTIER'), findsOneWidget);
      expect(find.text('ENTER SWARM'), findsOneWidget);
    });

    testWidgets('Navigates to AuthScreen when unauthenticated', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('ENTER SWARM'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('Navigates to SwarmDashboard when authenticated', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'auth_token': 'valid_token'});
      final mockP2P = MockP2PManager();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [p2pManagerProvider.overrideWithValue(mockP2P)],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ENTER SWARM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SwarmDashboard), findsOneWidget);
    });

    testWidgets('Shows QR Install Dialog through direct call', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final homeScreen = tester.widget<HomeScreen>(find.byType(HomeScreen));
      final BuildContext context = tester.element(find.byType(HomeScreen));

      // Use ipOverride to bypass NetworkInterface.list() delay
      unawaited(homeScreen.showQrInstallDialog(context, ipOverride: '1.2.3.4'));

      await tester.pumpAndSettle();

      expect(find.byType(QrInstallDialog), findsOneWidget);
      expect(find.textContaining('1.2.3.4'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);

      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      expect(find.byType(QrInstallDialog), findsNothing);
    });
  });
}
