// ignore_for_file: unused_import
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/physics.dart';

// Core
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/haptic_manager.dart';
import 'package:gardener/core/identity_manager.dart';
import 'package:gardener/core/local_kms.dart';
import 'package:gardener/core/keys_helper.dart' as keys_helper;
import 'package:gardener/core/metadata_normalizer.dart';
import 'package:gardener/core/pairing_manager.dart';
import 'package:gardener/core/reputation_manager.dart';
import 'package:gardener/core/security_manager.dart';
import 'package:gardener/core/stream_resolver.dart';

// P2P
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/p2p/p2p_protocol.dart';

// Scrapers
import 'package:gardener/scrapers/scraper_engine.dart';
import 'package:gardener/scrapers/torrentio_scraper.dart';
import 'package:gardener/scrapers/yts_scraper.dart';

// UI - Screens & Settings
import 'package:gardener/ui/screens/swarm_dashboard.dart';
import 'package:gardener/ui/screens/home_screen.dart';
import 'package:gardener/ui/settings/cortex_settings.dart';
import 'package:gardener/ui/settings/key_vault_settings.dart';
import 'package:gardener/ui/settings/playback_settings.dart';
import 'package:gardener/ui/settings/swarm_settings_menu.dart';
import 'package:gardener/ui/settings/swarm_uplink_settings.dart';
import 'package:gardener/ui/settings/torznab_manager.dart';

// UI - Theme & Widgets
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/theme/motion_physics.dart';
import 'package:gardener/ui/widgets/adaptive_bento_grid.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:gardener/ui/widgets/dpad_focus_aura.dart';

// Root
import 'package:gardener/main.dart';
import 'package:gardener/background_sentinel.dart';

void main() {
  test('Ensure all files are loaded', () async {
    // Just referring to classes force loads them if not constant folded
    expect(HapticManager, isNotNull);
    await HapticManager.light();
    expect(keys_helper.ensureKeysExist, isNotNull);

    expect(EntropySpring, isNotNull); // Was MotionPhysics
    expect(EntropySpring.standard, isA<SpringDescription>());

    expect(P2PManager, isNotNull);
    // ... We just need the imports to exist.
  });
}
