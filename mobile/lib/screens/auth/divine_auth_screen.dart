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
import 'package:openvine/screens/welcome_screen.dart';
import 'package:openvine/utils/validators.dart';

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
        backgroundColor: Colors.black,
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

    return SingleChildScrollView(
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
                icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 48),

            // Email field
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              errorText: widget.state.emailError,
              onChanged: (value) =>
                  context.read<DivineAuthCubit>().updateEmail(value),
              enabled: !isSubmitting,
            ),

            const SizedBox(height: 16),

            // Password field
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              obscureText: widget.state.obscurePassword,
              errorText: widget.state.passwordError,
              onChanged: (value) =>
                  context.read<DivineAuthCubit>().updatePassword(value),
              enabled: !isSubmitting,
              suffixIcon: IconButton(
                icon: Icon(
                  widget.state.obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () =>
                    context.read<DivineAuthCubit>().togglePasswordVisibility(),
              ),
            ),

            const SizedBox(height: 8),

            // General error message
            if (widget.state.generalError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VineTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VineTheme.error),
                ),
                child: Text(
                  widget.state.generalError!,
                  style: const TextStyle(color: VineTheme.error, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () => context.read<DivineAuthCubit>().submit(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  foregroundColor: Colors.white,
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
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isSignIn ? 'Sign in' : 'Set email & password',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            // Sign up specific: Skip button
            if (!isSignIn) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => context.read<DivineAuthCubit>().skipSignUp(),
                child: const Text(
                  'Skip for now',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
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
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              // Import Nostr key button
              OutlinedButton(
                onPressed: isSubmitting ? null : () => _importNostrKey(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.grey),
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
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                GestureDetector(
                  onTap: isSubmitting ? null : () => _toggleMode(context),
                  child: Text(
                    isSignIn ? 'Sign up' : 'Sign in',
                    style: const TextStyle(
                      color: VineTheme.vineGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? errorText,
    required ValueChanged<String> onChanged,
    bool enabled = true,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          autocorrect: false,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.grey),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: errorText != null ? VineTheme.error : Colors.grey,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: errorText != null
                    ? VineTheme.error
                    : VineTheme.vineGreen,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: VineTheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: VineTheme.error, width: 2),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.black,
          ),
          onChanged: onChanged,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText,
            style: const TextStyle(color: VineTheme.error, fontSize: 12),
          ),
        ],
      ],
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final resetEmailController = TextEditingController(
      text: _emailController.text,
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Reset Password',
          style: TextStyle(color: Colors.white),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Enter your email address and we'll send you a link to "
                  'reset your password.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.email_outlined),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: VineTheme.vineGreen,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: Validators.validateEmail,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: VineTheme.onSurfaceMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final email = resetEmailController.text.trim();
                dialogContext.pop();
                await context.read<DivineAuthCubit>().sendPasswordResetEmail(
                  email,
                );
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
              }
            },
            child: const Text('Email Reset Link'),
          ),
        ],
      ),
    );
  }

  void _toggleMode(BuildContext context) {
    // Navigate to the opposite mode, preserving email
    final newSignIn = !widget.state.isSignIn;
    final email = _emailController.text.trim();

    // Build URL with query params
    var url = '${WelcomeScreen.path}${DivineAuthScreen.path}?signIn=$newSignIn';
    if (email.isNotEmpty) {
      url += '&email=${Uri.encodeComponent(email)}';
    }

    context.go(url);
  }

  void _importNostrKey(BuildContext context) {
    context.push(KeyImportScreen.path);
  }
}
