import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';

/// Router endpoint for heartbeat (local dev or production)
const String _routerBase = 'https://seedsphere.fly.dev';

Future<void> initializeService() async {
  // coverage:ignore-start
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return;
  }
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'seedsphere_sentinel',
    'SeedSphere Sentinel',
    description: 'Ensures P2P network stability.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'seedsphere_sentinel',
      initialNotificationTitle: 'SeedSphere Sentinel',
      initialNotificationContent: 'P2P Swarm Active',
      foregroundServiceTypes: [AndroidForegroundType.specialUse],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
  // coverage:ignore-end
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // P2P Heartbeat logic - send heartbeat to router every 30s
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    await sentinelTick(service);
  });
}

@visibleForTesting
Future<void> sentinelTick(ServiceInstance service) async {
  // Send heartbeat to router
  await _sendHeartbeat();

  if (service is AndroidServiceInstance) {
    if (await service.isForegroundService()) {
      await service.setForegroundNotificationInfo(
        title: "SeedSphere Sentinel",
        content: "Swarm Connected | Heartbeat Active",
      );
    }
  }
}

/// Sends heartbeat to the router with user credentials.
Future<void> _sendHeartbeat() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final authToken = prefs.getString('auth_token');

    if (userId == null || userId.isEmpty) {
      return; // Not logged in, skip heartbeat
    }

    final uri = Uri.parse('$_routerBase/api/rooms/$userId/heartbeat');
    await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
    );
  } catch (e) {
    // Silently fail - background service shouldn't crash on network errors
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
