// ABOUTME: Guided consent video recording screen
// ABOUTME: Provides on-screen prompts for parent+child to record
// ABOUTME: a consent video together. Shell for Phase 1 — video capture
// ABOUTME: integration comes in Phase 3.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/onboarding_under16/age_acknowledgment_screen.dart';
import 'package:openvine/widgets/auth_back_button.dart';

/// Consent video screen — guided recording with on-screen prompts.
///
/// Grounded in Montessori's "structured independence" principle: we provide
/// the structure (prompts for what to say) but the parent and child own the
/// process. The video is their artifact, not ours.
class ConsentVideoScreen extends StatelessWidget {
  static const String routeName = 'under16-consent-video';
  static const String path = 'consent-video';

  const ConsentVideoScreen({super.key});

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
                'Record together',
                style: TextStyle(
                  fontFamily: VineTheme.fontFamilyBricolage,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: VineTheme.whiteText,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Make a short video with your parent or guardian. '
                "Here's what to say:",
                style: TextStyle(
                  fontSize: 16,
                  color: VineTheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // Guided prompts
              const _PromptItem(
                number: '1',
                text: 'Say hi and introduce yourselves',
              ),
              const SizedBox(height: 12),
              const _PromptItem(
                number: '2',
                text:
                    "Parent: say that you're ok with your "
                    'child using Divine',
              ),
              const SizedBox(height: 12),
              const _PromptItem(
                number: '3',
                text: 'Both: give a thumbs up or a wave',
              ),

              const SizedBox(height: 32),

              // Placeholder for camera preview — Phase 3
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: VineTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: VineTheme.outlineVariant),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam_outlined,
                          color: VineTheme.onSurfaceMuted,
                          size: 48,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Camera preview\n(coming soon)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: VineTheme.onSurfaceMuted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Record button placeholder
              DivineButton(
                label: 'Start recording',
                expanded: true,
                onPressed: () {
                  // Phase 3: integrate with camera
                },
              ),

              const SizedBox(height: 8),

              // Exit to confirmation
              Center(
                child: TextButton(
                  onPressed: () => context.go(
                    '${WelcomeScreen.path}'
                    '/${AgeAcknowledgmentScreen.path}'
                    '/confirmation',
                  ),
                  child: const Text(
                    'Not ready yet? No worries',
                    style: TextStyle(
                      color: VineTheme.onSurfaceMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// A numbered prompt item for the video recording instructions.
class _PromptItem extends StatelessWidget {
  const _PromptItem({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: VineTheme.primaryDarkGreen,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: VineTheme.vineGreen,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: VineTheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
