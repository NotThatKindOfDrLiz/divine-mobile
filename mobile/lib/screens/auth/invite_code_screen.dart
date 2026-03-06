// ABOUTME: Invite code flow — terms acceptance, code entry, and success screens
// ABOUTME: Three-step gate: accept terms → enter invite code → proceed to signup

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/invite_code/invite_code_bloc.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/invite_code_repository.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/invite_code_service.dart';
import 'package:openvine/widgets/auth/auth_hero_section.dart';
import 'package:openvine/widgets/divine_primary_button.dart';
import 'package:openvine/widgets/rounded_icon_button.dart';
import 'package:url_launcher/url_launcher.dart';

/// Invite code flow screen — three steps:
/// 1. Terms acceptance (age + legal)
/// 2. Invite code entry
/// 3. Success — proceed to account creation
class InviteCodeScreen extends ConsumerWidget {
  static const routeName = 'invite-code';
  static const path = '/invite-code';
  static const fullPath = '/invite-code';

  const InviteCodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPreferencesProvider);

    return BlocProvider(
      create: (_) => InviteCodeBloc(
        inviteCodeService: InviteCodeService(),
        repository: InviteCodeRepository(prefs: prefs),
      ),
      child: const _InviteCodeFlow(),
    );
  }
}

/// Manages the three-step flow via local state + BLoC state.
class _InviteCodeFlow extends StatefulWidget {
  const _InviteCodeFlow();

  @override
  State<_InviteCodeFlow> createState() => _InviteCodeFlowState();
}

class _InviteCodeFlowState extends State<_InviteCodeFlow> {
  bool _termsAccepted = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InviteCodeBloc, InviteCodeState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: VineTheme.backgroundColor,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildCurrentStep(state),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentStep(InviteCodeState state) {
    // Step 3: Success
    if (state.status == InviteCodeStatus.success) {
      return const _SuccessView();
    }
    // Step 2: Code entry (after terms accepted)
    if (_termsAccepted) {
      return _CodeEntryView(
        onBack: () => setState(() => _termsAccepted = false),
      );
    }
    // Step 1: Terms acceptance
    return _TermsView(
      onAccepted: () => setState(() => _termsAccepted = true),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1: Terms acceptance
// ---------------------------------------------------------------------------

/// First screen — Divine logo, subtitle, age + terms checkboxes.
class _TermsView extends StatefulWidget {
  const _TermsView({required this.onAccepted});

  final VoidCallback onAccepted;

  @override
  State<_TermsView> createState() => _TermsViewState();
}

class _TermsViewState extends State<_TermsView> {
  bool _ageConfirmed = false;
  bool _termsAccepted = false;

  bool get _canProceed => _ageConfirmed && _termsAccepted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AuthHeroSection(),
            ],
          ),
        ),

        // Age confirmation
        _TermsCheckbox(
          value: _ageConfirmed,
          onChanged: (v) => setState(() => _ageConfirmed = v ?? false),
          child: const Text(
            'I am 18 years or older',
            style: TextStyle(fontSize: 15, color: VineTheme.whiteText),
          ),
        ),

        const SizedBox(height: 12),

        // Terms acceptance
        _TermsCheckbox(
          value: _termsAccepted,
          onChanged: (v) => setState(() => _termsAccepted = v ?? false),
          child: const _TermsLinkText(),
        ),

        const SizedBox(height: 24),

