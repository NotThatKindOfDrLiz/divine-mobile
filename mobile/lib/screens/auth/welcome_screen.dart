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

  /// Path for reset password route.
  static const resetPasswordPath = '/welcome/login-options/reset-password';

  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(currentAuthStateProvider);
    final authService = ref.watch(authServiceProvider);
    final db = ref.watch(databaseProvider);

    final isAuthLoading =
        authState == AuthState.checking ||
        authState == AuthState.authenticating;

    return BlocProvider(
      create: (_) => WelcomeBloc(
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
              child: state.hasReturningUsers
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
    final account = state.selectedAccount;
    if (account == null) return const SizedBox.shrink();

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ReturningUserProfile(
                  pubkeyHex: account.pubkeyHex,
                  profile: account.profile,
                  authSource: account.authSource,
                ),

                // Account picker — only shown when multiple accounts exist
                if (state.previousAccounts.length > 1) ...[
                  const SizedBox(height: 16),
                  _AccountPickerChip(
                    accounts: state.previousAccounts,
                    selectedPubkeyHex: account.pubkeyHex,
                  ),
                ],
              ],
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

        // Create new account (tertiary)
        _SecondaryButton(
          label: 'Create a new Divine account',
          isLoading: isLoading,
          onPressed: () => context.read<WelcomeBloc>().add(
            const WelcomeCreateAccountRequested(),
          ),
        ),

        const SizedBox(height: 20),

        const _TermsNotice(),

        const SizedBox(height: 32),
      ],
    );
  }
}

/// Displays the returning user's avatar, display name, identifier, and auth
/// source badge.
class _ReturningUserProfile extends StatelessWidget {
  const _ReturningUserProfile({
    required this.pubkeyHex,
    required this.profile,
    required this.authSource,
  });

  final String pubkeyHex;
  final UserProfile? profile;
  final AuthenticationSource authSource;

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
        const SizedBox(height: 8),
        _AuthSourceBadge(source: authSource),
      ],
    );
  }
}

/// Small badge showing the authentication method used for an identity.
class _AuthSourceBadge extends StatelessWidget {
  const _AuthSourceBadge({required this.source});

  final AuthenticationSource source;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = _iconAndLabel(source);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: VineTheme.secondaryText),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: VineTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  static (IconData, String) _iconAndLabel(AuthenticationSource source) {
    return switch (source) {
      AuthenticationSource.automatic => (Icons.vpn_key_outlined, 'Local keys'),
      AuthenticationSource.importedKeys => (Icons.key, 'Imported keys'),
      AuthenticationSource.divineOAuth => (
        Icons.shield_outlined,
        'Divine account',
      ),
      AuthenticationSource.bunker => (Icons.cloud_outlined, 'NIP-46 Bunker'),
      AuthenticationSource.amber => (Icons.phonelink_lock_outlined, 'Amber'),
      AuthenticationSource.none => (Icons.help_outline, 'Unknown'),
    };
  }
}

/// Tappable chip that opens the account picker bottom sheet.
class _AccountPickerChip extends StatelessWidget {
  const _AccountPickerChip({
    required this.accounts,
    required this.selectedPubkeyHex,
  });

  final List<PreviousAccount> accounts;
  final String selectedPubkeyHex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAccountPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: VineTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VineTheme.outlineMuted),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_horiz, size: 16, color: VineTheme.vineGreen),
            const SizedBox(width: 6),
            Text(
              'Switch account (${accounts.length})',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: VineTheme.vineGreen,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: VineTheme.vineGreen,
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountPicker(BuildContext context) {
    final bloc = context.read<WelcomeBloc>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AccountPickerSheet(
        accounts: accounts,
        selectedPubkeyHex: selectedPubkeyHex,
        bloc: bloc,
      ),
    );
  }
}

/// Bottom sheet listing all known accounts for selection.
class _AccountPickerSheet extends StatelessWidget {
  const _AccountPickerSheet({
    required this.accounts,
    required this.selectedPubkeyHex,
    required this.bloc,
  });

  final List<PreviousAccount> accounts;
  final String selectedPubkeyHex;
  final WelcomeBloc bloc;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: VineTheme.outlineMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Select account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: VineTheme.whiteText,
            ),
          ),
          const SizedBox(height: 16),

          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                return _AccountTile(
                  account: account,
                  isSelected: account.pubkeyHex == selectedPubkeyHex,
                  onTap: () {
                    bloc.add(
                      WelcomeAccountSelected(pubkeyHex: account.pubkeyHex),
                    );
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Single account row in the picker sheet.
class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isSelected,
    required this.onTap,
  });

  final PreviousAccount account;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName =
        account.profile?.bestDisplayName ??
        NostrKeyUtils.truncateNpub(account.pubkeyHex);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? VineTheme.vineGreen.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: account.profile?.picture,
              name: displayName,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: VineTheme.whiteText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  _AuthSourceBadge(source: account.authSource),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                size: 20,
                color: VineTheme.vineGreen,
              ),
          ],
        ),
      ),
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
