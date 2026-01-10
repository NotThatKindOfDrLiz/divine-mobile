// ABOUTME: Instruction text widget for clip gallery
// ABOUTME: Animated fade and size transitions based on editing/reordering state

import 'package:flutter/material.dart';

/// Instruction text that appears below the clip gallery.
///
/// Displays "Tap to edit. Drag to reorder." with animated transitions
/// based on editing and reordering states.
class ClipGalleryInstructionText extends StatelessWidget {
  /// Creates clip gallery instruction text.
  const ClipGalleryInstructionText({
    required this.isEditing,
    required this.isReordering,
    super.key,
  });

  /// Whether the gallery is in editing mode.
  final bool isEditing;

  /// Whether clips are being reordered.
  final bool isReordering;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: 1,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: isEditing
          ? const SizedBox(width: double.infinity)
          : AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isReordering ? 0 : 1,
              child: const Align(
                child: Padding(
                  padding: .only(top: 25),
                  child: Text(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    'Tap to edit. Drag to reorder.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      height: 1.33,
                      letterSpacing: 0.4,
                      fontSize: 12,
                      color: Color(0x80FFFFFF),
                    ),
                    textAlign: .center,
                  ),
                ),
              ),
            ),
    );
  }
}
