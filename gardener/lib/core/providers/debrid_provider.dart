/// Abstract interface for Debrid service providers (Real-Debrid, AllDebrid, etc).
abstract class DebridProvider {
  /// The unique identifier for this provider (e.g., 'real_debrid').
  String get id;

  /// Fetches the current user's account information.
  Future<Map<String, dynamic>> getUser();

  /// Adds a magnet link to the service.
  /// Returns a map containing the ID of the added torrent.
  /// [options] can include service-specific flags like 'background'.
  Future<Map<String, dynamic>> addMagnet(
    String magnet, {
    Map<String, dynamic>? options,
  });

  /// Selects specific files to download for a given torrent ID.
  /// [fileIds] is usually a comma-separated string of IDs or "all".
  Future<void> selectFiles(String id, String fileIds);

  /// Retrieves detailed information about a specific torrent.
  Future<Map<String, dynamic>> getTorrentInfo(String id);

  /// Unrestricts a link (resolves it to a direct download URL).
  /// [link] is the source link provided by the service (e.g., in getTorrentInfo).
  Future<Map<String, dynamic>> unrestrictLink(String link);

  /// Checks the availability of files for a list of infohashes.
  /// Returns a map where keys are infohashes and values indicate if cached (true/false).
  Future<Map<String, bool>> checkAvailability(List<String> hashes);
}
