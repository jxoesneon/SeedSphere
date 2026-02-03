import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/auth/desktop_google_auth.dart';
import 'package:gardener/core/debug_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

// --- Mocks ---

class MockUrlLauncher extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

class MockHttpClient extends Mock implements HttpClient {
  @override
  set autoUncompress(bool _) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return MockHttpClientRequest();
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return MockHttpClientRequest();
  }
}

class MockHttpClientRequest extends Mock implements HttpClientRequest {
  final _headers = MockHttpHeaders();
  @override
  HttpHeaders get headers => _headers;

  @override
  void add(List<int> data) {}

  @override
  void write(Object? object) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain();
  }

  @override
  Future<HttpClientResponse> close() async {
    return MockHttpClientResponse();
  }
}

class MockHttpHeaders extends Mock implements HttpHeaders {
  @override
  ContentType? contentType;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class MockHttpClientResponse extends Mock implements HttpClientResponse {
  final _headers = MockHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => [];

  @override
  int get statusCode => 200;

  @override
  int get contentLength => -1;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final responseData = jsonEncode({'id_token': 'MOCK_ID_TOKEN'});
    return Stream.value(utf8.encode(responseData)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

// --- IO Overrides (Client Only) ---

class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

// --- Test ---

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockUrlLauncher mockLauncher;

  setUpAll(() {
    registerFallbackValue(LaunchOptions());
  });

  setUp(() {
    mockLauncher = MockUrlLauncher();
    UrlLauncherPlatform.instance = mockLauncher;
  });

  test(
    'DesktopGoogleAuth full flow success (Real Server, Mock Client)',
    () async {
      if (const String.fromEnvironment('GOOGLE_CLIENT_SECRET').isEmpty) {
        // ignore: avoid_print
        print('Skipping Google Auth test: GOOGLE_CLIENT_SECRET missing');
        return;
      }
      await HttpOverrides.runZoned(() async {
        // 1. Setup Launcher Mock
        when(() => mockLauncher.canLaunch(any())).thenAnswer((_) async => true);
        when(
          () => mockLauncher.launchUrl(any(), any()),
        ).thenAnswer((_) async => true);

        // 2. Start Auth (Should start real server on ephemeral port)
        final authFuture = DesktopGoogleAuth.signIn();

        // 3. Poll for server start / URL launch
        await untilCalled(() => mockLauncher.launchUrl(any(), any()));

        final verification = verify(
          () => mockLauncher.launchUrl(captureAny(), any()),
        );
        final url = verification.captured.first as String;
        final uri = Uri.parse(url);

        expect(uri.host, 'accounts.google.com');
        final redirectUri = Uri.parse(uri.queryParameters['redirect_uri']!);

        // 4. Simulate Callback to Real Server
        final port = redirectUri.port;
        final callbackPath = redirectUri.path;

        await _sendRawGetRequest(port, '$callbackPath?code=TEST_AUTH_CODE');

        // 5. Await Result
        final token = await authFuture;
        expect(token, 'MOCK_ID_TOKEN');
      }, createHttpClient: (context) => MockHttpClient());
    },
  );

  test('DesktopGoogleAuth logs debug traces when authGated is true', () async {
    if (const String.fromEnvironment('GOOGLE_CLIENT_SECRET').isEmpty) {
      // ignore: avoid_print
      print('Skipping Google Auth test: GOOGLE_CLIENT_SECRET missing');
      return;
    }
    DebugConfig.authGated = true; // Enable Debug Mode checks

    await HttpOverrides.runZoned(() async {
      when(() => mockLauncher.canLaunch(any())).thenAnswer((_) async => true);
      when(
        () => mockLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);

      final authFuture = DesktopGoogleAuth.signIn();
      await untilCalled(() => mockLauncher.launchUrl(any(), any()));

      final verification = verify(
        () => mockLauncher.launchUrl(captureAny(), any()),
      );
      final url = verification.captured.first as String;
      final uri = Uri.parse(url);
      final redirectUri = Uri.parse(uri.queryParameters['redirect_uri']!);

      // Complete successfully
      await _sendRawGetRequest(
        redirectUri.port,
        '${redirectUri.path}?code=TRACE_TEST',
      );
      await authFuture;
    }, createHttpClient: (context) => MockHttpClient());

    DebugConfig.authGated = false; // Reset
  });
}

Future<void> _sendRawGetRequest(int port, String path) async {
  // Use a raw socket to hit loopback, bypassing HttpOverrides
  final socket = await Socket.connect('localhost', port);
  socket.write('GET $path HTTP/1.1\r\nHost: localhost\r\n\r\n');
  await socket.flush();
  socket.destroy();
}
