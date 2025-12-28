import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:flutter/foundation.dart';

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
          AndroidFlutterLocalNotificationsPlugin>()
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

  // P2P Heartbeat logic will go here
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    await sentinelTick(service);
  });
}

@visibleForTesting
Future<void> sentinelTick(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    if (await service.isForegroundService()) {
      await service.setForegroundNotificationInfo(
        title: "SeedSphere Sentinel",
        content: "Swarm Connected | Peers: Active",
      );
    }
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
