// ABOUTME: Screen for adjusting audio timing/offset for video editor.
// ABOUTME: Displays video preview with audio segment selector overlay.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';

/// Screen for adjusting audio timing/offset in the video editor.
///
/// This screen is shown after selecting audio, allowing users to
/// set the start position of the audio track relative to the video.
class VideoAudioEditorTimingScreen extends ConsumerStatefulWidget {
  /// Creates the audio timing screen.
  const VideoAudioEditorTimingScreen({super.key});

  /// Route name for navigation.
  static const routeName = 'video-audio-timing';

  /// Route path.
  static const path = '/video-audio-timing';

  @override
  ConsumerState<VideoAudioEditorTimingScreen> createState() =>
      _VideoAudioEditorTimingScreenState();
}

class _VideoAudioEditorTimingScreenState
    extends ConsumerState<VideoAudioEditorTimingScreen> {
  // TODO: Implement actual audio playback and timing adjustment.
  double _startOffset = 0;

  @override
  void initState() {
    super.initState();
  }

  void _deleteAudio() {
    ref.read(selectedSoundProvider.notifier).clear();
    context.pop();
  }

  void _confirmSelection() {
    // TODO: Apply the timing offset to the selected sound.
    // ref.read(selectedSoundProvider.notifier).select(widget.audio);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Scrim overlay (65% black as per Figma)
            const ColoredBox(
              color: Color(0xA6000000), // rgba(0,0,0,0.65)
            ),

            // Content
            SafeArea(
              child: Column(
                children: [
                  // Top bar
                  _TopBar(onDelete: _deleteAudio, onConfirm: _confirmSelection),

                  const Spacer(),

                  // Bottom controls
                  _BottomControls(
                    startOffset: _startOffset,
                    audioDuration: ref.watch(
                      selectedSoundProvider.select((s) => s?.duration),
                    ),
                    onOffsetChanged: (offset) {
                      setState(() {
                        _startOffset = offset;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top navigation bar with delete button, audio chip, and confirm button.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onDelete, required this.onConfirm});

  final VoidCallback onDelete;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: .spaceBetween,
        spacing: 12,
        children: [
          // Delete button
          DivineIconButton(
            // TODO(l10n): Replace with context.l10n when localization is added.
            semanticLabel: 'Remove audio',
            icon: .trash,
            size: .small,
            type: .error,
            onPressed: onDelete,
          ),

          // Audio chip (centered, flexible)
          const Flexible(
            child: VideoEditorAudioChip(),
          ),

          // Confirm button
          DivineIconButton(
            // TODO(l10n): Replace with context.l10n when localization is added.
            semanticLabel: 'Confirm audio selection',
            icon: .check,
            size: .small,
            type: .tertiary,
            onPressed: onConfirm,
          ),
        ],
      ),
    );
  }
}

/// Bottom controls with instruction text and timeline selector.
class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.startOffset,
    required this.audioDuration,
    required this.onOffsetChanged,
  });

  final double startOffset;

  /// Audio duration in seconds, or null if unknown.
  final double? audioDuration;
  final ValueChanged<double> onOffsetChanged;

  /// Calculates the selection width ratio based on video maxDuration vs audio duration.
  ///
  /// The selection always represents [VideoEditorConstants.maxDuration] (6.3s).
  /// - If audio is shorter than maxDuration: returns 0.9 (90% width, max allowed)
  /// - If audio is longer: returns the proportional ratio (e.g., 33% for ~19s audio)
  /// - Minimum 10% to keep the selection visible and draggable
  double get _selectionWidthRatio {
    final audioDurationSecs = audioDuration;
    if (audioDurationSecs == null || audioDurationSecs <= 0) {
      return 0.9; // Unknown duration, assume max selection
    }

    final maxDurationSecs =
        VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;

    // If audio is shorter than video max duration, use max width (90%)
    if (audioDurationSecs <= maxDurationSecs) {
      return 0.9;
    }

    // Ratio of video duration to audio duration, clamped to [0.1, 0.9]
    return (maxDurationSecs / audioDurationSecs).clamp(0.1, 0.9);
  }

  @override
  Widget build(BuildContext context) {
    final selectionRatio = _selectionWidthRatio;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Instruction text
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Select the audio segment for your video',
            style: VineTheme.bodySmallFont(),
            textAlign: .center,
          ),
        ),

        const SizedBox(height: 48),

        // Video duration timeline (top bar with green segment)
        _VideoDurationTimeline(
          startOffset: startOffset,
          selectionWidthRatio: selectionRatio,
        ),

        const SizedBox(height: 38),

        // Audio waveform with draggable selection
        _AudioWaveformSelector(
          startOffset: startOffset,
          selectionWidthRatio: selectionRatio,
          onOffsetChanged: onOffsetChanged,
        ),
      ],
    );
  }
}

