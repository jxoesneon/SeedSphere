import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

class DbService {
  late Database _db;

  void init(String baseDir) {
    final dir = Directory(baseDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final dbFile = p.join(baseDir, 'seedsphere.db');
    _db = sqlite3.open(dbFile);

    // Enable WAL for concurrency
    _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('PRAGMA synchronous = NORMAL');

    _migrate();
  }

  void _migrate() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS gardeners (
        gardener_id TEXT PRIMARY KEY,
        user_id TEXT,
        platform TEXT,
        created_at INTEGER NOT NULL,
        last_seen INTEGER
      );
      CREATE TABLE IF NOT EXISTS seedlings (
        seedling_id TEXT PRIMARY KEY,
        user_id TEXT,
        created_at INTEGER NOT NULL,
        last_seen INTEGER
      );
      CREATE TABLE IF NOT EXISTS bindings (
        seedling_id TEXT NOT NULL,
        gardener_id TEXT NOT NULL,
        secret TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (seedling_id, gardener_id)
      );
      CREATE INDEX IF NOT EXISTS bindings_g ON bindings(gardener_id);
      CREATE INDEX IF NOT EXISTS bindings_s ON bindings(seedling_id);
      
      CREATE TABLE IF NOT EXISTS link_tokens (
        token TEXT PRIMARY KEY,
        gardener_id TEXT NOT NULL,
        expires_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );
      
      CREATE TABLE IF NOT EXISTS audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event TEXT NOT NULL,
        at INTEGER NOT NULL,
        meta_json TEXT
      );

      CREATE TABLE IF NOT EXISTS pairings (
        pair_code TEXT PRIMARY KEY,
        install_id TEXT NOT NULL,
        device_id TEXT,
        expires_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS reputation (
        entity_id TEXT PRIMARY KEY,
        score INTEGER DEFAULT 0,
        flags TEXT,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS whitelist (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');
  }

  // --- Methods ---

  String? getBindingSecret(String gardenerId, String seedlingId) {
    final stmt = _db.prepare(
      'SELECT secret FROM bindings WHERE gardener_id = ? AND seedling_id = ?',
    );
    final result = stmt.select([gardenerId, seedlingId]);
    if (result.isEmpty) return null;
    return result.first['secret'] as String;
  }

  void createBinding(String gardenerId, String seedlingId, String secret) {
    final stmt = _db.prepare(
      'INSERT OR REPLACE INTO bindings (seedling_id, gardener_id, secret, created_at) VALUES (?, ?, ?, ?)',
    );
    stmt.execute([
      seedlingId,
      gardenerId,
      secret,
      DateTime.now().millisecondsSinceEpoch,
    ]);
  }

  void upsertGardener(String gardenerId, {String? platform}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.execute(
      '''
      INSERT INTO gardeners (gardener_id, platform, created_at, last_seen)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(gardener_id) DO UPDATE SET platform = COALESCE(excluded.platform, gardeners.platform), last_seen = excluded.last_seen
    ''',
      [gardenerId, platform, now, now],
    );
  }

  void touchGardener(String gardenerId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.execute('UPDATE gardeners SET last_seen = ? WHERE gardener_id = ?', [
      now,
      gardenerId,
    ]);
  }

  void upsertSeedling(String seedlingId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.execute(
      '''
      INSERT INTO seedlings (seedling_id, created_at, last_seen)
      VALUES (?, ?, ?)
      ON CONFLICT(seedling_id) DO UPDATE SET last_seen = excluded.last_seen
    ''',
      [seedlingId, now, now],
    );
  }

  void createLinkToken(String token, String gardenerId, int ttlMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final exp = now + ttlMs;
    _db.execute(
      'INSERT OR REPLACE INTO link_tokens (token, gardener_id, expires_at, created_at) VALUES (?, ?, ?, ?)',
      [token, gardenerId, exp, now],
    );
  }

  Map<String, dynamic>? getLinkToken(String token) {
    final stmt = _db.prepare(
      'SELECT token, gardener_id, expires_at FROM link_tokens WHERE token = ?',
    );
    final result = stmt.select([token]);
    if (result.isEmpty) return null;
    final row = result.first;
    if (row['expires_at'] < DateTime.now().millisecondsSinceEpoch) return null;
    return row;
  }

  void deleteLinkToken(String token) {
    _db.execute('DELETE FROM link_tokens WHERE token = ?', [token]);
  }

  int getReputation(String entityId) {
    final stmt = _db.prepare(
      'SELECT score FROM reputation WHERE entity_id = ?',
    );
    final result = stmt.select([entityId]);
    if (result.isEmpty) return 0;
    return result.first['score'] as int;
  }

  void updateReputation(String entityId, int delta) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.execute(
      '''
      INSERT INTO reputation (entity_id, score, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(entity_id) DO UPDATE SET score = reputation.score + excluded.score, updated_at = excluded.updated_at
    ''',
      [entityId, delta, now],
    );
  }

  bool isWhitelisted(String id, String type) {
    final stmt = _db.prepare(
      'SELECT 1 FROM whitelist WHERE id = ? AND type = ?',
    );
    final result = stmt.select([id, type]);
    return result.isNotEmpty;
  }

  void writeAudit(String event, Map<String, dynamic>? meta) {
    _db
        .prepare('INSERT INTO audit (event, at, meta_json) VALUES (?, ?, ?)')
        .execute([
          event,
          DateTime.now().millisecondsSinceEpoch,
          meta != null ? jsonEncode(meta) : null,
        ]);
  }

  void pruneExpiredData() {
    final now = DateTime.now().millisecondsSinceEpoch;
    // 1. Expire old pairings
    _db
        .prepare(
          'UPDATE pairings SET status = ? WHERE expires_at < ? AND status = ?',
        )
        .execute(['expired', now, 'pending']);

    // 2. Delete expired link tokens
    _db.prepare('DELETE FROM link_tokens WHERE expires_at < ?').execute([now]);

    // 3. Mark old gardeners as offline (e.g., 24h of inactivity)
    final oneDayAgo = now - (24 * 60 * 60 * 1000);
    // Note: We don't delete them, just log or filter in queries later.

    // 4. Cleanup old audit logs (optional, e.g., keep 30 days)
    final thirtyDaysAgo = now - (30 * 24 * 60 * 60 * 1000);
    _db.prepare('DELETE FROM audit WHERE at < ?').execute([thirtyDaysAgo]);
  }

  void close() => _db.dispose();

  int countBindingsForGardener(String gardenerId) {
    final result = _db
        .prepare('SELECT COUNT(*) as cnt FROM bindings WHERE gardener_id = ?')
        .select([gardenerId]);
    return result.first['cnt'] as int;
  }

  int countBindingsForSeedling(String seedlingId) {
    final result = _db
        .prepare('SELECT COUNT(*) as cnt FROM bindings WHERE seedling_id = ?')
        .select([seedlingId]);
    return result.first['cnt'] as int;
  }
}
