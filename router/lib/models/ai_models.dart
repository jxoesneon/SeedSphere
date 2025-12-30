/// AI provider types supported by Cortex
enum AiProvider {
  /// DeepSeek (Default, Free)
  deepseek('deepseek'),

  /// OpenAI (GPT models)
  openai('openai'),

  /// Anthropic (Claude models)
  anthropic('anthropic'),

  /// Google (Gemini models)
  google('google'),

  /// xAI (Grok models)
  xai('xai'),

  /// Mistral AI
  mistral('mistral'),

  /// Meta (Llama models)
  meta('meta'),

  /// Cohere
  cohere('cohere');

  /// Construct from value
  const AiProvider(this.value);

  /// String value for serialization
  final String value;

  /// Parse from string with fallback to deepseek
  static AiProvider fromString(String value) {
    return AiProvider.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => AiProvider.deepseek,
    );
  }
}

/// Request to AI service for description enhancement
class AiDescriptionRequest {
  /// Media title
  final String title;

  /// Video resolution (e.g. 1080p, 4K)
  final String? resolution;

  /// Video codec (e.g. x264, HEVC)
  final String? codec;

  /// HDR format
  final String? hdr;

  /// Audio format
  final String? audio;

  /// Release source
  final String? source;

  /// Release group
  final String? group;

  /// Available languages
  final List<String>? languages;

  /// File size string
  final String? sizeStr;

  /// Number of trackers added
  final int? trackersAdded;

  /// Provider name
  final String? providerName;

  /// Original description to append
  final String? baseDescription;

  // AI configuration

  /// AI Provider to use
  final AiProvider provider;

  /// Model identifier
  final String model;

  /// API Key (optional override)
  final String? apiKey; // Optional override

  /// Timeout in milliseconds
  final int timeoutMs;

  /// User ID for context
  final String? userId; // For DB key lookup

  /// Create a new request
  const AiDescriptionRequest({
    required this.title,
    this.resolution,
    this.codec,
    this.hdr,
    this.audio,
    this.source,
    this.group,
    this.languages,
    this.sizeStr,
    this.trackersAdded,
    this.providerName,
    this.baseDescription,
    required this.provider,
    required this.model,
    this.apiKey,
    this.timeoutMs = 2500,
    this.userId,
  });

  /// Convert to JSON map
  Map<String, dynamic> toJson() => {
    'title': title,
    'resolution': resolution,
    'codec': codec,
    'hdr': hdr,
    'audio': audio,
    'source': source,
    'group': group,
    'languages': languages,
    'sizeStr': sizeStr,
    'trackersAdded': trackersAdded,
    'providerName': providerName,
    'baseDescription': baseDescription,
    'provider': provider.value,
    'model': model,
    'timeoutMs': timeoutMs,
  };
}

/// Response from AI service
class AiDescriptionResponse {
  /// The enhanced description text
  final String? enhancedDescription;

  /// Whether the request was successful
  final bool success;

  /// Error message if failed
  final String? error;

  /// Whether the response came from cache
  final bool fromCache;

  /// Create a new response
  const AiDescriptionResponse({
    this.enhancedDescription,
    required this.success,
    this.error,
    this.fromCache = false,
  });

  /// Create a success response
  factory AiDescriptionResponse.success(
    String description, {
    bool fromCache = false,
  }) {
    return AiDescriptionResponse(
      enhancedDescription: description,
      success: true,
      fromCache: fromCache,
    );
  }

  /// Create a failure response
  factory AiDescriptionResponse.failure(String error) {
    return AiDescriptionResponse(success: false, error: error);
  }
}
