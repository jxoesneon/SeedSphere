import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/cortex_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;

class MockConfigManager extends Mock implements ConfigManager {}

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockConfigManager mockConfig;
  late MockHttpClient mockClient;
  late CortexService cortex;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockConfig = MockConfigManager();
    mockClient = MockHttpClient();
    cortex = CortexService(config: mockConfig, client: mockClient);

    // Default config stubs
    when(() => mockConfig.neuroLinkEnabled).thenReturn(true);
    when(() => mockConfig.cortexModel).thenReturn('test-model');
    when(() => mockConfig.getApiKey(any())).thenAnswer((_) async => 'TEST_KEY');
  });

  test('Generates description using OpenAI', () async {
    when(() => mockConfig.cortexProvider).thenReturn('OpenAI');
    when(
      () => mockClient.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Use the Force, Luke 🪐'},
              },
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    final result = await cortex.generateDescription(
      title: 'Star Wars',
      type: 'movie',
      metadata: '1977',
    );

    expect(result, 'Use the Force, Luke 🪐');
    verify(
      () => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).called(1);
  });

  test('Generates description using Azure', () async {
    when(() => mockConfig.cortexProvider).thenReturn('Azure');
    when(() => mockConfig.azureResource).thenReturn('my-resource');
    when(() => mockConfig.azureDeployment).thenReturn('my-deployment');
    when(() => mockConfig.azureApiVersion).thenReturn('2023-05-15');

    when(
      () => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Azure Magic ✨'},
              },
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    final result = await cortex.generateDescription(
      title: 'Azure Test',
      type: 'show',
    );

    expect(result, 'Azure Magic ✨');
  });

  test('Generates description using Google', () async {
    when(() => mockConfig.cortexProvider).thenReturn('Google');

    when(
      () => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Gemini Output ♊'},
                  ],
                },
              },
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    final result = await cortex.generateDescription(title: 'G', type: 'movie');
    expect(result, 'Gemini Output ♊');
  });

  test('Generates description using Anthropic', () async {
    when(() => mockConfig.cortexProvider).thenReturn('Anthropic');

    when(
      () => mockClient.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'content': [
              {'text': 'Claude Output 🤖'},
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    final result = await cortex.generateDescription(title: 'A', type: 'movie');
    expect(result, 'Claude Output 🤖');
  });

  test('Generates description using DeepSeek', () async {
    when(() => mockConfig.cortexProvider).thenReturn('DeepSeek');

    when(
      () => mockClient.post(
        Uri.parse('https://api.deepseek.com/v1/chat/completions'),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'DeepSeek Logic 🧠'},
              },
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    final result = await cortex.generateDescription(title: 'DS', type: 'movie');
    expect(result, 'DeepSeek Logic 🧠');
  });

  test('Returns null if Neurolink disabled', () async {
    when(() => mockConfig.neuroLinkEnabled).thenReturn(false);

    final result = await cortex.generateDescription(
      title: 'Skip',
      type: 'movie',
    );
    expect(result, isNull);
    verifyNever(
      () => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    );
  });

  test('Handles API Error gracefully', () async {
    when(() => mockConfig.cortexProvider).thenReturn('OpenAI');
    when(
      () => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

    final result = await cortex.generateDescription(
      title: 'Error',
      type: 'movie',
    );
    expect(result, isNull);
  });
}
