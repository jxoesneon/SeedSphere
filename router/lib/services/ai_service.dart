import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_models.dart';
import 'ai_cache.dart';

/// AI service for enhancing torrent stream descriptions
/// Supports 8 AI providers with caching
/// API keys are passed from Gardener (stored on device)
class AiService {
  final AiCache _cache;
  final http.Client _client;

  /// Create a new AI service
  AiService({AiCache? cache, http.Client? client})
    : _cache = cache ?? AiCache(),
      _client = client ?? http.Client();

  /// Main entry point: Enhance a description using AI
  Future<AiDescriptionResponse> enhanceDescription(
    AiDescriptionRequest request,
  ) async {
    // Check cache first
    final cached = _cache.get(request);
    if (cached != null) {
      return AiDescriptionResponse.success(cached, fromCache: true);
    }

    // Build prompt
    final prompt = _buildPrompt(request);

    // API keys come from Gardener (stored on device)
    final apiKey = request.apiKey;

    // Call appropriate provider
    String? result;
    try {
      switch (request.provider) {
        case AiProvider.deepseek:
          result = await _callDeepSeek(
            apiKey: apiKey,
            model: request.model,
            prompt: prompt,
            timeoutMs: request.timeoutMs,
          );
        case AiProvider.openai:
          result = await _callOpenAI(
            apiKey: apiKey,
            model: request.model,
            prompt: prompt,
            timeoutMs: request.timeoutMs,
          );
        case AiProvider.anthropic:
          result = await _callAnthropic(
            apiKey: apiKey,
            model: request.model,
            prompt: prompt,
            timeoutMs: request.timeoutMs,
          );
        case AiProvider.google:
          result = await _callGoogle(
            apiKey: apiKey,
            model: request.model,
            prompt: prompt,
            timeoutMs: request.timeoutMs,
          );
        case AiProvider.xai:
          result = await _callXAI(
            apiKey: apiKey,
            model: request.model,
            prompt: prompt,
            timeoutMs: request.timeoutMs,
          );
        case AiProvider.mistral:
          result = await _callMistral(
            apiKey: apiKey,
            model: request.model,
            prompt: prompt,
            timeoutMs: request.timeoutMs,
          );
        case AiProvider.meta:
          result = await _callMeta(
            apiKey: apiKey,
            model: request.model,
            prompt: prompt,
            timeoutMs: request.timeoutMs,
          );
        case AiProvider.cohere:
          result = await _callCohere(
            apiKey: apiKey,
            model: request.model,
            prompt: prompt,
            timeoutMs: request.timeoutMs,
          );
      }
    } catch (e) {
      return AiDescriptionResponse.failure('AI API error: $e');
    }

    if (result == null || result.isEmpty) {
      return AiDescriptionResponse.failure('No response from AI provider');
    }

    // Cache the result
    _cache.set(request, result);

    return AiDescriptionResponse.success(result);
  }

  /// Build prompt from request metadata
  String _buildPrompt(AiDescriptionRequest request) {
    final lines = <String>[];
    lines.add('Title: ${request.title}');

    if (request.resolution != null) {
      lines.add('Resolution: ${request.resolution}');
    }
    if (request.group != null) {
      lines.add('Group: ${request.group}');
    }

    final tech = [
      request.source,
      request.codec,
      request.hdr,
      request.audio,
    ].where((e) => e != null).join(' • ');
    if (tech.isNotEmpty) {
      lines.add('Tech: $tech');
    }

    if (request.languages != null && request.languages!.isNotEmpty) {
      lines.add('Languages: ${request.languages!.join(', ')}');
    }
    if (request.sizeStr != null) {
      lines.add('Size: ${request.sizeStr}');
    }
    if (request.trackersAdded != null) {
      lines.add('TrackersAdded: ${request.trackersAdded}');
    }
    if (request.providerName != null) {
      lines.add('Provider: ${request.providerName}');
    }
    if (request.baseDescription != null) {
      lines.add('BaseDescription:\n${request.baseDescription}');
    }

    return '''Given the torrent release details below, produce a concise, emoji-rich, MULTILINE description suitable for Stremio. Keep it under 6 lines. Preserve facts, do not hallucinate. Use the style similar to Torrentio. Do not repeat the title.

${lines.join('\n')}''';
  }

