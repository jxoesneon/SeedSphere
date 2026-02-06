// ignore_for_file: avoid_print
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/debug_logger.dart';
import 'package:gardener/core/stremio_server.dart';
import 'package:gardener/p2p/p2p_manager.dart';

void main() async {
  // 1. Mock SharedPreferences for CLI environment
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});

  print('🌱 SeedSphere Gardener: Headless Runner');
  print('=======================================');

  // 2. Initialize Core Services
  await ConfigManager().init();

  // 3. Listen to DebugLogger to pipe to stdout
  DebugLogger.logsNotifier.addListener(() {
    final lastLog = DebugLogger.logs.last;
    print(
      '[${lastLog.timestamp.toIso8601String()}] [${lastLog.levelLabel}] ${lastLog.message}',
    );
    if (lastLog.error != null) {
      print('   Error: ${lastLog.error}');
    }
  });

  try {
    // 4. Start P2P Manager
    final p2p = P2PManager.instance;
    await p2p.start();
    print('✅ P2P Manager Started. ID: ${p2p.gardenerId}');

    // 5. Start Stremio Addon Server
    await StremioServer(p2p: p2p).start(gardenerId: p2p.gardenerId);
    print('🚀 Stremio Addon Server running on port 7001');

    print('\nPress Ctrl+C to terminate...');
  } catch (e, stack) {
    print('❌ Failed to start Headless Gardener: $e');
    print(stack);
    exit(1);
  }
}
