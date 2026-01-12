import 'package:flutter/foundation.dart';
import 'package:gardener/core/debug_logger.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/providers/debrid_provider.dart';
import 'package:gardener/core/providers/real_debrid_provider.dart';
import 'package:gardener/core/providers/all_debrid_provider.dart';
import 'package:gardener/core/providers/orion_provider.dart';
import 'package:gardener/core/providers/premiumize_provider.dart';

/// High-level resolver for converting magnet links into direct playback URLs.
///
/// Orchestrates the workflow of adding magnet links to the configured Debrid service
/// and obtaining direct streaming URLs. Supports Real-Debrid, AllDebrid, and Orion.
class StreamResolver {
  final ConfigManager _config;
  final DebridProvider? _testProvider;

  // Expose config for server use (e.g. prefix determination)
  ConfigManager get config => _config;

  /// Creates a new [StreamResolver] instance.
  ///
  /// [config] - Optional [ConfigManager] injection.
  /// [provider] - Optional [DebridProvider] for testing (bypasses config factory).
  StreamResolver({ConfigManager? config, DebridProvider? provider})
    : _config = config ?? ConfigManager(),
      _testProvider = provider;

  /// Returns the active [DebridProvider] based on configuration.
  @visibleForTesting
  /// Returns the prioritized list of [DebridProvider]s based on configuration.
  Future<List<DebridProvider>> getProviders() async {
    if (_testProvider != null) return [_testProvider];

    final primary = _config.debridService;
    final all = <String, Future<String?>>{
      'real_debrid': _config.getRealDebridToken(),
      'all_debrid': _config.getAllDebridApiKey(),
      'premiumize': _config.getPremiumizeApiKey(),
      'orion': _config.getOrionApiKey(),
    };

    final results = <DebridProvider>[];

    // Add primary first
    final primaryKey = await all[primary];
    if (primaryKey != null && primaryKey.isNotEmpty) {
      results.add(_createProvider(primary, primaryKey));
    }

    // Add others if failover enabled
    if (_config.providerFailover) {
      for (final entry in all.entries) {
        if (entry.key == primary) continue;
        final key = await entry.value;
        if (key != null && key.isNotEmpty) {
          results.add(_createProvider(entry.key, key));
        }
      }
    }

    return results;
  }

  DebridProvider _createProvider(String type, String key) {
    switch (type) {
      case 'all_debrid':
        return AllDebridProvider(key);
      case 'premiumize':
        return PremiumizeProvider(key);
      case 'orion':
        return OrionProvider(key);
      case 'real_debrid':
      default:
        return RealDebridProvider(key);
    }
  }

  @visibleForTesting
  Future<DebridProvider> getProvider() async {
    final list = await getProviders();
    if (list.isEmpty) throw Exception('No debrid providers configured');
    return list.first;
  }

  /// Resolves a magnet link or infohash to a direct playback URL.
  /// [magnetOrHash] - The magnet link URI or infohash string.
  /// [episodeMatcher] - Optional regex to match specific file (e.g. S01E02) inside the torrent.
  Future<String?> resolveStream(
    String magnetOrHash, {
    RegExp? episodeMatcher,
  }) async {
    DebugLogger.info('StreamResolver: Starting resolution for $magnetOrHash');
    final providers = await getProviders();
    if (providers.isEmpty) {
      DebugLogger.error('StreamResolver: No providers configured');
      return null;
    }

    for (final provider in providers) {
      try {
        final result = await _resolveWithProvider(
          provider,
          magnetOrHash,
          episodeMatcher: episodeMatcher,
        );
        if (result != null) return result;
      } catch (e) {
        DebugLogger.warn('StreamResolver: Provider ${provider.id} failed: $e');
        if (!_config.providerFailover) break;
      }
    }
    return null;
  }

