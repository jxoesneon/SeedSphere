import 'package:sqlite3/sqlite3.dart';

/// Manages database schema migrations for SeedSphere Router.
class MigrationManager {
  final Database _db;

  /// Creates a [MigrationManager] for the given [Database].
  MigrationManager(this._db);

  /// Runs all pending migrations.
  void migrate() {
    try {
      _createMigrationTable();
      final currentVersion = _getCurrentVersion();

      if (currentVersion < 1) {
        _runMigrationV1();
      }
      if (currentVersion < 2) {
        _runMigrationV2();
      }
    } catch (e, stack) {
      print('CRITICAL: Migration Failed: $e');
      print(stack);
      rethrow;
    }
  }

  void _createMigrationTable() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS _migrations (
        version INTEGER PRIMARY KEY,
        applied_at INTEGER NOT NULL
      )
    ''');
  }

  int _getCurrentVersion() {
    final result = _db.select('SELECT MAX(version) as v FROM _migrations');
    if (result.isEmpty || result.first['v'] == null) return 0;
    return result.first['v'] as int;
  }

  void _updateVersion(int version) {
    _db.execute('INSERT INTO _migrations (version, applied_at) VALUES (?, ?)', [
      version,
      DateTime.now().millisecondsSinceEpoch,
    ]);
  }

  /// Initial Schema
  void _runMigrationV1() {
    print('[Migration] Running V1: Base Schema');
    final statements = [
      '''
      CREATE TABLE IF NOT EXISTS gardeners (
        gardener_id TEXT PRIMARY KEY,
        user_id TEXT,
        platform TEXT,
        created_at INTEGER NOT NULL,
        last_seen INTEGER
      )''',
      '''
      CREATE TABLE IF NOT EXISTS seedlings (
        seedling_id TEXT PRIMARY KEY,
        user_id TEXT,
        created_at INTEGER NOT NULL,
        last_seen INTEGER
      )''',
      '''
      CREATE TABLE IF NOT EXISTS bindings (
        seedling_id TEXT NOT NULL,
        gardener_id TEXT NOT NULL,
        secret TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (seedling_id, gardener_id)
      )''',
      'CREATE INDEX IF NOT EXISTS bindings_g ON bindings(gardener_id)',
      'CREATE INDEX IF NOT EXISTS bindings_s ON bindings(seedling_id)',
      '''
      CREATE TABLE IF NOT EXISTS link_tokens (
        token TEXT PRIMARY KEY,
        gardener_id TEXT NOT NULL,
        expires_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )''',
      '''
      CREATE TABLE IF NOT EXISTS audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event TEXT NOT NULL,
        at INTEGER NOT NULL,
        meta_json TEXT
      )''',
      '''
      CREATE TABLE IF NOT EXISTS pairings (
        pair_code TEXT PRIMARY KEY,
        install_id TEXT NOT NULL,
        device_id TEXT,
        expires_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )''',
      '''
      CREATE TABLE IF NOT EXISTS reputation (
        entity_id TEXT PRIMARY KEY,
        score INTEGER DEFAULT 0,
        flags TEXT,
        updated_at INTEGER NOT NULL
      )''',
      '''
      CREATE TABLE IF NOT EXISTS whitelist (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )''',
      '''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT,
        provider TEXT,
        created_at INTEGER NOT NULL,
        last_seen INTEGER
      )''',
      '''
      CREATE TABLE IF NOT EXISTS sessions (
        sid TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )''',
      '''
      CREATE TABLE IF NOT EXISTS trackers (
        url TEXT PRIMARY KEY,
        score REAL DEFAULT 0,
        votes INTEGER DEFAULT 0,
        latency_avg INTEGER DEFAULT 0,
        last_verified_at INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )''',
      '''
      CREATE TABLE IF NOT EXISTS scrap_cache (
        id TEXT PRIMARY KEY,
        results_json TEXT,
        expires_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )''',
    ];

    for (final sql in statements) {
      _db.execute(sql);
    }
    _updateVersion(1);
  }

  /// Settings Support
  void _runMigrationV2() {
    print('[Migration] Running V2: User Settings');
    try {
      _db.execute('ALTER TABLE users ADD COLUMN settings_json TEXT');
    } catch (e) {
      // Column might already exist if coming from non-versioned V1.x
      print('[Migration] V2 Warning: $e');
    }
    _updateVersion(2);
  }
}
