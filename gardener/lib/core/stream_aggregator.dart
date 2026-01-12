import 'package:gardener/core/magnet_utils.dart';
import 'package:gardener/core/tracker_service.dart';

import 'package:gardener/core/parse_utils.dart';
import 'package:gardener/core/metadata_normalizer.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/cortex_service.dart';

import 'package:gardener/core/stream_cache.dart';

class StreamAggregator {
  final TrackerService _trackerService;
  final StreamCache _cache = StreamCache();

  final ConfigManager _config;
  final CortexService _cortex;

  StreamAggregator({
    TrackerService? trackerService,
    ConfigManager? config,
    CortexService? cortex,
  }) : _trackerService = trackerService ?? TrackerService(),
       _config = config ?? ConfigManager(),
       _cortex = cortex ?? CortexService(config: config);

  /// Checks if fresh streams exist in cache for the given ID.
  List<Map<String, dynamic>>? getCachedStreams(String id) {
    if (!_config.autoProxy) return null;
    return _cache.getFresh(id);
  }

  /// Checks if stale streams exist in cache (e.g. for fallback).
  List<Map<String, dynamic>>? getStaleStreams(String id) {
    if (!_config.autoProxy) return null;
    return _cache.getStale(id);
  }

  // Main entry point
  Future<List<Map<String, dynamic>>> aggregateStreams(
    List<Map<String, dynamic>> rawResults, {
    String? type,
    String? imdbId,
    int? season,
    int? episode,
    int? year,
    String? requestedTitle,
  }) async {
    // 0. AutoProxy Check
    if (!_config.autoProxy) {
      // If autoProxy is off, we do not aggregate/enhance.
      // We could return rawResults (if valid Stremio streams) or empty.
      // Legacy behavior: "Off (addon emits only its own demo)".
      // For a standalone app, "Off" might mean "Passthrough" or "Safety Kill".
      // Assuming "Passthrough" for now implies just returning raw if they are actionable,
      // but rawResults are scraper results, not streams.
      // So we return empty to simulate "Disabled".
      return [];
    }

    // 1. Fetch global best trackers once
    var globalTrackers = await _trackerService.getTrackers();

    // Limits
    final maxTrackers = _config.maxTrackers;
    if (maxTrackers > 0 && globalTrackers.length > maxTrackers) {
      globalTrackers = globalTrackers.sublist(0, maxTrackers);
    }

    // 1b. Prefer Encrypted (Sort HTTPS/WSS to top)
    if (_config.preferEncrypted && globalTrackers.isNotEmpty) {
      // Create a copy to sort
      globalTrackers = List<String>.from(globalTrackers);
      globalTrackers.sort((a, b) {
        final aSec = a.startsWith('https') || a.startsWith('wss');
        final bSec = b.startsWith('https') || b.startsWith('wss');
        if (aSec && !bSec) return -1;
        if (!aSec && bSec) return 1;
        return 0;
      });
    }

    // 2. Normalize and Deduplicate
    final Map<String, Map<String, dynamic>> uniqueStreams = {};

    for (var res in rawResults) {
      // Normalize
      final magnet = res['magnet']?.toString() ?? '';
      final rawHash = res['infoHash'];
      var infoHash = rawHash?.toString().toLowerCase();

      if (infoHash == null || infoHash.isEmpty) {
        // Try extract from magnet
        infoHash = MagnetUtils.getInfoHash(magnet);
      }

      if (infoHash == null || infoHash.isEmpty) continue; // Skip invalid

      if (!uniqueStreams.containsKey(infoHash)) {
        res['infoHash'] = infoHash;
        uniqueStreams[infoHash] = res;
        // Ensure magnet is set and normalized
        if (magnet.isEmpty) {
          uniqueStreams[infoHash]!['magnet'] = MagnetUtils.buildMagnet(
            infoHash,
            res['title'],
            globalTrackers,
          );
        } else {
          uniqueStreams[infoHash]!['magnet'] = MagnetUtils.normalizeMagnet(
            magnet,
          );
        }
      } else {
        // Merge logic (legacy: take better seeds/peers if available)
        final existing = uniqueStreams[infoHash]!;
        // Normalize: some scrapers use 'seeds', others use 'seeders'
        final newSeeds =
            int.tryParse((res['seeders'] ?? res['seeds'])?.toString() ?? '0') ??
            0;
        final oldSeeds =
            int.tryParse(
              (existing['seeders'] ?? existing['seeds'])?.toString() ?? '0',
            ) ??
            0;

        if (newSeeds > oldSeeds) {
          existing['seeders'] = newSeeds;
          existing['leechers'] = res['leechers'];
          // Keep provider name etc? Legacy keeps first, but updates stats.
        }
      }
    }

    final List<Map<String, dynamic>> processedList = [];
    final includeRegex = _config.includeRegex.isNotEmpty
        ? RegExp(_config.includeRegex, caseSensitive: false)
        : null;
    final excludeRegex = _config.excludeRegex.isNotEmpty
        ? RegExp(_config.excludeRegex, caseSensitive: false)
        : null;

    for (var stream in uniqueStreams.values) {
      final title = stream['title']?.toString() ?? '';

      // 1. Exclude CAM/TS if enabled
      if (_config.excludeCam) {
        if (title.contains(
          RegExp(r'CAM|TS|TELESYNC|SCREENER', caseSensitive: false),
        )) {
          continue;
        }
      }

      // 2. Exclude 3D if enabled
      if (_config.exclude3D) {
        if (title.contains(RegExp(r'3D|SBS|HALF-OU', caseSensitive: false))) {
          continue;
        }
      }

      // 3. Custom Regex Include
      if (includeRegex != null && !includeRegex.hasMatch(title)) {
        continue;
      }

      // 4. Custom Regex Exclude
      if (excludeRegex != null && excludeRegex.hasMatch(title)) {
        continue;
      }

      // 5. Max Resolution Filter (Gap Closure)
      // Check if this stream's resolution exceeds configured max
      final maxRes = _config.maxResolution; // '4k', '1080p', '720p', '480p'
      if (maxRes != '4k') {
        final resWeight = _getResolutionWeightFromTitle(title);
        final limitWeight = _getResolutionWeight(maxRes);
        if (resWeight > limitWeight) {
          continue;
        }
      }

      // 6. Content Integrity Filter (Series & Movie)
      if (requestedTitle != null && requestedTitle.isNotEmpty) {
        final naturalRequested = MetadataNormalizer.toTitleNatural(
          requestedTitle,
        ).toLowerCase();
        final naturalStream = MetadataNormalizer.toTitleNatural(
          title,
        ).toLowerCase();

        // Basic similarity: natural title should contain natural requested title
        // or vice versa (for cases where requested title is just a part of the stream title)
        if (!naturalStream.contains(naturalRequested) &&
            !naturalRequested.contains(naturalStream)) {
          // Strict mismatch
          continue;
        }
      }

      if (type == 'series' && season != null && episode != null) {
        final streamSE = ParseUtils.extractSeasonEpisode(title);
        if (streamSE != null) {
          if (streamSE['season'] != season || streamSE['episode'] != episode) {
            // Strict mismatch
            continue;
          }
        }
      } else if (type == 'movie' && year != null) {
        final streamYear = ParseUtils.extractYear(title);
        if (streamYear != null) {
          // Allow ±1 year for release dates or different regions
          if ((streamYear - year).abs() > 1) {
            continue;
          }
        }
      }

      processedList.add(stream);
    }

    // 3. Enrich & Build Description (Parallel)

    final List<Map<String, dynamic>> finalStreams = [];

    for (var stream in processedList) {
      // Parse detailed info
      final magnet = stream['magnet'].toString();
      final title = stream['title'].toString();

      // Use parse utils
      // Note: Scrapers usually provide 'title', but we re-parse for consistency
      final parsed = ParseUtils.parseReleaseInfo(magnet, title);
      final sizeData = ParseUtils.parseSize(title); // Or use stream['size']

      // 4. Inject Trackers (Prefer Encrypted / Normalize HTTPS handled in MagnetUtils if updated, or here)
      // For now we assume MagnetUtils handles protocol normalization if we pass flags to it,
      // but MagnetUtils isn't updated for that yet.
      // We will stick to appending trackers. Protocol normalization/encryption preference
      // usually happens at the generation of the magnet string or in the list we pass.

      final optimizedMagnet = MagnetUtils.appendTrackers(
        magnet,
        globalTrackers, // Uses sorted set if preferEncrypted is true
      );

      // 5. Build Description
      String description = _buildDescription(stream, parsed, sizeData);

      // 6. Cortex AI Enhancement (only for top result to save tokens/time)
      // Or we can do it for more if needed. Legacy usually does it for a few.
      if (_config.neuroLinkEnabled && finalStreams.isEmpty) {
        final aiDesc = await _cortex.generateDescription(
          title: title,
          type: type ?? 'movie',
          metadata:
              '${parsed['resolution']} ${parsed['codec']} ${sizeData['sizeStr']}',
        );
        if (aiDesc != null) {
          description = '🧠 $aiDesc\n$description';
        }
      }

      // Construct final Stremio Stream Object
      final stremioStream = {
        'name': 'SeedSphere\n${parsed['resolution'] ?? 'UNK'}',
        'title': title,
        'url': optimizedMagnet,
        'magnet': optimizedMagnet,
        'infoHash': stream['infoHash'],
        'seeders': stream['seeders'],
        'fileIdx': null, // Logic handled in StreamResolver via ID parsing
        'behaviorHints': {'bingeGroup': 'seedsphere-${parsed['resolution']}'},
        // Sort keys
        '_sort': {
          'resolution': parsed['resolution'],
          'seeds': int.tryParse(stream['seeders']?.toString() ?? '0') ?? 0,
          'sizeBytes': sizeData['sizeBytes'] ?? 0,
          'codec': parsed['codec'],
          'audio': parsed['audio'],
          'languages': parsed['languages'],
          'title': title, // Added for HDR Check
        },
      };

      // Set description
      stremioStream['description'] = description;

      finalStreams.add(stremioStream);
    }

    // 6. Sort

    // 6. Sort by user preference
    finalStreams.sort((a, b) {
      final sortBy = _config.sortBy;

      if (sortBy == 'Seeders') {
        final seedsA = a['seeders'] as int? ?? 0;
        final seedsB = b['seeders'] as int? ?? 0;
        if (seedsA != seedsB) return seedsB.compareTo(seedsA);
      } else if (sortBy == 'File Size') {
        final sizeA = (a['_sort']?['sizeBytes']) as int? ?? 0;
        final sizeB = (b['_sort']?['sizeBytes']) as int? ?? 0;
        if (sizeA != sizeB) return sizeB.compareTo(sizeA);
      }

      // Default or Tie-breaker: Weighted Score
      final scoreA = _calculateScore(a);
      final scoreB = _calculateScore(b);
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);

      // Final Tie-breakers
      final seedsA = a['seeders'] as int? ?? 0;
      final seedsB = b['seeders'] as int? ?? 0;
      if (seedsA != seedsB) return seedsB.compareTo(seedsA);

      final sizeA = (a['_sort']?['sizeBytes']) as int? ?? 0;
      final sizeB = (b['_sort']?['sizeBytes']) as int? ?? 0;
      if (sizeA != sizeB) return sizeB.compareTo(sizeA);

      return 0;
    });

