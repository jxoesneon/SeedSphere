import 'package:flutter_test/flutter_test.dart';
import 'dart:isolate';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/core/metadata_normalizer.dart';
import 'package:gardener/p2p/p2p_protocol.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/core/local_kms.dart';
import 'package:gardener/core/keys_helper.dart' as keys_helper;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  group('Coverage Booster', () {
    test('AethericTheme constants', () {
      expect(AethericTheme.deepVoid, isA<Color>());
      expect(AethericTheme.aetherBlue, isA<Color>());
      expect(AethericTheme.glassBorder, isA<Color>());
      expect(AethericTheme.darkTheme, isA<ThemeData>());
    });

    test('MetadataNormalizer resolution logic', () {
      expect(
        MetadataNormalizer.normalize({'title': 'Movie 4K'}, 'test').resolution,
        '4K',
      );
      expect(
        MetadataNormalizer.normalize({'title': 'Movie UHD'}, 'test').resolution,
        '4K',
      );
      expect(
        MetadataNormalizer.normalize({
          'title': 'Movie 1080p',
        }, 'test').resolution,
        '1080p',
      );
      expect(
        MetadataNormalizer.normalize({
          'title': 'Movie 720p',
        }, 'test').resolution,
        '720p',
      );
      expect(
        MetadataNormalizer.normalize({'title': 'Movie Cam'}, 'test').resolution,
        'SD',
      );

      // Test nulls
      final norm = MetadataNormalizer.normalize({}, 'test');
      expect(norm.title, 'Unknown Stream');
      expect(norm.infoHash, '');
      expect(norm.fileIdx, null);
      expect(norm.resolution, 'SD');
    });

    test('P2PCommand Serialization', () {
      final cmd = P2PCommand(
        type: P2PCommandType.search,
        imdbId: 'tt1',
        data: {'foo': 'bar'},
      );
      final json = cmd.toJson();
      expect(json['type'], 0); // Index for search
      expect(json['imdbId'], 'tt1');

      final fromJson = P2PCommand.fromJson(json);
      expect(fromJson.type, P2PCommandType.search);
      expect(fromJson.imdbId, 'tt1');
      expect(fromJson.data?['foo'], 'bar');
    });

    test('P2PManager Client Methods (Offline)', () {
      final manager = P2PManager();
      // Should not crash, just print error or do nothing
      manager.search('tt1');
      manager.publish('tt1');
      manager.getContent('cid');
      manager.stop(); // kill null isolate
      expect(manager.isInitialized, false);
    });

    test('P2PManager Client Methods (Connected)', () async {
      final manager = P2PManager();
      final rp = ReceivePort();
      manager.toIsolatePort = rp.sendPort;

      manager.search('tt1');
      final msg = await rp.first;
      expect(msg['type'], 0); // Search
      rp.close();
    });

    test('LocalKMS CRUD', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final kms = LocalKMS();
      await kms.storeAIKey('ai_secret');
      expect(await kms.getAIKey(), 'ai_secret');

      await kms.storeDebridKey('debrid_secret');
      expect(await kms.getDebridKey(), 'debrid_secret');

      await kms.clearAll();
      expect(await kms.getAIKey(), isNull);
    });

    test('SeedStream Serialization', () {
      final stream = SeedStream(
        title: 'Title',
        infoHash: 'hash',
        resolution: '4K',
        source: 'Debrid',
        seeders: 10,
        fileIdx: '1',
      );
      final json = stream.toJson();
      expect(json['title'], 'Title');
      expect(json['fileIdx'], '1');
      expect(json['resolution'], '4K');
    });
    test('KeysHelper ensures keys', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final kms = LocalKMS();
      await keys_helper.ensureKeysExist(kms);
      expect(await kms.getAIKey(), isNotNull);

      // Idempotency
      await keys_helper.ensureKeysExist(kms);
      expect(await kms.getAIKey(), isNotNull);
    });
  });
}
