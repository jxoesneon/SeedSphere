// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/debug_logger.dart';
import 'package:gardener/core/stremio_server.dart';
import 'package:gardener/p2p/p2p_manager.dart';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // Allow real network requests

  // Mock flutter_secure_storage with in-memory storage
  final secureStorage = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (methodCall) async {
          if (methodCall.method == 'read') {
            return secureStorage[methodCall.arguments['key']];
          }
          if (methodCall.method == 'write') {
            secureStorage[methodCall.arguments['key']!] =
                methodCall.arguments['value']!;
            return null;
          }
          if (methodCall.method == 'containsKey') {
            return secureStorage.containsKey(methodCall.arguments['key']);
          }
          if (methodCall.method == 'deleteAll') {
            secureStorage.clear();
            return null;
          }
          return null;
        },
      );

  // Mock path_provider
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return Directory.systemTemp.path;
          }
          if (methodCall.method == 'getTemporaryDirectory') {
            return Directory.systemTemp.path;
          }
          return null;
        },
      );

  test(
    'Headless Gardener Runner',
    () async {
      // 1. Mock SharedPreferences & SecureStorage with Debrid Config
      SharedPreferences.setMockInitialValues({
        'debrid_service': 'real_debrid',
        'pb_background_download':
            false, // Ensure no background download during verification
      });

      // Mock Real-Debrid API Key in Secure Storage
      const storage = FlutterSecureStorage();
      await storage.write(key: 'rd_api_key', value: 'MOCKED_VERIFICATION_KEY');
      await storage.write(
        key: 'shared_secret',
        value: 'MOCKED_LINK_SECRET',
      ); // Pre-seed secret

      DebugLogger.info('🌱 SeedSphere Gardener: Headless Runner (Test Mode)');
      DebugLogger.info('===================================================');

      // 2. Initialize Core Services
      await ConfigManager().init();

      // 3. Listen to DebugLogger and log to file
      final logFile = File('gardener_headless.log');
      if (logFile.existsSync()) logFile.deleteSync();
      final sink = logFile.openWrite(mode: FileMode.append);

      DebugLogger.logsNotifier.addListener(() {
        if (DebugLogger.logs.isNotEmpty) {
          final lastLog = DebugLogger.logs.last;
          final logLine =
              '[${lastLog.timestamp.toIso8601String()}] [${lastLog.levelLabel}] ${lastLog.message}';
          print(logLine);
          sink.writeln(logLine);
        }
      });

      try {
        // 4. Start P2P Manager
        final p2p = P2PManager.instance;
        await p2p.start();
        await p2p.start();
        DebugLogger.info('✅ P2P Manager Started. ID: ${p2p.gardenerId}');

        // 5. Start Stremio Addon Server
        final server = StremioServer();
        await server.start(gardenerId: p2p.gardenerId);
        await server.start(gardenerId: p2p.gardenerId);
        DebugLogger.info('🚀 Stremio Addon Server running on port 7001');

        DebugLogger.info(
          '\nRunner is active. Triggering simulation in 5 seconds...',
        );
        await Future.delayed(const Duration(seconds: 5));

        // Keep alive for a bit to allow manual/simulated testing
        DebugLogger.info('Runner will stay alive for 2 minutes...');
        await Future.delayed(const Duration(minutes: 2));

        await server.stop();
        await server.stop();
        DebugLogger.info('Stopping runner...');
      } catch (e, stack) {
        DebugLogger.error('❌ Failed to start Headless Gardener: $e');
        DebugLogger.error(stack.toString());
        fail('Runner failed');
      } finally {
        await sink.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: Platform.environment.containsKey('CI'),
  );
}
