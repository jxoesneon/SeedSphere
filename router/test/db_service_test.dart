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

    tearDown(() {
      db.close();
      tempDir.deleteSync(recursive: true);
    });

    test('upsertGardener and touchGardener', () {
      db.upsertGardener('g1', platform: 'android');
      db.touchGardener('g1');
      // No crash, basic coverage
    });

    test('Link Tokens', () {
      db.createLinkToken('t1', 'g1', 10000);
      final tok = db.getLinkToken('t1');
      expect(tok, isNotNull);
      expect(tok!['gardener_id'], 'g1');

      db.deleteLinkToken('t1');
      expect(db.getLinkToken('t1'), isNull);
    });

    test('Bindings and Caps', () {
      db.createBinding('g1', 's1', 'secret1');
      expect(db.getBindingSecret('g1', 's1'), 'secret1');

      expect(db.countBindingsForGardener('g1'), 1);
      expect(db.countBindingsForSeedling('s1'), 1);
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
      db.pruneExpiredData();
    });
  });
}
