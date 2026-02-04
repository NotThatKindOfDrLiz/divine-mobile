// ABOUTME: Screen shown when user fails npub verification
// ABOUTME: Directs user to enter invite code or wait for public access

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/invite_choice_screen.dart';

/// Arguments for WaitlistScreen navigation.
class WaitlistScreenArgs {
  const WaitlistScreenArgs({this.message});

  /// Custom message to display (e.g., from verification failure).
  final String? message;
}

/// Screen shown when a user's npub verification fails.
///
/// This screen is displayed when a user signs in without an invite code
/// and their npub is not verified for access. The user can either enter
/// an invite code or wait for public access.
class WaitlistScreen extends StatelessWidget {
  const WaitlistScreen({super.key, this.message});

  /// Route name for this screen.
  static const String routeName = 'waitlist';

  /// Path for this route (nested under /invite).
  static const String path = '/invite/waitlist';

  /// Custom message to display.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/icon/divine_icon_transparent.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Image.asset(
                    'assets/icon/divine_wordmark.png',
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 48),

                  // Title
                  Text(
                    'Waitlist',
                    style: VineTheme.headlineMediumFont(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Message
                  Text(
                    message ??
                        'Your account is not yet verified for access.\n\n'
                            'Divine is currently invite-only. Please enter an '
                            'invite code to continue.',
                    style: VineTheme.bodyMediumFont(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Enter invite code button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go(InviteChoiceScreen.path),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VineTheme.vineGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Enter Invite Code',
                        style: VineTheme.labelLargeFont(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Help text
                  Text(
                    "Don't have an invite code?\n"
                    'Ask a friend or wait for public access.',
                    style: VineTheme.bodySmallFont(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
