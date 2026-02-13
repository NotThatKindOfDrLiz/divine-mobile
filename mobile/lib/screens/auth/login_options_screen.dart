// ABOUTME: Sign-in screen with email/password form and alternative Nostr methods
// ABOUTME: Options: Email sign-in, Import Nostr Key, Signer App, or Amber

import 'dart:io' show Platform;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show AndroidPlugin;
import 'package:openvine/blocs/divine_auth/divine_auth_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/widgets/auth/auth_error_box.dart';
import 'package:openvine/widgets/auth/auth_password_field.dart';
import 'package:openvine/widgets/auth/auth_text_field.dart';
import 'package:openvine/widgets/auth/forgot_password_dialog.dart';
import 'package:openvine/widgets/auth_back_button.dart';

/// Sign-in screen — Page that provides [DivineAuthCubit].
class LoginOptionsScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const String routeName = 'login-options';

  /// Route path for this screen.
  static const String path = '/login-options';

  const LoginOptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oauthClient = ref.watch(oauthClientProvider);
    final authService = ref.watch(authServiceProvider);
    final pendingVerificationService = ref.watch(
      pendingVerificationServiceProvider,
    );

    return BlocProvider(
      create: (_) => DivineAuthCubit(
        oauthClient: oauthClient,
        authService: authService,
        pendingVerificationService: pendingVerificationService,
      )..initialize(isSignIn: true),
      child: const _LoginOptionsView(),
    );
  }
}

/// Sign-in screen — View that consumes [DivineAuthCubit] state.
class _LoginOptionsView extends StatelessWidget {
  const _LoginOptionsView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<DivineAuthCubit, DivineAuthState>(
      listenWhen: (prev, next) =>
          next is DivineAuthEmailVerification || next is DivineAuthSuccess,
      listener: (context, state) {
        if (state is DivineAuthEmailVerification) {
          final encodedEmail = Uri.encodeComponent(state.email);
          context.go(
            '${EmailVerificationScreen.path}'
            '?deviceCode=${state.deviceCode}'
            '&verifier=${state.verifier}'
            '&email=$encodedEmail',
          );
        }
      },
      child: Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: SafeArea(
          child: BlocBuilder<DivineAuthCubit, DivineAuthState>(
            builder: (context, state) {
              if (state is DivineAuthFormState) {
                return _SignInContent(state: state);
              }
              return const Center(
                child: CircularProgressIndicator(color: VineTheme.vineGreen),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Main content with email/password form and alternative login methods.
class _SignInContent extends ConsumerStatefulWidget {
  const _SignInContent({required this.state});

  final DivineAuthFormState state;

  @override
  ConsumerState<_SignInContent> createState() => _SignInContentState();
}

class _SignInContentState extends ConsumerState<_SignInContent> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isConnectingAmber = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.state.email);
    _passwordController = TextEditingController(text: widget.state.password);
  }

  @override
  void didUpdateWidget(covariant _SignInContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_emailController.text != widget.state.email) {
      _emailController.text = widget.state.email;
    }
    if (_passwordController.text != widget.state.password) {
      _passwordController.text = widget.state.password;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connectWithAmber() async {
    final isInstalled = await AndroidPlugin.existAndroidNostrSigner() ?? false;
    if (!isInstalled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Amber app is not installed'),
          backgroundColor: VineTheme.error,
        ),
      );
      return;
    }

    setState(() => _isConnectingAmber = true);

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.connectWithAmber();

      if (!mounted) return;

      if (result.success) {
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? 'Failed to connect with Amber',
            ),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnectingAmber = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    showForgotPasswordDialog(
      context: context,
      initialEmail: _emailController.text,
      onSendResetEmail: (email) async {
        await context.read<DivineAuthCubit>().sendPasswordResetEmail(email);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'If an account exists with that email, '
                'a password reset link has been sent.',
              ),
              backgroundColor: VineTheme.vineGreen,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = widget.state.isSubmitting;
    final isDisabled = isSubmitting || _isConnectingAmber;

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Top bar: back + info
                Row(
                  children: [
                    AuthBackButton(
                      onPressed: isDisabled ? null : () => context.pop(),
                    ),
                    const Spacer(),
                    _InfoButton(
                      onPressed: isDisabled
                          ? null
                          : () => _showInfoSheet(context),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Title
                const Text(
                  'Sign in',
                  style: TextStyle(
                    fontFamily: 'BricolageGrotesque',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: VineTheme.whiteText,
                  ),
                ),

                const SizedBox(height: 40),

                // Email field
                AuthTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  errorText: widget.state.emailError,
                  enabled: !isDisabled,
                  onChanged: (value) =>
                      context.read<DivineAuthCubit>().updateEmail(value),
                ),

                const SizedBox(height: 16),

                // Password field
                AuthPasswordField(
                  controller: _passwordController,
                  errorText: widget.state.passwordError,
                  enabled: !isDisabled,
                  onChanged: (value) =>
                      context.read<DivineAuthCubit>().updatePassword(value),
                ),

                // General error
                if (widget.state.generalError != null) ...[
                  const SizedBox(height: 16),
                  AuthErrorBox(message: widget.state.generalError!),
                ],

                const SizedBox(height: 24),

                // Sign in button
                _SignInButton(
                  isSubmitting: isSubmitting,
                  isDisabled: isDisabled,
                  onPressed: () => context.read<DivineAuthCubit>().submit(),
                ),

                const SizedBox(height: 16),

                // Forgot password
                Center(
                  child: GestureDetector(
                    onTap: isDisabled ? null : _showForgotPasswordDialog,
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: VineTheme.vineGreen,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: VineTheme.vineGreen,
                      ),
                    ),
                  ),
                ),

                // Push alternative methods to bottom
                const Spacer(),

                // Alternative login methods
                _AlternativeMethodButton(
                  label: 'Import Nostr key',
                  onPressed: isDisabled
                      ? null
                      : () => context.push(KeyImportScreen.path),
                ),

                const SizedBox(height: 12),

                _AlternativeMethodButton(
                  label: 'Connect with Signer App',
                  onPressed: isDisabled
                      ? null
                      : () => context.push(NostrConnectScreen.path),
                ),

                if (Platform.isAndroid) ...[
                  const SizedBox(height: 12),
                  _AlternativeMethodButton(
                    label: 'Sign in with Amber',
                    isLoading: _isConnectingAmber,
                    onPressed: isDisabled ? null : _connectWithAmber,
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Info button — circle with outlined border.
class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: VineTheme.vineGreen, width: 1.5),
        ),
        child: const Icon(
          Icons.info_outline,
          color: VineTheme.vineGreen,
          size: 22,
        ),
      ),
    );
  }
}

/// Green filled sign-in button.
class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.isSubmitting,
    required this.isDisabled,
    required this.onPressed,
  });

  final bool isSubmitting;
  final bool isDisabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: VineTheme.vineGreen,
          foregroundColor: VineTheme.backgroundColor,
          disabledBackgroundColor: VineTheme.vineGreen.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: VineTheme.backgroundColor,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Sign in',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

