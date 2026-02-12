// ABOUTME: Create account screen with email/password registration form
// ABOUTME: Provides DivineAuthCubit in sign-up mode with confirm password

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/divine_auth/divine_auth_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/auth_back_button.dart';

/// Create account screen — Page that provides [DivineAuthCubit] in sign-up
/// mode.
class CreateAccountScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const String routeName = 'create-account';

  /// Route path for this screen (relative, under /welcome).
  static const String path = '/create-account';

  const CreateAccountScreen({super.key});

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
      )..initialize(isSignIn: false),
      child: _CreateAccountView(authService: authService),
    );
  }
}

/// Create account screen — View that consumes [DivineAuthCubit] state.
class _CreateAccountView extends StatelessWidget {
  const _CreateAccountView({required this.authService});

  final AuthService authService;

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
                return _CreateAccountBody(
                  state: state,
                  authService: authService,
                );
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

/// Body of the create account form with email, password, and confirm password.
class _CreateAccountBody extends ConsumerStatefulWidget {
  const _CreateAccountBody({required this.state, required this.authService});

  final DivineAuthFormState state;
  final AuthService authService;

  @override
  ConsumerState<_CreateAccountBody> createState() => _CreateAccountBodyState();
}

class _CreateAccountBodyState extends ConsumerState<_CreateAccountBody> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  final _confirmPasswordController = TextEditingController();
  String? _confirmPasswordError;
  bool _isSkipping = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.state.email);
    _passwordController = TextEditingController(text: widget.state.password);
  }

  @override
  void didUpdateWidget(covariant _CreateAccountBody oldWidget) {
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
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    // Validate confirm password matches
    if (_confirmPasswordController.text != _passwordController.text) {
      setState(() {
        _confirmPasswordError = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _confirmPasswordError = null;
    });

    context.read<DivineAuthCubit>().submit();
  }

  Future<void> _skip() async {
    setState(() => _isSkipping = true);

    try {
      await widget.authService.signInAutomatically();
    } catch (_) {
      if (mounted) {
        setState(() => _isSkipping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = widget.state.isSubmitting;
    final isDisabled = isSubmitting || _isSkipping;

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

                // Back button
                AuthBackButton(
                  onPressed: isDisabled ? null : () => context.pop(),
                ),

                const SizedBox(height: 32),

                // Title
                const Text(
                  'Create account',
                  style: TextStyle(
                    fontFamily: 'BricolageGrotesque',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: VineTheme.whiteText,
                  ),
                ),

                const SizedBox(height: 32),

                // Email field
                _AccountTextField(
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
                _AccountTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  obscureText: true,
                  errorText: widget.state.passwordError,
                  enabled: !isDisabled,
                  onChanged: (value) =>
                      context.read<DivineAuthCubit>().updatePassword(value),
                ),

                const SizedBox(height: 16),

                // Confirm password field with dog sticker
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _AccountTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirm password',
                      obscureText: true,
                      errorText: _confirmPasswordError,
                      enabled: !isDisabled,
                      onChanged: (_) {
                        if (_confirmPasswordError != null) {
                          setState(() => _confirmPasswordError = null);
                        }
                      },
                    ),
                    Positioned(
                      right: -20,
                      bottom: -160,
                      child: Transform.rotate(
                        angle: 12 * 3.1415926535 / 180,
                        child: Image.asset(
                          'assets/stickers/samoyed_dog.png',
                          width: 140,
                          height: 140,
                        ),
                      ),
                    ),
                  ],
                ),

                // Error display
                if (widget.state.generalError != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBox(message: widget.state.generalError!),
                ],

                // Push buttons to bottom
                const Spacer(),

                // Create account button
                _CreateAccountButton(
                  isSubmitting: isSubmitting,
                  isDisabled: isDisabled,
                  onPressed: _submit,
                ),

                const SizedBox(height: 12),

                // Skip button
                _SkipButton(
                  isSkipping: _isSkipping,
                  isDisabled: isDisabled,
                  onPressed: _skip,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Styled text field for the create account form.
class _AccountTextField extends StatelessWidget {
  const _AccountTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.errorText,
    this.enabled = true,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          autocorrect: false,
          style: const TextStyle(color: VineTheme.primaryText, fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: VineTheme.lightText),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: VineTheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: VineTheme.error, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: VineTheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
          onChanged: onChanged,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: TextStyle(color: VineTheme.error, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// Green filled create account button.
class _CreateAccountButton extends StatelessWidget {
  const _CreateAccountButton({
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
                'Create account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

/// Skip button for users who want anonymous keys.
class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.isSkipping,
    required this.isDisabled,
    required this.onPressed,
  });

  final bool isSkipping;
  final bool isDisabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: isDisabled ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: VineTheme.secondaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: isSkipping
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  color: VineTheme.secondaryText,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Skip for now',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
      ),
    );
  }
}

/// Error message box for form validation errors.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VineTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VineTheme.error),
      ),
      child: Text(
        message,
        style: TextStyle(color: VineTheme.error, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}
