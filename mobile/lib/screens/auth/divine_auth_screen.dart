// ABOUTME: Native email/password authentication screen for diVine
// ABOUTME: Handles both login and registration with email verification flow

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/divine_auth/divine_auth_cubit.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/widgets/auth/auth_error_box.dart';
import 'package:openvine/widgets/auth/auth_password_field.dart';
import 'package:openvine/widgets/auth/auth_text_field.dart';
import 'package:openvine/widgets/auth/forgot_password_dialog.dart';

class DivineAuthScreen extends ConsumerWidget {
  /// Route name for the auth screen
  static const String routeName = 'auth-native';

  /// Path for the auth screen
  static const String path = '/auth-native';

  /// Initial mode - true for sign in, false for sign up
  final bool initialSignIn;

  /// Initial email to pre-populate (preserved when toggling modes)
  final String? initialEmail;

  const DivineAuthScreen({
    super.key,
    this.initialSignIn = false,
    this.initialEmail,
  });

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
      )..initialize(isSignIn: initialSignIn, initialEmail: initialEmail),
      child: const _DivineAuthScreenView(),
    );
  }
}

class _DivineAuthScreenView extends StatelessWidget {
  const _DivineAuthScreenView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<DivineAuthCubit, DivineAuthState>(
      listenWhen: (prev, next) =>
          next is DivineAuthEmailVerification || next is DivineAuthSuccess,
      listener: (context, state) {
        if (state is DivineAuthEmailVerification) {
          // Navigate to email verification screen
          final encodedEmail = Uri.encodeComponent(state.email);
          context.go(
            '${EmailVerificationScreen.path}'
            '?deviceCode=${state.deviceCode}'
            '&verifier=${state.verifier}'
            '&email=$encodedEmail',
          );
        } else if (state is DivineAuthSuccess) {
          // Navigation will be handled by auth state listener in router
        }
      },
      child: Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: SafeArea(
          child: BlocBuilder<DivineAuthCubit, DivineAuthState>(
            builder: (context, state) {
              if (state is DivineAuthFormState) {
                return _AuthForm(state: state);
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

class _AuthForm extends StatefulWidget {
  const _AuthForm({required this.state});

  final DivineAuthFormState state;

  @override
  State<_AuthForm> createState() => _DivineAuthFormState();
}

class _DivineAuthFormState extends State<_AuthForm> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.state.email);
    _passwordController = TextEditingController(text: widget.state.password);
  }

  @override
  void didUpdateWidget(covariant _AuthForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers if state changed from outside (e.g., mode toggle)
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

  @override
  Widget build(BuildContext context) {
    final isSignIn = widget.state.isSignIn;
    final isSubmitting = widget.state.isSubmitting;
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: VineTheme.whiteText,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  isSignIn ? 'Sign in' : 'Welcome to diVine!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: VineTheme.primaryText,
                  ),
                ),

                // Subtitle (sign-up only)
                if (!isSignIn) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Unlike other social apps, you can use diVine '
                    'without an email or password. Add them now or '
                    'later to recover your account on any device.',
                    style: TextStyle(
                      fontSize: 15,
                      color: VineTheme.secondaryText,
                      height: 1.4,
                    ),
                  ),
                ],

                SizedBox(height: isSignIn ? 48 : 40),

                // Email field
                AuthTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  errorText: widget.state.emailError,
                  onChanged: (value) =>
                      context.read<DivineAuthCubit>().updateEmail(value),
                  enabled: !isSubmitting,
                ),

                const SizedBox(height: 16),

                // Password field
                AuthPasswordField(
                  controller: _passwordController,
                  hintText: 'Password',
                  errorText: widget.state.passwordError,
                  onChanged: (value) =>
                      context.read<DivineAuthCubit>().updatePassword(value),
                  enabled: !isSubmitting,
                ),

                const SizedBox(height: 8),

                // General error message
                if (widget.state.generalError != null) ...[
                  const SizedBox(height: 8),
                  AuthErrorBox(message: widget.state.generalError!),
                ],

                // Spacer pushes buttons toward bottom
                const Spacer(),

                // Submit button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () => context.read<DivineAuthCubit>().submit(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.vineGreen,
                      foregroundColor: VineTheme.whiteText,
                      disabledBackgroundColor: VineTheme.vineGreen.withValues(
                        alpha: 0.7,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: VineTheme.whiteText,
                            ),
                          )
                        : Text(
                            isSignIn ? 'Sign in' : 'Set email & password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isSignIn
                                  ? null
                                  : VineTheme.backgroundColor,
                            ),
                          ),
                  ),
                ),
                // Sign up specific: Skip button (outlined green)
                if (!isSignIn) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: isSubmitting
                          ? null
                          : () => context.read<DivineAuthCubit>().skipSignUp(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VineTheme.vineGreen,
                        side: const BorderSide(color: VineTheme.vineGreen),
                        disabledForegroundColor: VineTheme.vineGreen.withValues(
                          alpha: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],

                // Sign in specific: Forgot password
                if (isSignIn) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => _showForgotPasswordDialog(context),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: VineTheme.lightText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Import Nostr key button
                  OutlinedButton(
                    onPressed: isSubmitting
                        ? null
                        : () => _importNostrKey(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VineTheme.whiteText,
                      side: const BorderSide(color: VineTheme.lightText),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Import Nostr key',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Toggle mode link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isSignIn
                          ? "Don't have an account? "
                          : 'Already on diVine or Nostr? ',
                      style: const TextStyle(
                        color: VineTheme.lightText,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: isSubmitting ? null : () => _toggleMode(context),
                      child: Text(
                        isSignIn ? 'Sign up' : 'Sign in',
                        style: const TextStyle(
                          color: VineTheme.vineGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: VineTheme.vineGreen,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
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

  void _toggleMode(BuildContext context) {
    // Navigate to the opposite mode, preserving email
    final newSignIn = !widget.state.isSignIn;
    final email = _emailController.text.trim();

    // Build URL with query params
    var url = '${WelcomeScreen.authNativePath}?signIn=$newSignIn';
    if (email.isNotEmpty) {
      url += '&email=${Uri.encodeComponent(email)}';
    }

    context.go(url);
  }

  void _importNostrKey(BuildContext context) {
    context.push(KeyImportScreen.path);
  }
}
