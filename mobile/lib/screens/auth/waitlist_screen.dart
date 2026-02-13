// ABOUTME: Screen for joining the waitlist with email signup
// ABOUTME: Dark theme UI with email input and foam finger sticker

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/waitlist/waitlist_bloc.dart';
import 'package:openvine/widgets/auth_back_button.dart';

/// Arguments for WaitlistScreen navigation.
class WaitlistScreenArgs {
  const WaitlistScreenArgs({this.message});

  /// Custom message to display (e.g., from verification failure).
  final String? message;
}

/// Screen for joining the Divine waitlist.
///
/// Allows users to enter their email to be notified when Divine
/// launches publicly or when they receive an invite.
class WaitlistScreen extends StatefulWidget {
  const WaitlistScreen({super.key, this.message});

  /// Route name for this screen.
  static const String routeName = 'waitlist';

  /// Path for this route (nested under /invite).
  static const String path = '/invite/waitlist';

  /// Custom message to display.
  final String? message;

  @override
  State<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends State<WaitlistScreen> {
  final _emailController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMessageBottomSheet(widget.message!);
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _focusNode.requestFocus();
      return;
    }

    context.read<WaitlistBloc>().add(WaitlistEmailSubmitted(email));
  }

  void _showMessageBottomSheet(String message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VineTheme.outlineMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Waving hand emoji
            const Text('👋', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 20),

            // Title
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'BricolageGrotesque',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: VineTheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              "Please join the waitlist and we'll notify you as "
              'soon as you can get access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: VineTheme.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // OK button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  context.pop();
                  _focusNode.requestFocus();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  foregroundColor: VineTheme.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onWaitlistStateChanged(BuildContext context, WaitlistState state) {
    if (state.isSuccess && state.submittedEmail != null) {
      _showSuccessBottomSheet(state.submittedEmail!);
    }
  }

  void _showSuccessBottomSheet(String email) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VineTheme.outlineMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Shaka emoji
            const Text('🤙', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 20),

            // "You're in!" title
            Text(
              "You're in!",
              style: TextStyle(
                fontFamily: 'BricolageGrotesque',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: VineTheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Description with email
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 16,
                  color: VineTheme.secondaryText,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "We'll send updates to "),
                  TextSpan(
                    text: email,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: VineTheme.whiteText,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ". When more invite codes are available, "
                        "we'll send them your way.",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // OK button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  context.pop(); // Dismiss bottom sheet
                  context.pop(); // Pop back to InviteChoiceScreen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  foregroundColor: VineTheme.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WaitlistBloc, WaitlistState>(
      listener: _onWaitlistStateChanged,
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
                        'Join the waitlist',
                        style: TextStyle(
                          fontFamily: 'BricolageGrotesque',
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: VineTheme.whiteText,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        'Divine will launch soon! Join the waitlist to '
                        "try the beta before it's publicly available.",
                        style: TextStyle(
                          fontSize: 16,
                          color: VineTheme.secondaryText,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Email input field with floating label
                      BlocBuilder<WaitlistBloc, WaitlistState>(
                        buildWhen: (previous, current) =>
                            previous.isSubmitting != current.isSubmitting,
                        builder: (context, state) {
                          return Container(
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
                                  'Email',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: VineTheme.vineGreen,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextField(
                                  controller: _emailController,
                                  focusNode: _focusNode,
                                  enabled: !state.isSubmitting,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: VineTheme.whiteText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'user@email.com',
                                    hintStyle: TextStyle(
                                      fontSize: 18,
                                      color: VineTheme.lightText,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                  onSubmitted: (_) => _submitEmail(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Foam finger sticker - rotated and partially off-screen
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Transform.translate(
                            offset: const Offset(70, 0),
                            child: Transform.rotate(
                              angle: -35 * pi / 180,
                              child: Image.asset(
                                'assets/stickers/foam_finger.png',
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
                child: BlocBuilder<WaitlistBloc, WaitlistState>(
                  buildWhen: (previous, current) =>
                      previous.isSubmitting != current.isSubmitting,
                  builder: (context, state) {
                    return SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: state.isSubmitting ? null : _submitEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VineTheme.vineGreen,
                          foregroundColor: VineTheme.backgroundColor,
                          disabledBackgroundColor: VineTheme.vineGreen
                              .withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: state.isSubmitting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: VineTheme.backgroundColor,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Join waitlist',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
