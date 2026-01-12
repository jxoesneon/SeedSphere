import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gardener/core/config_manager.dart';
import 'package:flutter/foundation.dart';

/// Service for interacting with various AI providers (Cortex).
///
/// Port of legacy/server/lib/ai_descriptions.cjs
class CortexService {
  final ConfigManager _config;
  final http.Client _client;

  CortexService({ConfigManager? config, http.Client? client})
    : _config = config ?? ConfigManager(),
      _client = client ?? http.Client();

  /// Generates an AI-enhanced description for a stream.
  Future<String?> generateDescription({
    required String title,
    required String type,
    String? metadata,
  }) async {
    if (!_config.neuroLinkEnabled) return null;

    final provider = _config.cortexProvider;
    final model = _config.cortexModel;
    final apiKey = await _config.getApiKey(provider);

    // Allow DeepSeek to proceed without key (Mock/Free Tier)
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('CORTEX: No API key for $provider');
      return null;
    }

    try {
      final prompt = _buildPrompt(title, type, metadata);

      switch (provider) {
        case 'OpenAI':
          return await _callOpenAI(model, apiKey, prompt);
        case 'Azure':
          return await _callAzure(apiKey, prompt);
        case 'DeepSeek':
          return await _callDeepSeek(model, apiKey, prompt);
        case 'Google':
          return await _callGoogle(model, apiKey, prompt);
        case 'Anthropic':
          return await _callAnthropic(model, apiKey, prompt);
        default:
          debugPrint('CORTEX: Provider $provider not implemented');
          return null;
      }
    } catch (e) {
      debugPrint('CORTEX: Error generating description: $e');
      return null;
    }
  }

  String _buildPrompt(String title, String type, String? metadata) {
    return 'Analyze this $type stream: "$title". metadata: $metadata. '
        'Provide a premium, high-density description for the SeedSphere catalog. '
        'Include: 1. Resolution & Quality emoji (e.g. 💎 4K). 2. Audio tech (e.g. 🎧 Atmos). 3. A one-sentence cinematic summary. '
        'Keep it under 150 characters total. No markdown. Use emojis sparingly for a clean look.';
  }

  Future<String?> _callAzure(String apiKey, String prompt) async {
    final resource = _config.azureResource;
    final deployment = _config.azureDeployment;
    final ver = _config.azureApiVersion;

    if (resource.isEmpty || deployment.isEmpty) return null;

    final url =
        'https://$resource.openai.azure.com/openai/deployments/$deployment/chat/completions?api-version=$ver';

    final response = await _client.post(
      Uri.parse(url),
      headers: {'api-key': apiKey, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 100,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    }
    return null;
  }

  Future<String?> _callDeepSeek(
    String model,
    String apiKey,
    String prompt,
  ) async {
    final response = await _client.post(
      Uri.parse('https://api.deepseek.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 50,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    }
    return null;
  }

  Future<String?> _callOpenAI(
    String model,
    String apiKey,
    String prompt,
  ) async {
    final response = await _client.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 50,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    }
    return null;
  }

  Future<String?> _callGoogle(
    String model,
    String apiKey,
    String prompt,
  ) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
    final response = await _client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'maxOutputTokens': 50},
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'];
    }
    return null;
  }

  Future<String?> _callAnthropic(
    String model,
    String apiKey,
    String prompt,
  ) async {
    final response = await _client.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 50,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'];
    }
    return null;
  }
}