/// Video duration timeline showing where the selected segment will play.
class _VideoDurationTimeline extends StatelessWidget {
  const _VideoDurationTimeline({
    required this.startOffset,
    required this.selectionWidthRatio,
  });

  final double startOffset;

  /// The ratio of the segment width to the total timeline width.
  final double selectionWidthRatio;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width - 32;
    final segmentWidth = screenWidth * selectionWidthRatio;

    return Container(
      margin: const .symmetric(horizontal: 16),
      height: 8,
      decoration: BoxDecoration(
        color: VineTheme.scrim65,
        borderRadius: .circular(4),
      ),
      child: Stack(
        children: [
          Positioned(
            left: startOffset * (screenWidth - segmentWidth),
            child: Container(
              width: segmentWidth,
              height: 8,
              decoration: BoxDecoration(
                color: VineTheme.vineGreen,
                borderRadius: BorderRadius.circular(4),
                border: .all(
                  color: VineTheme.accentYellow,
                  width: 4,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Audio waveform with draggable green selection area.
class _AudioWaveformSelector extends StatelessWidget {
  const _AudioWaveformSelector({
    required this.startOffset,
    required this.selectionWidthRatio,
    required this.onOffsetChanged,
  });

  final double startOffset;

  /// The ratio of the selection width to the total waveform width.
  final double selectionWidthRatio;
  final ValueChanged<double> onOffsetChanged;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width - 32;
    // Selection area represents portion of audio that fits video duration
    final selectionWidth = screenWidth * selectionWidthRatio;
    // Selection is always centered
    final selectionLeft = (screenWidth - selectionWidth) / 2;
    // Full waveform width represents the entire audio duration
    // If selection is 33% of screen, full waveform is ~3x the selection width
    final fullWaveformWidth = selectionWidth / selectionWidthRatio;
    // Calculate how far the waveform can scroll
    final maxScrollableDistance = fullWaveformWidth - selectionWidth;
    // Waveform position: at offset 0, waveform starts at selection left edge
    // at offset 1, waveform ends at selection right edge
    final waveformLeft = selectionLeft - startOffset * maxScrollableDistance;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // Don't allow scrolling if selection fills the waveform
        if (maxScrollableDistance < 1) return;

        final delta = details.delta.dx;
        // Invert delta: dragging right scrolls waveform left (increases offset)
        final newOffset = (startOffset - delta / maxScrollableDistance).clamp(
          0.0,
          1.0,
        );
        onOffsetChanged(newOffset);
      },
      onTapDown: (details) {
        // Tap doesn't change position since selection is fixed in center
      },
      child: Container(
        padding: const .fromLTRB(16, 8, 16, 11),
        height: 85,
        color: VineTheme.backgroundColor,
        child: ClipRect(
          child: Stack(
            children: [
              // Selection background always centered
              Positioned(
                left: selectionLeft,
                top: 0,
                bottom: 0,
                child: Container(
                  width: selectionWidth,
                  decoration: BoxDecoration(
                    color: VineTheme.primary,
                    borderRadius: .circular(24),
                    border: Border.all(
                      color: VineTheme.accentYellow,
                      width: 4,
                    ),
                  ),
                ),
              ),

              // Scrollable waveform (white bars) - offset based on selection
              Positioned(
                left: waveformLeft,
                top: 0,
                bottom: 0,
                width: fullWaveformWidth,
                child: CustomPaint(
                  painter: _WaveformPainter(barColor: VineTheme.whiteText),
                ),
              ),

              // Selection overlay - always centered
              Positioned(
                left: selectionLeft,
                top: 0,
                bottom: 0,
                child: Container(
                  width: selectionWidth,
                  decoration: BoxDecoration(
                    borderRadius: .circular(24),
                    border: Border.all(
                      color: VineTheme.accentYellow,
                      width: 4,
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

/// Paints audio waveform bars with pseudo-random heights.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.barColor});

  final Color barColor;

  static const _barWidth = 4.0;
  static const _barSpacing = 3.0;
  static const _barStep = _barWidth + _barSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = (size.width / _barStep).floor();
    final halfHeight = size.height / 2;

    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    // Generate pseudo-random heights for visual interest
    for (var i = 0; i < barCount; i++) {
      final x = i * _barStep;
      // Create varied waveform pattern
      final seed = (i * 17 + 7) % 23;
      final heightFactor = 0.2 + 0.8 * (seed / 23);
      final barHeight = size.height * 0.45 * heightFactor;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + _barWidth / 2, halfHeight),
            width: _barWidth,
            height: barHeight.clamp(4.0, size.height * 0.9),
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.barColor != barColor;
  }
}
