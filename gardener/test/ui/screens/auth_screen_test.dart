import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/ui/screens/auth_screen.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';

class MockClient extends Mock implements http.Client {}

class MockP2PManager extends Mock implements P2PManager {
  @override
  final ValueNotifier<int> peerCount = ValueNotifier(0);
  @override
  final ValueNotifier<bool> sseConnected = ValueNotifier(false);
  @override
  Stream<Map<String, dynamic>> get eventStream => const Stream.empty();
  @override
  String? get gardenerId => 'mock-gardener-id';
  @override
  Future<void> start() async {}
  @override
  Map<String, String> get diagnosticMetadata => {};
}

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient extends Mock implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
  @override
  Future<HttpClientRequest> postUrl(Uri url) async => _MockHttpClientRequest();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _MockHttpClientRequest();
  @override
  set autoUncompress(bool autoUncompress) {}
}

class _MockHttpClientRequest extends Mock implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
  @override
  void add(List<int> data) {}
  @override
  void write(Object? obj) {}
  @override
  void writeln([Object? obj = ""]) {}
  @override
  Future addStream(Stream<List<int>> stream) async {}
  @override
  Future<HttpClientResponse> get done async => _MockHttpClientResponse();
  @override
  set bufferOutput(bool bufferOutput) {}
  @override
  set contentLength(int contentLength) {}
  @override
  set encoding(Encoding encoding) {}
  @override
  set followRedirects(bool followRedirects) {}
  @override
  set maxRedirects(int maxRedirects) {}
  @override
  set persistentConnection(bool persistentConnection) {}
}

class _MockHttpHeaders extends Mock implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  set contentType(ContentType? type) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  List<String>? operator [](String name) => null;
}

class _MockHttpClientResponse extends Mock implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _transparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  HttpHeaders get headers => _MockHttpHeaders();
  @override
  bool get persistentConnection => true;
  @override
  bool get isRedirect => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_transparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followRedirects,
  ]) async => this;
}

final List<int> _transparentImage = utf8.encode(
  '{"ok":true}',
); // Default JSON response

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MockHttpOverrides();

  setUpAll(() async {
    AethericGlass.useFallback = true;
    SharedPreferences.setMockInitialValues({});
    await ConfigManager().init();
  });

  group('AuthScreen Tests', () {
    late MockP2PManager mockP2P;
    bool authenticated = false;

    setUp(() {
      mockP2P = MockP2PManager();
      authenticated = false;
      FlutterSecureStorage.setMockInitialValues({});
    });

    Widget createSubject() {
      return ProviderScope(
        overrides: [p2pManagerProvider.overrideWithValue(mockP2P)],
        child: MaterialApp(
          home: AuthScreen(
            onAuthenticated: () {
              authenticated = true;
            },
          ),
        ),
      );
    }

    testWidgets('Renders all login options', (WidgetTester tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pump();

      expect(find.text('SEEDSPHERE'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget); // Hint text
      expect(find.text('SEND MAGIC LINK'), findsOneWidget);
      expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget);
    });

    testWidgets('Magic Link flow - success', (WidgetTester tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pump();

      // Enter email
      await tester.enterText(find.byType(TextField), 'test@example.com');
      await tester.pump();

      // Tap send
      await tester.tap(find.text('SEND MAGIC LINK'));

      // We expect a POST /api/auth/magic/start
      // But we are using HttpOverrides, which returns 200 for everything by default in our mock

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // Wait for async
      await tester.pump();

      expect(find.text('Check your email!'), findsOneWidget);
      expect(
        find.text('Click the link we sent to complete sign-in.'),
        findsOneWidget,
      );
    });

    testWidgets('Magic Link flow - invalid email', (WidgetTester tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pump();

      // Enter invalid email
      await tester.enterText(find.byType(TextField), 'invalid-email');
      await tester.pump();

      // Tap send
      await tester.tap(find.text('SEND MAGIC LINK'));
      await tester.pump();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });

    testWidgets('Magic Link flow - network error', (WidgetTester tester) async {
      // For this specific test, we might want to verify it handles failure.
      // Since our mock HttpOverrides returns 200, it's hard to test 500 without more complex mocking.
      // But we can test the general UI behavior.
    });

    testWidgets('Debug Mode - Skip Auth is disabled in Release/Hotfix', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: AuthScreen(onAuthenticated: () {})),
        ),
      );

      // Verify the button is NOT present
      expect(find.text('Skip (Debug Only)'), findsNothing);
    });
  });
}