/// Outlined button for alternative login methods.
class _AlternativeMethodButton extends StatelessWidget {
  const _AlternativeMethodButton({
    required this.label,
    this.isLoading = false,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: VineTheme.vineGreen,
          backgroundColor: VineTheme.surfaceContainer,
          side: const BorderSide(color: VineTheme.outlineMuted, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: VineTheme.vineGreen,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

void _showInfoSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VineTheme.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _InfoSheet(),
  );
}

/// Bottom sheet explaining the available sign-in options.
class _InfoSheet extends StatelessWidget {
  const _InfoSheet();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VineTheme.outlineMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Sign-in options',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: VineTheme.whiteText,
            ),
          ),
          const SizedBox(height: 20),

          const _InfoItem(
            title: 'Email & Password',
            description:
                'Sign in with your diVine account. If you registered '
                'with an email and password, use them here.',
          ),
          const SizedBox(height: 16),
          const _InfoItem(
            title: 'Import Nostr key',
            description:
                'Already have a Nostr identity? Import your nsec '
                'private key from another client.',
          ),
          const SizedBox(height: 16),
          const _InfoItem(
            title: 'Signer App',
            description:
                'Connect using a NIP-46 compatible remote signer '
                'like nsecBunker for enhanced key security.',
          ),
          if (Platform.isAndroid) ...[
            const SizedBox(height: 16),
            const _InfoItem(
              title: 'Amber',
              description:
                  'Use the Amber signer app on Android to manage '
                  'your Nostr keys securely.',
            ),
          ],
        ],
      ),
    );
  }
}

/// Single info item in the info sheet.
class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          description,
          style: const TextStyle(
            fontSize: 14,
            color: VineTheme.secondaryText,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
