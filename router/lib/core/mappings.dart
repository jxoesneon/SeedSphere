/// Static data mappings ported from legacy JSON files.
class StreamMappings {
  // --- Languages ---

  /// Canonical language definitions
  static const List<Map<String, String>> languages = [
    {'code': 'en', 'display': 'English', 'flag': '🇬🇧'},
    {'code': 'es-ES', 'display': 'Spanish (Spain)', 'flag': '🇪🇸'},
    {'code': 'es-419', 'display': 'Spanish (Latino)', 'flag': '🇲🇽'},
    {'code': 'fr', 'display': 'French', 'flag': '🇫🇷'},
    {'code': 'de', 'display': 'German', 'flag': '🇩🇪'},
    {'code': 'it', 'display': 'Italian', 'flag': '🇮🇹'},
    {'code': 'pt-PT', 'display': 'Portuguese (Portugal)', 'flag': '🇵🇹'},
    {'code': 'pt-BR', 'display': 'Portuguese (Brazil)', 'flag': '🇧🇷'},
    {'code': 'nl', 'display': 'Dutch', 'flag': '🇳🇱'},
    {'code': 'sv', 'display': 'Swedish', 'flag': '🇸🇪'},
    {'code': 'no', 'display': 'Norwegian', 'flag': '🇳🇴'},
    {'code': 'da', 'display': 'Danish', 'flag': '🇩🇰'},
    {'code': 'fi', 'display': 'Finnish', 'flag': '🇫🇮'},
    {'code': 'pl', 'display': 'Polish', 'flag': '🇵🇱'},
    {'code': 'cs', 'display': 'Czech', 'flag': '🇨🇿'},
    {'code': 'ro', 'display': 'Romanian', 'flag': '🇷🇴'},
    {'code': 'hu', 'display': 'Hungarian', 'flag': '🇭🇺'},
    {'code': 'el', 'display': 'Greek', 'flag': '🇬🇷'},
    {'code': 'tr', 'display': 'Turkish', 'flag': '🇹🇷'},
    {'code': 'ru', 'display': 'Russian', 'flag': '🇷🇺'},
    {'code': 'uk', 'display': 'Ukrainian', 'flag': '🇺🇦'},
    {'code': 'he', 'display': 'Hebrew', 'flag': '🇮🇱'},
    {'code': 'ar', 'display': 'Arabic', 'flag': '🇦🇪'},
    {'code': 'hi', 'display': 'Hindi', 'flag': '🇮🇳'},
    {'code': 'id', 'display': 'Indonesian', 'flag': '🇮🇩'},
    {'code': 'th', 'display': 'Thai', 'flag': '🇹🇭'},
    {'code': 'vi', 'display': 'Vietnamese', 'flag': '🇻🇳'},
    {'code': 'ja', 'display': 'Japanese', 'flag': '🇯🇵'},
    {'code': 'ko', 'display': 'Korean', 'flag': '🇰🇷'},
    {'code': 'zh-CN', 'display': 'Chinese (Simplified)', 'flag': '🇨🇳'},
    {'code': 'zh-TW', 'display': 'Chinese (Traditional)', 'flag': '🇹🇼'},
  ];

  /// Language aliases for normalized detection
  static const Map<String, String> languageAliases = {
    'en': 'en',
    'eng': 'en',
    'english': 'en',
    'en-us': 'en',
    'en-gb': 'en',
    'es-es': 'es-ES',
    'es_es': 'es-ES',
    'castellano': 'es-ES',
    'spanish spain': 'es-ES',
    'es-419': 'es-419',
    'es_419': 'es-419',
    'latino': 'es-419',
    'es-la': 'es-419',
    'es-mx': 'es-419',
    'spanish latino': 'es-419',
    'fr': 'fr',
    'fre': 'fr',
    'fra': 'fr',
    'french': 'fr',
    'français': 'fr',
    'de': 'de',
    'ger': 'de',
    'deu': 'de',
    'german': 'de',
    'deutsch': 'de',
    'it': 'it',
    'ita': 'it',
    'italian': 'it',
    'italiano': 'it',
    'pt': 'pt-PT',
    'pt-pt': 'pt-PT',
    'portuguese': 'pt-PT',
    'português': 'pt-PT',
    'pt-br': 'pt-BR',
    'brazil': 'pt-BR',
    'br': 'pt-BR',
    'portuguese brazil': 'pt-BR',
    'zh-cn': 'zh-CN',
    'chs': 'zh-CN',
    'simplified chinese': 'zh-CN',
    'zh-tw': 'zh-TW',
    'cht': 'zh-TW',
    'traditional chinese': 'zh-TW',
    'multi': 'Multi',
    'multi-lang': 'Multi',
    'multi audio': 'Multi',
    'dual': 'Multi',
  };

  // --- Editions ---

  /// Mapping of standard edition types to their common aliases.
  static const Map<String, List<String>> editions = {
    'Director’s Cut': ['directors cut', 'director\'s cut', 'dircut'],
    'Extended Edition': [
      'extended',
      'extended edition',
      'ext edition',
      'extended cut',
    ],
    'Ultimate Edition': ['ultimate', 'ultimate edition'],
    'Theatrical Cut': ['theatrical', 'theatrical cut'],
    'Unrated': ['unrated'],
    'IMAX': ['imax'],
    'Special Edition': ['special', 'special edition'],
  };

  // --- Quality ---

  /// Mapping of resolution quality labels to their common aliases.
  static const Map<String, List<String>> qualityAliases = {
    '4K': ['2160p', '4k', 'uhd', 'ultra hd', 'uhd-4k', '4k uhd'],
    '1080p': [
      '1080p',
      'fhd',
      'fullhd',
      'full hd',
      'blu-ray 1080p',
      'web-dl 1080p',
      'bdrip 1080p',
    ],
    '720p': ['720p', 'hd', 'web 720p', 'bdrip 720p'],
    '480p': ['480p', 'sd', 'dvd', 'dvdrip'],
  };
}
