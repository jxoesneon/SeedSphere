import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:router/services/ai_service.dart';
import 'package:router/models/ai_models.dart';
import 'dart:convert';

@GenerateNiceMocks([MockSpec<http.Client>()])
import 'ai_service_coverage_test.mocks.dart';

void main() {
  group('AiService Full Coverage', () {
    late AiService aiService;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      aiService = AiService(client: mockClient);
    });

    test('enhanceDescription deepseek success', () async {
      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Enhanced Description'},
              },
            ],
          }),
          200,
        ),
      );

      const req = AiDescriptionRequest(
        title: 'Inception',
        provider: AiProvider.deepseek,
        model: 'deepseek-chat',
      );

      final res = await aiService.enhanceDescription(req);
      expect(res.success, isTrue);
      expect(res.enhancedDescription, 'Enhanced Description');
    });

    test('enhanceDescription openai failure (missing key)', () async {
      const req = AiDescriptionRequest(
        title: 'Inception',
        provider: AiProvider.openai,
        model: 'gpt-4',
      );

      final res = await aiService.enhanceDescription(req);
      expect(res.success, isFalse);
      expect(res.error, contains('No response from AI provider'));
    });
  });
}
