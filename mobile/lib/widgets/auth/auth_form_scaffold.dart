// ABOUTME: Shared scaffold layout for auth form screens (create account,
// ABOUTME: secure account). Provides dark background, back button, title,
// ABOUTME: email/password field slots, dog sticker, error, and button slots.
// Figma: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=6560-62187

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/widgets/auth_back_button.dart';

/// A shared scaffold layout for authentication form screens.
///
/// Provides the standard dark-background layout with:
/// - [AuthBackButton] at the top
/// - Title text
/// - Email and password field slots
/// - Dog sticker (right-aligned, rotated)
/// - Optional error widget
/// - Primary and optional secondary button slots pushed to bottom
///
/// Each screen passes its own field widgets and buttons, keeping
/// submit logic independent while sharing the visual structure.
class AuthFormScaffold extends StatelessWidget {
  const AuthFormScaffold({
    super.key,
    required this.title,
    required this.emailField,
    required this.passwordField,
    this.errorWidget,
    required this.primaryButton,
    this.secondaryButton,
    this.onBack,
  });

  /// The title displayed below the back button.
  final String title;

  /// The email input field widget.
  final Widget emailField;

  /// The password input field widget.
  final Widget passwordField;

  /// Optional error widget displayed below the dog sticker.
  final Widget? errorWidget;

  /// The primary action button (e.g. "Create account").
  final Widget primaryButton;

  /// Optional secondary action button (e.g. "Skip for now").
  final Widget? secondaryButton;

  /// Custom back button callback. Defaults to `context.pop()`.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Back button
                    AuthBackButton(onPressed: onBack ?? () => context.pop()),

                    const SizedBox(height: 32),

                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'BricolageGrotesque',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: VineTheme.whiteText,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Email field
                    emailField,

                    const SizedBox(height: 16),

                    // Password field
                    passwordField,

                    const SizedBox(height: 16),

                    // Dog sticker
                    Align(
                      alignment: Alignment.centerRight,
                      child: Transform.translate(
                        offset: const Offset(20, 0),
                        child: Transform.rotate(
                          angle: 12 * pi / 180,
                          child: Image.asset(
                            'assets/stickers/samoyed_dog.png',
                            width: 174,
                            height: 174,
                          ),
                        ),
                      ),
                    ),

                    // Error display
                    if (errorWidget != null) ...[
                      const SizedBox(height: 16),
                      errorWidget!,
                    ],

                    // Push buttons to bottom
                    const Spacer(),

                    // Primary button
                    primaryButton,

                    // Secondary button (optional)
                    if (secondaryButton != null) ...[
                      const SizedBox(height: 12),
                      secondaryButton!,
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
