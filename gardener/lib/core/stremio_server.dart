import 'dart:async';
import 'package:gardener/p2p/p2p_manager.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gardener/core/network_constants.dart';
import 'package:gardener/core/parse_utils.dart';
import 'package:http/http.dart' as http; // Use http for proxy
import 'package:gardener/core/debug_logger.dart';
import 'package:gardener/core/stream_history_manager.dart';
import 'package:gardener/core/stream_resolver.dart';
import 'package:gardener/core/activity_manager.dart';
import 'package:gardener/scrapers/scraper_engine.dart';
import 'package:gardener/core/stream_aggregator.dart';

/// A local HTTP server that acts as a Stremio Addon.
///
/// Provides a manifest and handles stream resolution requests from Stremio.
/// When a stream is resolved, it is automatically saved to [StreamHistoryManager].
class StremioServer {
  HttpServer? _server;
  final StreamResolver _resolver;
  final ScraperEngine _scrapers;
  final StreamAggregator _aggregator;
  String? _gardenerId;

  StremioServer({
    StreamResolver? resolver,
    ScraperEngine? scrapers,
    StreamAggregator? aggregator,
  }) : _resolver = resolver ?? StreamResolver(),
       _scrapers = scrapers ?? ScraperEngine.defaults(),
       _aggregator = aggregator ?? StreamAggregator();

  /// The port the server is listening on.
  int get port => _server?.port ?? 0;

