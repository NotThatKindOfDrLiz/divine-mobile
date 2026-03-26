// ABOUTME: PRR Level 2 — Coached Engagement (Redirect) screen
// ABOUTME: Presents three ways to involve a parent/guardian in the
// ABOUTME: consent process. Each option maps to a different level of
// ABOUTME: parent involvement (co-use, active mediation, deferred).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/onboarding_under16/age_acknowledgment_screen.dart';
import 'package:openvine/widgets/auth_back_button.dart';

/// Options screen — the PRR "redirect" moment.
///
/// Offers the youth an immediate opportunity to do the right thing
/// (TBRI principle: "immediate opportunity for a redo"). Three paths,
/// each with different levels of parent involvement, all framed as
/// positive choices rather than restrictions.
class OptionsScreen extends StatelessWidget {
  static const String routeName = 'under16-options';
  static const String path = 'options';

  const OptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const basePath = '${WelcomeScreen.path}/${AgeAcknowledgmentScreen.path}';

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

              const Text(
                'How do you want\nto do this?',
                style: TextStyle(
                  fontFamily: VineTheme.fontFamilyBricolage,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: VineTheme.whiteText,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Pick the option that works best for you and '
                'your parent or guardian.',
                style: TextStyle(
                  fontSize: 16,
                  color: VineTheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // Option A: Record together (co-use model)
              _OptionCard(
                icon: Icons.videocam_rounded,
                title: 'Record a video together',
                subtitle:
                    'You and your parent, on camera, '
                    "saying they're cool with it.",
                onTap: () => context.go('$basePath/consent-video'),
              ),

              const SizedBox(height: 12),

              // Option B: Send parent a link / QR code
              _OptionCard(
                icon: Icons.send_rounded,
                title: 'Send my parent a link',
                subtitle:
                    'Get a link or QR code you can '
                    'share with them.',
                onTap: () => context.go('$basePath/come-back-later'),
              ),

              const SizedBox(height: 12),

              // Option C: Come back later — warm exit
              _OptionCard(
                icon: Icons.schedule_rounded,
                title: 'Come back later',
                subtitle: "No pressure — we'll be here when you're ready.",
                onTap: () => context.go('$basePath/confirmation'),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable card representing a parent involvement option.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VineTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VineTheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, color: VineTheme.vineGreen, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: VineTheme.whiteText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: VineTheme.onSurfaceMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: VineTheme.onSurfaceMuted,
            ),
          ],
        ),
      ),
    );
  }
}
