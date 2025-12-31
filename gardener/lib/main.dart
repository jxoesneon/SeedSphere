import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/core/local_kms.dart';
import 'package:gardener/core/keys_helper.dart' as keys_helper;

import 'package:gardener/ui/screens/home_screen.dart';
import 'package:gardener/core/router.dart';

/// The entrance point for the SeedSphere 2.0 application.
///
/// Responsible for:
/// 1. Bootstrapping Flutter bindings.
/// 2. Initializing core security services ([LocalKMS]).
/// 3. Ensuring essential API keys exist.
/// 4. Wrapping the app in a [ProviderScope] for Riverpod state management.
/// 5. Configuring the global "Aetheric" theme.
///
/// **Architecture Note:**
/// The application uses Riverpod for dependency injection and state management.
/// Heavy P2P logic is offloaded to a background isolate (managed by `P2PManager`).
// coverage:ignore-start
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize minimal core services before UI launch
  final kms = LocalKMS();

  // Prevent app crash on first launch by ensuring placeholder keys exist
  await keys_helper.ensureKeysExist(kms);

  runApp(const ProviderScope(child: GardenerApp()));
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
    return MaterialApp.router(
      title: 'SeedSphere 2.0',
      debugShowCheckedModeBanner: false,

      // Apply the custom dark theme with Outfit typography
      theme: AethericTheme.darkTheme.copyWith(
        textTheme: GoogleFonts.outfitTextTheme(
          AethericTheme.darkTheme.textTheme,
        ),
      ),

      // GoRouter configuration
      routerConfig: router,
    );
  }
}
