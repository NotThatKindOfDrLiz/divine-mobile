// ABOUTME: Reusable rounded icon button for video editor controls
// ABOUTME: Customizable size, colors, and shadow styling

import 'package:flutter/material.dart';

/// Rounded icon button used throughout the video editor.
class VideoEditorIconButton extends StatelessWidget {
  /// Creates a video editor icon button.
  const VideoEditorIconButton({
    required this.icon,
    super.key,
    this.backgroundColor = const Color(0xFF101111),
    this.iconColor = Colors.white,
    this.iconSize = 24,
    this.size = 48,
    this.onTap,
    this.semanticLabel,
  });

  /// The icon to display.
  final IconData icon;
  
  /// Background color of the button.
  final Color backgroundColor;
  
  /// Color of the icon.
  final Color iconColor;
  
  /// Size of the icon.
  final double iconSize;
  
  /// Size of the button container.
  final double size;
  
  /// Callback when the button is tapped.
  final VoidCallback? onTap;
  
  /// Semantic label for accessibility.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: .circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 1,
                offset: const Offset(1, 1),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 0.6,
                offset: const Offset(0.4, 0.4),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}
