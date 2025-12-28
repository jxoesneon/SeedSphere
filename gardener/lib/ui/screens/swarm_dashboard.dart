import 'package:flutter/material.dart';
import 'package:gardener/ui/settings/swarm_settings_menu.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:gardener/ui/widgets/adaptive_bento_grid.dart';
import 'package:google_fonts/google_fonts.dart';

/// The central hub for swarm interactions and decentralized content discovery.
///
/// This dashboard provides a glassmorphic interface for monitoring swarm
/// health (peers, latency, uptime), searching the decentralized web,
/// and browsing popular/seeded content.
///
/// Uses [AethericGlass] for premium visual effects and [AdaptiveBentoGrid]
/// for a responsive content layout that adapts to mobile and desktop.
///
/// Example:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const SwarmDashboard()),
/// );
/// ```
class SwarmDashboard extends StatelessWidget {
  /// Creates a [SwarmDashboard] widget.
  const SwarmDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hub_rounded,
                color: AethericTheme.aetherBlue, size: 20),
            const SizedBox(width: 12),
            Text(
              'SWARM NODE',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_input_antenna_rounded,
                color: Colors.white70),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SwarmSettingsMenu()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Deep slate background with subtle gradients
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF020617),
                    Color(0xFF0F172A),
                    Color(0xFF020617),
                  ],
                ),
              ),
            ),
          ),

          Column(
            children: [
              const SizedBox(height: 100), // Spacing for transparent AppBar

              // 1. Swarm Vitality Stats Table (Glassmorphic Container)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AethericGlass(
                  borderRadius: 20,
                  baseColor: const Color(0x0DFFFFFF),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const _StatItem(
                          label: 'PEERS',
                          value: '842',
                          icon: Icons.people_outline_rounded),
                      _VerticalDivider(),
                      const _StatItem(
                          label: 'LATENCY',
                          value: '24ms',
                          icon: Icons.speed_rounded,
                          color: AethericTheme.aetherBlue),
                      _VerticalDivider(),
                      const _StatItem(
                          label: 'UPTIME',
                          value: '99.9%',
                          icon: Icons.timer_outlined),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 2. Swarm Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  style: GoogleFonts.outfit(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search the decentralized web...',
                    hintStyle: GoogleFonts.outfit(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    prefixIcon:
                        const Icon(Icons.search_rounded, color: Colors.white54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color:
                              AethericTheme.aetherBlue.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Featured Content Grid (Using Bento Layout)
              const Expanded(
                child: AdaptiveBentoGrid(
                  mobileColumns: 2,
                  desktopColumns: 4,
                  children: [
                    _ContentCard(
                        title: 'Cosmos Laundromat', type: 'Movie', seeds: 1240),
                    _ContentCard(title: 'Sintel', type: 'Short', seeds: 890),
                    _ContentCard(
                        title: 'Big Buck Bunny',
                        type: 'Animation',
                        seeds: 4500),
                    _ContentCard(
                        title: 'Tears of Steel', type: 'Sci-Fi', seeds: 620),
                    _ContentCard(
                        title: 'Elephants Dream', type: 'Classic', seeds: 310),
                    _ContentCard(
                        title: 'Spring', type: 'Animation', seeds: 1100),
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

/// A single statistic display within the dashboard stats header.
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatItem(
      {required this.label,
      required this.value,
      required this.icon,
      this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Icon(icon, color: color ?? Colors.white54, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            color: Colors.white30,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// A subtle vertical separator for the stat row.
class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

/// A card representing a piece of content discovered in the swarm.
class _ContentCard extends StatelessWidget {
  final String title;
  final String type;
  final int seeds;

  const _ContentCard(
      {required this.title, required this.type, required this.seeds});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_creation_outlined,
              size: 32, color: Colors.white24),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              title,
              style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$type • $seeds Seeds',
            style: GoogleFonts.outfit(
                color: AethericTheme.aetherBlue, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
