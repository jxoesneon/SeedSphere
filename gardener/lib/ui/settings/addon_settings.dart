import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gardener/core/network_constants.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/settings/settings.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

/// Settings screen for configuring SeedSphere Stremio Addon.
///
/// Allows managing content catalogs (Movies, Series, Anime) and
/// AI-driven dynamic lists.
class AddonSettings extends StatefulWidget {
  const AddonSettings({super.key});

  @override
  State<AddonSettings> createState() => _AddonSettingsState();
}

class _AddonSettingsState extends State<AddonSettings> {
  final _storage = const FlutterSecureStorage();

  bool _isLoading = true;
  String? _error;

  // Settings State
  bool _hideMovies = false;
  bool _hideSeries = false;
  bool _hideAnime = false;
  List<String> _dynamicCatalogs = [];

  final TextEditingController _dynamicInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<String?> _getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Not logged in. Please link your account or sign in.');
      }

      final uri = Uri.parse('${NetworkConstants.apiBase}/api/auth/session');
      final resp = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (resp.statusCode != 200) {
        throw Exception('Failed to fetch session: ${resp.statusCode}');
      }

      final data = jsonDecode(resp.body);
      if (data['ok'] != true || data['user'] == null) {
        throw Exception('Invalid session response');
      }

      final settings = data['user']['settings'] ?? {};

      setState(() {
        _hideMovies = settings['hide_movies'] == true;
        _hideSeries = settings['hide_series'] == true;
        _hideAnime = settings['hide_anime'] == true;

        final dynList = settings['dynamic_catalogs'];
        if (dynList is List) {
          _dynamicCatalogs = List<String>.from(dynList);
        } else {
          _dynamicCatalogs = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    // Optimistic UI update already happened. Now persist.
    // We don't show loading here to keep UI fluid, but we could show a snackbar.
    try {
      final token = await _getToken();
      if (token == null) return; // Should handle error

      final settings = {
        'hide_movies': _hideMovies,
        'hide_series': _hideSeries,
        'hide_anime': _hideAnime,
        'dynamic_catalogs': _dynamicCatalogs,
      };

      final uri = Uri.parse('${NetworkConstants.apiBase}/api/auth/settings');
      final resp = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(settings),
      );

      if (resp.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  void _addDynamicCatalog() {
    final val = _dynamicInput.text.trim();
    if (val.isEmpty) return;
    if (_dynamicCatalogs.contains(val)) return;

    setState(() {
      _dynamicCatalogs.add(val);
      _dynamicInput.clear();
    });
    _saveSettings();
  }

  void _removeDynamicCatalog(String val) {
    setState(() {
      _dynamicCatalogs.remove(val);
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'ADDON CONFIGURATION',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                // Standard Catalogs
                SettingsSection(
                  title: 'CONTENT CATALOGS',
                  children: [
                    SettingsToggle(
                      title: 'Movies',
                      description: 'Enable standard Movie catalogs',
                      leadingIcon: Icons.movie_rounded,
                      value: !_hideMovies,
                      onChanged: (v) {
                        setState(() => _hideMovies = !v);
                        _saveSettings();
                      },
                    ),
                    SettingsToggle(
                      title: 'Series',
                      description: 'Enable TV Series catalogs',
                      leadingIcon: Icons.tv_rounded,
                      value: !_hideSeries,
                      onChanged: (v) {
                        setState(() => _hideSeries = !v);
                        _saveSettings();
                      },
                    ),
                    SettingsToggle(
                      title: 'Anime',
                      description: 'Enable Anime catalogs',
                      leadingIcon: Icons.animation_rounded,
                      value: !_hideAnime,
                      onChanged: (v) {
                        setState(() => _hideAnime = !v);
                        _saveSettings();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Dynamic Catalogs
                SettingsSection(
                  title: 'DYNAMIC AI CATALOGS',
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Create custom catalogs powered by AI prompts.',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _dynamicInput,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Marvel, Cyberpunk 90s...',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withValues(
                                      alpha: 0.05,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  onSubmitted: (_) => _addDynamicCatalog(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: _addDynamicCatalog,
                                style: IconButton.styleFrom(
                                  backgroundColor: AethericTheme.aetherBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(12),
                                ),
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _dynamicCatalogs.map((cat) {
                              return Chip(
                                label: Text(
                                  cat,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: AethericTheme.glassSurface,
                                deleteIcon: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                                onDeleted: () => _removeDynamicCatalog(cat),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
