// ABOUTME: Welcome screen for new users with hero branding and account options
// ABOUTME: Shows AuthHeroSection, create/login buttons, and passive TOS notice

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/widgets/auth/auth_hero_section.dart';
import 'package:openvine/widgets/error_message.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'welcome';

  /// Path for this route.
  static const path = '/welcome';

  /// Path for login options route.
  static const loginOptionsPath = '/welcome/login-options';

  /// Path for auth native route.
  static const authNativePath = '/welcome/login-options/auth-native';

  /// Path for reset password route.
  static const resetPasswordPath =
      '/welcome/login-options/auth-native/reset-password';

  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isAccepting = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(currentAuthStateProvider);
    final authService = ref.watch(authServiceProvider);

    final isLoading =
        authState == AuthState.checking ||
        authState == AuthState.authenticating ||
        _isAccepting;

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Hero section with tagline and stickers
              const Expanded(child: Center(child: AuthHeroSection())),

              // Error display
              if (authService.lastError != null) ...[
                ErrorMessage(message: authService.lastError!),
                const SizedBox(height: 16),
              ],

              // Create new account button
              _CreateAccountButton(
                isLoading: isLoading,
                onPressed: () => _handleContinue(context),
              ),

              const SizedBox(height: 12),

              // Login with different account button
              _LoginButton(
                isLoading: isLoading,
                onPressed: () {
                  ref.read(authServiceProvider).acceptTerms();
                  context.push(WelcomeScreen.loginOptionsPath);
                },
              ),

              const SizedBox(height: 20),

              // Passive terms notice
              const _TermsNotice(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleContinue(BuildContext context) async {
    setState(() => _isAccepting = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInAutomatically();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to continue: $e'),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }
}

/// Primary action button to create a new diVine account.
class _CreateAccountButton extends StatelessWidget {
  const _CreateAccountButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: VineTheme.vineGreen,
          foregroundColor: VineTheme.backgroundColor,
          disabledBackgroundColor: VineTheme.vineGreen.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: VineTheme.backgroundColor,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Create new diVine account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

/// Secondary action button to login with a different account.
class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: VineTheme.vineGreen,
          backgroundColor: VineTheme.surfaceContainer,
          side: const BorderSide(color: VineTheme.outlineMuted, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Text(
          'Login with a different account',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Passive terms notice text with clickable links.
class _TermsNotice extends StatelessWidget {
  const _TermsNotice();

  Future<void> _openUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      color: VineTheme.vineGreen,
      decoration: TextDecoration.underline,
      decorationColor: VineTheme.vineGreen,
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: VineTheme.secondaryText,
          height: 1.4,
        ),
        children: [
          const TextSpan(
            text:
                'By selecting an option above, you confirm you are '
                'at least 16 years old and agree to the ',
          ),
          TextSpan(
            text: 'Terms of Service',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openUrl('https://divine.video/terms'),
          ),
          const TextSpan(text: ', '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openUrl('https://divine.video/privacy'),
          ),
          const TextSpan(text: ', and '),
          TextSpan(
            text: 'Safety Standards',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openUrl('https://divine.video/safety'),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
