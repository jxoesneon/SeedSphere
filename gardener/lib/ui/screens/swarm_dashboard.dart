import 'dart:async';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/ui/settings/swarm_settings_menu.dart';
import 'package:gardener/ui/widgets/user_profile_dialog.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/screens/expert_screen.dart';
import 'package:gardener/ui/widgets/swarm_health_hero.dart';
import 'package:gardener/ui/widgets/signal_card.dart';
import 'package:gardener/core/network_constants.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/core/debug_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/core/stream_history_manager.dart';
import 'package:gardener/core/activity_manager.dart';
import 'package:gardener/scrapers/scraper_engine.dart';
import 'package:gardener/core/security_manager.dart';
import 'package:gardener/core/debug_logger.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;

/// "The Observatory" - Central hub for swarm monitoring and discovery.
class SwarmDashboard extends ConsumerStatefulWidget {
  final http.Client? client;

  const SwarmDashboard({super.key, this.client});

  @override
  ConsumerState<SwarmDashboard> createState() => _SwarmDashboardState();
}

class _SwarmDashboardState extends ConsumerState<SwarmDashboard>
    with TickerProviderStateMixin {
  // State
  bool _sseConnected = false;
  final List<String> _logs = [];
  List<Map<String, dynamic>> _myStreams = []; // Local resolution history
  List<Map<String, dynamic>> _popularSignals = [];

  // Heartbeat tracking for graph visualization
  final List<DateTime> _heartbeatTimestamps = [];
  bool _showLogMode = false; // Toggle between graph and log view
  bool _showEkgDebug = false; // Toggle for diagnostic EKG calibration mode

  StreamSubscription? _sseSubscription;
  late final http.Client _client;
  late final P2PManager _p2pManager;

  @override
  void initState() {
    super.initState();
    _p2pManager = ref.read(p2pManagerProvider);
    if (DebugConfig.pulseGated) {
      DebugLogger.debug(
        'SWARM_DEBUG: SwarmDashboard initializing...',
        category: 'PULSE',
      );
    }
    DebugLogger.info('Swarm: SwarmDashboard initializing...', category: 'UI');
    _client = widget.client ?? http.Client();
    _ekgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _ekgController!.addListener(_updateEkgTrace);

    _bootstrapPulse();
    _fetchHistory();
    _fetchPopular();
  }

  Future<void> _bootstrapPulse() async {
    await _verifyAndHealSession();
    // Subscribe to P2PManager's persistent SSE stream (replaces local SSE)
    _subscribeToP2PEvents();
  }

  /// Subscribe to the global P2PManager event stream for heartbeats.
  void _subscribeToP2PEvents() {
    _sseSubscription = _p2pManager.eventStream.listen(
      (event) {
        _handleEvent(event);
      },
      onError: (e) {
        DebugLogger.error('Swarm: P2P event stream error', error: e);
      },
    );
    // Bind SSE connected status from P2PManager
    _p2pManager.sseConnected.addListener(_onSseStatusChange);
    _sseConnected = _p2pManager.sseConnected.value;
    DebugLogger.info('Swarm: Subscribed to P2PManager event stream');
  }

  void _onSseStatusChange() {
    if (mounted) {
      setState(() {
        _sseConnected = _p2pManager.sseConnected.value;
      });
    }
  }

  /// Verifies current session is valid and ensures device linking is healed.
  Future<void> _verifyAndHealSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      /* if (token == null) {
        DebugLogger.warn(
          'Swarm: No auth token found. Session healing skipped.',
        );
        return;
      } */

      DebugLogger.info('Swarm: Verifying session...', category: 'AUTH');

      final gardenerId = _p2pManager.gardenerId;
      if (gardenerId == null) {
        DebugLogger.warn('Swarm: gardenerId is null during session check');
        return;
      }

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

          // Restart P2P to inject the new shared secret for heartbeats
          // ignore: use_build_context_synchronously
          if (mounted) {
            // We can access the provider directly via ref since we differ the call
            unawaited(_p2pManager.restart());
          }
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
      DebugLogger.error('Swarm: Session check critical failure', error: e);
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
    _ekgController?.dispose();
    _sseSubscription?.cancel();
    _p2pManager.sseConnected.removeListener(_onSseStatusChange);
    _client.close();
    super.dispose();
  }

  /// Fetches popular content from the local SeedSphere Addon.
  Future<void> _fetchPopular() async {
    try {
      DebugLogger.info('Swarm: Fetching popular signals...', category: 'API');
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
              final id = m['imdbId'] ?? m['id'];
              // Check if we already have this in history
              final existing = _myStreams.firstWhere(
                (s) => s['id'] == id,
                orElse: () => {},
              );

              if (existing.isNotEmpty && existing['magnet'] != null) {
                return {
                  'id': id,
                  'title': m['name'],
                  'subtitle':
                      existing['subtitle'] ?? m['releaseInfo'] ?? 'Unknown',
                  'source': 'History',
                  'magnet': existing['magnet'],
                  'seeders': existing['seeders'] ?? 0,
                  'poster': m['poster'],
                };
              }

              // Not found? Check settings for resolution strategy.
              final config = ConfigManager();
              if (config.swarmMissingOnly) {
                // Optimization: Try HTTP fallback first. Only P2P search if failed.
                _resolveViaHttp(id, m['name']).then((found) {
                  if (!found) {
                    _p2pManager.search(id);
                  }
                });
              } else {
                // Default: Parallel P2P + HTTP (Max speed/redundancy)
                _p2pManager.search(id);
                _resolveViaHttp(id, m['name']);
              }

              return {
                'id': id,
                'title': m['name'],
                'subtitle': m['releaseInfo'] ?? 'Unknown',
                'source': 'Swarm (Resolving...)',
                'magnet': null,
                'seeders': 0,
                'poster': m['poster'],
              };
            }).toList();
            DebugLogger.info(
              'Swarm: Loaded ${_popularSignals.length} popular signals (Auto-resolving).',
              category: 'API',
            );
          });
        }
      }
    } catch (e) {
      DebugLogger.error('Swarm: Failed to fetch popular signals', error: e);
      _addLog('[WARN] Failed to fetch popular signals: $e');
    }
  }

  /// HTTP fallback for stream resolution when P2P mesh is unavailable.
  /// Returns true if a valid stream was found and resolved.
  Future<bool> _resolveViaHttp(String imdbId, String? title) async {
    try {
      final uri = Uri.parse(
        '${NetworkConstants.apiBase}/api/streams/resolve?id=$imdbId',
      );
      final resp = await _client.get(uri).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['ok'] == true && (data['streams'] as List).isNotEmpty) {
          final streams = data['streams'] as List;
          final bestStream = streams.first as Map<String, dynamic>;

          // Validate seeders to ensure it's worth keeping
          final seeders = bestStream['seeders'] ?? 0;
          if (seeders <= 0) return false;

          // Update the signal in the list
          final index = _popularSignals.indexWhere((s) => s['id'] == imdbId);
          if (index != -1 && _popularSignals[index]['magnet'] == null) {
            if (mounted) {
              setState(() {
                _popularSignals[index] = {
                  ..._popularSignals[index],
                  'magnet': bestStream['url'] ?? bestStream['infoHash'],
                  'seeders': seeders,
                  'source': 'Router (HTTP)',
                };
              });
            }

            DebugLogger.info(
              'Swarm: Signal RESOLVED via HTTP: $title ($imdbId)',
              category: 'HTTP-FALLBACK',
            );
            _addLog('[HTTP] Resolved: $title');
            return true;
          }
        }
      }
    } catch (e) {
      // HTTP fallback failed silently - P2P may still succeed
      DebugLogger.debug('HTTP fallback failed for $imdbId: $e');
    }
    return false;
  }

  void _handleEvent(Map<String, dynamic> event) {
    if (event.containsKey('t')) {
      if (DebugConfig.pulseGated) {
        DebugLogger.info(
          'Swarm: [EKG] Heartbeat triggered animation',
          category: 'PULSE',
        );
      }
      if (mounted) {
        setState(() {
          // Track heartbeat timestamps for sparkline visualization
          _heartbeatTimestamps.add(DateTime.now());
          _onHeartbeatReceived(); // Trigger EKG animation
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

        // Update Popular Streams if match found
        final index = _popularSignals.indexWhere(
          (s) => s['id'] == newStream['id'],
        );
        if (index != -1) {
          final wasPending = _popularSignals[index]['magnet'] == null;
          _popularSignals[index] = {
            ..._popularSignals[index],
            'magnet': newStream['magnet'],
            'seeders': newStream['seeders'],
            'subtitle': newStream['subtitle'],
            'source': 'Swarm (Resolved)',
          };

          if (wasPending) {
            DebugLogger.info(
              'Swarm: Popular Signal RESOLVED: ${newStream['title']} (${newStream['id']})',
              category: 'P2P',
            );
            _addLog('Signal RESOLVED: ${newStream['title']}');
          }
        }

        StreamHistoryManager.addStream(newStream).then((_) => _fetchHistory());
        _addLog('Received stream: ${res['title']}');
      }
    }

    // Task event (Coordinated Signaling)
    if (event.containsKey('type') && event['type'] == 'task') {
      _handleTask(event);
    }

    // Scraper Events (Local Progress)
    if (event['type'] == 'scraper_event') {
      final scraper = event['scraper'] ?? 'Unknown';
      final status = event['event'] ?? 'event';
      if (status == 'start') {
        _addLog('📡 [$scraper] Scraping started for ${event['imdbId']}...');
      } else if (status == 'done') {
        _addLog('✅ [$scraper] Found ${event['count']} results.');
      } else if (status == 'error') {
        _addLog('❌ [$scraper] Failed or timed out.');
      }
    }

    // Stremio Events (Incoming local requests)
    if (event['type'] == 'stremio_event') {
      final status = event['event'] ?? 'event';
      if (status == 'request') {
        _addLog(
          '🚀 [Stremio] Incoming request for ${event['id']} (${event['mediaType']})',
        );
      }
    }

    // P2P Swarm Event (Discovery Relay)
    if (event['type'] == 'p2p_cmd') {
      final p2pType = event['p2p_type'] as int?;
      final payload = event['payload'] as Map<String, dynamic>?;

      if (p2pType == 0) {
        // P2PCommandType.search
        final imdbId = payload?['imdbId'] as String?;
        final sender = event['p2p_sender'] as String?;
        if (imdbId != null) {
          _handleIncomingSearch(imdbId, sender);
        }
      }
    }
  }

  /// Responds to incoming search requests from the swarm if we have the data.
  Future<void> _handleIncomingSearch(String imdbId, String? sender) async {
    // 1. Check if we already have this in our local resolved history
    final match = _myStreams.firstWhere(
      (s) => s['id'] == imdbId || s['imdbId'] == imdbId,
      orElse: () => {},
    );

    if (match.isNotEmpty && match['magnet'] != null) {
      DebugLogger.info(
        'Swarm: Responding to search for $imdbId (Requested by $sender) - SHARED LOCAL METADATA',
        category: 'P2P',
      );
      _addLog('Sharing metadata for $imdbId...');

      // Format metadata to match what AGGREGATOR needs
      final metadata = {
        'title': match['title'],
        'infoHash': match['infoHash'],
        'magnet': match['magnet'],
        'seeders': match['seeders'],
        'description': match['description'],
      };

      // Broadcast back to swarm
      _p2pManager.publish(imdbId, data: metadata);
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
          onPressed: () {
            DebugLogger.info('UI: Back Button Pressed', category: 'UI');
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_rounded, color: Colors.white70),
            tooltip: 'Swarm Intelligence',
            onPressed: () {
              DebugLogger.info('UI: Opened Expert Screen', category: 'UI');
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ExpertScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
            tooltip: 'Node Configuration',
            onPressed: () {
              DebugLogger.info('UI: Opened Node Configuration', category: 'UI');
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SwarmSettingsMenu()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_rounded, color: Colors.white),
            tooltip: 'User Profile',
            onPressed: () {
              DebugLogger.info('UI: Opened User Profile', category: 'UI');
              showDialog(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.8),
                builder: (_) => const UserProfileDialog(),
              );
            },
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
                // isConnecting = Has NOT established connection yet AND Peers = 0
                Consumer(
                  builder: (context, ref, _) {
                    final manager = ref.watch(p2pManagerProvider);
                    final hasEstablished =
                        manager.hasEstablishedConnection.value;
                    final peers = manager.peerCount.value;

                    return SwarmHealthHero(
                      peerCount: peers,
                      isHealthy: _sseConnected && peers > 0,
                      isConnecting: !hasEstablished && peers == 0,
                      heartbeats: _heartbeatTimestamps,
                    );
                  },
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
      onTap: () {
        DebugLogger.info(
          'UI: Toggled Log View Mode (${!_showLogMode})',
          category: 'UI',
        );
        setState(() => _showLogMode = !_showLogMode);
      },
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
    return Padding(
      key: const ValueKey('graph'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onLongPress: () {
              setState(() {
                _showEkgDebug = !_showEkgDebug;
              });
              DebugLogger.info(
                'UI: EKG Debug Mode: ${_showEkgDebug ? "ON" : "OFF"}',
                category: 'UI',
              );
            },
            child: Text(
              'PULSE',
              style: GoogleFonts.outfit(
                color: _showEkgDebug ? const Color(0xFFFF00FF) : Colors.white24,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 10, // Explicit height for EKG waveform
              child: AnimatedBuilder(
                animation: _ekgController!,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size.infinite, // Take full available space
                    painter: _HeartbeatSparklinePainter(
                      dataPoints: List<double>.from(_ekgTrace),
                      scrollOffset: _scrollOffset,
                      color: AethericTheme.aetherBlue,
                      isConnected: _sseConnected,
                      showDebug: _showEkgDebug,
                    ),
                  );
                },
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

  // EKG Animation State
  final List<double> _ekgTrace = List.filled(
    60,
    0.0,
    growable: true,
  ); // 60 points for better visibility on restart
  AnimationController? _ekgController;
  double _scrollOffset = 0.0; // Sub-pixel scrolling offset (0.0 to 1.0)
  double _ekgPhase = 0.0; // 0.0 to 1.0 represents one heartbeat cycle
  bool _isBeating = false;

  // Normalized scroll velocity (percentage of data buffer width per frame at 60fps)
  // 0.001 roughly matches the "slow" preference regardless of point count.
  static const double _ekgScrollVelocity = 0.001;

  void _updateEkgTrace() {
    // 60fps Smooth Sub-pixel Scrolling
    // Crucial: Increment offset based on velocity and point count to decouple speed.
    // Velocity is "fraction of screen per frame", so points/trace moves that much.
    _scrollOffset += _ekgScrollVelocity * _ekgTrace.length;

    // Pulse Phase Update: animate heartbeat smoothly every frame (60fps)
    if (_isBeating) {
      // Fixed speed for the pulse itself (0.02 matches the ~1s duration)
      _ekgPhase += 0.02;
      if (_ekgPhase > 1.0) {
        _isBeating = false;
        _ekgPhase = 0.0;
      }
    }

    if (_scrollOffset >= 1.0) {
      _scrollOffset -= 1.0;
      // Shift data left (scroll)
      _ekgTrace.removeAt(0);

      // 2. Calculate new value (New point on the right)
      double newValue = 0.0;

      if (_isBeating) {
        // PQRST Waveform using Gaussian functions for each component
        // Gaussian helper: amplitude * exp(-pow((phase - center) / width, 2))
        double gaussian(double center, double width, double amp) {
          return amp * math.exp(-math.pow((_ekgPhase - center) / width, 2));
        }

        // P-wave: small atrial depolarization
        final pWave = gaussian(0.10, 0.04, 0.15);
        // Q-wave: small negative dip before R
        final qWave = gaussian(0.24, 0.015, -0.12);
        // R-wave: tall positive spike - main QRS peak
        final rWave = gaussian(0.28, 0.02, 1.0);
        // S-wave: negative deflection after R
        final sWave = gaussian(0.32, 0.02, -0.25);
        // T-wave: ventricular repolarization
        final tWave = gaussian(0.55, 0.06, 0.25);

        // Baseline slight noise
        final noise = (math.Random().nextDouble() - 0.5) * 0.02;

        // Combine all waves
        newValue = pWave + qWave + rWave + sWave + tWave + noise;
      } else {
        // Flatline with slight baseline noise
        newValue = (math.Random().nextDouble() - 0.5) * 0.08;
      }

      _ekgTrace.add(newValue);
    }

    // Force repaint every frame for 60fps smoothness
    if (mounted) {
      setState(() {});
    }
  }

  // Hook into heartbeat listener
  void _onHeartbeatReceived() {
    if (DebugConfig.pulseGated) {
      DebugLogger.debug('Swarm: EKG Heartbeat Triggered', category: 'PULSE');
    }
    // Trigger a beat if not already processing one (or overlap them)
    _isBeating = true;
    _ekgPhase = 0.0;
  }
}

class _HeartbeatSparklinePainter extends CustomPainter {
  final List<double> dataPoints;
  final double scrollOffset;
  final Color color;
  final bool isConnected;
  final bool showDebug;

  _HeartbeatSparklinePainter({
    required this.dataPoints,
    required this.scrollOffset,
    required this.color,
    required this.isConnected,
    this.showDebug = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final stepX = size.width / (dataPoints.length - 1);

    // Center line is at height / 2
    final midY = size.height / 2;
    // Scale factor for EKG waveform amplitude (final tuning)
    final scaleY = size.height * 1.0;

    // Draw each segment with color based on amplitude
    for (int i = 0; i < dataPoints.length - 1; i++) {
      final x1 = (i - scrollOffset) * stepX;
      final y1 = midY - (dataPoints[i] * scaleY);
      final x2 = (i + 1 - scrollOffset) * stepX;
      final y2 = midY - (dataPoints[i + 1] * scaleY);

      // Calculate transparency gradient based on actual Screen X for smoothness
      final xMid = (x1 + x2) / 2;
      final fadeArea = size.width * 0.15;
      final amplitude = dataPoints[i + 1].abs();
      final segmentColor = _getColorForAmplitude(amplitude);

      final Color bgColor = AethericTheme.deepVoid;
      Color paintColor = segmentColor;
      double finalAlpha = 1.0;

      if (xMid < fadeArea) {
        finalAlpha = (xMid / fadeArea).clamp(0.0, 1.0);
        if (showDebug) {
          // Left Diagnostic: Magenta (Alpha 0) -> Green (Alpha 1)
          const Color debugMagenta = Color(0xFFFF00FF);
          const Color debugGreen = Color(0xFF00FF00);
          paintColor = Color.lerp(debugMagenta, debugGreen, finalAlpha)!;
        } else {
          // Left Atmospheric: bgColor -> segmentColor
          paintColor = Color.lerp(bgColor, segmentColor, finalAlpha)!;
        }
      } else if (xMid > size.width - fadeArea) {
        finalAlpha = ((size.width - xMid) / fadeArea).clamp(0.0, 1.0);
        if (showDebug) {
          // Right Diagnostic: Green (Alpha 1) -> Magenta (Alpha 0)
          const Color debugMagenta = Color(0xFFFF00FF);
          const Color debugGreen = Color(0xFF00FF00);
          paintColor = Color.lerp(debugMagenta, debugGreen, finalAlpha)!;
        } else {
          // Right Atmospheric: segmentColor -> bgColor
          paintColor = Color.lerp(bgColor, segmentColor, finalAlpha)!;
        }
      }

      final paint = Paint()
        ..color = paintColor.withValues(alpha: paintColor.a * finalAlpha)
        ..strokeWidth = amplitude > 0.3
            ? 2.5
            : 1.5 // Thicker on peaks
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }

    // Glow effect for visibility
    final path = Path();
    for (int i = 0; i < dataPoints.length; i++) {
      final x = (i - scrollOffset) * stepX;
      final y = midY - (dataPoints[i] * scaleY);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, 0),
        [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0.0),
        ],
        [0.0, 0.15, 0.85, 1.0],
      );

    canvas.drawPath(path, glowPaint);
  }

  Color _getColorForAmplitude(double amplitude) {
    // Alignment with Aetheric Design System (Removed green, using Aether Blue tones)
    if (amplitude < 0.15) {
      // Subdued Aether Blue for the baseline noise
      return AethericTheme.aetherBlue.withValues(alpha: 0.5);
    } else if (amplitude < 0.45) {
      // Transition from dimmed to vibrant Aether Blue (the main spike)
      final t = (amplitude - 0.15) / 0.3;
      return Color.lerp(
        AethericTheme.aetherBlue.withValues(alpha: 0.5),
        AethericTheme.aetherBlue,
        t,
      )!;
    } else if (amplitude < 0.75) {
      // Transition from Aether Blue to Info (Blue)
      final t = (amplitude - 0.45) / 0.3;
      return Color.lerp(AethericTheme.aetherBlue, AethericTheme.info, t)!;
    } else {
      // Final transition to Error (Red) for extreme peaks
      final t = ((amplitude - 0.75) / 0.25).clamp(0.0, 1.0);
      return Color.lerp(AethericTheme.info, AethericTheme.error, t)!;
    }
  }

  @override
  bool shouldRepaint(covariant _HeartbeatSparklinePainter oldDelegate) => true;
}
