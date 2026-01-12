import 'package:flutter/material.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/settings/settings.dart';
import 'package:google_fonts/google_fonts.dart';

class OptimizationSettings extends StatefulWidget {
  const OptimizationSettings({super.key});

  @override
  State<OptimizationSettings> createState() => _OptimizationSettingsState();
}

class _OptimizationSettingsState extends State<OptimizationSettings> {
  final _config = ConfigManager();

  late String _validationMode;
  late bool _probeProviders;
  final _probeTimeoutController = TextEditingController();
  final _provFetchTimeoutController = TextEditingController();
  late bool _swarmEnabled;
  final _swarmTopNController = TextEditingController();
  late bool _swarmMissingOnly;
  final _swarmTimeoutController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _validationMode = _config.validationMode;
    _probeProviders = _config.probeProviders;
    _probeTimeoutController.text = _config.probeTimeoutMs.toString();
    _provFetchTimeoutController.text = _config.providerFetchTimeoutMs
        .toString();
    _swarmEnabled = _config.swarmEnabled;
    _swarmTopNController.text = _config.swarmTopN.toString();
    _swarmMissingOnly = _config.swarmMissingOnly;
    _swarmTimeoutController.text = _config.swarmTimeoutMs.toString();
  }

  void _saveInt(TextEditingController controller, Function(int) setter) {
    final val = int.tryParse(controller.text);
    if (val != null && val >= 0) {
      setter(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      appBar: AppBar(
        title: Text(
          'OPTIMIZATION',
          style: GoogleFonts.outfit(letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Hero(
            tag: 'settings_icon_opt',
            child: const Icon(Icons.speed_rounded, color: Colors.white70),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InfoCard(
              message:
                  'Tune performance and behavior. Aggressive settings may increase load times.',
              severity: InfoCardSeverity.info,
              customIcon: Icons.speed_rounded,
            ),
            const SizedBox(height: 24),

            const SectionHeader('VALIDATION & PROBING'),
            const SizedBox(height: 8),

            SettingsDropdown<String>(
              value: _validationMode,
              items: const ['off', 'basic', 'aggressive'],
              icon: Icons.verified_user_rounded,
              getLabel: (val) {
                switch (val) {
                  case 'off':
                    return 'Off (Fastest)';
                  case 'basic':
                    return 'Basic (DNS + HTTP Head)';
                  case 'aggressive':
                    return 'Aggressive (Full Probe)';
                  default:
                    return val.toUpperCase();
                }
              },
              onChanged: (val) {
                setState(() => _validationMode = val!);
                _config.validationMode = val!;
              },
            ),
            const SizedBox(height: 16),

            SettingsToggle(
              title: 'Probe Providers',
              description: 'Check if provider is responsive before querying',
              value: _probeProviders,
              leadingIcon: Icons.network_check_rounded,
              onChanged: (v) {
                setState(() => _probeProviders = v);
                _config.probeProviders = v;
              },
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: SettingsTextField(
                    controller: _probeTimeoutController,
                    label: 'Probe Timeout (ms)',
                    hint: '500',
                    leadingIcon: Icons.timer_outlined,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _saveInt(
                      _probeTimeoutController,
                      (v) => _config.probeTimeoutMs = v,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SettingsTextField(
                    controller: _provFetchTimeoutController,
                    label: 'Fetch Timeout (ms)',
                    hint: '3000',
                    leadingIcon: Icons.downloading_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _saveInt(
                      _provFetchTimeoutController,
                      (v) => _config.providerFetchTimeoutMs = v,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            const SectionHeader('SWARM SCRAPING'),
            const SizedBox(height: 8),

            SettingsToggle(
              title: 'Enable Swarm',
              description: 'Recursively finding more peers from found magnets',
              value: _swarmEnabled,
              leadingIcon: Icons.hive_rounded,
              onChanged: (v) {
                setState(() => _swarmEnabled = v);
                _config.swarmEnabled = v;
              },
            ),
            if (_swarmEnabled) ...[
              const SizedBox(height: 16),
              SettingsToggle(
                title: 'Missing Only',
                description: 'Only swarm if upstream lacks seeds',
                value: _swarmMissingOnly,
                leadingIcon: Icons.filter_list_off_rounded,
                onChanged: (v) {
                  setState(() => _swarmMissingOnly = v);
                  _config.swarmMissingOnly = v;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SettingsTextField(
                      controller: _swarmTopNController,
                      label: 'Top N Items',
                      hint: '2',
                      leadingIcon: Icons.format_list_numbered_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _saveInt(
                        _swarmTopNController,
                        (v) => _config.swarmTopN = v,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SettingsTextField(
                      controller: _swarmTimeoutController,
                      label: 'Swarm Timeout (ms)',
                      hint: '800',
                      leadingIcon: Icons.timer_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _saveInt(
                        _swarmTimeoutController,
                        (v) => _config.swarmTimeoutMs = v,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