  /// DeepSeek API (OpenAI-compatible, free tier available)
  Future<String?> _callDeepSeek({
    String? apiKey,
    required String model,
    required String prompt,
    required int timeoutMs,
  }) async {
    return _callOpenAICompatible(
      url: 'https://api.deepseek.com/v1/chat/completions',
      apiKey: apiKey ?? '', // Free tier allows empty key
      model: model,
      prompt: prompt,
      timeoutMs: timeoutMs,
    );
  }

  /// OpenAI API
  Future<String?> _callOpenAI({
    String? apiKey,
    required String model,
    required String prompt,
    required int timeoutMs,
  }) async {
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }
    return _callOpenAICompatible(
      url: 'https://api.openai.com/v1/chat/completions',
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      timeoutMs: timeoutMs,
    );
  }

  /// xAI Grok API (OpenAI-compatible)
  Future<String?> _callXAI({
    String? apiKey,
    required String model,
    required String prompt,
    required int timeoutMs,
  }) async {
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }
    return _callOpenAICompatible(
      url: 'https://api.x.ai/v1/chat/completions',
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      timeoutMs: timeoutMs,
    );
  }

  /// Mistral API (OpenAI-compatible)
  Future<String?> _callMistral({
    String? apiKey,
    required String model,
    required String prompt,
    required int timeoutMs,
  }) async {
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }
    return _callOpenAICompatible(
      url: 'https://api.mistral.ai/v1/chat/completions',
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      timeoutMs: timeoutMs,
    );
  }

  /// Meta Llama API (OpenAI-compatible via various providers)
  Future<String?> _callMeta({
    String? apiKey,
    required String model,
    required String prompt,
    required int timeoutMs,
  }) async {
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }
    // Using Meta's hosted API (if they have one) or Replicate
    return _callOpenAICompatible(
      url:
          'https://api.together.xyz/v1/chat/completions', // Together AI hosts Llama
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      timeoutMs: timeoutMs,
    );
  }

  /// Generic OpenAI-compatible API caller
  Future<String?> _callOpenAICompatible({
    required String url,
    required String apiKey,
    required String model,
    required String prompt,
    required int timeoutMs,
  }) async {
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.2,
    });

    final response = await _client
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: body,
        )
        .timeout(Duration(milliseconds: timeoutMs));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) return null;

    final message = choices[0]['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    return content?.trim();
  }

  /// Anthropic Claude API
  Future<String?> _callAnthropic({
    String? apiKey,
    required String model,
    required String prompt,
    required int timeoutMs,
  }) async {
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final body = jsonEncode({
      'model': model,
      'max_tokens': 300,
      'temperature': 0.2,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    });

    final response = await _client
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: body,
        )
        .timeout(Duration(milliseconds: timeoutMs));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List?;
    if (content == null || content.isEmpty) return null;

    final text = content[0]['text'] as String?;
    return text?.trim();
  }

  /// Google Gemini API
  Future<String?> _callGoogle({
    String? apiKey,
    required String model,
    required String prompt,
    required int timeoutMs,
  }) async {
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'safetySettings': [],
      'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 300},
    });

    final response = await _client
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(Duration(milliseconds: timeoutMs));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) return null;

    final text = parts[0]['text'] as String?;
    return text?.trim();
  }

  /// Cohere API
  Future<String?> _callCohere({
    String? apiKey,
    required String model,
    required String prompt,
    required int timeoutMs,
  }) async {
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final body = jsonEncode({
      'model': model,
      'message': prompt,
      'temperature': 0.2,
      'max_tokens': 300,
    });

    final response = await _client
        .post(
          Uri.parse('https://api.cohere.ai/v1/chat'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: body,
        )
        .timeout(Duration(milliseconds: timeoutMs));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['text'] as String?;
    return text?.trim();
  }

  /// Get cache statistics
  Map<String, int> get cacheStats => _cache.stats;

  /// Clear cache
  void clearCache() => _cache.clear();
}
