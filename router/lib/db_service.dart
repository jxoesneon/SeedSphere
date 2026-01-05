import 'dart:convert';
import 'dart:io';
import 'package:router/crypto_helper.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

/// Service for managing the SQLite database.
class DbService {
  late Database _db;

  /// Initializes the database connection and runs migrations.
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
      

      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT,
        provider TEXT,
        created_at INTEGER NOT NULL,
        last_seen INTEGER,
        settings_json TEXT
      );
      
      CREATE TABLE IF NOT EXISTS sessions (
        sid TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS trackers (
        url TEXT PRIMARY KEY,
        score REAL DEFAULT 0,
        votes INTEGER DEFAULT 0,
        latency_avg INTEGER DEFAULT 0,
        last_verified_at INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      );
    ''');

    // MIGRATIONS (Since we don't have a versioning system yet)
    try {
      _db.execute('ALTER TABLE users ADD COLUMN settings_json TEXT');
    } catch (_) {
      // Ignore "duplicate column name" error
    }
  }

  // --- Trackers (Distributed Reputation) ---

  /// Ingests a tracker into the system. Ignored if already exists.
  void upsertTracker(String url) {
    if (url.isEmpty) return;
    try {
      _db.execute(
        'INSERT OR IGNORE INTO trackers (url, created_at) VALUES (?, ?)',
        [url, DateTime.now().millisecondsSinceEpoch],
      );
    } catch (_) {}
  }

  /// Submits a vote from a Gardener.
  ///
  /// [url]: The tracker URL.
  /// [up]: True if reachable.
  /// [latency]: RTT in ms.
  void submitTrackerVote(String url, bool up, int latency) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Simple Score Logic: +1 for UP, -1 for DOWN.
    // Latency: Exponential Moving Average (alpha = 0.2)

    // We do this in a transaction to be safe or just a single complex update
    // But SQLite allows complex updates.

    if (up) {
      _db.execute(
        '''
        UPDATE trackers SET 
          votes = votes + 1,
          score = score + 1.0,
          latency_avg = CASE WHEN latency_avg = 0 THEN ? ELSE CAST((latency_avg * 0.8) + (? * 0.2) AS INTEGER) END,
          last_verified_at = ?
        WHERE url = ?
      ''',
        [latency, latency, now, url],
      );
    } else {
      _db.execute(
        '''
        UPDATE trackers SET 
          votes = votes + 1,
          score = score - 1.0, 
          last_verified_at = ?
        WHERE url = ?
      ''',
        [now, url],
      );
    }
  }

  /// Returns the top [limit] best trackers based on score.
  List<String> getBestTrackers({int limit = 50}) {
    // We default to score descending.
    final result = _db.select(
      'SELECT url FROM trackers WHERE score > -5 ORDER BY score DESC, latency_avg ASC LIMIT ?',
      [limit],
    );
    return result.map((row) => row['url'] as String).toList();
  }

  /// Returns ALL trackers for synchronization.
  List<String> getTrackers({int limit = 2000}) {
    final result = _db.select('SELECT url FROM trackers LIMIT ?', [limit]);
    return result.map((row) => row['url'] as String).toList();
  }

  /// Alias for Gardeners to sync.
  List<String> getTrackersSync({int limit = 2000}) => getTrackers(limit: limit);

  // --- Methods ---

  // Sessions

  /// Creates a new session with the given [sid], [userId], and [ttlMs].
  void createSession(String sid, String userId, int ttlMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final exp = now + ttlMs;
    // Ensure user exists first or handle FK error?
    // upsertUser should be called before session creation usually.
    _db.execute(
      'INSERT OR REPLACE INTO sessions (sid, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)',
      [sid, userId, now, exp],
    );
  }

  /// Retrieves a session by [sid].
  ///
  /// Returns `null` if the session doesn't exist or has expired.
  Map<String, dynamic>? getSession(String sid) {
    final stmt = _db.prepare(
      'SELECT sid, user_id, expires_at FROM sessions WHERE sid = ?',
    );
    final result = stmt.select([sid]);
    if (result.isEmpty) return null;
    final row = result.first;
    if ((row['expires_at'] as int) < DateTime.now().millisecondsSinceEpoch) {
      deleteSession(sid);
      return null;
    }
    return row;
  }

  /// Retrieves active sessions for a [userId].
  List<Map<String, dynamic>> getSessions(String userId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stmt = _db.prepare(
      'SELECT sid, created_at, expires_at FROM sessions WHERE user_id = ? AND expires_at > ? ORDER BY created_at DESC',
    );
    final result = stmt.select([userId, now]);
    return result
        .map(
          (row) => {
            'sid': row['sid'],
            'created_at': row['created_at'],
            'expires_at': row['expires_at'],
            // We could add user_agent/ip here if we stored it in the future
          },
        )
        .toList();
  }

  /// Deletes a session by [sid].
  void deleteSession(String sid) {
    _db.execute('DELETE FROM sessions WHERE sid = ?', [sid]);
  }

  /// Alias for deleteSession
  void revokeSession(String sid) => deleteSession(sid);

  /// Retrieves the binding secret between a [gardenerId] and [seedlingId].
  String? getBindingSecret(String gardenerId, String seedlingId) {
    final stmt = _db.prepare(
      'SELECT secret FROM bindings WHERE gardener_id = ? AND seedling_id = ?',
    );
    final result = stmt.select([gardenerId, seedlingId]);
    if (result.isEmpty) return null;
    return result.first['secret'] as String;
  }

  /// Creates a persistent binding between a [gardenerId] and [seedlingId].
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

  /// Upserts a Gardener's record, updating their platform and last seen time.
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

  /// Updates the `last_seen` timestamp for a Gardener.
  void touchGardener(String gardenerId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.execute('UPDATE gardeners SET last_seen = ? WHERE gardener_id = ?', [
      now,
      gardenerId,
    ]);
  }

  /// Ingests or updates a Seedling record.
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

  /// Creates a short-lived link token for identity verification.
  void createLinkToken(String token, String gardenerId, int ttlMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final exp = now + ttlMs;
    _db.execute(
      'INSERT OR REPLACE INTO link_tokens (token, gardener_id, expires_at, created_at) VALUES (?, ?, ?, ?)',
      [token, gardenerId, exp, now],
    );
  }

  /// Retrieves and validates a link token.
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

  /// Deletes a used or expired link token.
  void deleteLinkToken(String token) {
    _db.execute('DELETE FROM link_tokens WHERE token = ?', [token]);
  }

  /// Returns the reputation score for a given [entityId].
  int getReputation(String entityId) {
    final stmt = _db.prepare(
      'SELECT score FROM reputation WHERE entity_id = ?',
    );
    final result = stmt.select([entityId]);
    if (result.isEmpty) return 0;
    return result.first['score'] as int;
  }

  /// Increments or decrements reputation for an entity.
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

  /// Checks if an ID is present in the global whitelist.
  bool isWhitelisted(String id, String type) {
    final stmt = _db.prepare(
      'SELECT 1 FROM whitelist WHERE id = ? AND type = ?',
    );
    final result = stmt.select([id, type]);
    return result.isNotEmpty;
  }

  /// Logs an audit event with optional metadata.
  void writeAudit(String event, Map<String, dynamic>? meta) {
    _db
        .prepare('INSERT INTO audit (event, at, meta_json) VALUES (?, ?, ?)')
        .execute([
          event,
          DateTime.now().millisecondsSinceEpoch,
          meta != null ? jsonEncode(meta) : null,
        ]);
  }

  /// Performs background cleanup of expired tokens and sessions.
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

    // 3. Delete expired sessions
    _db.prepare('DELETE FROM sessions WHERE expires_at < ?').execute([now]);

    // 4. Cleanup old audit logs (optional, e.g., keep 30 days)
    final thirtyDaysAgo = now - (30 * 24 * 60 * 60 * 1000);
    _db.prepare('DELETE FROM audit WHERE at < ?').execute([thirtyDaysAgo]);
  }

  /// Closes the database connection.
  void close() => _db.close();

  /// Returns the number of active bindings for a Gardener.
  int countBindingsForGardener(String gardenerId) {
    final result = _db
        .prepare('SELECT COUNT(*) as cnt FROM bindings WHERE gardener_id = ?')
        .select([gardenerId]);
    return result.first['cnt'] as int;
  }

  /// Returns the number of active bindings for a Seedling.
  int countBindingsForSeedling(String seedlingId) {
    final result = _db
        .prepare('SELECT COUNT(*) as cnt FROM bindings WHERE seedling_id = ?')
        .select([seedlingId]);
    return result.first['cnt'] as int;
  }

  /// Returns a list of all devices (seedlings or gardeners) bound to this Entity (User/Gardener).
  List<Map<String, dynamic>> getBindings(String entityId) {
    final results = <Map<String, dynamic>>[];

    // 1. Entity is the Gardener -> Show Seedlings
    final asGardener = _db.select(
      'SELECT seedling_id as device_id, created_at FROM bindings WHERE gardener_id = ?',
      [entityId],
    );
    results.addAll(asGardener);

    // 2. Entity is the Seedling -> Show Gardeners
    final asSeedling = _db.select(
      'SELECT gardener_id as device_id, created_at FROM bindings WHERE seedling_id = ?',
      [entityId],
    );
    results.addAll(asSeedling);

    // Sort by timestamp descending
    results.sort(
      (a, b) => (b['created_at'] as int).compareTo(a['created_at'] as int),
    );

    return results
        .map(
          (row) => {
            'device_id': row['device_id'],
            'linked_at': row['created_at'],
          },
        )
        .toList();
  }

  /// Returns the owner (Gardener ID) for a given Seedling ID.
  String? getOwnerForDevice(String seedlingId) {
    final res = _db.select(
      'SELECT gardener_id FROM bindings WHERE seedling_id = ? LIMIT 1',
      [seedlingId],
    );
    if (res.isEmpty) return null;
    return res.first['gardener_id'] as String;
  }

  /// Aggregates user activity from various tables (Account creation, Bindings).
  List<Map<String, dynamic>> getUserActivity(String userId) {
    final activities = <Map<String, dynamic>>[];

    // 1. Account Creation
    final userRes = _db.select('SELECT created_at FROM users WHERE id = ?', [
      userId,
    ]);
    if (userRes.isNotEmpty) {
      activities.add({
        'type': 'account_created',
        'title': 'Account Created',
        'timestamp': userRes.first['created_at'],
        'icon': '🌱',
      });
    }

    // 2. Linked Devices
    final bindings = getBindings(userId);
    for (final b in bindings) {
      activities.add({
        'type': 'device_linked',
        'title': 'Device Linked',
        'details': 'Linked device ${b['device_id']}',
        'timestamp': b['linked_at'],
        'icon': '🔗',
      });
    }

    // Sort by timestamp descending
    activities.sort(
      (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
    );

    return activities;
  }

  // --- Encryption Support ---
  String get _encryptionKey {
    final key = Platform.environment['DB_ENCRYPTION_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception(
        'FATAL: DB_ENCRYPTION_KEY environment variable is required for secure storage.',
      );
    }
    return key;
  }

  final _sensitiveKeys = const ['rd_key', 'ad_key'];

  /// Retrieves user data by [id], decrypting sensitive settings automatically.
  Map<String, dynamic>? getUser(String id) {
    final stmt = _db.prepare('SELECT * FROM users WHERE id = ?');
    final result = stmt.select([id]);
    if (result.isEmpty) return null;

    final user = Map<String, dynamic>.from(result.first); // Make mutable
    if (user['settings_json'] != null) {
      try {
        final settings =
            jsonDecode(user['settings_json'] as String) as Map<String, dynamic>;

        // Decrypt sensitive fields
        for (final key in _sensitiveKeys) {
          if (settings.containsKey(key)) {
            try {
              settings[key] = CryptoHelper.decrypt(
                settings[key],
                _encryptionKey,
              );
            } catch (_) {}
          }
        }
        // Map to 'settings' key for the consumer (and tests)
        user['settings'] = settings;
      } catch (_) {}
    }
    return user;
  }

  /// Ingests or updates a User record, encrypting sensitive fields.
  void upsertUser({
    required String id,
    required String email,
    required String provider,
    Map<String, dynamic>? settings,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Encrypt settings if provided
    String? settingsJson;
    if (settings != null) {
      final secureSettings = Map<String, dynamic>.from(settings);
      for (final key in _sensitiveKeys) {
        if (secureSettings.containsKey(key)) {
          secureSettings[key] = CryptoHelper.encrypt(
            secureSettings[key],
            _encryptionKey,
          );
        }
      }
      settingsJson = jsonEncode(secureSettings);
    }

    _db.execute(
      '''
      INSERT INTO users (id, email, provider, created_at, last_seen, settings_json)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET 
        email = excluded.email,
        last_seen = excluded.last_seen,
        settings_json = COALESCE(excluded.settings_json, users.settings_json)
    ''',
      [id, email, provider, now, now, settingsJson],
    );
  }

  /// Merges new settings into an existing user record with encryption.
  void updateUserSettings(String id, Map<String, dynamic> newSettings) {
    // 1. Fetch current raw (encrypted) settings directly to merge correctly
    final stmt = _db.prepare('SELECT settings_json FROM users WHERE id = ?');
    final result = stmt.select([id]);

    Map<String, dynamic> merged = {};
    if (result.isNotEmpty && result.first['settings_json'] != null) {
      try {
        merged = jsonDecode(result.first['settings_json'] as String);
      } catch (_) {}
    }

    // 2. Encrypt new sensitive values
    final secureUpdates = Map<String, dynamic>.from(newSettings);
    for (final key in _sensitiveKeys) {
      if (secureUpdates.containsKey(key)) {
        secureUpdates[key] = CryptoHelper.encrypt(
          secureUpdates[key],
          _encryptionKey,
        );
      }
    }

    // 3. Merge
    merged.addAll(secureUpdates);

    // 4. Save
    _db.execute('UPDATE users SET settings_json = ? WHERE id = ?', [
      jsonEncode(merged),
      id,
    ]);
  }

  /// Permanently removes a user and all their associated data.
  void deleteUser(String id) {
    // Delete user
    _db.execute('DELETE FROM users WHERE id = ?', [id]);
    // Also delete associated bindings
    deleteUserBindings(id);
    // And tokens
    _db.execute('DELETE FROM link_tokens WHERE gardener_id = ?', [id]);
    // And sessions
    _db.execute('DELETE FROM sessions WHERE user_id = ?', [id]);
  }

  /// Removes all associated bindings for a user/gardener.
  void deleteUserBindings(String userId) {
    _db.execute(
      'DELETE FROM bindings WHERE gardener_id = ? OR seedling_id = ?',
      [userId, userId],
    );
  }

  /// Removes a specific binding between a gardener and seedling.
  void deleteBinding(String gardenerId, String seedlingId) {
    _db.execute(
      'DELETE FROM bindings WHERE gardener_id = ? AND seedling_id = ?',
      [gardenerId, seedlingId],
    );
  }

  /// Executes a block within a database transaction.
  T transaction<T>(T Function() action) {
    _db.execute('BEGIN EXCLUSIVE');
    try {
      final result = action();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}
