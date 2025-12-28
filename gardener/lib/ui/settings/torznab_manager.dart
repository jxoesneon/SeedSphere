import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

/// Settings screen for managing custom Torznab indexer endpoints.
///
/// Enables users to add, update, and remove multiple Torznab-compatible
/// indexers (e.g., Prowlarr, Jackett) for cross-platform torrent indexing.
///
/// **Persistence:**
/// - Serializes the list of endpoints to a JSON string.
/// - Stores the serialized string in [FlutterSecureStorage] for encrypted persistence.
///
/// **UI Features:**
/// - dynamic list of indexer cards.
/// - Glassmorphic design using [AethericGlass].
/// - Secure input for API keys.
class TorznabManager extends StatefulWidget {
  /// Creates a [TorznabManager] widget.
  const TorznabManager({super.key});

  @override
  State<TorznabManager> createState() => _TorznabManagerState();
}

class _TorznabManagerState extends State<TorznabManager> {
  /// Reference to encrypted platform storage.
  final _storage = const FlutterSecureStorage();

  /// Reactive list of indexer endpoint maps ({'url': ..., 'key': ...}).
  List<Map<String, String>> _endpoints = [];

  /// State flag for first-load async operations.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEndpoints();
  }

  /// Loads the saved JSON endpoint list from secure storage.
  Future<void> _loadEndpoints() async {
    final jsonStr = await _storage.read(key: 'torznab_endpoints');
    if (jsonStr != null) {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      _endpoints = decoded.map((e) => Map<String, String>.from(e)).toList();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Serializes and saves the current [_endpoints] list to secure storage.
  Future<void> _saveEndpoints() async {
    final jsonStr = jsonEncode(_endpoints);
    await _storage.write(key: 'torznab_endpoints', value: jsonStr);
  }

  /// Appends a new empty endpoint entry to the list.
  void _addEndpoint() {
    setState(() {
      _endpoints.add({'url': '', 'key': ''});
    });
  }

  /// Updates a specific field in an endpoint entry and triggers a save.
  ///
  /// [index] - Position in the [_endpoints] list.
  /// [field] - Key to update ('url' or 'key').
  /// [value] - New value for the field.
  void _updateEndpoint(int index, String field, String value) {
    setState(() {
      _endpoints[index][field] = value;
    });
    _saveEndpoints();
  }

  /// Removes an endpoint entry at the given [index].
  void _removeEndpoint(int index) {
    setState(() {
      _endpoints.removeAt(index);
    });
    _saveEndpoints();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      appBar: AppBar(
        title: Text('TORZNAB INDEXERS',
            style: GoogleFonts.outfit(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Global add button
          IconButton(
            icon:
                const Icon(Icons.add_rounded, color: AethericTheme.aetherBlue),
            onPressed: _addEndpoint,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _endpoints.isEmpty
              ? Center(
                  child: Text(
                    'No indexers configured.\nAdd Prowlarr or Jackett endpoints.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: Colors.white30),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _endpoints.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final ep = _endpoints[index];
                    return AethericGlass(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Endpoint URL Input
                            TextField(
                              controller: TextEditingController(text: ep['url'])
                                ..selection = TextSelection.collapsed(
                                    offset: ep['url']?.length ?? 0),
                              onChanged: (val) =>
                                  _updateEndpoint(index, 'url', val),
                              style: GoogleFonts.outfit(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Torznab URL',
                                labelStyle: TextStyle(color: Colors.white54),
                                prefixIcon: Icon(Icons.link_rounded,
                                    color: Colors.white54),
                                border: InputBorder.none,
                              ),
                            ),
                            const Divider(color: Colors.white10),
                            // Endpoint Auth Key Input
                            TextField(
                              controller: TextEditingController(text: ep['key'])
                                ..selection = TextSelection.collapsed(
                                    offset: ep['key']?.length ?? 0),
                              onChanged: (val) =>
                                  _updateEndpoint(index, 'key', val),
                              obscureText: true,
                              style: GoogleFonts.outfit(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'API Key',
                                labelStyle: TextStyle(color: Colors.white54),
                                prefixIcon: Icon(Icons.vpn_key_rounded,
                                    color: Colors.white54),
                                border: InputBorder.none,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Removal Action
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 16),
                                label: Text('Remove',
                                    style: GoogleFonts.outfit(
                                        color: Colors.redAccent)),
                                onPressed: () => _removeEndpoint(index),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
