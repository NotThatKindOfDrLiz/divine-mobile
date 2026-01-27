// ABOUTME: Custom checkbox widget for legal acceptance screen
// ABOUTME: Displays bordered container with checkbox and content, supports error state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A custom checkbox widget with a bordered container.
///
/// Displays a checkbox inside a rounded container with border color that
/// changes based on checked and error states:
/// - Unchecked (default): muted green border
/// - Checked: bright green border
/// - Error: red border (when user tried to submit without checking)
class LegalCheckbox extends StatelessWidget {
  const LegalCheckbox({
    required this.checked,
    required this.onChanged,
    required this.child,
    this.showError = false,
    super.key,
  });

  /// Whether the checkbox is checked
  final bool checked;

  /// Callback when checkbox is tapped
  final VoidCallback onChanged;

  /// Content to display next to checkbox (typically Text or RichText)
  final Widget child;

  /// Whether to show error state (red border)
  final bool showError;

  Color get _borderColor {
    if (showError) {
      return VineTheme.error;
    }
    if (checked) {
      return VineTheme.vineGreen;
    }
    return VineTheme.outlineVariant;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _borderColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: checked,
                onChanged: (_) => onChanged(),
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return VineTheme.vineGreen;
                  }
                  return Colors.transparent;
                }),
                checkColor: Colors.white,
                side: BorderSide(
                  color: showError ? VineTheme.error : VineTheme.vineGreen,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
