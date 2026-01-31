// ABOUTME: Screen for importing existing Nostr private keys (nsec or hex format)
// ABOUTME: Also supports NIP-46 bunker URLs for remote signing
// ABOUTME: Validates keys and imports them securely for existing Nostr users

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/divine_auth_screen.dart';
import 'package:openvine/screens/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

class KeyImportScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'import-key';

  /// Path for this route.
  static const path = '/import-key';

  const KeyImportScreen({super.key});

  @override
  ConsumerState<KeyImportScreen> createState() => _KeyImportScreenState();
}

class _KeyImportScreenState extends ConsumerState<KeyImportScreen> {
  final _keyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isImporting = false;
  bool _obscureKey = true;

  // Save reference to authService for safe disposal
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    // Save ref early so we can use it safely in dispose
    _authService = ref.read(authServiceProvider);
  }

  @override
  void dispose() {
    _keyController.dispose();

    // Clear any authentication errors when leaving this screen
    // This prevents stale errors from being displayed on the welcome screen
    _authService.clearError();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Back button
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () => context.pop(),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),

                const SizedBox(height: 24),

                // Title
                const Text(
                  'Import your Nostr ID',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'Import your existing Nostr identity using your '
                  'private key or a bunker URL.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[300]),
                ),
                const SizedBox(height: 40),

                // Private key input
                TextFormField(
                  controller: _keyController,
                  obscureText: _obscureKey,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Private key or bunker URL',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'nsec, hex format or bunker URL',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: VineTheme.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: VineTheme.vineGreen,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: VineTheme.error),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: VineTheme.error,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(20),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _obscureKey
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureKey = !_obscureKey;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.paste, color: Colors.grey),
                          onPressed: _pasteFromClipboard,
                        ),
                      ],
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your private key or bunker URL';
                    }

                    final trimmed = value.trim();

                    // Check if it's a bunker URL
                    if (NostrRemoteSignerInfo.isBunkerUrl(trimmed)) {
                      try {
                        NostrRemoteSignerInfo.parseBunkerUrl(trimmed);
                      } catch (e) {
                        return 'Invalid bunker URL';
                      }
                      return null;
                    }

                    // Check if it looks like a valid key format
                    if (!trimmed.startsWith('nsec') && trimmed.length != 64) {
                      return 'Invalid format. Use nsec..., hex, or bunker://...';
                    }

                    if (trimmed.startsWith('nsec') && trimmed.length != 63) {
                      return 'Invalid nsec format. Should be 63 characters';
                    }

                    return null;
                  },
                  minLines: 1,
                ),
                const SizedBox(height: 24),

                // Import button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isImporting ? null : _importKey,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.vineGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: VineTheme.vineGreen.withValues(
                        alpha: 0.7,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _isImporting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Importing...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Import Nostr ID',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Security warning
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.shade800.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange.shade400,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Keep your private key secure!',
                            style: TextStyle(
                              color: Colors.orange.shade400,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Never share your private key with anyone. This key '
                        'gives full access to your Nostr identity.',
                        style: TextStyle(
                          color: Colors.orange.shade300,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 80),

                // Bottom section - Don't have a Nostr identity?
                Center(
                  child: Column(
                    children: [
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          children: const [
                            TextSpan(
                              text: "Don't have a Nostr identity? ",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text:
                                  "We'll automatically create one for you when you sign up for diVine.",
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign up button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () {
                            // Navigate to sign up screen (signIn=false for sign-up mode)
                            context.go(
                              '${WelcomeScreen.path}${DivineAuthScreen.path}?signIn=false',
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: VineTheme.vineGreen,
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Sign up',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        _keyController.text = clipboardData!.text!.trim();
      }
    } catch (e) {
      Log.error(
        'Failed to paste from clipboard: $e',
        name: 'KeyImportScreen',
        category: LogCategory.ui,
      );
    }
  }

  Future<void> _importKey() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final keyText = _keyController.text.trim();
      final AuthResult result;

      if (NostrRemoteSignerInfo.isBunkerUrl(keyText)) {
        // Handle bunker URL (NIP-46 remote signing)
        result = await authService.connectWithBunker(keyText);
      } else if (keyText.startsWith('nsec')) {
        result = await authService.importFromNsec(keyText);
      } else {
        result = await authService.importFromHex(keyText);
      }

      if (result.success && mounted) {
        // Clear the text field for security
        _keyController.clear();

        // Start fetching the user's profile from relays in background
        // This ensures profile data is available when user navigates to profile
        final pubkeyHex = authService.currentPublicKeyHex;
        if (pubkeyHex != null) {
          final userProfileService = ref.read(userProfileServiceProvider);
          unawaited(userProfileService.fetchProfile(pubkeyHex));
          Log.info(
            'Started background fetch for imported user profile',
            name: 'KeyImportScreen',
            category: LogCategory.auth,
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? 'Failed to import key or connect bunker',
            ),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }
}
