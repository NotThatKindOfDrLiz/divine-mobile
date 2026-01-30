// ABOUTME: Legal acceptance screen for age verification and terms acceptance
// ABOUTME: Blocking gate before signup - delegates persistence to AuthService

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/legal/legal_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/auth/divine_auth_screen.dart';
import 'package:openvine/widgets/legal_checkbox.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomeScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final authService = ref.watch(authServiceProvider);

    return BlocProvider(
      create: (_) =>
          LegalCubit(sharedPreferences: prefs, authService: authService)
            ..loadSavedState(),
      child: const _LegalScreenView(),
    );
  }
}

class _LegalScreenView extends StatelessWidget {
  const _LegalScreenView();

  Future<void> _openUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LegalCubit, LegalState>(
      listenWhen: (prev, next) => next is LegalSuccess || next is LegalError,
      listener: (context, state) {
        if (state is LegalSuccess) {
          // Navigate to sign-up mode (signIn=false)
          context.go('${WelcomeScreen.path}${DivineAuthScreen.path}?signIn=false');
          // Reset state for when user navigates back
          context.read<LegalCubit>().loadSavedState();
        } else if (state is LegalError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: VineTheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxHeight < 700;
              final iconSize = isSmallScreen ? 160.0 : 224.0;
              final wordmarkWidth = isSmallScreen ? 100.0 : 130.0;

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Top section with branding
                            Column(
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.width < 600
                                      ? 0
                                      : 40,
                                ),
                                // App branding - Divine icon
                                Image.asset(
                                  'assets/icon/divine_icon_transparent.png',
                                  height: iconSize,
                                  fit: BoxFit.contain,
                                ),
                                // Wordmark logo
                                Image.asset(
                                  'assets/icon/divine_wordmark.png',
                                  width: wordmarkWidth,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Create and share short videos\non the decentralized web',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFFF5F6EA),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),

                            // Bottom section with checkboxes and button
                            Column(
                              children: [
                                _CheckboxSection(onOpenUrl: _openUrl),
                                const SizedBox(height: 32),
                                const _AcceptButton(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CheckboxSection extends StatelessWidget {
  const _CheckboxSection({required this.onOpenUrl});

  final Future<void> Function(String) onOpenUrl;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LegalCubit, LegalState>(
      buildWhen: (prev, next) => next is LegalLoaded,
      builder: (context, state) {
        if (state is! LegalLoaded) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            // Age verification checkbox
            LegalCheckbox(
              checked: state.isAgeVerified,
              showError: state.ageShowError,
              onChanged: () => context.read<LegalCubit>().toggleAgeVerified(),
              child: const Text(
                'I am 16 years or older',
                style: TextStyle(color: VineTheme.whiteText, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Terms acceptance checkbox with links
            LegalCheckbox(
              checked: state.isTermsAccepted,
              showError: state.termsShowError,
              onChanged: () => context.read<LegalCubit>().toggleTermsAccepted(),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 14,
                  ),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: const TextStyle(
                        color: VineTheme.vineGreen,
                        decoration: TextDecoration.underline,
                        decorationColor: VineTheme.vineGreen,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => onOpenUrl('https://divine.video/terms'),
                    ),
                    const TextSpan(text: ', '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        color: VineTheme.vineGreen,
                        decoration: TextDecoration.underline,
                        decorationColor: VineTheme.vineGreen,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () =>
                            onOpenUrl('https://divine.video/privacy'),
                    ),
                    const TextSpan(text: ', and '),
                    TextSpan(
                      text: 'Safety Standards',
                      style: const TextStyle(
                        color: VineTheme.vineGreen,
                        decoration: TextDecoration.underline,
                        decorationColor: VineTheme.vineGreen,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () =>
                            onOpenUrl('https://divine.video/safety'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AcceptButton extends StatelessWidget {
  const _AcceptButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LegalCubit, LegalState>(
      builder: (context, state) {
        final isSubmitting = state is LegalSubmitting;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isSubmitting
                ? null
                : () => context.read<LegalCubit>().submit(),
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: VineTheme.vineGreen.withValues(
                alpha: 0.7,
              ),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Accept & continue',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
          ),
        );
      },
    );
  }
}
