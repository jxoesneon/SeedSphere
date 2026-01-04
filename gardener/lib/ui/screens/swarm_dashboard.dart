import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gardener/ui/settings/swarm_settings_menu.dart';
import 'package:gardener/ui/settings/swarm_uplink_settings.dart';
import 'package:gardener/ui/widgets/user_profile_dialog.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/swarm_health_hero.dart';
import 'package:gardener/ui/widgets/signal_card.dart';
import 'package:gardener/core/network_constants.dart';
import 'package:google_fonts/google_fonts.dart';

/// "The Observatory" - Central hub for swarm monitoring and discovery.
class SwarmDashboard extends StatefulWidget {
  final http.Client? client;

  const SwarmDashboard({super.key, this.client});

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

  // Heartbeat tracking for graph visualization
  final List<DateTime> _heartbeatTimestamps = [];
  bool _showLogMode = false; // Toggle between graph and log view

  StreamSubscription? _sseSubscription;
  late final http.Client _client;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? http.Client();
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
      final uri = Uri.parse(
        '${NetworkConstants.catalogEndpoint}/movie/top.json',
      );
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

  /// Connects to the Router's Event Stream (SSE) for user-scoped events.
  void _connectSSE() async {
    try {
      // Get user ID for user-scoped events
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'swarm';
      final authToken = prefs.getString('auth_token');

      final req = http.Request(
        'GET',
        Uri.parse('${NetworkConstants.eventsEndpoint}/$userId/events'),
      );
      req.headers['Accept'] = 'text/event-stream';
      if (authToken != null) {
        req.headers['Authorization'] = 'Bearer $authToken';
      }

      final resp = await _client.send(req);
      if (mounted) setState(() => _sseConnected = true);
      _addLog('Connected to User Swarm (SSE) - $userId');

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
      // heartbeat or generic - track timestamp for graph
      if (mounted) {
        setState(() {
          _peerCount = (_peerCount + 1) % 100 + 10;
          // Track heartbeat timestamps for sparkline visualization
          _heartbeatTimestamps.add(DateTime.now());
          // Keep only last 60 heartbeats (30 min at 30s intervals)
          if (_heartbeatTimestamps.length > 60) {
            _heartbeatTimestamps.removeAt(0);
          }
        });
      }
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
          // User Profile
          IconButton(
            icon: const Icon(Icons.account_circle_rounded, color: Colors.white),
            tooltip: 'User Profile',
            onPressed: () => showDialog(
              context: context,
              barrierColor: Colors.black.withValues(alpha: 0.8),
              builder: (_) => const UserProfileDialog(),
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

  /// Builds a minimal heartbeat sparkline ticker (2025 PhD-level UX)
  /// - Default: Shows heartbeat activity as a subtle sparkline graph
  /// - On tap: Toggles to show the last log entry
  Widget _buildSystemTicker() {
    return GestureDetector(
      onTap: () => setState(() => _showLogMode = !_showLogMode),
      child: Container(
        width: double.infinity,
        height: 32, // Same compact height as before
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.9),
          border: const Border(top: BorderSide(color: Colors.white10)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _showLogMode ? _buildLogView() : _buildHeartbeatGraph(),
        ),
      ),
    );
  }

  /// Heartbeat sparkline visualization
  Widget _buildHeartbeatGraph() {
    // Generate sparkline data points from heartbeat intervals
    final dataPoints = _generateHeartbeatData();

    return Padding(
      key: const ValueKey('graph'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Subtle label
          Text(
            'PULSE',
            style: GoogleFonts.outfit(
              color: Colors.white24,
              fontSize: 8,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          // Sparkline graph
          Expanded(
            child: CustomPaint(
              painter: _HeartbeatSparklinePainter(
                dataPoints: dataPoints,
                color: AethericTheme.aetherBlue,
                isConnected: _sseConnected,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Heartbeat count indicator
          Text(
            '${_heartbeatTimestamps.length}',
            style: GoogleFonts.firaCode(
              color: AethericTheme.aetherBlue.withValues(alpha: 0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  /// Log view (shown on tap)
  Widget _buildLogView() {
    final lastLog = _logs.isEmpty ? 'System initialized...' : _logs.last;
    return Padding(
      key: const ValueKey('log'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        lastLog,
        style: GoogleFonts.firaCode(
          color: AethericTheme.aetherBlue.withValues(alpha: 0.8),
          fontSize: 10,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Generates normalized data points for the sparkline
  List<double> _generateHeartbeatData() {
    if (_heartbeatTimestamps.isEmpty) {
      // Show flat line when no data
      return List.filled(30, 0.5);
    }

    // Calculate intervals between heartbeats (normalized)
    final intervals = <double>[];
    for (int i = 1; i < _heartbeatTimestamps.length; i++) {
      final diff = _heartbeatTimestamps[i]
          .difference(_heartbeatTimestamps[i - 1])
          .inMilliseconds;
      // Normalize: 30000ms (30s) = 0.5, faster = higher, slower = lower
      final normalized = (1.0 - (diff / 60000.0)).clamp(0.1, 1.0);
      intervals.add(normalized);
    }

    // Ensure minimum 30 data points for smooth visualization
    while (intervals.length < 30) {
      intervals.insert(0, 0.5);
    }

    // Return only the last 60 data points
    if (intervals.length > 60) {
      return intervals.skip(intervals.length - 60).toList();
    }
    return intervals;
  }
}

/// Custom painter for the heartbeat sparkline
class _HeartbeatSparklinePainter extends CustomPainter {
  final List<double> dataPoints;
  final Color color;
  final bool isConnected;

  _HeartbeatSparklinePainter({
    required this.dataPoints,
    required this.color,
    required this.isConnected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paint = Paint()
      ..color = isConnected ? color : color.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX =
        size.width / (dataPoints.length - 1).clamp(1, double.infinity);

    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * stepX;
      final y = size.height - (dataPoints[i] * size.height * 0.8);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw subtle glow under the line
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final glowPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(glowPath, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _HeartbeatSparklinePainter oldDelegate) {
    return dataPoints != oldDelegate.dataPoints ||
        isConnected != oldDelegate.isConnected;
  }
}
