import 'package:router/models/ai_models.dart';
import 'package:test/test.dart';

void main() {
  group('AiProvider', () {
    test('fromString returns correct enum', () {
      expect(AiProvider.fromString('deepseek'), AiProvider.deepseek);
      expect(AiProvider.fromString('openai'), AiProvider.openai);
      expect(AiProvider.fromString('anthropic'), AiProvider.anthropic);
    });

    test('fromString returns fallback for unknown', () {
      expect(AiProvider.fromString('unknown'), AiProvider.deepseek);
      expect(AiProvider.fromString(''), AiProvider.deepseek);
    });
  });

  group('AiDescriptionRequest', () {
    test('toJson serializes correctly', () {
      const req = AiDescriptionRequest(
        title: 'Movie',
        provider: AiProvider.openai,
        model: 'gpt-4o',
        resolution: '4K',
        trackersAdded: 5,
        timeoutMs: 5000,
      );

      final json = req.toJson();
      expect(json['title'], 'Movie');
      expect(json['provider'], 'openai');
      expect(json['model'], 'gpt-4o');
      expect(json['resolution'], '4K');
      expect(json['trackersAdded'], 5);
      expect(json['timeoutMs'], 5000);
      expect(json['codec'], isNull);
    });
  });

  group('AiDescriptionResponse', () {
    test('success factory', () {
      final res = AiDescriptionResponse.success('Desc', fromCache: true);
      expect(res.success, isTrue);
      expect(res.enhancedDescription, 'Desc');
      expect(res.fromCache, isTrue);
      expect(res.error, isNull);
    });

    test('failure factory', () {
      final res = AiDescriptionResponse.failure('Error');
      expect(res.success, isFalse);
      expect(res.error, 'Error');
      expect(res.enhancedDescription, isNull);
    });
  });
}
