// ABOUTME: Top navigation bar for video publish screen
// ABOUTME: Contains back button and publish button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Top navigation bar with back and publish buttons.
class VideoPublishTopBar extends ConsumerWidget {
  /// Creates a video publish top bar.
  const VideoPublishTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back button
            _buildIconButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
            // Publish button
            _buildIconButton(
              icon: Icons.send,
              backgroundColor: VineTheme.tabIndicatorGreen,
              onTap: () {
                // TODO: Implement publish
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a circular icon button with consistent styling.
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: backgroundColor ?? const Color(0xFF101111),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(1, 1),
              blurRadius: 1,
            ),
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0.4, 0.4),
              blurRadius: 0.6,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
