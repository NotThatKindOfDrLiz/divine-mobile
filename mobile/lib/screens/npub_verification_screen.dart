// ABOUTME: Screen for npub verification during invite skip flow
// ABOUTME: Shows loading state while verifying, handles success/failure

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/npub_verification_provider.dart';
import 'package:openvine/screens/waitlist_screen.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Screen shown during npub verification for users who signed in
/// without an invite code.
///
/// This screen:
/// - Shows a loading indicator while verifying the npub
/// - On success: invalidates providers to trigger router redirect
/// - On failure: signs out and navigates to WaitlistScreen
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
  bool _isVerifying = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Start verification after first frame to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifyNpub();
    });
  }

  Future<void> _verifyNpub() async {
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

    final verificationService = ref.read(npubVerificationServiceProvider);

    try {
      final result = await verificationService.verifyNpub(npub);

      if (!mounted) return;

      if (result.valid) {
        Log.info(
          'Npub verification successful, router will redirect',
          name: 'NpubVerificationScreen',
          category: LogCategory.auth,
        );
        // Clear skip invite flag now that verification succeeded
        ref.read(skipInviteRequestedProvider.notifier).clear();
        // Invalidate providers to trigger redirect re-evaluation
        ref.invalidate(isNpubVerifiedProvider);
        ref.invalidate(needsNpubVerificationProvider);
        // Router redirect will handle navigation to home/TOS
        return;
      }

      // Verification failed
      await _handleVerificationFailure(result.message);
    } catch (e) {
      if (!mounted) return;

      Log.error(
        'Npub verification error: $e',
        name: 'NpubVerificationScreen',
        category: LogCategory.auth,
      );

      setState(() {
        _isVerifying = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _handleVerificationFailure(String? message) async {
    Log.warning(
      'Npub verification failed: $message',
      name: 'NpubVerificationScreen',
      category: LogCategory.auth,
    );

    final authService = ref.read(authServiceProvider);

    // Sign out and delete keys to prevent bypass
    await authService.signOut(deleteKeys: true);

    // Clear skip invite flag so user goes back to invite screen flow
    ref.read(skipInviteRequestedProvider.notifier).clear();

    if (!mounted) return;

    // Navigate to waitlist screen
    context.go(
      WaitlistScreen.path,
      extra: WaitlistScreenArgs(
        message: message ??
            'Your account is not yet verified. Please enter an invite code.',
      ),
    );
  }

  Future<void> _retry() async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });
    await _verifyNpub();
  }

  @override
  Widget build(BuildContext context) {
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

                if (_isVerifying) ...[
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
                ] else if (_errorMessage != null) ...[
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
                    _errorMessage!,
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
                    child: Text('Try Again', style: VineTheme.labelLargeFont()),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