  /// Starts the Stremio server on the configured port.
  Future<void> start({String? gardenerId, int? port}) async {
    if (_server != null) return;
    _gardenerId = gardenerId;

    final bindPort = port ?? NetworkConstants.stremioManifestPort;

    try {
      debugPrint('STREMIO: Attempting to bind to anyIPv4 on port $bindPort');
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, bindPort);
      debugPrint('STREMIO: Server listening on port ${_server!.port}');

      _server!.listen((HttpRequest request) async {
        try {
          final path = request.uri.path;

          if (path == '/manifest.json') {
            await _handleManifest(request);
          } else if (path.startsWith('/catalog/')) {
            await _handleCatalog(request);
          } else if (path.startsWith('/stream/')) {
            await _handleStream(request);
          } else {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
          }
        } catch (e) {
          debugPrint('STREMIO: Error handling request: $e');
        }
      });
    } catch (e) {
      debugPrint('STREMIO: Failed to start server: $e');
    }
  }

  Future<Map<String, dynamic>> getManifest() async {
    final gardenerId =
        _gardenerId ??
        (NetworkConstants.apiBase.contains('localhost')
            ? 'dev-gardener'
            : 'gardener-generic');

    return {
      'id': 'org.seedsphere.gardener',
      'version': '2.0.0',
      'name': 'SeedSphere Gardener',
      'description': 'Direct P2P resolution for SeedSphere Swarm.',
      'resources': ['stream', 'catalog'],
      'types': ['movie', 'series', 'anime'],
      'idPrefixes': ['tt'],
      'catalogs': [
        {
          'id': 'seedsphere.recent',
          'type': 'movie',
          'name': 'SeedSphere: Recently Resolved',
          'extra': [
            {'name': 'skip', 'isRequired': false},
          ],
        },
        {
          'id': 'seedsphere.trending',
          'type': 'movie',
          'name': 'SeedSphere: Trending Movies',
          'extra': [
            {'name': 'skip', 'isRequired': false},
          ],
        },
      ],
      'behaviorHints': {'configurable': true, 'configurationRequired': true},
      'configurationURL':
          '${NetworkConstants.apiBase}/configure.html?id=$gardenerId',
    };
  }

  Future<void> _handleManifest(HttpRequest request) async {
    final manifest = await getManifest();

    request.response.headers.contentType = ContentType.json;
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Cache-Control',
      'max-age=3600, stale-while-revalidate=1800',
    );
    request.response.write(jsonEncode(manifest));
    await request.response.close();
  }

  Future<Map<String, dynamic>> getCatalog(
    String type,
    String id,
    Map<String, String> extra,
  ) async {
    final metas = <Map<String, dynamic>>[];

    if (id == 'seedsphere.trending') {
      // Gap Closure: Trending Catalog (Proxy Cinemeta)
      try {
        final skip = extra['skip'] ?? '0';
        final url =
            'https://v3-cinemeta.strem.io/catalog/movie/top/skip=$skip.json';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['metas'] != null) {
            metas.addAll(List<Map<String, dynamic>>.from(data['metas']));
          }
        } else {
          DebugLogger.warn(
            'StremioServer: Failed to fetch Cinemeta: ${response.statusCode}',
          );
        }
      } catch (e) {
        DebugLogger.error('StremioServer: Error proxying Cinemeta', error: e);
      }
    } else {
      // Default: seedsphere.recent
      final history = await StreamHistoryManager.getHistory();
      metas.addAll(
        history.map((item) {
          return {
            'id': item['id'],
            'type': 'movie',
            'name': item['title'] ?? 'Resolved Stream',
            'posterShape': 'poster',
          };
        }),
      );
    }
    return {'metas': metas};
  }

  Future<void> _handleCatalog(HttpRequest request) async {
    // Path: /catalog/{type}/{id}.json
    // Or /catalog/{type}/{id}/{skip}.json
    final segments = request.uri.pathSegments;
    // segments: ['catalog', 'movie', 'seedsphere.recent.json']
    // strip .json from last segment

    // We need 'id' to determine which catalog.
    // 'id' is usually 3rd segment (index 2), but might contain .json extension
    if (segments.length < 3) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    String catalogId = segments[2];
    final Map<String, String> extra = {};

    // Segment 2 might be "id.json"
    if (catalogId.endsWith('.json')) {
      catalogId = catalogId.substring(0, catalogId.length - 5);
    }

    // Segments 3...n might contain extra params like "skip=100.json"
    for (int i = 3; i < segments.length; i++) {
      String extraSeg = segments[i];
      if (extraSeg.endsWith('.json')) {
        extraSeg = extraSeg.substring(0, extraSeg.length - 5);
      }
      if (extraSeg.contains('=')) {
        final parts = extraSeg.split('=');
        extra[parts[0]] = parts[1];
      }
    }

    final catalog = await getCatalog(segments[1], catalogId, extra);

    request.response.headers.contentType = ContentType.json;
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Cache-Control',
      'max-age=1800, stale-while-revalidate=600',
    );
    request.response.write(jsonEncode(catalog));
    await request.response.close();
  }

  Future<void> _handleStream(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    if (segments.length < 3) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    final type = segments[1];
    final id = segments[2].replaceAll('.json', '');

    P2PManager.instance.addLocalEvent({
      'type': 'stremio_event',
      'event': 'request',
      'mediaType': type,
      'id': id,
    });

    debugPrint('STREMIO: Stream request for type: $type, ID: $id');

    // Extract context for filtering
    int? season;
    int? episode;
    if (type == 'series') {
      final se = ParseUtils.parseSeriesId(id);
      if (se != null) {
        season = se['season'];
        episode = se['episode'];
      }
    }

    // Fetch basic meta for filtering context
    String? requestedTitle;
    int? year;
    try {
      final metaId = id.split(':').first;
      final metaUrl = 'https://v3-cinemeta.strem.io/meta/$type/$metaId.json';
      final metaResp = await http
          .get(Uri.parse(metaUrl))
          .timeout(const Duration(seconds: 2));
      if (metaResp.statusCode == 200) {
        final metaData = jsonDecode(metaResp.body);
        final meta = metaData['meta'];
        if (meta != null) {
          requestedTitle = meta['name'] ?? meta['title'];
          if (type == 'movie') {
            year = int.tryParse(meta['year']?.toString() ?? '');
          }
        }
      }
    } catch (_) {
      // Ignore meta fetch errors
    }

    // 0. Cache Check (Fresh)
    final freshCache = _aggregator.getCachedStreams(id);
    if (freshCache != null) {
      debugPrint('STREMIO: Using fresh cache for $id');
      await _processAndSendStreams(
        request,
        id,
        type,
        season,
        episode,
        freshCache,
      );
      return;
    }

    // 1. Scrape for magnets
    final results = await _scrapers.scrapeAll(id);

    if (results.isEmpty) {
      // 1b. Cache Check (Stale Fallback)
      final staleCache = _aggregator.getStaleStreams(id);
      if (staleCache != null) {
        debugPrint(
          'STREMIO: Scrapers failed, falling back to stale cache for $id',
        );
        await _processAndSendStreams(
          request,
          id,
          type,
          season,
          episode,
          staleCache,
        );
        return;
      }

      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'streams': [
            {
              'name': 'SeedSphere',
              'title':
                  '⚠️ No Sources Found\nWe searched all configured providers but found no results.',
              'url': 'data:text/plain;charset=utf-8,No%20sources%20found',
              'behaviorHints': {'bingeGroup': 'seedsphere-error'},
            },
          ],
        }),
      );
      await request.response.close();
      return;
    }

    // 2. Aggregate and Sort results using legacy parity engine
    final aggregatedStreams = await _aggregator.aggregateStreams(
      results,
      type: type,
      imdbId: id,
      season: season,
      episode: episode,
      year: year,
      requestedTitle: requestedTitle,
    );

    await _processAndSendStreams(
      request,
      id,
      type,
      season,
      episode,
      aggregatedStreams,
    );
  }

  Future<void> _processAndSendStreams(
    HttpRequest request,
    String id,
    String type,
    int? season,
    int? episode,
    List<Map<String, dynamic>> aggregatedStreams,
  ) async {
    if (aggregatedStreams.isEmpty) {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'streams': []}));
      await request.response.close();
      return;
    }

    // 3. Batch Check Cache Implementation (Gap Closure)
    final allHashes = aggregatedStreams
        .map((s) => s['infoHash'] as String?)
        .where((h) => h != null && h.isNotEmpty)
        .cast<String>()
        .toList();

    // Deduplicate hashes for query
    final uniqueHashes = allHashes.toSet().toList();
    final cacheMap = await _resolver.checkAvailability(uniqueHashes);

    // 4. Update Titles and Optional Filtering (Gap Closure)
    final service = _resolver.config.debridService;
    String cachedPrefix = '[+]';
    if (service == 'real_debrid') cachedPrefix = '[RD+]';
    if (service == 'all_debrid') cachedPrefix = '[AD+]';
    if (service == 'premiumize') cachedPrefix = '[PM+]';
    if (service == 'orion') cachedPrefix = '[ON+]';

    final List<Map<String, dynamic>> finalStreams = [];
    final onlyShowCached = _resolver.config.onlyShowCached;

    for (var stream in aggregatedStreams) {
      final hash = stream['infoHash'] as String?;
      final isCached = (hash != null && cacheMap[hash] == true);

      // Gap Closure: Show Cached Only
      if (onlyShowCached && !isCached) {
        // Skip uncached stream
        continue;
      }

      final oldTitle = stream['title']?.toString() ?? '';
      final oldName = stream['name']?.toString() ?? '';

      if (isCached) {
        stream['title'] = '$cachedPrefix $oldTitle';
        stream['name'] = '$cachedPrefix $oldName';
      } else {
        stream['title'] = '[D] $oldTitle';
        stream['name'] = '[D] $oldName';
      }

      finalStreams.add(stream);
    }

    // Check if filtering removed everything
    if (aggregatedStreams.isNotEmpty && finalStreams.isEmpty) {
      // Informative Error: Hidden by Cached Only filter
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'streams': [
            {
              'name': 'SeedSphere',
              'title':
                  '⚠️ Non-Cached Streams Hidden\nSources exist but are not cached on $service.\nDisable "Show Cached Only" to see download links.',
              'url': 'data:text/plain;charset=utf-8,Streams%20filtered',
              'behaviorHints': {'bingeGroup': 'seedsphere-error'},
            },
          ],
        }),
      );
      await request.response.close();
      return;
    }

    // 5. Take first result (Best Sorted)
    if (finalStreams.isEmpty) {
      request.response.write(jsonEncode({'streams': []}));
      await request.response.close();
      return;
    }

    final topResult = finalStreams.first;
    final magnet = topResult['magnet'] as String?;
    final title = topResult['title'];

    if (magnet == null) {
      request.response.write(jsonEncode({'streams': []}));
      await request.response.close();
      return;
    }

    // 4. Resolve to direct link
    RegExp? episodeMatcher;
    if (id.contains(':')) {
      final parts = id.split(':');
      if (parts.length >= 3) {
        final seasonNum = int.tryParse(parts[1]);
        final episodeNum = int.tryParse(parts[2]);
        if (seasonNum != null && episodeNum != null) {
          episodeMatcher = RegExp(
            '[sS]0*$seasonNum[eE]0*$episodeNum[^0-9]|\\b${seasonNum}x0*$episodeNum[^0-9]',
            caseSensitive: false,
          );
        }
      }
    }

    final directUrl = await _resolver.resolveStream(
      magnet,
      episodeMatcher: episodeMatcher,
    );

    if (directUrl != null) {
      // 5. Log to history
      await StreamHistoryManager.addStream({
        'id': id,
        'title': title ?? 'Resolved Stream',
        'subtitle':
            (topResult['infoHash'] as String?) != null &&
                (topResult['infoHash'] as String).length >= 8
            ? (topResult['infoHash'] as String).substring(0, 8)
            : topResult['infoHash'] ?? id,
        'source': 'Gardener',
        'magnet': magnet,
        'seeders': topResult['seeders'] ?? 0,
      });

      // 6. Report activity to central Router
      unawaited(
        ActivityManager().reportActivity(
          type: 'stremio',
          title: 'Resolved via Extension: ${title ?? id}',
          meta: {'id': id, 'source': 'gardener'},
        ),
      );

      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'streams': [
            {
              'name':
                  'SeedSphere\n${cachedPrefix.isNotEmpty ? cachedPrefix : '[D]'}',
              'title': topResult['description'] ?? topResult['title'] ?? '',
              'url': directUrl,
              'behaviorHints': {'bingeGroup': 'seedsphere-$id'},
            },
          ],
        }),
      );
    } else {
      request.response.write(jsonEncode({'streams': []}));
    }

    await request.response.close();
  }

  /// Stops the Stremio server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
