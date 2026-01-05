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
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/core/stream_history_manager.dart';
import 'package:gardener/core/activity_manager.dart';
import 'package:gardener/scrapers/scraper_engine.dart';
import 'package:gardener/core/security_manager.dart';
import 'package:gardener/core/debug_logger.dart';
import 'package:uuid/uuid.dart';

/// "The Observatory" - Central hub for swarm monitoring and discovery.
class SwarmDashboard extends ConsumerStatefulWidget {
  final http.Client? client;

  const SwarmDashboard({super.key, this.client});

  @override
  ConsumerState<SwarmDashboard> createState() => _SwarmDashboardState();
}

class _SwarmDashboardState extends ConsumerState<SwarmDashboard> {
  // State
  bool _sseConnected = false;
  final List<String> _logs = [];
  List<Map<String, dynamic>> _myStreams = []; // Local resolution history
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
    _verifyAndHealSession().then((_) {
      if (mounted) _connectSSE();
    });
    _fetchHistory();
    _fetchPopular();
  }

  /// Verifies current session is valid and ensures device linking is healed.
  Future<void> _verifyAndHealSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final gardenerId = ref.read(p2pManagerProvider).gardenerId;
      if (gardenerId == null) return; // P2P not ready?

      final uri = Uri.parse(
        '${NetworkConstants.apiBase}/api/auth/session?gardenerId=$gardenerId',
      );
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ok'] != true || data['user'] == null) {
          // Session invalid?
          // We could force logout here, but let's be gentle for now unless 401/403
        }

        if (data['secret'] != null) {
          final secret = data['secret'] as String;
          final security = SecurityManager();
          // Only write if we don't have it or want to ensure it's in sync
          await security.setSharedSecret(secret);
          DebugLogger.info(
            'Swarm: Session healed. Device linked successfully.',
          );
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Token expired
        await prefs.remove('auth_token');
        if (mounted) {
          if (context.mounted) {
            await Navigator.of(
              context,
            ).pushReplacementNamed('/'); // Go home/auth
          }
        }
      }
    } catch (e) {
      DebugLogger.error('Session check failed: $e');
    }
  }

  Future<void> _fetchHistory() async {
    final history = await StreamHistoryManager.getHistory();
    if (mounted) {
      setState(() => _myStreams = history);
    }
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
                'id': m['imdbId'] ?? m['id'],
                'title': m['name'],
                'subtitle': m['releaseInfo'] ?? 'Unknown',
                'source': 'Popular',
                'magnet': null, // Marks as "Needs Resolution"
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

  /// Connects to the Router's Event Stream (SSE) for user-scoped events.
  void _connectSSE() async {
    try {
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
    if (event.containsKey('t')) {
      if (mounted) {
        setState(() {
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
      if (res is Map && res.containsKey('title')) {
        final newStream = {
          'id': res['id'] ?? res['imdbId'] ?? const Uuid().v4(),
          'title': res['title'],
          'subtitle': res['infoHash']?.substring(0, 8) ?? 'Unknown Hash',
          'source': 'Swarm',
          'magnet': res['magnet'],
          'seeders': res['seeders'] ?? 0,
        };

        StreamHistoryManager.addStream(newStream).then((_) => _fetchHistory());
        _addLog('Received stream: ${res['title']}');
      }
    }

    // Task event (Coordinated Signaling)
    if (event.containsKey('type') && event['type'] == 'task') {
      _handleTask(event);
    }
  }

  Future<void> _handleTask(Map<String, dynamic> task) async {
    final type = task['type'];
    final params = task['params'] as Map<String, dynamic>?;
    final token = task['task_token']; // Optional token if provided by server

    _addLog('Router issued task: $type');

    if (type == 'resolve' && params != null) {
      final imdbId = params['imdbId'];
      if (imdbId != null) {
        _addLog('Executing resolution for $imdbId...');
        // 1. Scrape
        final ScraperEngine engine = ScraperEngine.defaults();
        final results = await engine.scrapeAll(imdbId);

        if (results.isNotEmpty) {
          final best = results.first;
          _addLog('Resolved $imdbId => ${best['title']}');

          // 2. Report result back to Router
          await _postTaskResult(token, best);

          // 3. Local activity logging
          await ActivityManager().reportActivity(
            type: 'task',
            title: 'Automated Resolution: ${best['title']}',
            meta: {'imdbId': imdbId, 'source': 'router_signal'},
          );
        }
      }
    }
  }

  Future<void> _postTaskResult(
    String? token,
    Map<String, dynamic> result,
  ) async {
    try {
      final url = Uri.parse('${NetworkConstants.apiBase}/api/tasks/result');
      await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'result': result}),
      );
    } catch (e) {
      _addLog('[ERROR] Failed to post task result: $e');
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
    // Watch peer count from riverpod to ensure health UI updates
    final realPeerCount = ref.watch(p2pManagerProvider).peerCount.value;

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
          IconButton(
            icon: const Icon(Icons.insights_rounded, color: Colors.white70),
            tooltip: 'Network Diagnostics',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SwarmUplinkSettings()),
            ),
          ),
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
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),

                // 1. HERO: Swarm Vitality (The Eye)
                // Logical Health = SSE + Physical Health = Peers > 0
                SwarmHealthHero(
                  peerCount: realPeerCount,
                  isHealthy: _sseConnected && realPeerCount > 0,
                  heartbeats: _heartbeatTimestamps,
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

                // 3. MY STREAMS (Local History)
                _buildSectionHeader('MY STREAMS'),
                const SizedBox(height: 16),
                if (_myStreams.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'No resolved streams found in the hive.',
                      style: GoogleFonts.firaCode(
                        color: Colors.white24,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  _buildSignalStream(_myStreams),

                const SizedBox(height: 32),

                const SizedBox(height: 40), // Sufficient bottom spacing
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(child: _buildSystemTicker()),
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
            id: sig['id'], // Pass ID for resolution
          );
        },
      ),
    );
  }

  Widget _buildSystemTicker() {
    return GestureDetector(
      onTap: () => setState(() => _showLogMode = !_showLogMode),
      child: Container(
        width: double.infinity,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          border: const Border(
            top: BorderSide(color: Colors.white10, width: 0.5),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _showLogMode ? _buildLogView() : _buildHeartbeatGraph(),
        ),
      ),
    );
  }

  Widget _buildHeartbeatGraph() {
    final dataPoints = _generateHeartbeatData();

    return Padding(
      key: const ValueKey('graph'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
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

  List<double> _generateHeartbeatData() {
    if (_heartbeatTimestamps.isEmpty) {
      return List.filled(30, 0.5);
    }

    final intervals = <double>[];
    for (int i = 1; i < _heartbeatTimestamps.length; i++) {
      final diff = _heartbeatTimestamps[i]
          .difference(_heartbeatTimestamps[i - 1])
          .inMilliseconds;
      final normalized = (1.0 - (diff / 60000.0)).clamp(0.1, 1.0);
      intervals.add(normalized);
    }

    while (intervals.length < 30) {
      intervals.insert(0, 0.5);
    }

    if (intervals.length > 60) {
      return intervals.skip(intervals.length - 60).toList();
    }
    return intervals;
  }
}

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