  Future<String?> _resolveWithProvider(
    DebridProvider provider,
    String magnetOrHash, {
    RegExp? episodeMatcher,
  }) async {
    DebugLogger.debug(
      'StreamResolver: Attempting resolution with ${provider.id}',
    );
    // 1. Convert raw infohash to magnet URI if needed
    final magnet = magnetOrHash.startsWith('magnet:')
        ? magnetOrHash
        : 'magnet:?xt=urn:btih:$magnetOrHash';

    // 2. Add magnet to Provider with background option
    final addResult = await provider.addMagnet(
      magnet,
      options: {'background': _config.backgroundDownload},
    );
    final id = addResult['id'] as String;
    DebugLogger.debug(
      'StreamResolver: [${provider.id}] Magnet added with ID: $id',
    );

    // 3. Early exit if background download is requested
    if (_config.backgroundDownload) {
      return 'seedsphere://background-download-started?id=$id&provider=${provider.id}';
    }

    // 4. Initial fetch of torrent info
    Map<String, dynamic> info = await provider.getTorrentInfo(id);

    // 4. Wait for torrent to be ready for file selection if needed
    int infoAttempts = 0;
    while (info['status'] == 'magnet_conversion' && infoAttempts < 15) {
      await Future.delayed(Duration(milliseconds: 500 + (infoAttempts * 200)));
      info = await provider.getTorrentInfo(id);
      infoAttempts++;
    }

    // 5. Handle file selection if needed
    String? matchedFileId;
    if (info['status'] == 'waiting_files_selection') {
      final List files = info['files'] ?? [];
      if (files.isEmpty) return null;

      String targetId = '';
      int largestSize = 0;
      final videoExtensions = ['.mkv', '.mp4', '.avi', '.mov', '.wmv'];

      if (episodeMatcher != null) {
        for (final f in files) {
          final path = (f['path'] as String? ?? '');
          final name = path.split('/').last;
          if (episodeMatcher.hasMatch(name)) {
            final size = (f['bytes'] as num?)?.toInt() ?? 0;
            if (size > largestSize) {
              largestSize = size;
              targetId = f['id']?.toString() ?? '';
            }
          }
        }
      }

      if (targetId.isEmpty) {
        largestSize = 0;
        for (int i = 0; i < files.length; i++) {
          final f = files[i];
          final path = (f['path'] as String? ?? '').toLowerCase();
          final size = (f['bytes'] as num?)?.toInt() ?? 0;
          final fileId = f['id']?.toString() ?? (i + 1).toString();
          final isVideo = videoExtensions.any((ext) => path.endsWith(ext));
          if (isVideo && size > largestSize) {
            largestSize = size;
            targetId = fileId;
          }
        }
      }

      if (targetId.isNotEmpty) {
        matchedFileId = targetId;
        await provider.selectFiles(id, targetId);
        info = await provider.getTorrentInfo(id);
      }
    }

    // 6. Poll until downloaded
    int attempts = 0;
    const maxAttempts = 20;
    while (info['status'] != 'downloaded' && attempts < maxAttempts) {
      if (info['status'] == 'error' ||
          info['status'] == 'dead' ||
          info['status'] == 'virus') {
        return null;
      }
      await Future.delayed(Duration(seconds: 1 + (attempts ~/ 5)));
      info = await provider.getTorrentInfo(id);
      attempts++;
    }

    if (info['status'] != 'downloaded') return null;

    final List links = info['links'] ?? [];
    if (links.isEmpty) return null;

    String linkToUnrestrict = '';
    final List files = info['files'] ?? [];

    if (matchedFileId != null && info['status'] == 'downloaded') {
      if (links.length == 1) {
        linkToUnrestrict = links.first.toString();
      } else {
        final List selectedIndices = (info['selected_files'] as List? ?? [])
            .map((e) => e.toString())
            .toList();
        final targetIndex = selectedIndices.indexOf(matchedFileId);
        if (targetIndex != -1 && targetIndex < links.length) {
          linkToUnrestrict = links[targetIndex].toString();
        }
      }
    }

    if (linkToUnrestrict.isEmpty && episodeMatcher != null) {
      for (final f in files) {
        final path = (f['path'] as String? ?? '');
        final name = path.split('/').last;
        if (episodeMatcher.hasMatch(name) && f['link'] != null) {
          linkToUnrestrict = f['link'].toString();
          break;
        }
      }
    }

    if (linkToUnrestrict.isEmpty) {
      linkToUnrestrict = links.first.toString();
    }

    final unrestrictRes = await provider.unrestrictLink(linkToUnrestrict);
    return unrestrictRes['download'];
  }

  /// Checks availability of hashes with the configured provider.
  Future<Map<String, bool>> checkAvailability(List<String> hashes) async {
    if (hashes.isEmpty) return {};
    try {
      final provider = await getProvider();
      return await provider.checkAvailability(hashes);
    } catch (e) {
      DebugLogger.warn('StreamResolver: Cache check failed: $e');
      return {};
    }
  }
}
