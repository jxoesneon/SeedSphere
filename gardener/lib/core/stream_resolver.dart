import 'package:gardener/core/debrid_client.dart';
import 'package:gardener/core/network_constants.dart';

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
  /// 3. Returns streaming URL (currently simplified)
  ///
  /// **Note:** Current implementation assumes instant/cached availability.
  /// Production version should poll torrent status and handle file selection.
  Future<String?> resolveStream(String magnetOrHash) async {
    try {
      // Convert raw infohash to magnet URI if needed
      final magnet = magnetOrHash.startsWith('magnet:')
          ? magnetOrHash
          : 'magnet:?xt=urn:btih:$magnetOrHash';

      // Add magnet to Real-Debrid
      final addResult = await _debrid.addMagnet(magnet);
      final id = addResult['id'];

      // TODO: Poll torrent status for non-cached torrents
      // TODO: Select largest video file from torrent
      // TODO: Unrestrict the selected file link
      // For now, return placeholder streaming URL from constants

      return NetworkConstants.getDebridStreamingUrl(id);
    } catch (e) {
      // Silent failure - caller checks for null
      return null;
    }
  }
}
