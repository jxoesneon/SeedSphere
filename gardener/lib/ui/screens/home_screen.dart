import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:gardener/core/haptic_manager.dart';
import 'package:gardener/ui/screens/swarm_dashboard.dart';

/// The entry point/landing screen of the SeedSphere application.
///
/// Features a minimalist, premium aesthetic with a glassmorphic central card
/// set against a deep cosmic gradient. This screen serves as the gateway
/// to the [SwarmDashboard].
///
/// **Visual elements:**
/// - Radial gradient background (Deep Void)
/// - [AethericGlass] container for the main branding and CTA
/// - Custom typography using Google Fonts (Outfit)
/// - Integrated [HapticManager] feedback on button interaction
class HomeScreen extends StatelessWidget {
  /// Creates a [HomeScreen] widget.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background: Deep Void with a subtle radial gradient for depth
          RepaintBoundary(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.5,
                  colors: [Color(0xFF0F172A), AethericTheme.deepVoid],
                ),
              ),
            ),
          ),

          // Main Call to Action (CTA) Content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: AethericGlass(
                borderRadius: 24,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Application Branding
                      Text(
                        'SEEDSPHERE 2.0',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'THE FEDERATED FRONTIER',
                        style: TextStyle(
                          color: Colors.white38,
                          letterSpacing: 4,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Primary Action: Navigate to Dashboard
                      ElevatedButton(
                        onPressed: () {
                          // Provide tactile feedback for the important navigation
                          HapticManager.heavy();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SwarmDashboard()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AethericTheme.aetherBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          shadowColor:
                              AethericTheme.aetherBlue.withValues(alpha: 0.3),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          child: Text(
                            'ENTER SWARM',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
