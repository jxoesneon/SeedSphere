import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gardener/core/debug_logger.dart';
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
void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      runApp(
        const ProviderScope(child: BootstrapWrapper(child: GardenerApp())),
      );
    },
    (error, stack) {
      DebugLogger.error(
        'Uncaught Asynchronous Error',
        error: error,
        stackTrace: stack,
      );
    },
  );
}

/// A wrapper that handles the application bootstrap sequence.
///
/// Shows a loading indicator while initialization is running, and
/// displays an error screen if initialization fails.
class BootstrapWrapper extends StatefulWidget {
  final Widget child;

  const BootstrapWrapper({super.key, required this.child});

  @override
  State<BootstrapWrapper> createState() => _BootstrapWrapperState();
}

class _BootstrapWrapperState extends State<BootstrapWrapper> {
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      DebugLogger.info('Gardener: Starting bootstrap sequence...');

      // Request runtime permissions for background service (Android 13+)
      await _requestBackgroundPermissions();

      // Initialize minimal core services before UI launch
      final kms = LocalKMS();

      // Prevent app crash on first launch by ensuring placeholder keys exist
      DebugLogger.debug('Gardener: Ensuring API keys exist...');
      await keys_helper.ensureKeysExist(kms);

      // Initialize background sentinel for P2P network stability
      DebugLogger.debug('Gardener: Initializing background services...');
      await initializeService();

      // Ensure logs are visible in debug console
      if (kDebugMode) {
        DebugLogger.info('Gardener: Bootstrap complete');
        FlutterError.onError = (details) {
          FlutterError.dumpErrorToConsole(details);
          DebugLogger.error(
            'Flutter Framework Error',
            error: details.exception,
            stackTrace: details.stack,
          );
        };
      }

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e, stack) {
      DebugLogger.error('Bootstrap failed', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AethericTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to start Gardener',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                      });
                      _bootstrap();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AethericTheme.darkTheme,
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.deepPurpleAccent),
                SizedBox(height: 24),
                Text(
                  'Initializing SeedSphere...',
                  style: TextStyle(color: Colors.white70, letterSpacing: 1.2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
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
