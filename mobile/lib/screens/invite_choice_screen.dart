// ABOUTME: Screen presenting invite flow options to new users
// ABOUTME: Hero text with decorative emojis, three action options at bottom

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Hero section with text and decorative emojis
              Expanded(child: Center(child: _HeroSection())),

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

/// Hero section with large text and decorative 3D emoji stickers.
class _HeroSection extends StatelessWidget {
  // Placeholder sticker path - replace with actual assets when available
  static const String _stickerPath = 'assets/stickers/disco_ball.png';

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hero text with positioned emoji stickers
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Main text
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    // "Authentic moments." - green, BricolageGrotesque font
                    Text(
                      'Authentic moments.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'BricolageGrotesque',
                        fontSize: 48,
                        fontWeight: FontWeight.w800, // ExtraBold
                        color: VineTheme.vineGreen,
                        height: 1.1,
                      ),
                    ),
                    // "Human creativity." - white, BricolageGrotesque font
                    Text(
                      'Human creativity.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'BricolageGrotesque',
                        fontSize: 48,
                        fontWeight: FontWeight.w800, // ExtraBold
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),

              // Camera emoji - top left
              Positioned(
                top: -30,
                left: 10,
                child: _StickerImage(path: _stickerPath, size: 60),
              ),

              // Teeth emoji - top right
              Positioned(
                top: -5,
                right: -20,
                child: _StickerImage(path: _stickerPath, size: 70),
              ),

              // Balloon dog emoji - bottom left
              Positioned(
                bottom: -34,
                left: 15,
                child: _StickerImage(path: _stickerPath, size: 80),
              ),

              // Disco ball emoji - bottom right
              Positioned(
                bottom: -10,
                right: -10,
                child: _StickerImage(path: _stickerPath, size: 65),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Divine wordmark (green SVG logo)
          SvgPicture.asset('assets/icon/divine_new.svg', width: 120),
        ],
      ),
    );
  }
}

/// Decorative sticker image widget.
class _StickerImage extends StatelessWidget {
  const _StickerImage({required this.path, required this.size});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(path, width: size, height: size, fit: BoxFit.contain);
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
                foregroundColor: Colors.black,
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
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              children: [
                const TextSpan(text: 'Have an account? '),
                TextSpan(
                  text: 'Sign in',
                  style: const TextStyle(
                    color: Colors.white,
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
