// ABOUTME: PRR Level 1 — Casual Engagement (Reflect) screen
// ABOUTME: Educational screen explaining why we ask about age and why
// ABOUTME: honesty matters. Calm, non-punitive, no cortisol trigger.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/onboarding_under16/age_acknowledgment_screen.dart';
import 'package:openvine/widgets/auth_back_button.dart';

/// Honesty screen — the PRR "reflect" moment.
///
/// Grounded in the paper's principle that gentle prompts create pauses
/// where youth can consider context and consequence. No sound, no urgency,
/// no shame. Explains WHY we ask (safety, not gatekeeping) and frames
/// parent involvement as empowering.
class HonestyScreen extends StatelessWidget {
  static const String routeName = 'under16-honesty';
  static const String path = 'honesty';

  const HonestyScreen({super.key});

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

              AuthBackButton(onPressed: () => context.pop()),

              const SizedBox(height: 48),

              // Title — playful, not alarming
              const Text(
                "That's cool.\nLet's figure this out.",
                style: TextStyle(
                  fontFamily: VineTheme.fontFamilyBricolage,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: VineTheme.vineGreen,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 24),

              // Body — calm explanation, "Tell me more..." pattern from PRR
              const Text(
                "Most apps just ask you to say you're old enough "
                "and hope you tell the truth. We think that's a "
                'bad setup because it teaches you that lying is the '
                'price of admission.\n\n'
                "We'd rather help you do this the right way — "
                'with someone you trust.',
                style: TextStyle(
                  fontSize: 16,
                  color: VineTheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),

              const Spacer(),

              // Continue to options
              DivineButton(
                label: 'Show me my options',
                expanded: true,
                onPressed: () {
                  context.go(
                    '${WelcomeScreen.path}'
                    '/${AgeAcknowledgmentScreen.path}'
                    '/options',
                  );
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
