import 'dart:io';
import 'package:test/test.dart';
import 'package:router/db_service.dart';

void main() {
  group('DbService', () {
    late DbService db;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('db_test');
      db = DbService()..init(tempDir.path);
    });

    tearDown(() async {
      db.close();
      // Give time for handle release
      await Future.delayed(const Duration(milliseconds: 50));
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (e) {
        print('Ignored cleanup error: $e');
      }
    });

    test('upsertGardener and touchGardener', () {
      db.upsertGardener('g1', platform: 'android');
      db.touchGardener('g1');
      // No crash, ensure it was inserted?
      // Since getGardener isn't exposed, we trust no error.
      // But we can check via countBindings logic or side effects.
    });

    test('Link Tokens', () {
      db.createLinkToken('t1', 'g1', 10000);
      final tok = db.getLinkToken('t1');
      expect(tok, isNotNull);
      expect(tok!['gardener_id'], 'g1');

      db.deleteLinkToken('t1');
      expect(db.getLinkToken('t1'), isNull);
    });

    test('Link Token Expiry', () async {
      db.createLinkToken('expired', 'g1', -1000); // Already expired
      expect(db.getLinkToken('expired'), isNull);
    });

    test('Bindings and Caps', () {
      db.createBinding('g1', 's1', 'secret1');
      expect(db.getBindingSecret('g1', 's1'), 'secret1');

      expect(db.countBindingsForGardener('g1'), 1);
      expect(db.countBindingsForSeedling('s1'), 1);

      db.createBinding('g1', 's2', 'secret2');
      expect(db.countBindingsForGardener('g1'), 2);
    });

    test('Reputation', () {
      expect(db.getReputation('e1'), 0);
      db.updateReputation('e1', 10);
      expect(db.getReputation('e1'), 10);
      db.updateReputation('e1', -5);
      expect(db.getReputation('e1'), 5);
    });

    test('Whitelist', () {
      expect(db.isWhitelisted('w1', 'ip'), isFalse);
    });

    test('Audit', () {
      db.writeAudit('test_event', {'foo': 'bar'});
    });

    test('Prune Expired Data', () {
      // Setup expired token
      db.createLinkToken('old', 'g1', -5000);
      db.pruneExpiredData();
      // Should be gone
      expect(db.getLinkToken('old'), isNull);
    });

    test('User Management (Encryption)', () {
      const uid = 'u1';
      db.upsertUser(
        id: uid,
        email: 'test@example.com',
        provider: 'google',
        settings: {'apiKey': 'secret-123', 'theme': 'dark'},
      );

      final user = db.getUser(uid);
      expect(user, isNotNull);
      expect(user!['email'], 'test@example.com');
      // Verify automatic decryption
      final settings = user['settings'] as Map<String, dynamic>;
      expect(settings['apiKey'], 'secret-123'); // Should be decrypted back
      expect(settings['theme'], 'dark');

      // Update settings
      db.updateUserSettings(uid, {'theme': 'light'});
      final updated = db.getUser(uid);
      final newSettings = updated!['settings'] as Map<String, dynamic>;
      expect(newSettings['theme'], 'light');
      expect(newSettings['apiKey'], 'secret-123'); // Should persist merge
    });

    test('User Deletion', () {
      db.upsertUser(id: 'del', email: 'del@e.com', provider: 'test');
      expect(db.getUser('del'), isNotNull);
      db.deleteUser('del');
      expect(db.getUser('del'), isNull);
    });

    test('Session Management', () {
      db.createSession('sess1', 'u1', 5000);
      final valid = db.getSession('sess1');
      expect(valid, isNotNull);
      expect(valid!['user_id'], 'u1');

      db.createSession('expired_sess', 'u1', -5000);
      expect(db.getSession('expired_sess'), isNull);

      db.deleteSession('sess1');
      expect(db.getSession('sess1'), isNull);
    });

    test('Tracker Management', () {
      // Upsert
      db.upsertTracker('udp://t1.com:80');
      // Vote
      db.submitTrackerVote('udp://t1.com:80', true, 50);
      db.submitTrackerVote('udp://t1.com:80', true, 60);

      // Retrieve
      final best = db.getBestTrackers(limit: 10);
      expect(best.any((t) => t == 'udp://t1.com:80'), isTrue);

      final all = db.getTrackersSync();
      expect(all, contains('udp://t1.com:80'));
    });

    test('Transaction rollback', () {
      try {
        db.transaction(() {
          db.createLinkToken('rollback', 'g1', 1000);
          throw Exception('fail');
        });
      } catch (_) {}

      // Should not exist
      expect(db.getLinkToken('rollback'), isNull);
    });
  });
}