    if (finalStreams.isNotEmpty && imdbId != null) {
      _cache.set(imdbId, finalStreams);
    }

    return finalStreams;
  }

  int _calculateScore(Map<String, dynamic> stream) {
    int score = 0;
    final title = (stream['title'] as String).toUpperCase();
    final resolution = stream['resolution'] as String? ?? 'SD';
    final seeds = stream['seeders'] as int? ?? 0;

    // 1. Resolution Rank (Strong weighting)
    final res = resolution.toLowerCase();
    if (res == '2160p' || res == '4k') {
      score += 10000;
    } else if (res == '1080p') {
      score += 5000;
    } else if (res == '720p') {
      score += 2000;
    } else if (res == '480p') {
      score += 500;
    }

    // 2. HDR / Dolby Vision
    if (title.contains('HDR')) score += 500;
    if (title.contains('DV') ||
        title.contains('DOLBY') ||
        title.contains('VISION')) {
      score += 800;
    }

    // 3. Premium Audio
    if (title.contains('ATMOS')) score += 400;
    if (title.contains('DTS-X') ||
        title.contains('DTS-HD') ||
        title.contains('TRUEHD')) {
      score += 300;
    }
    if (title.contains('5.1') ||
        title.contains('7.1') ||
        title.contains('DDP')) {
      score += 150;
    }

    // 4. Source Quality
    final prefSource = _config.preferredSourceType.toUpperCase();
    if (prefSource != 'ANY') {
      if (prefSource == 'BLU-RAY' &&
          (title.contains('BLURAY') || title.contains('BDREMUX'))) {
        score += 5000;
      }
      if (prefSource == 'WEB-DL' &&
          (title.contains('WEB-DL') || title.contains('WEBRIP'))) {
        score += 5000;
      }
      if (prefSource == 'HDTV' && title.contains('HDTV')) {
        score += 5000;
      }
    }

    if (title.contains('BLURAY') ||
        title.contains('BDREMUX') ||
        title.contains('REMUX')) {
      score += 1000;
    }
    if (title.contains('WEB-DL') || title.contains('WEBRIP')) {
      score += 500;
    }
    if (title.contains('HDTV')) {
      score += 200;
    }

    // 5. Codec Preference
    if (title.contains('X265') ||
        title.contains('HEVC') ||
        title.contains('AV1')) {
      score += 300;
    }
    if (title.contains('10BIT')) {
      score += 200;
    }

    // 6. Language Priority (Gap Closure)
    final prioritizedLangs = _config.prioritizedLanguages;
    if (prioritizedLangs.isNotEmpty) {
      final sa = stream['_sort'] as Map;
      final audio = (sa['audio'] as String? ?? '').toLowerCase();
      final langs = (sa['languages'] as List<dynamic>? ?? [])
          .map((e) => e.toString().toLowerCase())
          .toList();

      for (int i = 0; i < prioritizedLangs.length; i++) {
        final l = prioritizedLangs[i].toLowerCase();
        if (audio.contains(l) || langs.contains(l)) {
          // Bonus for matching prioritized language (diminishing by index)
          score += (50000 - (i * 5000));
          break;
        }
      }
    }

    // 7. Seeders (diminishing bonus)
    score += (seeds > 500 ? 500 : seeds);

    // 7. Penalties
    if (title.contains('CAM') ||
        title.contains('TS') ||
        title.contains('TELESYNC')) {
      score -= 50000;
    }
    if (title.contains('KORSUB')) score -= 2000;

    return score;
  }

  int _getResolutionWeight(String? res) {
    if (res == null) return 0;
    final r = res.toLowerCase();
    if (r.contains('2160') || r.contains('4k')) return 40;
    if (r.contains('1080')) return 30;
    if (r.contains('720')) return 20;
    if (r.contains('480')) return 10;
    return 0;
  }

  int _getResolutionWeightFromTitle(String title) {
    // Simplified parsing purely for filtering
    final t = title.toLowerCase();
    if (t.contains('2160') || t.contains('4k')) return 40;
    if (t.contains('1080')) return 30;
    if (t.contains('720')) return 20;
    if (t.contains('480')) return 10;
    return 0;
  }

  String _buildDescription(
    Map<String, dynamic> stream,
    Map<String, dynamic> parsed,
    Map<String, dynamic> size,
  ) {
    final buffer = StringBuffer();
    final originalDesc = stream['description']?.toString() ?? '';
    final hasParsedDetails = parsed['resolution'] != null;

    // Legacy Requirement: If requireDetailsForOriginal is ON, and we failed to parse details,
    // we MUST use the original description (if available) as fallback/primary.
    if (_config.requireDetailsForOriginal &&
        !hasParsedDetails &&
        originalDesc.isNotEmpty) {
      return originalDesc;
    }

    // Line 1: 🎥 Title
    final cleanName = _config.seriesTitleCleanup
        ? ParseUtils.cleanShowName(parsed['name'])
        : parsed['name'];
    buffer.writeln('🎥 $cleanName');

    // Line 2: 💿 Resolution | Codec | HDR
    final tech = [
      parsed['resolution'],
      parsed['codec'],
      parsed['hdr'],
      parsed['source'],
    ].where((e) => e != null).join(' • ');
    if (tech.isNotEmpty) buffer.writeln('💿 $tech');

    // Line 3: 🔊 Audio | 📦 Size
    final audio = parsed['audio'];
    final sStr = size['sizeStr'];
    final seeds = stream['seeders'] ?? 0;
    final row3 = [
      if (audio != null) '🔊 $audio',
      if (sStr != null) '📦 $sStr',
      '👤 $seeds Seeds',
    ].join('  ');
    if (row3.isNotEmpty) buffer.writeln(row3);

    final generated = buffer.toString();

    // Append Original if enabled
    if (_config.appendOriginalDesc && originalDesc.isNotEmpty) {
      return '$generated\n\n📝 Original: $originalDesc';
    }

    return generated;
  }
}
