// ABOUTME: Bottom bar widget for video recorder screen
// ABOUTME: Contains flash, timer, record button, camera flip, and more options

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

/// Bottom bar with record button and camera controls.
class VideoRecorderBottomBar extends ConsumerWidget {
  /// Creates a video recorder bottom bar widget.
  const VideoRecorderBottomBar({super.key});

  /// Shows a styled snackbar with the given message.
  void _showSnackBar({
    required BuildContext context,
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: .floating,
        margin: const .fromLTRB(16, 0, 16, 68),
        duration: Duration(seconds: isError ? 3 : 2),
        content: DivineSnackbarContainer(label: message, error: isError),
      ),
    );
  }

  /// Show more options menu
  Future<void> _showMoreOptions(BuildContext context, WidgetRef ref) async {
    final clipManager = ref.read(
      clipManagerProvider.select(
        (p) => (hasClips: p.hasClips, clipCount: p.clipCount),
      ),
    );
    final clipsNotifier = ref.read(clipManagerProvider.notifier);
    final recorderNotifier = ref.read(videoRecorderProvider.notifier);
    final recorderState = ref.read(
      videoRecorderProvider.select(
        (p) => (
          isGhostEnabled: p.isGhostEnabled,
          isAudioEnabled: p.isAudioEnabled,
        ),
      ),
    );

    VineBottomSheetActionMenu.show(
      context: context,
      options: [
        // Ghost mode toggle
        VineBottomSheetActionData(
          iconPath: 'assets/icon/ghost.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: recorderState.isGhostEnabled
              ? 'Ghost mode (on)'
              : 'Ghost mode',
          onTap: clipManager.hasClips ? recorderNotifier.toggleGhost : null,
        ),
        // Audio toggle
        VineBottomSheetActionData(
          iconPath: 'assets/icon/mic.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: recorderState.isAudioEnabled ? 'Audio (on)' : 'Audio (off)',
          onTap: recorderNotifier.toggleAudio,
        ),
        // Resize clips
        VineBottomSheetActionData(
          iconPath: 'assets/icon/arrows_counter_clockwise.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Resize clips',
          onTap: clipManager.hasClips
              ? () => _showResizeDialog(context, ref)
              : null,
        ),
        VineBottomSheetActionData(
          iconPath: 'assets/icon/save.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: clipManager.clipCount > 1
              ? 'Save clips to Library'
              : 'Save clip to Library',
          onTap: clipManager.hasClips
              ? () async {
                  final success = await clipsNotifier.saveClipsToLibrary();
                  if (!context.mounted) return;
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  _showSnackBar(
                    context: context,
                    message: success
                        ? 'Clips saved to library'
                        : 'Failed to save clips',
                    isError: !success,
                  );
                }
              : null,
        ),
        VineBottomSheetActionData(
          iconPath: 'assets/icon/undo.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Remove last clip',
          onTap: clipManager.hasClips
              ? () {
                  unawaited(clipsNotifier.removeLastClip());
                  unawaited(recorderNotifier.updateGhostFrame());
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  _showSnackBar(context: context, message: 'Clip removed');
                }
              : null,
        ),
        VineBottomSheetActionData(
          iconPath: 'assets/icon/trash.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Clear all clips',
          onTap: clipManager.hasClips
              ? () {
                  unawaited(clipsNotifier.clearAll());
                  recorderNotifier.clearGhost();
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  _showSnackBar(context: context, message: 'All clips cleared');
                }
              : null,
          isDestructive: true,
        ),
      ],
    );
  }

  /// Shows a dialog to resize all clips to a uniform duration.
  Future<void> _showResizeDialog(BuildContext context, WidgetRef ref) async {
    final clipState = ref.read(clipManagerProvider);
    final clips = clipState.clips;
    if (clips.isEmpty) return;

    final minMs = clips
        .map((c) => c.duration.inMilliseconds)
        .reduce((a, b) => a < b ? a : b);
    final maxMs = clips
        .map((c) => c.duration.inMilliseconds)
        .reduce((a, b) => a > b ? a : b);

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return _ResizeClipsDialog(
          clipCount: clips.length,
          minMs: minMs,
          maxMs: maxMs,
        );
      },
    );

    if (result == null || !context.mounted) return;

    final success = await ref
        .read(clipManagerProvider.notifier)
        .resizeAllClips(Duration(milliseconds: result));

    if (!context.mounted) return;
    // TODO(l10n): Replace with context.l10n when localization is added.
    _showSnackBar(
      context: context,
      message: success ? 'Clips resized' : 'Failed to resize clips',
      isError: !success,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoRecorderProvider.notifier);

    final state = ref.watch(
      videoRecorderProvider.select(
        (p) => (
          flashMode: p.flashMode,
          timer: p.timerDuration,
          aspectRatio: p.aspectRatio,
          canSwitchCamera: p.canSwitchCamera,
          hasFlash: p.hasFlash,
          isRecording: p.isRecording,
        ),
      ),
    );

    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));

    return SafeArea(
      top: false,
      child: IgnorePointer(
        ignoring: state.isRecording,
        child: Padding(
          padding: const .only(bottom: 4.0),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: state.isRecording ? 0 : 1,
            child: Row(
              mainAxisAlignment: .spaceAround,
              children: [
                // Flash toggle
                _ActionButton(
                  iconPath: state.flashMode.iconPath,
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'Toggle flash',
                  onPressed: state.hasFlash ? notifier.toggleFlash : null,
                ),

                // Timer toggle
                _ActionButton(
                  iconPath: state.timer.iconPath,
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'Cycle timer',
                  onPressed: notifier.cycleTimer,
                ),

                // Aspect-Ratio
                _ActionButton(
                  iconPath: state.aspectRatio == .square
                      ? 'assets/icon/crop_square.svg'
                      : 'assets/icon/crop_portrait.svg',
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'Toggle aspect ratio',
                  onPressed: !hasClips ? notifier.toggleAspectRatio : null,
                ),

                // Flip camera
                _ActionButton(
                  iconPath: 'assets/icon/refresh.svg',
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'Switch camera',
                  onPressed: state.canSwitchCamera
                      ? notifier.switchCamera
                      : null,
                ),

                // More options
                _ActionButton(
                  iconPath: 'assets/icon/more_horiz.svg',
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'More options',
                  onPressed: () => _showMoreOptions(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResizeClipsDialog extends StatefulWidget {
  const _ResizeClipsDialog({
    required this.clipCount,
    required this.minMs,
    required this.maxMs,
  });

  final int clipCount;
  final int minMs;
  final int maxMs;

  @override
  State<_ResizeClipsDialog> createState() => _ResizeClipsDialogState();
}

class _ResizeClipsDialogState extends State<_ResizeClipsDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const int _absoluteMinMs = 30;
  int get _maxTargetMs => 6000 ~/ widget.clipCount;

  /// Pure validity check — safe to call during build (no setState).
  bool _isValid(String value) {
    if (value.isEmpty) return false;
    final ms = int.tryParse(value);
    if (ms == null || ms <= 0) return false;
    if (ms < _absoluteMinMs || ms > _maxTargetMs) return false;
    return true;
  }

  /// Validates input and updates error text — only call from onChanged.
  void _validate(String value) {
    if (value.isEmpty) {
      setState(() => _errorText = null);
      return;
    }
    final ms = int.tryParse(value);
    if (ms == null || ms <= 0) {
      setState(() => _errorText = 'Enter a positive number');
      return;
    }
    if (ms < _absoluteMinMs || ms > _maxTargetMs) {
      setState(
        () => _errorText = 'Must be ${_absoluteMinMs}ms–${_maxTargetMs}ms',
      );
      return;
    }
    setState(() => _errorText = null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      // TODO(l10n): Replace with context.l10n when localization is added.
      title: Text(
        'Resize clips',
        style: TextStyle(color: VineTheme.primaryText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODO(l10n): Replace with context.l10n when localization is added.
          Text(
            '${widget.clipCount} clips — '
            'Min: ${widget.minMs}ms / Max: ${widget.maxMs}ms',
            style: TextStyle(color: VineTheme.secondaryText),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(color: VineTheme.primaryText),
            decoration: InputDecoration(
              // TODO(l10n): Replace with context.l10n when localization is added.
              hintText: 'Target duration (ms)',
              hintStyle: TextStyle(color: VineTheme.secondaryText),
              errorText: _errorText,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: VineTheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: VineTheme.vineGreen),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: VineTheme.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: VineTheme.error),
              ),
            ),
            onChanged: _validate,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          // TODO(l10n): Replace with context.l10n when localization is added.
          child: Text(
            'Cancel',
            style: TextStyle(color: VineTheme.secondaryText),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final isValid = _isValid(value.text);
            return TextButton(
              onPressed: isValid
                  ? () => Navigator.of(context).pop(int.parse(_controller.text))
                  : null,
              // TODO(l10n): Replace with context.l10n when localization is added.
              child: Text(
                'Apply',
                style: TextStyle(
                  color: isValid
                      ? VineTheme.vineGreen
                      : VineTheme.secondaryText,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onPressed,
    required this.tooltip,
    required this.iconPath,
  });
  final VoidCallback? onPressed;
  final String tooltip;
  final String iconPath;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: SizedBox(
        height: 32,
        width: 32,
        child: SvgPicture.asset(
          iconPath,
          colorFilter: ColorFilter.mode(
            Color.fromRGBO(255, 255, 255, isEnabled ? 1.0 : 0.3),
            .srcIn,
          ),
        ),
      ),
    );
  }
}
