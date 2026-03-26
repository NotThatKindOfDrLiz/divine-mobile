// ABOUTME: "I'll come back with my parent" screen for under-16 flow
// ABOUTME: Shows a shareable link and QR code the kid can give to
// ABOUTME: their parent so they can return together later.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/onboarding_under16/age_acknowledgment_screen.dart';
import 'package:openvine/widgets/auth_back_button.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Come back later screen — the "deferred" TBRI path.
///
/// Gives the kid something concrete to take to their parent:
/// a QR code they can scan or a link they can share.
class ComeBackLaterScreen extends StatelessWidget {
  static const String routeName = 'under16-come-back-later';
  static const String path = 'come-back-later';

  // Placeholder URL — will point to a real parent info page later
  static const String _parentInfoUrl = 'https://divine.video/parent-info';

  const ComeBackLaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              AuthBackButton(
                onPressed: () => context.go(
                  '${WelcomeScreen.path}'
                  '/${AgeAcknowledgmentScreen.path}'
                  '/options',
                ),
              ),

              const SizedBox(height: 48),

              const Text(
                'Show this to\nyour parent 📱',
                style: TextStyle(
                  fontFamily: VineTheme.fontFamilyBricolage,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: VineTheme.whiteText,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'They can scan this code or use the link '
                'to learn about Divine and help you get set up.',
                style: TextStyle(
                  fontSize: 16,
                  color: VineTheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // QR code
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: VineTheme.inverseSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: _parentInfoUrl,
                    size: 180,
                    backgroundColor: VineTheme.inverseSurface,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Link display + copy
              const _LinkRow(url: _parentInfoUrl),

              const Spacer(),

              // Share button
              DivineButton(
                label: 'Share with my parent',
                expanded: true,
                onPressed: () async {
                  await SharePlus.instance.share(
                    ShareParams(
                      text:
                          'My kid wants to join Divine — '
                          "here's what you need to know: "
                          '$_parentInfoUrl',
                      title: 'Divine — Parent Info',
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),

              Center(
                child: TextButton(
                  onPressed: () => context.go(
                    '${WelcomeScreen.path}'
                    '/${AgeAcknowledgmentScreen.path}'
                    '/confirmation',
                  ),
                  child: const Text(
                    "I'll do this later",
                    style: TextStyle(
                      color: VineTheme.onSurfaceMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row showing the URL with a copy button.
class _LinkRow extends StatefulWidget {
  const _LinkRow({required this.url});

  final String url;

  @override
  State<_LinkRow> createState() => _LinkRowState();
}

class _LinkRowState extends State<_LinkRow> {
  bool _copied = false;

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VineTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.url,
              style: const TextStyle(
                fontSize: 14,
                color: VineTheme.vineGreen,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _copyToClipboard,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _copied
                  ? const Icon(
                      Icons.check,
                      key: ValueKey('check'),
                      color: VineTheme.vineGreen,
                      size: 20,
                    )
                  : const Icon(
                      Icons.copy,
                      key: ValueKey('copy'),
                      color: VineTheme.onSurfaceMuted,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
