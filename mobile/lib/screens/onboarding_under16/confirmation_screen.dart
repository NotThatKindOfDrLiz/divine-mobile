// ABOUTME: Warm terminal screen for the under-16 flow
// ABOUTME: Affirms the user's honesty, gives a clear exit back to
// ABOUTME: welcome, and leaves the door open without promising access.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/onboarding_under16/age_acknowledgment_screen.dart';
import 'package:openvine/widgets/auth_back_button.dart';

/// Terminal screen for the under-16 flow.
///
/// This is the dignified exit — no account creation promise,
/// no dead-end. Acknowledges honesty, keeps the door open,
/// and sends the user back to the welcome screen.
class ConfirmationScreen extends StatelessWidget {
  static const String routeName = 'under16-confirmation';
  static const String path = 'confirmation';

  const ConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              AuthBackButton(
                onPressed: () => context.go(
                  '${WelcomeScreen.path}'
                  '/${AgeAcknowledgmentScreen.path}'
                  '/options',
                ),
              ),

              const SizedBox(height: 48),

              const Text(
                'You did the right\nthing 💛',
                style: TextStyle(
                  fontFamily: VineTheme.fontFamilyBricolage,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: VineTheme.vineGreen,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Being honest about your age takes guts. '
                "Most apps don't make that easy — we're "
                'trying to be different.',
                style: TextStyle(
                  fontSize: 16,
                  color: VineTheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              const _InfoCard(
                icon: Icons.favorite_outline,
                text:
                    'Talk to your parent or guardian about '
                    'what you saw here. They can help you '
                    'figure out the next step.',
              ),
              const SizedBox(height: 12),
              const _InfoCard(
                icon: Icons.access_time_rounded,
                text:
                    "Divine will be here when you're ready. "
                    'No rush.',
              ),

              const Spacer(),

              DivineButton(
                label: 'Back to start',
                expanded: true,
                onPressed: () => context.go(WelcomeScreen.path),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple info card with an icon and text.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VineTheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: VineTheme.vineGreen, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: VineTheme.onSurfaceMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
