// ABOUTME: PRR Level 1 entry point — the age group selection screen
// ABOUTME: Presents age as a neutral choice with equal visual weight
// ABOUTME: so neither option feels like the "wrong" answer

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/widgets/auth_back_button.dart';

/// Age group selection screen — the PRR Level 1 "pause" moment.
///
/// Instead of a punitive age gate, this screen presents age as a
/// neutral choice with equal visual weight — neither option is "wrong":
/// - "I'm 16 or older" → normal account creation
/// - "I'm under 16" → PRR-informed educational flow with parent involvement
class AgeAcknowledgmentScreen extends StatelessWidget {
  static const String routeName = 'age-check';
  static const String path = 'age-check';

  const AgeAcknowledgmentScreen({super.key});

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

              // Title
              const Text(
                'How old are you? 🎂',
                style: TextStyle(
                  fontFamily: VineTheme.fontFamilyBricolage,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: VineTheme.whiteText,
                  height: 1.2,
                ),
              ),

              const Spacer(),

              // Equal-weight choices — neither is "wrong"
              _AgeGroupCard(
                label: "I'm 16 or older 🎉",
                onTap: () => context.go(WelcomeScreen.createAccountPath),
              ),

              const SizedBox(height: 12),

              _AgeGroupCard(
                label: "I'm under 16 ✌️",
                onTap: () {
                  context.go(
                    '${WelcomeScreen.path}/${AgeAcknowledgmentScreen.path}'
                    '/honesty',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable card for an age group choice.
///
/// Both options get identical styling so neither feels like
/// the "right" or "wrong" answer.
class _AgeGroupCard extends StatelessWidget {
  const _AgeGroupCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: VineTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VineTheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: VineTheme.whiteText,
                ),
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
