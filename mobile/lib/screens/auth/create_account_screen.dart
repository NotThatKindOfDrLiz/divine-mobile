// ABOUTME: Create account screen with email/password registration form
// ABOUTME: Provides DivineAuthCubit in sign-up mode

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/divine_auth/divine_auth_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/auth/auth_error_box.dart';
import 'package:openvine/widgets/auth/auth_form_scaffold.dart';
import 'package:openvine/widgets/auth/auth_password_field.dart';
import 'package:openvine/widgets/auth/auth_text_field.dart';

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
      child: BlocBuilder<DivineAuthCubit, DivineAuthState>(
        builder: (context, state) {
          if (state is DivineAuthFormState) {
            return _CreateAccountBody(state: state, authService: authService);
          }
          return const Scaffold(
            backgroundColor: VineTheme.backgroundColor,
            body: Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
          );
        },
      ),
    );
  }
}

/// Body of the create account form with email and password.
class _CreateAccountBody extends StatefulWidget {
  const _CreateAccountBody({required this.state, required this.authService});

  final DivineAuthFormState state;
  final AuthService authService;

  @override
  State<_CreateAccountBody> createState() => _CreateAccountBodyState();
}

class _CreateAccountBodyState extends State<_CreateAccountBody> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
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
    super.dispose();
  }

  void _submit() {
    context.read<DivineAuthCubit>().submit();
  }

  Future<void> _skip() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VineTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SkipConfirmationSheet(),
    );

    if (confirmed != true || !mounted) return;

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

    return AuthFormScaffold(
      title: 'Create account',
      onBack: isDisabled ? null : () => context.pop(),
      emailField: AuthTextField(
        controller: _emailController,
        hintText: 'Email',
        keyboardType: TextInputType.emailAddress,
        errorText: widget.state.emailError,
        enabled: !isDisabled,
        onChanged: (value) =>
            context.read<DivineAuthCubit>().updateEmail(value),
      ),
      passwordField: AuthPasswordField(
        controller: _passwordController,
        errorText: widget.state.passwordError,
        enabled: !isDisabled,
        onChanged: (value) =>
            context.read<DivineAuthCubit>().updatePassword(value),
      ),
      errorWidget: widget.state.generalError != null
          ? AuthErrorBox(message: widget.state.generalError!)
          : null,
      primaryButton: _CreateAccountButton(
        isSubmitting: isSubmitting,
        isDisabled: isDisabled,
        onPressed: _submit,
      ),
      secondaryButton: _SkipButton(
        isSkipping: _isSkipping,
        isDisabled: isDisabled,
        onPressed: _skip,
      ),
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

/// Bottom sheet asking the user to confirm skipping email/password setup.
class _SkipConfirmationSheet extends StatelessWidget {
  const _SkipConfirmationSheet();

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
          const SizedBox(height: 32),

          Center(
            child: Image.asset(
              'assets/stickers/pause.png',
              width: 132,
              height: 132,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          const Center(
            child: Text(
              'One last thing...',
              style: TextStyle(
                fontFamily: 'BricolageGrotesque',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: VineTheme.whiteText,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          const Text(
            "You're in! We'll create a secure key that powers "
            'your Divine account.',
            style: TextStyle(
              fontSize: 16,
              color: VineTheme.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Without an email, your key is the only way '
            'Divine knows this account is yours.',
            style: TextStyle(
              fontSize: 16,
              color: VineTheme.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "You can access your key in the app, but, if "
            "you're not technical we recommend adding an "
            'email and password now. It makes it easier to '
            'login and restore your account if you lose or '
            'reset this device.',
            style: TextStyle(
              fontSize: 16,
              color: VineTheme.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Add email & password button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, false),
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.backgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Add email & password',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Use this device only button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: VineTheme.secondaryText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Use this device only',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
