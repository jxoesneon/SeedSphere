import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:router/services/ai_service.dart';
import 'package:router/services/ai_cache.dart';
import 'package:router/models/ai_models.dart';

void main() {
  group('AiCache', () {
    test('should store and retrieve values', () {
      final cache = AiCache();
      final request = const AiDescriptionRequest(
        title: 'Test Movie',
        provider: AiProvider.deepseek,
        model: 'test-model',
      );

      cache.set(request, 'Cached Result');
      final result = cache.get(request);

      expect(result, 'Cached Result');
      expect(cache.stats['hits'], 1);
      expect(cache.stats['misses'], 0);
    });

    test('should return null for missing keys', () {
      final cache = AiCache();
      final request = const AiDescriptionRequest(
        title: 'Missing Movie',
        provider: AiProvider.deepseek,
        model: 'test-model',
      );

      final result = cache.get(request);

      expect(result, isNull);
      expect(cache.stats['hits'], 0);
      expect(cache.stats['misses'], 1);
    });

    test('should expire values after TTL', () async {
      final cache = AiCache(defaultTtlMs: 1); // 1ms TTL
      final request = const AiDescriptionRequest(
        title: 'Expired Movie',
        provider: AiProvider.deepseek,
        model: 'test-model',
      );

      cache.set(request, 'Expired Result');
      await Future.delayed(
        const Duration(milliseconds: 10),
      ); // Wait for expiration
      final result = cache.get(request);

      expect(result, isNull);
      expect(cache.stats['misses'], 1); // Should count as miss due to expiry
    });

    test('clear should empty cache', () {
      final cache = AiCache();
      final request = const AiDescriptionRequest(
        title: 'Test',
        provider: AiProvider.deepseek,
        model: 'test-model',
      );
      cache.set(request, 'Val');
      cache.clear();
      expect(cache.get(request), isNull);
    });
  });

  group('AiService', () {
    test(
      'should enhance description using DeepSeek (OpenAI compatible)',
      () async {
        final mockClient = MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.deepseek.com/v1/chat/completions',
          );
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Enhanced Description'},
                },
              ],
            }),
            200,
          );
        });

        final service = AiService(client: mockClient);
        final request = const AiDescriptionRequest(
          title: 'Test Movie',
          provider: AiProvider.deepseek,
          model: 'deepseek-chat',
          apiKey: 'test-key',
        );

        final response = await service.enhanceDescription(request);

        expect(response.success, isTrue);
        expect(response.enhancedDescription, 'Enhanced Description');
        expect(response.fromCache, isFalse);
      },
    );

    test('should use cached response if available', () async {
      // Client shouldn't be called
      final mockClient = MockClient(
        (request) async => http.Response('Error', 500),
      );
      final cache = AiCache();
      final service = AiService(client: mockClient, cache: cache);
      final request = const AiDescriptionRequest(
        title: 'Cached Movie',
        provider: AiProvider.deepseek,
        model: 'deepseek-chat',
      );

      cache.set(request, 'Cached Description');

      final response = await service.enhanceDescription(request);

      expect(response.success, isTrue);
      expect(response.enhancedDescription, 'Cached Description');
      expect(response.fromCache, isTrue);
    });

    test('should handle API errors gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = AiService(client: mockClient);
      final request = const AiDescriptionRequest(
        title: 'Error Movie',
        provider: AiProvider.deepseek,
        model: 'deepseek-chat',
        apiKey: 'test-key',
      );

      final response = await service.enhanceDescription(request);

      expect(response.success, isFalse);
      expect(response.error, contains('HTTP 500'));
    });

    test('should handle Anthropic format', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');
        return http.Response(
          jsonEncode({
            'content': [
              {'text': 'Claude Description'},
            ],
          }),
          200,
        );
      });

      final service = AiService(client: mockClient);
      final request = const AiDescriptionRequest(
        title: 'Test Movie',
        provider: AiProvider.anthropic,
        model: 'claude-3',
        apiKey: 'test-key',
      );

      final response = await service.enhanceDescription(request);

      expect(response.success, isTrue);
      expect(response.enhancedDescription, 'Claude Description');
    });

    test('should handle Google Gemini format', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          contains('generativelanguage.googleapis.com'),
        );
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Gemini Description'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = AiService(client: mockClient);
      final request = const AiDescriptionRequest(
        title: 'Test Movie',
        provider: AiProvider.google,
        model: 'gemini-pro',
        apiKey: 'test-key',
      );

      final response = await service.enhanceDescription(request);

      expect(response.success, isTrue);
      expect(response.enhancedDescription, 'Gemini Description');
    });

    test('should handle Cohere format', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.cohere.ai/v1/chat');
        return http.Response(jsonEncode({'text': 'Cohere Description'}), 200);
      });

      final service = AiService(client: mockClient);
      final request = const AiDescriptionRequest(
        title: 'Test Movie',
        provider: AiProvider.cohere,
        model: 'command-r',
        apiKey: 'test-key',
      );

      final response = await service.enhanceDescription(request);

      expect(response.success, isTrue);
      expect(response.enhancedDescription, 'Cohere Description');
    });
  });
}
