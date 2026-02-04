// ABOUTME: Screen presenting invite flow options to new users
// ABOUTME: Three choices: enter invite code, join waitlist, or sign in

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/npub_verification/npub_verification_bloc.dart';
import 'package:openvine/screens/invite_code_entry_screen.dart';
import 'package:openvine/screens/waitlist_screen.dart';
import 'package:openvine/screens/welcome_screen.dart';

/// Screen presenting options for new users without an invite code.
///
/// Offers three choices:
/// - Enter an invite code (navigates to code entry screen)
/// - Join the waitlist (navigates to waitlist screen)
/// - Sign in with existing account (goes to login flow with npub verification)
class InviteChoiceScreen extends StatelessWidget {
  const InviteChoiceScreen({super.key});

  /// Route name for this screen.
  static const routeName = 'invite';

  /// Path for this route.
  static const path = '/invite';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Divine logo
                  Image.asset(
                    'assets/icon/divine_icon_transparent.png',
                    height: 120,
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
                    'Welcome to Divine',
                    style: VineTheme.headlineMediumFont(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Divine is currently invite-only.\n'
                    'Choose an option below to get started.',
                    style: VineTheme.bodyMediumFont(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Option 1: Enter invite code
                  _ChoiceButton(
                    icon: Icons.confirmation_number_outlined,
                    title: 'I have an invite code',
                    subtitle: 'Enter your 8-character code',
                    onTap: () => context.push(InviteCodeEntryScreen.path),
                  ),
                  const SizedBox(height: 16),

                  // Option 2: Join waitlist
                  _ChoiceButton(
                    icon: Icons.hourglass_empty,
                    title: 'Join the waitlist',
                    subtitle: 'Get notified when spots open up',
                    onTap: () => context.push(WaitlistScreen.path),
                  ),
                  const SizedBox(height: 16),

                  // Option 3: Sign in with existing account
                  _ChoiceButton(
                    icon: Icons.login,
                    title: 'Sign in with existing account',
                    subtitle: 'For users who already have access',
                    onTap: () {
                      // Set flag to allow bypassing invite screen for login flow
                      context.read<NpubVerificationBloc>().add(
                        const NpubVerificationSkipInviteSet(),
                      );
                      context.go(WelcomeScreen.path);
                    },
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

/// A styled button for the choice options.
class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VineTheme.cardBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: VineTheme.vineGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: VineTheme.vineGreen, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: VineTheme.labelLargeFont()),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: VineTheme.bodySmallFont(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
