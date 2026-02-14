// ABOUTME: Welcome screen with returning-user variant and new-user variant
// ABOUTME: Page/View pattern with WelcomeBloc for state management

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/welcome/welcome_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:models/models.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/auth/auth_hero_section.dart';
import 'package:openvine/widgets/error_message.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Welcome screen — Page that provides [WelcomeBloc] and auth state.
class WelcomeScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'welcome';

  /// Path for this route.
  static const path = '/welcome';

  /// Path for login options route.
  static const loginOptionsPath = '/welcome/login-options';

  /// Path for create account route.
  static const createAccountPath = '/welcome/create-account';

  /// Path for auth native route.
  static const authNativePath = '/welcome/login-options/auth-native';

  /// Path for reset password route.
  static const resetPasswordPath =
      '/welcome/login-options/auth-native/reset-password';

  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(currentAuthStateProvider);
    final authService = ref.watch(authServiceProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final db = ref.watch(databaseProvider);

    final isAuthLoading =
        authState == AuthState.checking ||
        authState == AuthState.authenticating;

    return BlocProvider(
      create: (_) => WelcomeBloc(
        sharedPreferences: prefs,
        userProfilesDao: db.userProfilesDao,
        authService: authService,
      )..add(const WelcomeStarted()),
      child: _WelcomeView(
        isAuthLoading: isAuthLoading,
        lastError: authService.lastError,
      ),
    );
  }
}

/// Welcome screen — View that consumes [WelcomeBloc] state.
class _WelcomeView extends StatelessWidget {
  const _WelcomeView({required this.isAuthLoading, required this.lastError});

  /// Whether the global auth state is in a loading state.
  final bool isAuthLoading;

  /// Auth service error to display, if any.
  final String? lastError;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WelcomeBloc, WelcomeState>(
      listener: (context, state) {
        if (state.status == WelcomeStatus.error && state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: VineTheme.error,
            ),
          );
        }
        if (state.shouldNavigateToLoginOptions ||
            state.shouldNavigateToCreateAccount) {
          if (state.shouldNavigateToLoginOptions) {
            context.push(WelcomeScreen.loginOptionsPath);
          }
          if (state.shouldNavigateToCreateAccount) {
            context.push(WelcomeScreen.createAccountPath);
          }
          context.read<WelcomeBloc>().add(const WelcomeNavigationConsumed());
        }
      },
      builder: (context, state) {
        final isLoading = isAuthLoading || state.isAccepting;

        return Scaffold(
          backgroundColor: VineTheme.backgroundColor,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: state.hasReturningUser
                  ? _ReturningUserLayout(
                      state: state,
                      isLoading: isLoading,
                      lastError: lastError,
                    )
                  : _NewUserLayout(isLoading: isLoading, lastError: lastError),
            ),
          ),
        );
      },
    );
  }
}

/// Default layout for new users — AuthHeroSection with create/login buttons.
class _NewUserLayout extends StatelessWidget {
  const _NewUserLayout({required this.isLoading, required this.lastError});

  final bool isLoading;
  final String? lastError;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(child: Center(child: AuthHeroSection())),

        if (lastError != null) ...[
          ErrorMessage(message: lastError!),
          const SizedBox(height: 16),
        ],

        _PrimaryButton(
          label: 'Create a new Divine account',
          isLoading: isLoading,
          onPressed: () => context.read<WelcomeBloc>().add(
            const WelcomeCreateAccountRequested(),
          ),
        ),

        const SizedBox(height: 12),

        _SecondaryButton(
          label: 'Login with a different account',
          isLoading: isLoading,
          onPressed: () => context.read<WelcomeBloc>().add(
            const WelcomeLoginOptionsRequested(),
          ),
        ),

        const SizedBox(height: 20),

        const _TermsNotice(),

        const SizedBox(height: 32),
      ],
    );
  }
}

/// Returning-user layout with profile info and log back in button.
class _ReturningUserLayout extends StatelessWidget {
  const _ReturningUserLayout({
    required this.state,
    required this.isLoading,
    required this.lastError,
  });

