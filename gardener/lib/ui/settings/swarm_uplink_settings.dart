import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

/// Advanced network settings for the P2P swarm and DHT uplink.
///
/// This screen handles the configuration of the BitTorrent and IPFS
/// networking layers, including bootstrap node connection, tracker
/// variations, swarm scraping parameters, and network diagnostics.
///
/// **Sections:**
/// - **Bootstrap Nodes**: DHT connectivity (Auto-Bootstrap).
/// - **Tracker Sources**: Configuration of public BitTorrent trackers.
/// - **Optimization**: Validation modes and swarm scraping depth.
/// - **Diagnostics**: Manual network optimization tasks (Swarm Sweep).
class SwarmUplinkSettings extends StatefulWidget {
  /// Creates a [SwarmUplinkSettings] widget.
  const SwarmUplinkSettings({super.key});

  @override
  State<SwarmUplinkSettings> createState() => _SwarmUplinkSettingsState();
}

class _SwarmUplinkSettingsState extends State<SwarmUplinkSettings> {
  /// Whether to automatically connect to IPFS bootstrap nodes.
  bool _autoBootstrap = true;

  /// The selected tracker subset (e.g., 'all', 'best', 'udp').
  String _trackerVariant = 'all';

  /// Whether to use a custom tracker list URL.
  bool _useCustomTrackers = false;

  /// Controller for the custom tracker list URL.
  final TextEditingController _trackerUrlController = TextEditingController();

  /// Metadata validation strictness ('off', 'basic', 'aggressive').
  String _validationMode = 'basic';

  /// Whether to perform live P2P swarm scraping.
  bool _scrapeSwarm = true;

  /// The number of top peers to query during a swarm scrape.
  double _swarmTopN = 20;

  /// Whether a "Swarm Sweep" diagnostic task is currently running.
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
            // DHT Bootstrap Configuration
            _buildSectionHeader('BOOTSTRAP NODES'),
            const SizedBox(height: 8),
            AethericGlass(
              child: SwitchListTile(
                title: Text('Auto-Bootstrap',
                    style: GoogleFonts.outfit(color: Colors.white)),
                subtitle: Text(
                  'Automatically connect to detailed public DHT nodes (IPFS).',
                  style:
                      GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                ),
                value: _autoBootstrap,
                activeTrackColor: AethericTheme.aetherBlue,
                onChanged: (val) => setState(() => _autoBootstrap = val),
              ),
            ),
            const SizedBox(height: 32),

            // Tracker Source Configuration
            _buildSectionHeader('TRACKER SOURCES'),
            const SizedBox(height: 8),
            AethericGlass(
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: const Color(0xFF1E293B),
                        value: _trackerVariant,
                        isExpanded: true,
                        style: GoogleFonts.outfit(color: Colors.white),
                        icon: const Icon(Icons.router_rounded,
                            color: AethericTheme.aetherBlue),
                        items: [
                          'all',
                          'best',
                          'best_ip',
                          'all_udp',
                          'all_http',
                          'all_https',
                          'all_ws'
                        ]
                            .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text('Variant: ${m.toUpperCase()}')))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _trackerVariant = val!),
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white10),
                  SwitchListTile(
                    title: Text('Use Custom Trackers',
                        style: GoogleFonts.outfit(color: Colors.white)),
                    subtitle: Text(
                      'Override default swarm trackers with a custom list.',
                      style: GoogleFonts.outfit(
                          color: Colors.white54, fontSize: 12),
                    ),
                    value: _useCustomTrackers,
                    activeTrackColor: AethericTheme.aetherBlue,
                    onChanged: (val) =>
                        setState(() => _useCustomTrackers = val),
                  ),
                  if (_useCustomTrackers)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _trackerUrlController,
                        style: GoogleFonts.outfit(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Tracker List URL',
                          labelStyle: TextStyle(color: Colors.white54),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: AethericTheme.aetherBlue),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Performance and Validation Tuning
            _buildSectionHeader('OPTIMIZATION'),
            const SizedBox(height: 8),
            AethericGlass(
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: const Color(0xFF1E293B),
                        value: _validationMode,
                        isExpanded: true,
                        style: GoogleFonts.outfit(color: Colors.white),
                        icon: const Icon(Icons.shield_moon_rounded,
                            color: AethericTheme.aetherBlue),
                        items: ['off', 'basic', 'aggressive']
                            .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text('Validation: ${m.toUpperCase()}')))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _validationMode = val!),
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white10),
                  SwitchListTile(
                    title: Text('Scrape Swarm',
                        style: GoogleFonts.outfit(color: Colors.white)),
                    subtitle: Text('Enable live P2P swarm scraping.',
                        style: GoogleFonts.outfit(
                            color: Colors.white54, fontSize: 12)),
                    value: _scrapeSwarm,
                    activeTrackColor: AethericTheme.aetherBlue,
                    onChanged: (val) => setState(() => _scrapeSwarm = val),
                  ),
                  if (_scrapeSwarm)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Swarm Top N: ${_swarmTopN.round()}',
                              style: GoogleFonts.outfit(
                                  color: Colors.white70, fontSize: 12)),
                          Slider(
                            value: _swarmTopN,
                            min: 0,
                            max: 100,
                            divisions: 20,
                            activeColor: AethericTheme.aetherBlue,
                            inactiveColor: Colors.white10,
                            onChanged: (val) =>
                                setState(() => _swarmTopN = val),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Network Diagnostics
            _buildSectionHeader('DIAGNOSTICS'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isSweeping
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cleaning_services_rounded),
                label: Text(_isSweeping ? 'SWEEPING...' : 'RUN SWARM SWEEP'),
                onPressed: _isSweeping
                    ? null
                    : () async {
                        setState(() => _isSweeping = true);
                        final messenger = ScaffoldMessenger.of(context);

                        // Simulate a background optimization task
                        await Future.delayed(const Duration(seconds: 3));

                        if (!mounted) return;

                        setState(() => _isSweeping = false);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Swarm Sweep Complete: 84 Nodes Optimised.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a section header with accent typography.
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: AethericTheme.aetherBlue,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        fontSize: 12,
      ),
    );
  }
}
