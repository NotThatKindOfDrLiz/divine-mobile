// ABOUTME: Screen to handle email verification via polling or token
// ABOUTME: Supports polling mode (after registration) and token mode (from deep link)
// ABOUTME: Supports auto-login on cold start via persisted verification data

import 'dart:async';
import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/auth_back_button.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  /// Route name for navigation
  static const String routeName = 'verify-email';

  /// Path for navigation
  static const String path = '/verify-email';

  const EmailVerificationScreen({
    super.key,
    this.token,
    this.deviceCode,
    this.verifier,
    this.email,
  });

  /// Token from deep link (token mode)
  final String? token;

  /// Device code from registration (polling mode)
  final String? deviceCode;

  /// PKCE verifier from registration (polling mode)
  final String? verifier;

  /// User's email address (polling mode)
  final String? email;

  /// Check if this is polling mode
  bool get isPollingMode =>
      deviceCode != null && deviceCode!.isNotEmpty && verifier != null;

  /// Check if this is token mode
  bool get isTokenMode => token != null && token!.isNotEmpty;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _isTokenMode = false;
  StreamSubscription<AuthState>? _authSubscription;

  /// Get the app-level cubit provided in main.dart
  EmailVerificationCubit get _cubit => context.read<EmailVerificationCubit>();

  @override
  void initState() {
    super.initState();

    // Use post-frame callback to access context safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVerification();
      _listenForAuthState();
    });
  }

  /// Listen for auth state changes and navigate away when authenticated.
  ///
  /// GoRouter's `refreshListenable` redirect is unreliable for navigating
  /// away from this screen after sign-in completes. This listener provides
  /// an explicit, reliable navigation path.
  void _listenForAuthState() {
    final authService = ref.read(authServiceProvider);
    _authSubscription = authService.authStateStream.listen((authState) {
      if (authState == AuthState.authenticated && mounted) {
        Log.info(
          'Auth state became authenticated, navigating to explore '
          '(cubit=${_cubit.hashCode})',
          name: 'EmailVerificationScreen',
          category: LogCategory.auth,
        );
        _cubit.stopPolling();
        ref.read(pendingVerificationServiceProvider).clear();
        ref.read(forceExploreTabNameProvider.notifier).state = 'popular';
        context.go(ExploreScreen.path);
      }
    });
  }

  void _initializeVerification() {
    // Start the appropriate verification mode
    if (widget.isPollingMode) {
      Log.info(
        'Starting polling mode verification (cubit=${_cubit.hashCode})',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      _cubit.startPolling(
        deviceCode: widget.deviceCode!,
        verifier: widget.verifier!,
        email: widget.email ?? '',
      );
    } else if (widget.isTokenMode) {
      // Token mode - check for persisted verification data for auto-login
      _isTokenMode = true;
      _initTokenModeWithPersistenceCheck();
    } else {
      Log.warning(
        'EmailVerificationScreen opened without token or deviceCode',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
    }
  }

  /// Initialize token mode, checking for persisted data for auto-login.
  ///
  /// If persisted verification data exists (from a previous registration),
  /// we can verify the email and then complete the OAuth flow automatically
  /// instead of requiring the user to log in manually.
  Future<void> _initTokenModeWithPersistenceCheck() async {
    final pendingService = ref.read(pendingVerificationServiceProvider);
    final pending = await pendingService.load();

    if (pending != null) {
      Log.info(
        'Found persisted verification data for ${pending.email}, '
        'attempting auto-login flow',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );

      // Verify the email first via OAuth client, then start polling to
      // complete login
      final oauth = ref.read(oauthClientProvider);
      try {
        await oauth.verifyEmail(token: widget.token!);
      } catch (e) {
        Log.error(
          'Email verification error: $e',
          name: 'EmailVerificationScreen',
          category: LogCategory.auth,
        );
      }

      _cubit.startPolling(
        deviceCode: pending.deviceCode,
        verifier: pending.verifier,
        email: pending.email,
      );
    } else {
      Log.info(
        'No persisted verification data, using standard token mode',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      _verifyWithToken(widget.token!);
    }
  }

  /// Verify email with token (standalone token mode without polling)
  Future<void> _verifyWithToken(String token) async {
    Log.info(
      'Verifying email with token',
      name: 'EmailVerificationScreen',
      category: LogCategory.auth,
    );

    final oauth = ref.read(oauthClientProvider);
    try {
      final result = await oauth.verifyEmail(token: token);
      if (result.success) {
        Log.info(
          'Email verification successful (token mode)',
          name: 'EmailVerificationScreen',
          category: LogCategory.auth,
        );
        // In token mode without polling, redirect to login
        _handleTokenModeSuccess();
      } else {
        Log.warning(
          'Email verification failed: ${result.error}',
          name: 'EmailVerificationScreen',
          category: LogCategory.auth,
        );
        _cubit.emitFailure(
          result.error ?? 'This verification link is no longer valid.',
        );
      }
    } catch (e) {
      Log.error(
        'Email verification error: $e',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      _cubit.emitFailure(
        'Unable to verify email. Please check your connection and try again.',
      );
    }
  }

  @override
  void didUpdateWidget(EmailVerificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If we receive a token via deep link while polling, verify it
    // This marks the email as verified on the server, allowing the poll to
    // complete
    if (widget.isTokenMode && !oldWidget.isTokenMode) {
      Log.info(
        'Token received via deep link, calling verifyEmail',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      final oauth = ref.read(oauthClientProvider);
      oauth.verifyEmail(token: widget.token!);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    // Stop polling when the screen is disposed (e.g., router redirect after
    // auth). The cubit is app-level so we don't close() it, but we must stop
    // its timers to prevent zombie polling.
    _cubit.stopPolling();
    super.dispose();
  }

  void _handleSuccess() {
    // Clear persisted verification data on successful login
    ref.read(pendingVerificationServiceProvider).clear();

    if (!_isTokenMode) {
      // Polling mode: navigate to explore screen (Popular tab) after
      // verification
      Log.info(
        'Email verification succeeded, navigating to explore (Popular tab)',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      // Set tab by NAME (not index) because indices shift when
      // Classics/ForYou tabs become available asynchronously
      ref.read(forceExploreTabNameProvider.notifier).state = 'popular';
    } else {
      // Token mode: redirect to login screen
      _handleTokenModeSuccess();
    }
  }

  void _handleTokenModeSuccess() {
    // Clear persisted verification data
    ref.read(pendingVerificationServiceProvider).clear();
    // Show feedback message before redirecting to login
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email verified! Please log in to continue.'),
        backgroundColor: VineTheme.vineGreen,
        duration: Duration(seconds: 3),
      ),
    );
    // Redirect to login screen
    context.go(WelcomeScreen.authNativePath);
  }

  void _handleCancel() {
    _cubit.stopPolling();
    // Don't clear pending verification data - user may still verify via email
    // link later. Data will be cleared on: successful login, logout, or
    // expiration (30 minutes).
    // Go back to previous screen (registration form)
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _handleGoBack() {
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: BlocConsumer<EmailVerificationCubit, EmailVerificationState>(
          listener: (context, state) {
            if (state.status == EmailVerificationStatus.success) {
              _handleSuccess();
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AuthBackButton(onPressed: _handleCancel),
                  ),
                ),

                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: switch (state.status) {
                      EmailVerificationStatus.initial => _PollingContent(
                        email: null,
                        isPollingMode: widget.isPollingMode || !_isTokenMode,
                        onCancel: _handleCancel,
                      ),
                      EmailVerificationStatus.polling => _PollingContent(
                        email: state.pendingEmail,
                        isPollingMode: widget.isPollingMode || !_isTokenMode,
                        onCancel: _handleCancel,
                      ),
                      EmailVerificationStatus.success =>
                        const _SuccessContent(),
                      EmailVerificationStatus.failure => _ErrorContent(
                        errorMessage: state.error ?? 'Verification failed',
                        onGoBack: _handleGoBack,
                      ),
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Polling/loading content shown while waiting for email verification.
class _PollingContent extends StatelessWidget {
  const _PollingContent({
    required this.email,
    required this.isPollingMode,
    required this.onCancel,
  });

  final String? email;
  final bool isPollingMode;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),

        // Email sticker
        Transform.rotate(
          angle: -8 * pi / 180,
          child: Image.asset(
            'assets/stickers/email.png',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 32),

        // Title
        Text(
          isPollingMode ? 'Verify your email' : 'Verifying...',
          style: const TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: VineTheme.whiteText,
          ),
        ),
        const SizedBox(height: 12),

        if (isPollingMode && email != null && email!.isNotEmpty) ...[
          Text(
            'We sent a verification link to:',
            style: TextStyle(
              fontSize: 16,
              color: VineTheme.secondaryText,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            email!,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: VineTheme.whiteText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Click the link in your email to complete registration.',
            style: TextStyle(
              fontSize: 14,
              color: VineTheme.secondaryText,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          Text(
            'Please wait while we verify your email...',
            style: TextStyle(
              fontSize: 16,
              color: VineTheme.secondaryText,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 32),

        // Spinner row
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: VineTheme.vineGreen,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Waiting for verification...',
              style: TextStyle(color: VineTheme.lightText, fontSize: 14),
            ),
          ],
        ),

        const Spacer(),

        // Cancel button at bottom
        if (isPollingMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: VineTheme.secondaryText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Success content shown briefly when email is verified.
class _SuccessContent extends StatelessWidget {
  const _SuccessContent();

  @override
  Widget build(BuildContext context) {
    // Navigation happens automatically via BlocConsumer listener
    // This UI is shown briefly during the transition
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_outline, color: VineTheme.vineGreen, size: 80),
        const SizedBox(height: 24),
        const Text(
          'Email Verified!',
          style: TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: VineTheme.whiteText,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Signing you in...',
          style: TextStyle(
            fontSize: 16,
            color: VineTheme.secondaryText,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Error content shown when verification fails.
class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.errorMessage, required this.onGoBack});

  final String errorMessage;
  final VoidCallback onGoBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),

        Icon(Icons.error_outline, color: VineTheme.error, size: 80),
        const SizedBox(height: 24),
        const Text(
          'Verification Failed',
          style: TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: VineTheme.whiteText,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          errorMessage,
          style: TextStyle(
            fontSize: 16,
            color: VineTheme.secondaryText,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),

        const Spacer(),

        // Go back button at bottom
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onGoBack,
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.backgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Go Back',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
