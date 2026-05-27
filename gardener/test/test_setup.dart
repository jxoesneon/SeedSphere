import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global test setup for SeedSphere Gardener.
Future<void> setupSeedSphereTest() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // 1. Disable Google Fonts in tests and provide fallbacks
  GoogleFonts.config.allowRuntimeFetching = false;

  // Register a dummy license to suppress warnings
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(<String>['Outfit', 'FiraCode'], 'Dummy license');
  });

  // 2. Mock path_provider
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (MethodCall methodCall) async {
    if (methodCall.method == 'getApplicationDocumentsDirectory' ||
        methodCall.method == 'getTemporaryDirectory' ||
        methodCall.method == 'getApplicationSupportDirectory') {
      return '.';
    }
    return null;
  });

  // 3. Mock storage
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});

  // 4. Initialize Config
  // ignore: avoid_print
  print('Initializing ConfigManager...');
  await ConfigManager().init();
  // ignore: avoid_print
  print('ConfigManager initialized.');
}
