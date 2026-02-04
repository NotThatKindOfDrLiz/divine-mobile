// ABOUTME: Screen for entering invite codes manually or via deep link
// ABOUTME: Dark theme UI with 8-character alphanumeric input

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/invite_code/invite_code_bloc.dart';
import 'package:openvine/screens/welcome_screen.dart';
import 'package:openvine/utils/unified_logger.dart';

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

  /// Validate the invite code format.
  String? _validateCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an invite code';
    }
    if (value.length != 8) {
      return 'Invite code must be 8 characters';
    }
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(value.toUpperCase())) {
      return 'Invite code can only contain letters and numbers';
    }
    return null;
  }

  /// Submit the invite code for verification.
  void _submitCode() {
    final code = _codeController.text.trim().toUpperCase();
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
  void _onInviteCodeStateChanged(
    BuildContext context,
    InviteCodeState state,
  ) {
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
      final errorMsg = state.error ??
          state.result?.message ??
          'Invalid invite code';
      setState(() => _errorMessage = errorMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InviteCodeBloc, InviteCodeState>(
      listener: _onInviteCodeStateChanged,
      child: Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Divine logo
                  Image.asset(
                    'assets/icon/divine_icon_transparent.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Enter Invite Code',
                    style: VineTheme.headlineMediumFont(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your 8-character invite code to continue.',
                    style: VineTheme.bodyMediumFont(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Code input field
                  TextField(
                    controller: _codeController,
                    focusNode: _focusNode,
                    enabled: !_isSubmitting,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 8,
                    style: VineTheme.headlineSmallFont().copyWith(
                      letterSpacing: 4,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      _UpperCaseTextFormatter(),
                    ],
                    decoration: InputDecoration(
                      hintText: 'ABCD1234',
                      hintStyle: VineTheme.headlineSmallFont(
                        color: Colors.grey.withValues(alpha: 0.5),
                      ).copyWith(letterSpacing: 4),
                      counterText: '',
                      filled: true,
                      fillColor: VineTheme.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: VineTheme.vineGreen,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: VineTheme.error,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                    ),
                    onSubmitted: (_) => _submitCode(),
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
                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VineTheme.vineGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: VineTheme.vineGreen.withValues(
                          alpha: 0.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text('Continue', style: VineTheme.labelLargeFont()),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
