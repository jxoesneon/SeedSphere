import 'package:gardener/core/debrid_client.dart';

/// High-level resolver for converting magnet links into direct playback URLs.
///
/// Orchestrates the workflow of adding magnet links to Real-Debrid and
/// obtaining direct streaming URLs for media playback. Handles both
/// magnet URIs and raw infohashes.
///
/// Example:
/// ```dart
/// final resolver = StreamResolver();
/// final url = await resolver.resolveStream('magnet:?xt=urn:btih:...');
/// if (url != null) {
///   player.play(url);
/// }
/// ```
///
/// See also:
/// * [DebridClient] for the underlying Real-Debrid API integration
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
  /// 3. Returns streaming URL (currently simplified - full implementation
  ///    would poll torrent status and select largest video file)
  ///
  /// **Note:** Current implementation assumes instant/cached availability.
  /// Production version should poll torrent status and handle file selection.
  ///
  /// Example:
  /// ```dart
  /// // From magnet URI
  /// final url1 = await resolver.resolveStream('magnet:?xt=urn:btih:ABC123...');
  ///
  /// // From infohash
  /// final url2 = await resolver.resolveStream('ABC123DEF456...');
  /// ```
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
      // For now, return placeholder streaming URL

      return 'https://real-debrid.com/streaming/$id';
    } catch (e) {
      // Silent failure - caller checks for null
      return null;
    }
  }
}
