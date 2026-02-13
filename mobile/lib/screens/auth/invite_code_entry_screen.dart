// ABOUTME: Screen for entering invite codes manually or via deep link
// ABOUTME: Dark theme UI with 8-character alphanumeric input (XXXX-XXXX format)

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/invite_code/invite_code_bloc.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/auth_back_button.dart';

/// Screen for entering invite codes to access the app.
///
/// Supports:
/// - Manual 8-character alphanumeric code entry
/// - Auto-fill from deep links (via [InviteCodeBloc])
/// - Uppercase formatting
/// - Error display with retry
class InviteCodeEntryScreen extends StatefulWidget {
  /// Route name for this screen.
  static const routeName = 'enter-code';

  /// Path for this route (nested under /invite).
  static const path = '/invite/enter-code';

  const InviteCodeEntryScreen({super.key});

  @override
  State<InviteCodeEntryScreen> createState() => _InviteCodeEntryScreenState();
}

class _InviteCodeEntryScreenState extends State<InviteCodeEntryScreen> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Validate the invite code format (strips dash for validation).
  String? _validateCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an invite code';
    }
    // Strip dash for validation
    final cleanValue = value.replaceAll('-', '');
    if (cleanValue.length != 8) {
      return 'Invite code must be 8 characters';
    }
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(cleanValue.toUpperCase())) {
      return 'Invite code can only contain letters and numbers';
    }
    return null;
  }

  /// Submit the invite code for verification.
  void _submitCode() {
    // Strip dash and normalize
    final code = _codeController.text.replaceAll('-', '').trim().toUpperCase();
    final validationError = _validateCode(code);

    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() => _errorMessage = null);

    // Dispatch claim event - BlocListener handles the result
    context.read<InviteCodeBloc>().add(InviteCodeClaimRequested(code));
  }

  /// Handle BLoC state changes for invite code claiming.
  void _onInviteCodeStateChanged(BuildContext context, InviteCodeState state) {
    // Update loading state
    if (state.isLoading != _isSubmitting) {
      setState(() => _isSubmitting = state.isLoading);
    }

    // Handle success
    if (state.status == InviteCodeStatus.success) {
      Log.info(
        'Invite code accepted, navigating to welcome',
        name: 'InviteCodeEntryScreen',
        category: LogCategory.auth,
      );
      context.go(WelcomeScreen.path);
      return;
    }

    // Handle failure
    if (state.status == InviteCodeStatus.failure) {
      final errorMsg =
          state.error ?? state.result?.message ?? 'Invalid invite code';
      setState(() => _errorMessage = errorMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InviteCodeBloc, InviteCodeState>(
      listener: _onInviteCodeStateChanged,
      child: Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              // Back button
              const Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AuthBackButton(),
                ),
              ),

              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        'Add your invite code',
                        style: TextStyle(
                          fontFamily: 'BricolageGrotesque',
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: VineTheme.whiteText,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Code input field with floating label
                      Container(
                        decoration: BoxDecoration(
                          color: VineTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invite code',
                              style: TextStyle(
                                fontSize: 14,
                                color: VineTheme.vineGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextField(
                              controller: _codeController,
                              focusNode: _focusNode,
                              enabled: !_isSubmitting,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 9, // 8 chars + 1 dash
                              style: const TextStyle(
                                fontSize: 24,
                                color: VineTheme.whiteText,
                                fontWeight: FontWeight.w500,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9\-]'),
                                ),
                                _UpperCaseTextFormatter(),
                                _InviteCodeFormatter(),
                              ],
                              decoration: const InputDecoration(
                                hintText: '1234-5678',
                                hintStyle: TextStyle(
                                  fontSize: 24,
                                  color: VineTheme.lightText,
                                  fontWeight: FontWeight.w500,
                                ),
                                counterText: '',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              onSubmitted: (_) => _submitCode(),
                            ),
                          ],
                        ),
                      ),

                      // Error message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: VineTheme.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: VineTheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: VineTheme.bodySmallFont(
                                    color: VineTheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Confetti sticker - rotated and partially off-screen
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: const Offset(-50, 0),
                            child: Transform.rotate(
                              angle: 10 * pi / 180,
                              child: Image.asset(
                                'assets/stickers/confetti.png',
                                width: 180,
                                height: 180,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Submit button at bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.vineGreen,
                      foregroundColor: VineTheme.backgroundColor,
                      disabledBackgroundColor: VineTheme.vineGreen.withValues(
                        alpha: 0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: VineTheme.backgroundColor,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Let's go!",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text formatter to convert input to uppercase.
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Text formatter to add dash after 4 characters (XXXX-XXXX format).
class _InviteCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove any existing dashes to work with raw input
    final rawText = newValue.text.replaceAll('-', '');

    // Limit to 8 characters (excluding dash)
    final limitedText = rawText.length > 8 ? rawText.substring(0, 8) : rawText;

    // Add dash after 4th character if we have more than 4 chars
    String formattedText;
    if (limitedText.length > 4) {
      formattedText =
          '${limitedText.substring(0, 4)}-${limitedText.substring(4)}';
    } else {
      formattedText = limitedText;
    }

    // Calculate new cursor position
    var newCursorPosition = newValue.selection.end;
    if (newValue.text.length < formattedText.length) {
      // Dash was added, move cursor forward
      newCursorPosition = formattedText.length;
    } else if (newValue.text.length > formattedText.length) {
      // Characters were removed
      newCursorPosition = formattedText.length;
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(
        offset: newCursorPosition.clamp(0, formattedText.length),
      ),
    );
  }
}
