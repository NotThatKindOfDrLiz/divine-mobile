// ABOUTME: Reusable styled text field for authentication screens
// ABOUTME: Consistent gray-themed input with hint text, error display,
// ABOUTME: and optional suffix icon

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A styled text field for authentication screens.
///
/// Provides consistent styling across sign-in, sign-up, and account screens
/// with gray hint text, rounded borders, and optional error display.
class AuthTextField extends StatelessWidget {
  /// Creates a text field for authentication screens.
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.errorText,
    this.enabled = true,
    required this.onChanged,
    this.suffixIcon,
    this.textInputAction,
    this.onSubmitted,
  });

  /// Controller for the text field.
  final TextEditingController controller;

  /// Hint text displayed when the field is empty.
  final String hintText;

  /// The keyboard type to use.
  final TextInputType? keyboardType;

  /// Whether to obscure the text (e.g. for passwords).
  final bool obscureText;

  /// Error text to display below the field. If null, no error is shown.
  final String? errorText;

  /// Whether the field is enabled for input.
  final bool enabled;

  /// Called when the field value changes.
  final ValueChanged<String> onChanged;

  /// Optional widget to display at the end of the field.
  final Widget? suffixIcon;

  /// The keyboard action button type.
  final TextInputAction? textInputAction;

  /// Called when the user submits the field (e.g. presses done).
  final ValueChanged<String>? onSubmitted;

  static const _borderRadius = 16.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          autocorrect: false,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: const TextStyle(color: VineTheme.primaryText, fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: VineTheme.lightText),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_borderRadius),
              borderSide: BorderSide(
                color: errorText != null
                    ? VineTheme.error
                    : VineTheme.outlineVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_borderRadius),
              borderSide: BorderSide(
                color: errorText != null
                    ? VineTheme.error
                    : VineTheme.vineGreen,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_borderRadius),
              borderSide: const BorderSide(color: VineTheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_borderRadius),
              borderSide: const BorderSide(color: VineTheme.error, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_borderRadius),
              borderSide: const BorderSide(color: VineTheme.outlineVariant),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: VineTheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
          onChanged: onChanged,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: TextStyle(color: VineTheme.error, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
