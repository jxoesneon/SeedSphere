import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/core/local_kms.dart';
import 'package:gardener/core/keys_helper.dart' as keys_helper;
import 'package:gardener/background_sentinel.dart';

import 'package:gardener/ui/screens/home_screen.dart';

/// The entrance point for the SeedSphere 2.0 application.
///
/// Responsible for:
/// 1. Bootstrapping Flutter bindings.
/// 2. Requesting runtime permissions for background service.
/// 3. Initializing core security services ([LocalKMS]).
/// 4. Initializing the background sentinel service.
/// 5. Ensuring essential API keys exist.
/// 6. Wrapping the app in a [ProviderScope] for Riverpod state management.
/// 7. Configuring the global "Aetheric" theme.
///
/// **Architecture Note:**
/// The application uses Riverpod for dependency injection and state management.
/// Heavy P2P logic is offloaded to a background isolate (managed by `P2PManager`).
// coverage:ignore-start
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request runtime permissions for background service (Android 13+)
  await _requestBackgroundPermissions();

  // Initialize minimal core services before UI launch
  final kms = LocalKMS();

  // Prevent app crash on first launch by ensuring placeholder keys exist
  await keys_helper.ensureKeysExist(kms);

  // Initialize background sentinel for P2P network stability
  await initializeService();

  runApp(const ProviderScope(child: GardenerApp()));
}

/// Request runtime permissions for background service operation.
Future<void> _requestBackgroundPermissions() async {
  // Skip on non-mobile platforms
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return;
  }

  // Request notification permission (Android 13+ / iOS)
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  // Request battery optimization exemption (Android)
  if (defaultTargetPlatform == TargetPlatform.android) {
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
}
// coverage:ignore-end

/// The root widget of the application.
///
/// Configures the global [MaterialApp] with the [AethericTheme] and
/// sets [HomeScreen] as the initial route.
class GardenerApp extends StatelessWidget {
  /// Creates the root [GardenerApp].
  const GardenerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeedSphere 2.0',
      debugShowCheckedModeBanner: false,

      // Apply the custom dark theme with Outfit typography
      theme: AethericTheme.darkTheme.copyWith(
        textTheme: GoogleFonts.outfitTextTheme(
          AethericTheme.darkTheme.textTheme,
        ),
      ),

      // Default entry screen
      home: const HomeScreen(),
    );
  }
}
