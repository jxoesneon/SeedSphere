import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/network_status_card.dart';
import 'package:gardener/ui/widgets/network_mode_toggle.dart';
import 'package:google_fonts/google_fonts.dart';

/// Advanced network settings for the P2P swarm uplink.
///
/// This redesigned screen (2025 UX principles) features:
/// - **Status-First Design**: Network health front and center
/// - **Progressive Disclosure**: Advanced settings collapsed by default
/// - **Smart Defaults**: Auto mode for 90% of users
/// - **Contextual Help**: Tooltips explain every option
/// - **Real-time Feedback**: Live peer count and status updates
///
/// Target Personas:
/// - Privacy Advocates: Clear security indicators
/// - P2P Enthusiasts: Advanced metrics and controls
/// - Streamers: "Just works" with smart defaults
class SwarmUplinkSettings extends StatefulWidget {
  /// Creates a [SwarmUplinkSettings] widget.
  const SwarmUplinkSettings({super.key});

  @override
  State<SwarmUplinkSettings> createState() => _SwarmUplinkSettingsState();
}

class _SwarmUplinkSettingsState extends State<SwarmUplinkSettings> {
  // Network status (mock - replace with real API)
  NetworkStatus _networkStatus = NetworkStatus.optimal;
  int _peerCount = 12;
  final int _latencyMs = 45;
  final String _region = 'NA';

  // Network mode
  NetworkMode _networkMode = NetworkMode.automatic;

  // Advanced settings (only shown in Manual mode)
  bool _autoBootstrap = true;
  String _trackerPreset = 'auto';
  bool _useCustomTrackers = false;
  final TextEditingController _trackerUrlController = TextEditingController();
  String _validationLevel = 'basic';
  bool _scrapeSwarm = true;
  double _swarmTopN = 20;