        DivinePrimaryButton(
          label: 'Accept terms & continue',
          onPressed: _canProceed ? widget.onAccepted : null,
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2: Code entry
// ---------------------------------------------------------------------------

/// Code entry screen — back button, title, invite code input, confetti,
/// "Next" button pinned to bottom.
class _CodeEntryView extends StatefulWidget {
  const _CodeEntryView({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_CodeEntryView> createState() => _CodeEntryViewState();
}

class _CodeEntryViewState extends State<_CodeEntryView> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
    if (code.isEmpty) return;
    context.read<InviteCodeBloc>().add(InviteCodeClaimRequested(code));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Back button
            RoundedIconButton(
              onPressed: widget.onBack,
              icon: const Icon(
                Icons.chevron_left,
                color: VineTheme.vineGreenLight,
                size: 28,
              ),
            ),

            const SizedBox(height: 32),

            // Title
            const Text(
              'Add your invite code',
              style: TextStyle(
                fontFamily: VineTheme.fontFamilyBricolage,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: VineTheme.whiteText,
                height: 1.25,
              ),
            ),

            const SizedBox(height: 32),

            // Code input
            _InviteCodeInput(controller: _controller),
          ],
        ),

        // Confetti sticker — bottom-left, rotated
        Positioned(
          left: -36,
          top: 392,
          child: Transform.rotate(
            angle: 11.99 * 3.14159 / 180,
            child: Image.asset(
              'assets/stickers/confetti.png',
              width: 174,
              height: 174,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // "Next" button pinned to bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: BlocBuilder<InviteCodeBloc, InviteCodeState>(
            builder: (context, state) {
              return DivinePrimaryButton(
                label: 'Next',
                isLoading: state.isLoading,
                onPressed: state.isLoading ? null : _submit,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Invite code input — tall field with green label matching Figma specs.
class _InviteCodeInput extends StatelessWidget {
  const _InviteCodeInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InviteCodeBloc, InviteCodeState>(
      builder: (context, state) {
        final hasError = state.error != null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              enabled: !state.isLoading,
              autofocus: true,
              inputFormatters: [_InviteCodeFormatter()],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: VineTheme.whiteText,
                letterSpacing: 0.15,
              ),
              decoration: InputDecoration(
                labelText: 'Invite code',
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: hasError ? VineTheme.error : VineTheme.vineGreen,
                ),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: 'Enter your code',
                hintStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: VineTheme.whiteText.withValues(alpha: 0.25),
                  letterSpacing: 0.15,
                ),
                filled: true,
                fillColor: VineTheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: hasError
                      ? const BorderSide(color: VineTheme.error)
                      : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: hasError ? VineTheme.error : VineTheme.vineGreen,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
              ),
              onSubmitted: (_) {
                final code = controller.text.replaceAll(
                  RegExp('[^a-zA-Z0-9]'),
                  '',
                );
                if (code.isEmpty) return;
                context.read<InviteCodeBloc>().add(
                  InviteCodeClaimRequested(code),
                );
              },
            ),

            // Error message
            if (hasError) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  state.error!,
                  style: const TextStyle(
                    color: VineTheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Formats input as XXXX-XXXX, auto-inserting hyphen after 4 characters.
class _InviteCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
    final limited = cleaned.length > 8 ? cleaned.substring(0, 8) : cleaned;

    String formatted;
    if (limited.length <= 4) {
      formatted = limited;
    } else {
      formatted = '${limited.substring(0, 4)}-${limited.substring(4)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3: Success
// ---------------------------------------------------------------------------

/// Success screen — Divine logo, "Your playground for human creativity",
/// celebration stickers, then auto-navigates to welcome.
class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),

        const Spacer(),

        // Divine logo
        const AuthHeroSection(),

        const SizedBox(height: 32),

        // Hero text
        const Text(
          'Your\nplayground\nfor human\ncreativity',
          style: TextStyle(
            fontFamily: VineTheme.fontFamilyBricolage,
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: VineTheme.whiteText,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // Celebration stickers
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/stickers/confetti.png',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/stickers/disco_ball.png',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
            ),
          ],
        ),

        const Spacer(),

        // Continue — navigate to welcome/account creation
        DivinePrimaryButton(
          label: 'Continue',
          onPressed: () => context.go(WelcomeScreen.path),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

/// Checkbox row for the terms screen.
class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
    required this.child,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: VineTheme.vineGreen,
              checkColor: VineTheme.backgroundColor,
              side: const BorderSide(color: VineTheme.secondaryText),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Terms text with clickable links to TOS, Privacy Policy, Safety Standards.
class _TermsLinkText extends StatefulWidget {
  const _TermsLinkText();

  @override
  State<_TermsLinkText> createState() => _TermsLinkTextState();
}

class _TermsLinkTextState extends State<_TermsLinkText> {
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
      color: VineTheme.vineGreen,
      decoration: TextDecoration.underline,
      decorationColor: VineTheme.vineGreen,
    );

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 15,
          color: VineTheme.whiteText,
          height: 1.4,
        ),
        children: [
          const TextSpan(text: 'I agree to the '),
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
        ],
      ),
    );
  }
}
