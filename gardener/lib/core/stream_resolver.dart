import 'package:gardener/core/debrid_client.dart';

/// High-level resolver for converting magnet links into direct playback URLs.
///
/// Orchestrates the workflow of adding magnet links to Real-Debrid and
/// obtaining direct streaming URLs for media playback. Handles both
/// magnet URIs and raw infohashes.
class StreamResolver {
  final DebridClient _debrid;

  /// Creates a new [StreamResolver] instance.
  ///
  /// [debrid] - Optional [DebridClient] for testing. Defaults to new instance.
  StreamResolver({DebridClient? debrid}) : _debrid = debrid ?? DebridClient();

  /// Resolves a magnet link or infohash to a direct playback URL.
  ///
  /// [magnetOrHash] - Either a complete `magnet:?xt=urn:btih:` URI or just
  ///   the infohash hex string. If just a hash is provided, it's automatically
  ///   converted to a magnet URI.
  ///
  /// Returns a direct streaming URL if successful, `null` if resolution fails.
  ///
  /// **Workflow:**
  /// 1. Converts infohash to magnet URI if needed
  /// 2. Adds magnet to Real-Debrid account
  /// 3. Polls until torrent is ready and files are listed
  /// 4. Selects the largest video file
  /// 5. Unrestricts the link for direct streaming
  Future<String?> resolveStream(String magnetOrHash) async {
    try {
      // 1. Convert raw infohash to magnet URI if needed
      final magnet = magnetOrHash.startsWith('magnet:')
          ? magnetOrHash
          : 'magnet:?xt=urn:btih:$magnetOrHash';

      // 2. Add magnet to Real-Debrid
      final addResult = await _debrid.addMagnet(magnet);
      final id = addResult['id'];

      // 3. Initial fetch of torrent info
      Map<String, dynamic> info = await _debrid.getTorrentInfo(id);

      // 3. Wait for torrent to be ready for file selection if needed
      int infoAttempts = 0;
      while (info['status'] == 'magnet_conversion' && infoAttempts < 5) {
        await Future.delayed(const Duration(seconds: 1));
        info = await _debrid.getTorrentInfo(id);
        infoAttempts++;
      }

      // 4. Handle file selection if needed
      if (info['status'] == 'waiting_files_selection') {
        final List files = info['files'] ?? [];
        if (files.isEmpty) return null;

        // Select largest video file (filter by extension for quality)
        int largestSize = 0;
        int targetIdx = -1;
        final videoExtensions = ['.mkv', '.mp4', '.avi', '.mov', '.wmv'];

        for (int i = 0; i < files.length; i++) {
          final f = files[i];
          final path = (f['path'] as String? ?? '').toLowerCase();
          final size = (f['bytes'] as num?)?.toInt() ?? 0;

          final isVideo = videoExtensions.any((ext) => path.endsWith(ext));
          if (isVideo && size > largestSize) {
            largestSize = size;
            targetIdx = (f['id'] as num?)?.toInt() ?? (i + 1);
          }
        }

        // Fallback to largest file if no video extension matched
        if (targetIdx == -1) {
          for (int i = 0; i < files.length; i++) {
            final f = files[i];
            final size = (f['bytes'] as num?)?.toInt() ?? 0;
            if (size > largestSize) {
              largestSize = size;
              targetIdx = (f['id'] as num?)?.toInt() ?? (i + 1);
            }
          }
        }

        if (targetIdx != -1) {
          await _debrid.selectFiles(id, targetIdx.toString());
          info = await _debrid.getTorrentInfo(id); // Refresh after selection
        }
      }

      // 5. Poll until downloaded or ready (robust polling with backoff)
      int attempts = 0;
      const maxAttempts = 15; // Increased timeout to 30s+
      while (info['status'] != 'downloaded' && attempts < maxAttempts) {
        // Check for error statuses
        if (info['status'] == 'error' ||
            info['status'] == 'dead' ||
            info['status'] == 'virus') {
          return null;
        }

        await Future.delayed(
          Duration(seconds: 1 + (attempts ~/ 5)),
        ); // Slight backoff
        info = await _debrid.getTorrentInfo(id);
        attempts++;
      }

      if (info['status'] != 'downloaded') return null;

      // 6. Unrestrict the first link (usually corresponds to the selected file)
      final List links = info['links'] ?? [];
      if (links.isEmpty) return null;

      final unrestrictRes = await _debrid.unrestrictLink(links.first);
      return unrestrictRes['download']; // Direct streaming URL
    } catch (e) {
      // Silent failure - caller checks for null
      return null;
    }
  }
}
