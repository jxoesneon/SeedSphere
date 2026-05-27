import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'dart:convert';
import 'package:router/auth_service.dart';
import 'package:router/db_service.dart';
import 'package:router/mailer_service.dart';
import 'package:router/linking_service.dart';

@GenerateNiceMocks([
  MockSpec<DbService>(),
  MockSpec<MailerService>(),
  MockSpec<LinkingService>(),
  MockSpec<http.Client>(),
])
import 'auth_service_coverage_test.mocks.dart';

void main() {
  group('AuthService Deep Coverage', () {
    late AuthService authService;
    late MockDbService mockDb;
    late MockMailerService mockMailer;
    late MockLinkingService mockLinking;
    late MockClient mockClient;

    setUp(() {
      mockDb = MockDbService();
      mockMailer = MockMailerService();
      mockLinking = MockLinkingService();
      mockClient = MockClient();
      authService = AuthService(
        mockDb,
        mockMailer,
        mockLinking,
        client: mockClient,
        googleClientId: 'web-id',
        googleClientSecret: 'secret',
      );
    });

    test('logout clears session', () async {
      final req = Request(
        'POST',
        Uri.parse('http://localhost/logout'),
        headers: {'cookie': 'seedsphere_session=sid1'},
      );
      final res = await authService.router(req);
      expect(res.statusCode, 200);
      expect(res.headers['set-cookie'], contains('Max-Age=0'));
      verify(mockDb.deleteSession('sid1')).called(1);
    });

    test('get sessions list', () async {
      when(mockDb.getSession('sid1')).thenReturn({'user_id': 'u1'});
      when(mockDb.getSessions('u1')).thenReturn([
        {'sid': 'sid1'},
        {'sid': 'sid2'},
      ]);

      final req = Request(
        'GET',
        Uri.parse('http://localhost/sessions'),
        headers: {'cookie': 'seedsphere_session=sid1'},
      );
      final res = await authService.router(req);
      final body = jsonDecode(await res.readAsString());
      expect(body['sessions'], hasLength(2));
      expect(body['sessions'][0]['is_current'], isTrue);
    });

    test('google verify auto-link', () async {
      final payload = base64UrlEncode(
        utf8.encode(
          jsonEncode({
            'sub': '123',
            'email': 'user@gmail.com',
            'aud': 'web-id',
          }),
        ),
      );
      final idToken = 'header.$payload.signature';

      when(
        mockLinking.bindDirectly('g1', 'mobile-app'),
      ).thenReturn('secret123');

      final req = Request(
        'POST',
        Uri.parse('http://localhost/google/verify'),
        body: jsonEncode({'idToken': idToken, 'gardenerId': 'g1'}),
      );
      final res = await authService.router(req);
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString());
      expect(body['secret'], 'secret123');
      verify(
        mockDb.upsertGardener('g1', platform: anyNamed('platform')),
      ).called(1);
    });
  });
}