  final WelcomeState state;
  final bool isLoading;
  final String? lastError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // "Welcome back!" title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Welcome back!',
            style: TextStyle(
              fontFamily: 'BricolageGrotesque',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: VineTheme.whiteText,
            ),
          ),
        ),

        // Profile section
        Expanded(
          child: Center(
            child: _ReturningUserProfile(
              pubkeyHex: state.lastUserPubkeyHex!,
              profile: state.lastUserProfile,
            ),
          ),
        ),

        if (lastError != null) ...[
          ErrorMessage(message: lastError!),
          const SizedBox(height: 16),
        ],

        // Log back in button (primary)
        _PrimaryButton(
          label: 'Log back in',
          isLoading: isLoading,
          onPressed: () => context.read<WelcomeBloc>().add(
            const WelcomeLogBackInRequested(),
          ),
        ),

        const SizedBox(height: 12),

        // Login with different account (secondary)
        _SecondaryButton(
          label: 'Login with a different account',
          isLoading: isLoading,
          onPressed: () => context.read<WelcomeBloc>().add(
            const WelcomeLoginOptionsRequested(),
          ),
        ),

        const SizedBox(height: 12),

        // Create new account (tertiary) — shows confirmation bottom sheet
        _SecondaryButton(
          label: 'Create a new Divine account',
          isLoading: isLoading,
          onPressed: () =>
              showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                backgroundColor: VineTheme.surfaceContainer,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => const _NewAccountConfirmationSheet(),
              ).then((confirmed) {
                if (confirmed == true && context.mounted) {
                  context.read<WelcomeBloc>().add(
                    const WelcomeCreateNewAccountRequested(),
                  );
                }
              }),
        ),

        const SizedBox(height: 20),

        const _TermsNotice(),

        const SizedBox(height: 32),
      ],
    );
  }
}

/// Displays the returning user's avatar, display name, and identifier.
class _ReturningUserProfile extends StatelessWidget {
  const _ReturningUserProfile({required this.pubkeyHex, required this.profile});

  final String pubkeyHex;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final displayName =
        profile?.bestDisplayName ?? NostrKeyUtils.truncateNpub(pubkeyHex);
    final identifier =
        profile?.displayNip05 ?? NostrKeyUtils.truncateNpub(pubkeyHex);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(imageUrl: profile?.picture, name: displayName, size: 150),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: VineTheme.whiteText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          identifier,
          style: const TextStyle(fontSize: 14, color: VineTheme.vineGreen),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Primary action button (green filled).
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
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

/// Secondary action button (outlined).
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
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
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Passive terms notice text with clickable links.
class _TermsNotice extends StatefulWidget {
  const _TermsNotice();

  @override
  State<_TermsNotice> createState() => _TermsNoticeState();
}

class _TermsNoticeState extends State<_TermsNotice> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;
  late final TapGestureRecognizer _safetyRecognizer;

  Future<void> _openUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl('https://divine.video/terms');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl('https://divine.video/privacy');
    _safetyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl('https://divine.video/safety');
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _safetyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      color: VineTheme.whiteText,
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
            recognizer: _termsRecognizer,
          ),
          const TextSpan(text: ', '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          const TextSpan(text: ', and '),
          TextSpan(
            text: 'Safety Standards',
            style: linkStyle,
            recognizer: _safetyRecognizer,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

/// Confirmation bottom sheet shown before creating a new account.
class _NewAccountConfirmationSheet extends StatelessWidget {
  const _NewAccountConfirmationSheet();

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 32 + bottomPadding),
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

            // Title
            const Text(
              'Create a new Divine account?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: VineTheme.whiteText,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            const Text(
              'Creating a new account will:',
              style: TextStyle(fontSize: 15, color: VineTheme.secondaryText),
            ),
            const SizedBox(height: 12),

            // Bullet points
            const _BulletPoint('Delete your current keys from this device'),
            const SizedBox(height: 8),
            const _BulletPoint('Generate a completely new Nostr identity'),
            const SizedBox(height: 20),

            // Warning box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VineTheme.error),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: VineTheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'If you start fresh...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: VineTheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You will not be able to access your previous '
                    'account unless you have a backup of your nsec',
                    style: TextStyle(
                      fontSize: 14,
                      color: VineTheme.error,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Confirmation question
            const Text(
              'Are you sure you want to start fresh?',
              style: TextStyle(fontSize: 15, color: VineTheme.secondaryText),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VineTheme.vineGreen,
                      side: const BorderSide(
                        color: VineTheme.outlineMuted,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.vineGreen,
                      foregroundColor: VineTheme.backgroundColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Start fresh',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bullet point text row for the confirmation sheet.
class _BulletPoint extends StatelessWidget {
  const _BulletPoint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '\u2022  ',
          style: TextStyle(fontSize: 15, color: VineTheme.whiteText),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: VineTheme.whiteText,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
