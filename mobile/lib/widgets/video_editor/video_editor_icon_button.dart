import 'package:flutter/material.dart';

class VideoEditorIconButton extends StatelessWidget {
  const VideoEditorIconButton({
    super.key,
    required this.icon,
    this.backgroundColor = const Color(0xFF101111),
    this.iconColor = Colors.white,
    this.iconSize = 24,
    this.size = 48,
    this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final double iconSize;
  final double size;
  final VoidCallback? onTap;
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
