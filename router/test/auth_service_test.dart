import 'package:test/test.dart';
import 'package:shelf/shelf.dart';
import 'package:router/auth_service.dart';
import 'package:router/db_service.dart';
import 'package:router/mailer_service.dart';
import 'package:router/linking_service.dart';

// --- Fakes ---

class FakeDbService implements DbService {
  final Map<String, Map<String, dynamic>> _users = {};
  final Map<String, Map<String, dynamic>> _sessions = {};

  @override
  void upsertUser({
    required String id,
    required String email,
    required String provider,
    Map<String, dynamic>? settings,
  }) {
    _users[id] = {
      'id': id,
      'email': email,
      'provider': provider,
      'settings_json': settings.toString(),
    };
  }

  @override
  Map<String, dynamic>? getUser(String id) => _users[id];

  @override
  void updateUserSettings(String id, Map<String, dynamic> settings) {
    if (_users.containsKey(id)) {
      _users[id]!['settings_json'] = settings.toString(); // Simplified
    }
  }

  @override
  void deleteUser(String id) => _users.remove(id);

  @override
  void createSession(String sid, String userId, int ttlMs) {
    _sessions[sid] = {
      'sid': sid,
      'user_id': userId,
      'expires_at': DateTime.now().millisecondsSinceEpoch + ttlMs,
    };
  }

  @override
  Map<String, dynamic>? getSession(String sid) {
    final session = _sessions[sid];
    if (session == null) return null;
    if (session['expires_at'] < DateTime.now().millisecondsSinceEpoch) {
      _sessions.remove(sid);
      return null;
    }
    return session;
  }

  @override
  void deleteSession(String sid) => _sessions.remove(sid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMailerService implements MailerService {
  @override
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    bool isHtml = false,
  }) async {
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLinkingService implements LinkingService {
  @override
  Map<String, dynamic> startLinking(String userId, {String? platform}) {
    return {'token': 'fake-token'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AuthService', () {
    late AuthService authService;
    late FakeDbService db;

    setUp(() {
      db = FakeDbService();
      authService = AuthService(db, FakeMailerService(), FakeLinkingService());
    });

    test('Update Settings - Missing Session - 403', () async {
      final req = Request('POST', Uri.parse('http://localhost/settings'));
      final res = await authService.router(req);
      expect(res.statusCode, 403);
      final body = await res.readAsString();
      expect(body, contains('unauthorized'));
    });

    test('Update Settings - With Session / No CSRF - 403', () async {
      // Setup User & Session
      db.upsertUser(id: 'user1', email: 'test@example.com', provider: 'google');
      db.createSession('sid_1', 'user1', 100000);

      final req = Request(
        'POST',
        Uri.parse('http://localhost/settings'),
        headers: {'cookie': 'seedsphere_session=sid_1'},
      );

      final res = await authService.router(req);
      expect(res.statusCode, 403);
      final body = await res.readAsString();
      expect(body, contains('csrf_violation'));
    });

    test('Update Settings - With Session AND CSRF - 200', () async {
      // Setup User & Session
      db.upsertUser(id: 'user1', email: 'test@example.com', provider: 'google');
      db.createSession('sid_1', 'user1', 100000);

      final req = Request(
        'POST',
        Uri.parse('http://localhost/settings'),
        headers: {
          'cookie': 'seedsphere_session=sid_1',
          'x-seedsphere-client': 'web',
        },
        body: '{"theme":"dark"}',
      );

      final res = await authService.router(req);
      expect(res.statusCode, 200);
      final body = await res.readAsString();
      expect(body, contains('ok'));
    });

    test('Delete Account - CSRF Enforcement', () async {
      db.upsertUser(id: 'user1', email: 'test@example.com', provider: 'google');
      db.createSession('sid_1', 'user1', 100000);

      final req = Request(
        'DELETE',
        Uri.parse('http://localhost/account'),
        headers: {'cookie': 'seedsphere_session=sid_1'},
      );

      final res = await authService.router(req);
      expect(res.statusCode, 403); // CSRF fail
    });

    test('Unlink Devices - CSRF Enforcement', () async {
      db.upsertUser(id: 'user1', email: 'test@example.com', provider: 'google');
      db.createSession('sid_1', 'user1', 100000);

      final req = Request(
        'POST',
        Uri.parse('http://localhost/unlink'),
        headers: {'cookie': 'seedsphere_session=sid_1'},
      );

      final res = await authService.router(req);
      expect(res.statusCode, 403); // CSRF fail
    });

    test('Magic Link Start - 200', () async {
      final req = Request(
        'POST',
        Uri.parse('http://localhost/magic/start'),
        body: '{"email":"magic@test.com"}',
      );
      final res = await authService.router(req);
      expect(res.statusCode, 200);
      final body = await res.readAsString();
      expect(body, contains('"ok":true'));
    });
  });
}
