/// Design system components for Gardener settings pages.
///
/// Provides standardized, reusable widgets following the Aetheric design
/// language and 2025 UI/UX best practices.
///
/// All components include built-in accessibility, consistent styling,
/// and follow WCAG 2.2 guidelines.
///
/// ## Usage
/// ```dart
/// import 'package:gardener/ui/widgets/settings/settings.dart';
///
/// SectionHeader('My Section'),
/// SizedBox(height: 8),
/// SettingsToggle(
///   title: 'Enable Feature',
///   description: 'Turn this feature on or off',
///   value: _enabled,
///   onChanged: (v) => setState(() => _enabled = v),
/// ),
/// ```
///
/// ## Design System
/// For complete design tokens, spacing, and guidelines, see:
/// `design_system.md` in the project documentation.
library;

export 'expandable_section.dart';
export 'info_card.dart';
export 'navigation_card.dart';
export 'section_header.dart';
export 'settings_dropdown.dart';
export 'settings_slider.dart';
export 'settings_text_field.dart';
export 'settings_toggle.dart';
