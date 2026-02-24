// ABOUTME: Screen presenting invite flow options to new users
// ABOUTME: Hero text with decorative emojis, three action options at bottom

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/npub_verification/npub_verification_bloc.dart';
import 'package:openvine/widgets/auth/auth_hero_section.dart';
import 'package:openvine/screens/auth/invite_code_entry_screen.dart';
import 'package:openvine/screens/auth/waitlist_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Hero section with text and decorative emojis
              Expanded(child: Center(child: AuthHeroSection())),

              // Bottom action buttons
              _ActionButtons(
                onEnterInviteCode: () =>
                    context.push(InviteCodeEntryScreen.path),
                onJoinWaitlist: () => context.push(WaitlistScreen.path),
                onSignIn: () {
                  context.read<NpubVerificationBloc>().add(
                    const NpubVerificationSkipInviteSet(),
                  );
                  context.push(WelcomeScreen.path);
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom action buttons section.
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onEnterInviteCode,
    required this.onJoinWaitlist,
    required this.onSignIn,
  });

  final VoidCallback onEnterInviteCode;
  final VoidCallback onJoinWaitlist;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary: Enter invite code (filled green button)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onEnterInviteCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.backgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Enter invite code',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Secondary: Join the waitlist (outlined button)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: onJoinWaitlist,
              style: OutlinedButton.styleFrom(
                foregroundColor: VineTheme.vineGreen,
                backgroundColor: VineTheme.surfaceContainer,
                side: const BorderSide(
                  color: VineTheme.outlineMuted,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Join the waitlist',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Tertiary: Sign in text link
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: VineTheme.secondaryText),
              children: [
                const TextSpan(text: 'Have an account? '),
                TextSpan(
                  text: 'Sign in',
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onSignIn,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
