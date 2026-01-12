import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:gardener/ui/widgets/user_profile_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AethericGlass.useFallback = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 'test-user-id',
      'user_email': 'test@example.com',
      'auth_token': 'test-token',
    });
  });

  Widget createSubject() {
    return const MaterialApp(home: Scaffold(body: UserProfileDialog()));
  }

  testWidgets('UserProfileDialog renders user info', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('USER PROFILE'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('ID'), findsOneWidget);
    expect(find.text('test-user-id'), findsOneWidget);
  });

  testWidgets('Logout clears prefs and closes dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const UserProfileDialog(),
              );
            },
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open dialog
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.byType(UserProfileDialog), findsOneWidget);

    // Tap Logout
    await tester.tap(find.text('LOGOUT'));
    await tester.pumpAndSettle();

    // Dialog should be closed
    expect(find.byType(UserProfileDialog), findsNothing);

    // Prefs cleared
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('auth_token'), false);
    expect(prefs.containsKey('user_id'), false);
    expect(prefs.containsKey('user_email'), false);
  });

  testWidgets('Unlink All shows confirmation dialog', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('UNLINK ALL'));
    await tester.pumpAndSettle();

    // Check confirmation dialog
    expect(find.text('UNLINK ALL DEVICES?'), findsOneWidget);
    expect(
      find.text(
        'This will sign out all your devices. You will need to sign back in everywhere.',
      ),
      findsOneWidget,
    );

    // Cancel
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    expect(find.text('UNLINK ALL DEVICES?'), findsNothing);
  });
}
