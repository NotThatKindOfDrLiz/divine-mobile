// ABOUTME: Shared password text field for authentication screens
// ABOUTME: Wraps AuthTextField with visibility toggle and obscured input

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/widgets/auth/auth_text_field.dart';

/// A styled password text field for authentication screens.
///
/// Wraps [AuthTextField] with password-specific behavior:
/// - Obscured text input by default
/// - Optional visibility toggle (eye icon)
///
/// Set [showVisibilityToggle] to `false` for confirm password fields
/// where toggling visibility is not needed.
class AuthPasswordField extends StatefulWidget {
  /// Creates a password text field for authentication screens.
  const AuthPasswordField({
    super.key,
    required this.controller,
    this.hintText = 'Password',
    this.errorText,
    this.enabled = true,
    required this.onChanged,
    this.showVisibilityToggle = true,
    this.textInputAction,
    this.onSubmitted,
  });

  /// Controller for the text field.
  final TextEditingController controller;

  /// Hint text displayed when the field is empty. Defaults to 'Password'.
  final String hintText;

  /// Error text to display below the field. If null, no error is shown.
  final String? errorText;

  /// Whether the field is enabled for input.
  final bool enabled;

  /// Called when the field value changes.
  final ValueChanged<String> onChanged;

  /// Whether to show the visibility toggle icon. Defaults to true.
  final bool showVisibilityToggle;

  /// The keyboard action button type.
  final TextInputAction? textInputAction;

  /// Called when the user submits the field (e.g. presses done).
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      controller: widget.controller,
      hintText: widget.hintText,
      obscureText: _obscureText,
      errorText: widget.errorText,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      suffixIcon: widget.showVisibilityToggle
          ? IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility_off : Icons.visibility,
                color: VineTheme.lightText,
              ),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            )
          : null,
    );
  }
}
