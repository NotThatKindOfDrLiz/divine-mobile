// ABOUTME: Reusable back button for authentication flow screens
// ABOUTME: Green circular button with chevron icon

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/widgets/circular_icon_button.dart';
import 'package:divine_ui/divine_ui.dart';

/// A green circular back button used in authentication flow screens.
///
/// Displays a chevron-left icon inside a solid green circle.
/// Automatically calls `context.pop()` when pressed, or uses a custom
/// [onPressed] callback if provided.
///
/// Example usage:
/// ```dart
/// AuthBackButton()
/// ```
///
/// Or with custom callback:
/// ```dart
/// AuthBackButton(onPressed: () => customNavigation())
/// ```
class AuthBackButton extends StatelessWidget {
  /// Creates an authentication flow back button.
  ///
  /// If [onPressed] is null, the button will call `context.pop()`.
  const AuthBackButton({super.key, this.onPressed});

  /// Optional custom callback when the button is pressed.
  ///
  /// If null, defaults to `context.pop()`.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CircularIconButton(
      onPressed: onPressed ?? () => context.pop(),
      backgroundColor: VineTheme.surfaceContainer,
      backgroundOpacity: 1.0,
      size: 44,
      icon: const Icon(
        Icons.chevron_left,
        color: VineTheme.vineGreenLight,
        size: 28,
      ),
    );
  }
}
