// ABOUTME: Key management screen for importing, exporting, and backing up Nostr keys
// ABOUTME: Simple, clear interface focused on user needs with helpful explanations

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/utils/key_backup_words.dart';

class KeyManagementScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'key-management';

  /// Path for this route.
  static const path = '/key-management';

  const KeyManagementScreen({super.key});

  @override
  ConsumerState<KeyManagementScreen> createState() =>
      _KeyManagementScreenState();
}

class _KeyManagementScreenState extends ConsumerState<KeyManagementScreen> {
  bool _isProcessing = false;
  final _importController = TextEditingController();

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nostrService = ref.watch(nostrServiceProvider);

    return Scaffold(
      appBar: DiVineAppBar(
        title: 'Nostr Keys',
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: .fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              // What are Nostr keys explanation
              _buildExplanationCard(),
              const SizedBox(height: 24),

              // Import existing key section
              _buildImportSection(context, nostrService),
              const SizedBox(height: 24),

              // Export/Backup section
              _buildExportSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.vineGreen.withValues(alpha: 0.15),
        border: Border.all(color: VineTheme.vineGreen.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: VineTheme.vineGreen, size: 24),
              SizedBox(width: 12),
              Text(
                'What are Nostr keys?',
                style: TextStyle(
                  color: VineTheme.vineGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Your Nostr identity is a cryptographic key pair:\n\n'
            '• Your public key (npub) is like your username - share it freely\n'
            '• Your private key (nsec) is like your password - keep it secret!\n\n'
            'Your nsec lets you access your account on any Nostr app.',
            style: TextStyle(
              color: VineTheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportSection(
    BuildContext context,
    nostrService,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Import Existing Key',
          style: TextStyle(
            color: VineTheme.whiteText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Paste your plain nsec, 24-word backup phrase, or ncryptsec1.',
          style: TextStyle(
            color: VineTheme.onSurfaceMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VineTheme.cardBackground),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _importController,
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'nsec1... / 24 words / ncryptsec1...',
                  hintStyle: const TextStyle(color: VineTheme.lightText),
                  filled: true,
                  fillColor: VineTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: VineTheme.cardBackground,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: VineTheme.cardBackground,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: VineTheme.vineGreen),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.paste,
                      color: VineTheme.secondaryText,
                    ),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        _importController.text = data!.text!.trim();
                      }
                    },
                  ),
                ),
                maxLines: 3,
                enabled: !_isProcessing,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _importKey(context, nostrService),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    foregroundColor: VineTheme.whiteText,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: VineTheme.whiteText,
                          ),
                        )
                      : const Text(
                          'Import Key',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VineTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: VineTheme.warning.withValues(alpha: 0.5),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: VineTheme.warning,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will replace your current key!',
                        style: TextStyle(
                          color: VineTheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExportSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Backup Your Key',
          style: TextStyle(
            color: VineTheme.whiteText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Save your private key (nsec) to use your account in other Nostr apps.',
          style: TextStyle(
            color: VineTheme.onSurfaceMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VineTheme.cardBackground),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _exportKey(context),
                  icon: const Icon(Icons.copy, size: 20),
                  label: const Text(
                    'Copy plain nsec (raw key)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    foregroundColor: VineTheme.whiteText,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _exportWordsBackup(context),
                  icon: const Icon(Icons.text_fields, size: 20),
                  label: const Text('Copy 24-word backup'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _exportEncryptedBackup(context),
                  icon: const Icon(Icons.lock, size: 20),
                  label: const Text('Create password-encrypted ncryptsec1'),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VineTheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: VineTheme.error.withValues(alpha: 0.5),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security, color: VineTheme.error, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Never share your nsec with anyone!',
                        style: TextStyle(
                          color: VineTheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _importKey(
    BuildContext context,
    nostrService,
  ) async {
    final keyInput = _importController.text.trim();

    if (keyInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste your key, words, or ncryptsec1'),
          backgroundColor: VineTheme.warning,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Import This Key?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: const Text(
          'This will replace your current identity with the imported one.\n\n'
          'Your current key will be lost unless you backed it up first.',
          style: TextStyle(color: VineTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
            ),
            onPressed: () => context.pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      // Use AuthService for proper session setup and relay discovery
      final authService = ref.read(authServiceProvider);
      final result = await (() async {
        if (Nip49.isEncryptedKey(keyInput)) {
          final password = await _promptPassword(context);
          if (password == null || password.isEmpty) {
            throw Exception('Import cancelled');
          }
          return authService.importFromNcryptsec(keyInput, password);
        }

        if (KeyBackupWords.isValidMnemonic(keyInput)) {
          return authService.importFromMnemonic(keyInput);
        }

        if (keyInput.startsWith('nsec')) {
          return authService.importFromNsec(keyInput);
        }

        return authService.importFromHex(keyInput);
      })();

      if (!result.success) {
        throw Exception(result.errorMessage ?? 'Failed to import key');
      }

      // Fetch profile after successful import (authService is source of truth)
      if (context.mounted && authService.currentPublicKeyHex != null) {
        try {
          await ref
              .read(profileRepositoryProvider)
              ?.fetchFreshProfile(
                pubkey: authService.currentPublicKeyHex!,
              );
        } catch (e) {
          // Non-fatal - profile fetch failure shouldn't block import
        }
      }

      if (context.mounted) {
        _importController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Key imported successfully!'),
            backgroundColor: VineTheme.vineGreen,
            duration: Duration(seconds: 3),
          ),
        );

        // Pop back to settings after successful import
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import key: $e'),
            backgroundColor: VineTheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _exportKey(BuildContext context) async {
    try {
      final nsec = await ref.read(authServiceProvider).exportNsec();

      if (nsec == null) {
        throw Exception('No private key available to export.');
      }

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: nsec));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Private key copied to clipboard!\n\nStore it somewhere safe.',
            ),
            backgroundColor: VineTheme.vineGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export key: $e'),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _exportWordsBackup(BuildContext context) async {
    try {
      final words = await ref.read(authServiceProvider).exportMnemonicWords();
      if (words == null) throw Exception('No private key available to export.');

      await Clipboard.setData(ClipboardData(text: words));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 24-word backup copied to clipboard.'),
            backgroundColor: VineTheme.vineGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export words: $e'),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _exportEncryptedBackup(BuildContext context) async {
    final password = await _promptPassword(context);
    if (password == null || password.isEmpty) return;

    try {
      final ncrypt = await ref
          .read(authServiceProvider)
          .exportNcryptsec(password);
      if (ncrypt == null) {
        throw Exception('No private key available to export.');
      }

      await Clipboard.setData(ClipboardData(text: ncrypt));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Encrypted ncryptsec1 copied to clipboard.'),
            backgroundColor: VineTheme.vineGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export encrypted backup: $e'),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }

  Future<String?> _promptPassword(BuildContext context) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text('Backup password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter password',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => context.pop(controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return password;
  }
}
