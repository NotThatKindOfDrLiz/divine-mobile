// ABOUTME: Screen for npub verification during invite skip flow
// ABOUTME: Shows loading state while verifying, handles success/failure

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/npub_verification/npub_verification_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/waitlist_screen.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Screen shown during npub verification for users who signed in
/// without an invite code.
///
/// This screen:
/// - Shows a loading indicator while verifying the npub
/// - On success: BLoC state triggers router redirect via AppStateListenable
/// - On failure: signs out (preserving keys) and navigates to WaitlistScreen
class NpubVerificationScreen extends ConsumerStatefulWidget {
  const NpubVerificationScreen({super.key});

  /// Route name for this screen.
  static const String routeName = 'npub-verification';

  /// Path for this route.
  static const String path = '/npub-verification';

  @override
  ConsumerState<NpubVerificationScreen> createState() =>
      _NpubVerificationScreenState();
}

class _NpubVerificationScreenState
    extends ConsumerState<NpubVerificationScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Start verification after first frame to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifyNpub();
    });
  }

  void _verifyNpub() {
    final authService = ref.read(authServiceProvider);
    final npub = authService.currentNpub;

    if (npub == null) {
      Log.warning(
        'No npub available for verification',
        name: 'NpubVerificationScreen',
        category: LogCategory.auth,
      );
      _handleVerificationFailure('No account found to verify.');
      return;
    }

    // Dispatch verification request - BlocListener handles the result
    context.read<NpubVerificationBloc>().add(NpubVerificationRequested(npub));
  }

  /// Handle BLoC state changes for npub verification.
  void _onVerificationStateChanged(
    BuildContext context,
    NpubVerificationState state,
  ) {
    // Handle success - router will redirect via AppStateListenable
    if (state.isVerified) {
      Log.info(
        'Npub verification successful, router will redirect',
        name: 'NpubVerificationScreen',
        category: LogCategory.auth,
      );
      // AppStateListenable is listening to the BLoC and will notify
      // the router to re-evaluate redirects
      return;
    }

    // Handle failure
    if (state.isFailed) {
      _handleVerificationFailure(state.error);
    }
  }

  Future<void> _handleVerificationFailure(String? message) async {
    Log.warning(
      'Npub verification failed: $message',
      name: 'NpubVerificationScreen',
      category: LogCategory.auth,
    );

    final authService = ref.read(authServiceProvider);

    // Sign out but preserve keys so the user can retry or use an invite code
    await authService.signOut();

    // Clear skip invite flag so user goes back to invite screen flow
    if (mounted) {
      context.read<NpubVerificationBloc>().add(
        const NpubVerificationSkipInviteCleared(),
      );
    }

    if (!mounted) return;

    // Navigate to waitlist screen
    context.go(
      WaitlistScreen.path,
      extra: WaitlistScreenArgs(
        message: message ?? 'Divine is currently in private beta.',
      ),
    );
  }

  void _retry() {
    setState(() => _errorMessage = null);
    _verifyNpub();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NpubVerificationBloc, NpubVerificationState>(
      listener: _onVerificationStateChanged,
      child: BlocBuilder<NpubVerificationBloc, NpubVerificationState>(
        builder: (context, state) {
          final isVerifying = state.isVerifying;
          final errorMessage = _errorMessage ?? state.error;
          final showError = state.isFailed || _errorMessage != null;

          return Scaffold(
            backgroundColor: VineTheme.backgroundColor,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Image.asset(
                        'assets/icon/divine_icon_transparent.png',
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 32),

                      if (isVerifying) ...[
                        const CircularProgressIndicator(
                          color: VineTheme.vineGreen,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Verifying your account...',
                          style: VineTheme.headlineSmallFont(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please wait while we verify your identity',
                          style: VineTheme.bodyMediumFont(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ] else if (showError) ...[
                        Icon(
                          Icons.error_outline,
                          color: VineTheme.error,
                          size: 48,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Verification Failed',
                          style: VineTheme.headlineSmallFont(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          errorMessage ?? 'An error occurred',
                          style: VineTheme.bodyMediumFont(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _retry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VineTheme.vineGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Try Again',
                            style: VineTheme.labelLargeFont(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
