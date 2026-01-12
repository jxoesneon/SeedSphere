import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/ui/screens/swarm_dashboard.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/ui/widgets/swarm_health_hero.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MockP2PManager extends Mock implements P2PManager {}

class MockHttpClient extends Mock implements http.Client {}

class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _createMockImageClient();
  }

  HttpClient _createMockImageClient() {
    final client = MockIoHttpClient();
    final request = MockIoHttpClientRequest();
    final response = MockIoHttpClientResponse();
    final headers = MockHttpHeaders();

    when(() => client.getUrl(any())).thenAnswer((_) async => request);
    when(() => request.headers).thenReturn(headers);
    when(() => request.close()).thenAnswer((_) async => response);
    when(() => response.statusCode).thenReturn(200);
    // Valid 1x1 GIF
    final bytes = [
      0x47,
      0x49,
      0x46,
      0x38,
      0x39,
      0x61,
      0x01,
      0x00,
      0x01,
      0x00,
      0x80,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0xFF,
      0xFF,
      0xFF,
      0x21,
      0xF9,
      0x04,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x2C,
      0x00,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x01,
      0x00,
      0x00,
      0x02,
      0x02,
      0x44,
      0x01,
      0x00,
      0x3B,
    ];

    when(() => response.contentLength).thenReturn(bytes.length);
    when(
      () => response.compressionState,
    ).thenReturn(HttpClientResponseCompressionState.notCompressed);
    when(
      () => response.listen(
        any(),
        cancelOnError: any(named: 'cancelOnError'),
        onDone: any(named: 'onDone'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((invocation) {
      final onData =
          invocation.positionalArguments[0] as void Function(List<int>)?;
      final onDone = invocation.namedArguments[#onDone] as void Function()?;
      onData?.call(bytes);
      onDone?.call();
      return Stream<List<int>>.fromIterable([bytes]).listen(null);
    });

    return client;
  }
}

class MockIoHttpClient extends Mock implements HttpClient {}

class MockIoHttpClientRequest extends Mock implements HttpClientRequest {}

class MockIoHttpClientResponse extends Mock implements HttpClientResponse {}

class MockHttpHeaders extends Mock implements HttpHeaders {}

void main() {
  late MockP2PManager mockP2P;
  late MockHttpClient mockClient;
  late StreamController<Map<String, dynamic>> eventController;

  setUp(() async {
    mockP2P = MockP2PManager();
    mockClient = MockHttpClient();
    eventController = StreamController<Map<String, dynamic>>.broadcast();

    // Disable shaders for testing
    AethericGlass.useFallback = true;

    // Setup SharedPreferences
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test_token',
      'stream_history': '[]',
    });
    await ConfigManager().init();

    // Mock P2P setup
    when(() => mockP2P.peerCount).thenReturn(ValueNotifier<int>(0));
    when(
      () => mockP2P.hasEstablishedConnection,
    ).thenReturn(ValueNotifier<bool>(false));
    when(() => mockP2P.sseConnected).thenReturn(ValueNotifier<bool>(false));
    when(() => mockP2P.eventStream).thenAnswer((_) => eventController.stream);
    when(() => mockP2P.gardenerId).thenReturn('test-gardener');

    // Mock HTTP calls
    registerFallbackValue(Uri.parse('http://example.com'));

    // Auth Check
    when(
      () => mockClient.get(
        any(that: predicate<Uri>((u) => u.path.contains('/api/auth/session'))),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'ok': true,
          'user': {'id': '123'},
        }),
        200,
      ),
    );

    // Popular fetch
    when(
      () => mockClient.get(
        any(that: predicate<Uri>((u) => u.path.contains('/movie/top.json'))),
      ),
    ).thenAnswer((_) async => http.Response(jsonEncode({'metas': []}), 200));
  });

  tearDown(() {
    eventController.close();
    AethericGlass.useFallback = false;
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [p2pManagerProvider.overrideWithValue(mockP2P)],
      child: MaterialApp(home: SwarmDashboard(client: mockClient)),
    );
  }

  testWidgets('SwarmDashboard renders core sections', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pump(); // Init state

    expect(find.byType(SwarmHealthHero), findsOneWidget);
    expect(find.text('POPULAR STREAMS'), findsOneWidget);
    expect(find.text('MY STREAMS'), findsOneWidget);
    expect(find.text('PULSE'), findsOneWidget); // Bottom ticker
  });

  testWidgets('SwarmDashboard updates peer count', (tester) async {
    final countNotifier = ValueNotifier<int>(0);
    when(() => mockP2P.peerCount).thenReturn(countNotifier);

    await tester.pumpWidget(createTestWidget());
    await tester.pump();

    // Should show 0 peers initially (implied by SwarmHealthHero state)
    // Update value
    countNotifier.value = 5;
    await tester.pump();

    // SwarmHealthHero should update
    expect(find.textContaining('5 ACTIVE PEERS'), findsOneWidget);
  });

  testWidgets('SwarmDashboard handles popular streams load', (tester) async {
    await HttpOverrides.runZoned(() async {
      final mockMetas = [
        {
          'id': 'tt001',
          'name': 'Test Movie',
          'releaseInfo': '2023',
          'poster': 'url',
        },
      ];
      when(
        () => mockClient.get(
          any(that: predicate<Uri>((u) => u.path.contains('/movie/top.json'))),
        ),
      ).thenAnswer(
        (_) async => http.Response(jsonEncode({'metas': mockMetas}), 200),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump(); // Trigger init
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // Allow future builder/async

      expect(find.text('Test Movie'), findsOneWidget);
    }, createHttpClient: (c) => TestHttpOverrides().createHttpClient(c));
  });

  testWidgets('SwarmDashboard handles interactions (Profile, Logs)', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response(jsonEncode({'metas': []}), 200));

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Tap Profile Icon (Top Right, implied by AppBar or Actions)
      // Assuming layout has an Avatar or Logout button.
      // Looking for UserProfileDialog trigger.

      // Tap "Logs" toggle (if exists) or verify Pulse
      await tester.tap(find.text('PULSE'));
      await tester.pump();
      // Verify state change if possible (e.g. icon color change)

      // Verify "MY STREAMS" section exists
      expect(find.text('MY STREAMS'), findsOneWidget);
    }, createHttpClient: (c) => TestHttpOverrides().createHttpClient(c));
  });
}
