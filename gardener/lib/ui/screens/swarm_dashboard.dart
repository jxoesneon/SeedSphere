import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gardener/ui/settings/swarm_settings_menu.dart';
import 'package:gardener/ui/settings/swarm_uplink_settings.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/swarm_health_hero.dart';
import 'package:gardener/ui/widgets/signal_card.dart';
import 'package:google_fonts/google_fonts.dart';

/// "The Observatory" - Central hub for swarm monitoring and discovery.
class SwarmDashboard extends StatefulWidget {
  const SwarmDashboard({super.key});

  @override
  State<SwarmDashboard> createState() => _SwarmDashboardState();
}

class _SwarmDashboardState extends State<SwarmDashboard> {
  // State
  bool _sseConnected = false;
  int _peerCount = 0;
  final List<String> _logs = [];
  final List<Map<String, dynamic>> _recentResults = [];
  List<Map<String, dynamic>> _popularSignals = [];

  StreamSubscription? _sseSubscription;
  final http.Client _client = http.Client();

  @override
  void initState() {
    super.initState();
    _connectSSE();
    _fetchPopular();
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _client.close();
    super.dispose();
  }

  /// Fetches popular content from the local SeedSphere Addon.
  Future<void> _fetchPopular() async {
    try {
      // SeedSphere router exposes standard Stremio addon catalog at root
      // 'top' catalog for 'movie' type
      final uri = Uri.parse('http://127.0.0.1:8080/catalog/movie/top.json');
      final resp = await _client.get(uri);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final metas = (data['metas'] as List).take(10).toList();

        if (mounted) {
          setState(() {
            _popularSignals = metas.map<Map<String, dynamic>>((m) {
              return {
                'title': m['name'],
                'subtitle': m['releaseInfo'] ?? 'Unknown',
                'source': 'Popular',
                'magnet': null,
                'seeders': 0,
                'poster': m['poster'],
              };
            }).toList();
          });
        }
      }
    } catch (e) {
      _addLog('[WARN] Failed to fetch popular signals: $e');
    }
  }

  /// Connects to the Router's Event Stream (SSE).
  void _connectSSE() async {
    try {
      final req = http.Request(
        'GET',
        Uri.parse('http://127.0.0.1:8080/api/rooms/swarm/events'),
      );
      req.headers['Accept'] = 'text/event-stream';

      final resp = await _client.send(req);
      if (mounted) setState(() => _sseConnected = true);
      _addLog('Connected to Swarm Uplink (SSE)');

      _sseSubscription = resp.stream
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.startsWith('data: ')) {
                final payload = line.substring(6);
                try {
                  final event = jsonDecode(payload);
                  _handleEvent(event);
                } catch (_) {}
              }
            },
            onError: (e) {
              if (mounted) setState(() => _sseConnected = false);
              _addLog('[ERROR] SSE Disconnected');
            },
          );
    } catch (e) {
      if (mounted) setState(() => _sseConnected = false);
      _addLog('[ERROR] Connection failed: $e');
    }
  }

  void _handleEvent(Map<String, dynamic> event) {
    // Simple logic to interpret events for visualization
    if (event.containsKey('t')) {
      // heartbeat or generic
      // Update peer count simulation or parse real if available
      // For now, we increment peer count on activity to show "liveness"
      if (mounted) setState(() => _peerCount = (_peerCount + 1) % 100 + 10);
    }

    // Result event (Task Completion)
    if (event['ok'] == true && event.containsKey('result')) {
      final res = event['result'];
      // If result looks like a stream/meta
      if (res is Map && res.containsKey('title')) {
        if (mounted) {
          setState(() {
            _recentResults.insert(0, {
              'title': res['title'],
              'subtitle': res['infoHash']?.substring(0, 8) ?? 'Unknown Hash',
              'source': 'Swarm',
              'magnet': res['magnet'],
              'seeders': res['seeders'] ?? 0,
            });
            if (_recentResults.length > 10) _recentResults.removeLast();
          });
          _addLog('Received stream: ${res['title']}');
        }
      }
    }
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.add(
        '[${DateTime.now().toIso8601String().split('T')[1].substring(0, 8)}] $msg',
      );
      if (_logs.length > 50) _logs.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Network Diagnostics / P2P Status
          IconButton(
            icon: const Icon(Icons.insights_rounded, color: Colors.white70),
            tooltip: 'Network Diagnostics',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SwarmUplinkSettings()),
            ),
          ),
          // Settings Menu
          IconButton(
            icon: const Icon(
              Icons.settings_input_antenna_rounded,
              color: Colors.white70,
            ),
            tooltip: 'Node Configuration',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SwarmSettingsMenu()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Deep Void Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF020617), // Deep Void
                    Color(0xFF0F172A), // Slate 900
                    Color(0xFF020617),
                  ],
                ),
              ),
            ),
          ),

          // Main Scrollable Content
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),

                // 1. HERO: Swarm Vitality (The Eye)
                SwarmHealthHero(
                  peerCount: _peerCount,
                  isHealthy: _sseConnected,
                ),

                const SizedBox(height: 24),

                // 2. POPULAR STREAMS (Discovery)
                _buildSectionHeader('POPULAR STREAMS'),
                const SizedBox(height: 16),
                if (_popularSignals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Scanning frequency bands...',
                      style: GoogleFonts.firaCode(
                        color: Colors.white30,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  _buildSignalStream(_popularSignals),

                const SizedBox(height: 32),

                // 3. RECENT STREAMS (Active History)
                if (_recentResults.isNotEmpty) ...[
                  _buildSectionHeader('RECENT STREAMS'),
                  const SizedBox(height: 16),
                  _buildSignalStream(_recentResults),
                  const SizedBox(height: 32),
                ],

                const SizedBox(height: 100), // Spacing for footer
              ],
            ),
          ),

          // 4. FOOTER: Ambient Monitor (Ticker)
          Positioned(left: 0, right: 0, bottom: 0, child: _buildSystemTicker()),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: AethericTheme.aetherBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalStream(List<Map<String, dynamic>> signals) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: signals.length,
        itemBuilder: (context, index) {
          final sig = signals[index];
          return SignalCard(
            title: sig['title'],
            subtitle: sig['subtitle'],
            seeders: sig['seeders'] ?? 0,
            source: sig['source'],
            magnet: sig['magnet'],
            posterUrl: sig['poster'],
          );
        },
      ),
    );
  }

  Widget _buildSystemTicker() {
    // A simplified ticker using the last log entry
    final lastLog = _logs.isEmpty ? 'System initialized...' : _logs.last;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AethericTheme.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AethericTheme.success.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lastLog,
              style: GoogleFonts.firaCode(
                color: AethericTheme.aetherBlue,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.terminal, size: 12, color: Colors.white30),
        ],
      ),
    );
  }
}
