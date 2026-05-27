import 'dart:io';
import 'package:test/test.dart';
import 'package:router/db_service.dart';

void main() {
  group('DbService Full Coverage', () {
    late DbService db;
    late Directory tempDir;

    setUp(() {
      final id = DateTime.now().microsecondsSinceEpoch;
      tempDir = Directory.systemTemp.createTempSync('db_full_test_$id');
      db = DbService()..init(tempDir.path);
    });

    tearDown(() async {
      try {
        db.close();
        await Future.delayed(const Duration(milliseconds: 100));
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (e) {
        print('Cleanup warning: $e');
      }
    });

    test('getBindings and deleteUserBindings', () {
      db.createBinding('g1', 'u1', 's1');
      db.createBinding('g2', 'u1', 's2');

      final bindings = db.getBindings('u1');
      expect(bindings.length, 2);

      db.deleteUserBindings('u1');
      expect(db.getBindings('u1').length, 0);
    });

    test('getUserActivity and writeAudit', () {
      db.upsertUser(id: 'u1', email: 't@t.com', provider: 'test');
      db.writeAudit('event1', {'data': 1});

      final activity = db.getUserActivity('u1');
      expect(activity.length, 1); // Account created
    });

    test('getSessions and revokeSession', () {
      db.createSession('s1', 'u1', 10000);
      db.createSession('s2', 'u1', 10000);

      final sessions = db.getSessions('u1');
      expect(sessions.length, 2);

      db.revokeSession('s1');
      expect(db.getSession('s1'), isNull);
      expect(db.getSessions('u1').length, 1);
    });

    test('Scrap cache', () {
      final results = [
        {'name': 'S1'},
      ];
      db.setScrapCache('id1', results);
      final cached = db.getScrapCache('id1');
      expect(cached, isNotNull);
      expect(cached![0]['name'], 'S1');

      final missing = db.getScrapCache('missing');
      expect(missing, isNull);
    });

    test('unlinkDevice', () {
      db.upsertGardener('g1');
      db.createBinding('g1', 's1', 'sec');
      db.unlinkDevice('g1');
      expect(db.getBindingSecret('g1', 's1'), isNull);
    });
  });
}