  // UI state
  bool _isAdvancedExpanded = false;
  bool _isSweeping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      appBar: AppBar(
        title:
            Text('SWARM UPLINK', style: GoogleFonts.outfit(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HERO: Network Status Card
            NetworkStatusCard(
              status: _networkStatus,
              peerCount: _peerCount,
              latencyMs: _latencyMs,
              region: _region,
              onOptimize: _handleOptimize,
              onShowDetails: _handleShowDetails,
            ),
            const SizedBox(height: 20),

            // Network Mode Selector
            NetworkModeToggle(
              mode: _networkMode,
              onModeChanged: (mode) {
                setState(() {
                  _networkMode = mode;
                  // Auto mode collapses advanced settings
                  if (mode == NetworkMode.automatic) {
                    _isAdvancedExpanded = false;
                  }
                });
              },
            ),
            const SizedBox(height: 24),

            // Advanced Configuration (Progressive Disclosure)
            if (_networkMode == NetworkMode.manual) ...[
              _buildAdvancedSection(),
              const SizedBox(height: 24),
            ],

            // Diagnostics (always visible)
            _buildDiagnosticsSection(),
          ],
        ),
      ),
    );
  }

  /// Advanced configuration section (collapsible)
  Widget _buildAdvancedSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.01),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AethericTheme.glassBorder,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  setState(() => _isAdvancedExpanded = !_isAdvancedExpanded),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      color: AethericTheme.aetherBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ADVANCED CONFIGURATION',
                            style: GoogleFonts.outfit(
                              color: AethericTheme.aetherBlue,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.3,
                              fontSize: 12,
                            ),
                          ),
                          if (!_isAdvancedExpanded) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Trackers: ${_trackerPreset.toUpperCase()} • Validation: ${_validationLevel.toUpperCase()}',
                              style: GoogleFonts.outfit(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      _isAdvancedExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expandable content
          if (_isAdvancedExpanded) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bootstrap Nodes
                  _buildSubsectionHeader('Bootstrap Nodes'),
                  const SizedBox(height: 8),
                  _buildTooltipSwitch(
                    title: 'Connect to SeedSphere Network',
                    description:
                        'Uses global relay servers to find peers faster',
                    value: _autoBootstrap,
                    onChanged: (val) => setState(() => _autoBootstrap = val),
                  ),
                  const SizedBox(height: 20),

                  // Tracker Configuration
                  _buildSubsectionHeader('Tracker Sources'),
                  const SizedBox(height: 8),
                  _buildTrackerSelector(),
                  if (_useCustomTrackers) ...[
                    const SizedBox(height: 12),
                    _buildCustomTrackerInput(),
                  ],
                  const SizedBox(height: 20),

                  // Performance Tuning
                  _buildSubsectionHeader('Performance'),
                  const SizedBox(height: 8),
                  _buildValidationSelector(),
                  const SizedBox(height: 12),
                  _buildScrapeSwarmToggle(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubsectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }

  Widget _buildTooltipSwitch({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AethericTheme.aetherBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerSelector() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _trackerPreset,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E293B),
              style: GoogleFonts.outfit(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
              items: [
                'auto',
                'best',
                'fast (udp)',
                'private (https)',
              ]
                  .map((preset) => DropdownMenuItem(
                        value: preset,
                        child: Text(preset.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _trackerPreset = val!),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildTooltipSwitch(
          title: 'Use Custom Trackers',
          description: 'Override with your own tracker list URL',
          value: _useCustomTrackers,
          onChanged: (val) => setState(() => _useCustomTrackers = val),
        ),
      ],
    );
  }

  Widget _buildCustomTrackerInput() {
    return TextField(
      controller: _trackerUrlController,
      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Tracker List URL',
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        hintText: 'https://.../tracker-list.txt',
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AethericTheme.aetherBlue),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildValidationSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _validationLevel,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          style: GoogleFonts.outfit(color: Colors.white),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
          items: [
            'off',
            'basic',
            'strict',
          ]
              .map((level) => DropdownMenuItem(
                    value: level,
                    child: Text('Content Verification: ${level.toUpperCase()}'),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _validationLevel = val!),
        ),
      ),
    );
  }

  Widget _buildScrapeSwarmToggle() {
    return Column(
      children: [
        _buildTooltipSwitch(
          title: 'Real-time Peer Discovery',
          description: 'Actively search for more peers (uses more data)',
          value: _scrapeSwarm,
          onChanged: (val) => setState(() => _scrapeSwarm = val),
        ),
        if (_scrapeSwarm) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Max Peers to Query: ${_swarmTopN.round()}',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Slider(
                  value: _swarmTopN,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  thumbColor: AethericTheme.aetherBlue,
                  activeColor: AethericTheme.aetherBlue,
                  inactiveColor: Colors.white10,
                  onChanged: (val) => setState(() => _swarmTopN = val),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDiagnosticsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.01),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AethericTheme.glassBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded,
                  color: AethericTheme.aetherBlue, size: 20),
              const SizedBox(width: 12),
              Text(
                'DIAGNOSTICS',
                style: GoogleFonts.outfit(
                  color: AethericTheme.aetherBlue,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isSweeping
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.cleaning_services_rounded),
              label: Text(_isSweeping ? 'OPTIMIZING...' : 'Optimize Network'),
              onPressed: _isSweeping ? null : _handleOptimize,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleOptimize() async {
    setState(() => _isSweeping = true);
    final messenger = ScaffoldMessenger.of(context);

    // Simulate optimization
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    setState(() {
      _isSweeping = false;
      _networkStatus = NetworkStatus.optimal;
      _peerCount = 18; // Improved peer count
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text('Network optimized: Connected to $_peerCount peers'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _handleShowDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Network Details',
            style: GoogleFonts.outfit(color: Colors.white)),
        content: Text(
          'Status: $_networkStatus\n'
          'Peers: $_peerCount\n'
          'Latency: ${_latencyMs}ms\n'
          'Region: $_region\n'
          '\nFor more detailed metrics, check the Dashboard.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: GoogleFonts.outfit(color: AethericTheme.aetherBlue)),
          ),
        ],
      ),
    );
  }
}
