import 'package:flutter/material.dart';

/// A responsive grid widget following the "Bento" design pattern.
///
/// Automatically adjusts the number of columns based on the available width.
/// Useful for displaying dashboard items, content cards, or features in a
/// visually organized manner across mobile and desktop.
///
/// **Layout Logic:**
/// - Uses [LayoutBuilder] to detect screen width.
/// - Switches to [desktopColumns] when width exceeds 900 logical pixels.
/// - Otherwise uses [mobileColumns].
/// - Adjusts `childAspectRatio` dynamically for better aesthetics.
class AdaptiveBentoGrid extends StatelessWidget {
  /// The widgets to display in the grid.
  final List<Widget> children;

  /// Number of columns to use on small screens (mobile/tablet portrait).
  final int mobileColumns;

  /// Number of columns to use on large screens (desktop/tablet landscape).
  final int desktopColumns;

  /// Creates an [AdaptiveBentoGrid] instance.
  const AdaptiveBentoGrid({
    super.key,
    required this.children,
    this.mobileColumns = 2,
    this.desktopColumns = 4,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop threshold at 900px
        final int columns =
            constraints.maxWidth > 900 ? desktopColumns : mobileColumns;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            // Calculate aspect ratio to avoid squished items on narrow screens
            childAspectRatio: columns == 1 ? 2.5 : 1.1,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}
