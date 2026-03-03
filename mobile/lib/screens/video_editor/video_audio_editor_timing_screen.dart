// ABOUTME: Screen for adjusting audio timing/offset for video editor.
// ABOUTME: Displays video preview with audio segment selector overlay.

import 'dart:async';
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/stereo_waveform_painter.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:sound_service/sound_service.dart';

/// Result of the audio timing screen.
///
/// Returned via [Navigator.pop] to indicate whether the user confirmed
/// the timing selection or deleted the audio.
sealed class AudioTimingResult {
  const AudioTimingResult();
}

/// User confirmed the audio timing selection.
class AudioTimingConfirmed extends AudioTimingResult {
  /// Creates a confirmed result with the updated sound.
  const AudioTimingConfirmed(this.sound);

  /// The sound with updated [AudioEvent.startOffset].
  final AudioEvent sound;
}

/// User deleted the audio.
class AudioTimingDeleted extends AudioTimingResult {
  /// Creates a deleted result.
  const AudioTimingDeleted();
}

/// Screen for adjusting audio timing/offset in the video editor.
///
/// This screen is shown after selecting audio, allowing users to
/// set the start position of the audio track relative to the video.
///
/// Returns an [AudioTimingResult] via [Navigator.pop]:
/// - [AudioTimingConfirmed] with the updated sound when confirmed
/// - [AudioTimingDeleted] when the user deletes the audio
/// - `null` when cancelled (back navigation)
class VideoAudioEditorTimingScreen extends ConsumerStatefulWidget {
  /// Creates the audio timing screen.
  const VideoAudioEditorTimingScreen({
    required this.sound,
    super.key,
  });

  /// The sound to edit timing for.
  final AudioEvent sound;

  /// Route name for navigation.
  static const routeName = 'video-audio-timing';

  /// Route path.
  static const path = '/video-audio-timing';

  @override
  ConsumerState<VideoAudioEditorTimingScreen> createState() =>
      _VideoAudioEditorTimingScreenState();
}

class _VideoAudioEditorTimingScreenState
    extends ConsumerState<VideoAudioEditorTimingScreen>
    with SingleTickerProviderStateMixin {
  double _startOffset = 0;
  late final SoundWaveformBloc _waveformBloc;
  late final AnimationController _flingController;
  late final AudioPlayer _audioPlayer;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  /// Cached audio duration (read once on init to avoid visual jump on clear).
  double? _audioDuration;

  /// Friction for momentum scrolling (higher = stops faster).
  static const double _friction = 0.015;

  @override
  void initState() {
    super.initState();
    _waveformBloc = SoundWaveformBloc();
    _flingController = AnimationController.unbounded(vsync: this);
    _flingController.addListener(_onFlingUpdate);
    _audioPlayer = AudioPlayer();

    // Listen for audio completion to restart loop
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(
      _onPlayerStateChanged,
    );

    // Delay extraction until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final sound = widget.sound;

      // Cache audio duration (won't change during screen lifetime)
      final audioDuration = sound.duration ?? 0;
      final maxDurationSecs =
          VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;
      final scrollableAudioSecs = (audioDuration - maxDurationSecs).clamp(
        0.0,
        double.infinity,
      );

      // Restore previous selection offset (normalized 0-1)
      var initialOffset = 0.0;
      if (scrollableAudioSecs > 0) {
        final startTimeSecs = sound.startOffset.inMilliseconds / 1000.0;
        initialOffset = (startTimeSecs / scrollableAudioSecs).clamp(0.0, 1.0);
      }

      setState(() {
        _audioDuration = audioDuration;
        _startOffset = initialOffset;
      });
      // Sync fling controller with initial offset
      _flingController.value = initialOffset;

      _extractWaveform();
      _loadAndPlayAudio();
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    _flingController
      ..removeListener(_onFlingUpdate)
      ..dispose();
    _waveformBloc.close();
    super.dispose();
  }

  /// Called when player state changes - handles looping.
  void _onPlayerStateChanged(PlayerState state) {
    // When playback completes, restart from the beginning
    if (state.processingState == ProcessingState.completed) {
      _audioPlayer.seek(Duration.zero);
      _audioPlayer.play();
    }
  }

  /// Loads the selected audio and starts looped playback.
  Future<void> _loadAndPlayAudio() async {
    try {
      await _setClippedAudioSource();
      // Manual looping via _onPlayerStateChanged instead of LoopMode
      // because ClippingAudioSource + LoopMode.one can be unreliable
      await _audioPlayer.play();
    } catch (e, s) {
      Log.error(
        'Failed to load audio: $e',
        name: 'VideoAudioEditorTimingScreen',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Creates a clipped audio source for the current selection.
  Future<void> _setClippedAudioSource() async {
    final sound = widget.sound;

    final audioDurationSecs = _audioDuration ?? 0;
    if (audioDurationSecs <= 0) return;

    final maxDurationSecs =
        VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;
    final scrollableAudioSecs = (audioDurationSecs - maxDurationSecs).clamp(
      0.0,
      double.infinity,
    );
    final startPositionSecs = _startOffset * scrollableAudioSecs;

    // Calculate clip boundaries
    final clipStart = Duration(
      milliseconds: (startPositionSecs * 1000).toInt(),
    );
    // End is either maxDuration after start, or end of audio
    final clipEndSecs = (startPositionSecs + maxDurationSecs).clamp(
      0.0,
      audioDurationSecs,
    );
    final clipEnd = Duration(milliseconds: (clipEndSecs * 1000).toInt());

    // Create the appropriate audio source
    AudioSource audioSource;
    if (sound.isBundled && sound.assetPath != null) {
      audioSource = ClippingAudioSource(
        child: AudioSource.asset(sound.assetPath!),
        start: clipStart,
        end: clipEnd,
      );
    } else if (sound.url != null) {
      audioSource = ClippingAudioSource(
        child: AudioSource.uri(Uri.parse(sound.url!)),
        start: clipStart,
        end: clipEnd,
      );
    } else {
      Log.warning(
        'No audio source available for sound: ${sound.id}',
        name: 'VideoAudioEditorTimingScreen',
      );
      return;
    }

    await _audioPlayer.setAudioSource(audioSource);
  }

  void _onFlingUpdate() {
    setState(() {
      _startOffset = _flingController.value.clamp(0.0, 1.0);
    });
    // Play audio at end of fling (when velocity approaches 0)
    if (_flingController.velocity.abs() < 0.001) {
      _resumeAudioAfterDrag();
    }
  }

  void _handleFling(double velocity) {
    // If velocity is too low, just play audio immediately
    if (velocity.abs() < 0.01) {
      _resumeAudioAfterDrag();
      return;
    }

    // Convert velocity to offset units (normalized 0-1 range)
    // Positive velocity = moving right/forward in audio
    final simulation = FrictionSimulation(
      _friction,
      _startOffset,
      velocity,
    );
    _flingController.animateWith(simulation);
  }

  void _handleOffsetChanged(double offset) {
    _flingController.stop();
    setState(() {
      _startOffset = offset;
    });
  }

  /// Pauses audio playback when dragging starts.
  void _handleDragStart() {
    _audioPlayer.pause();
  }

  /// Resumes audio playback after dragging ends.
  /// Called from onDragEnd - actual resume happens in _handleFling.
  void _handleDragEnd() {
    // Audio resume is handled by _handleFling / _onFlingUpdate
  }

  /// Resumes audio after drag/fling is complete.
  Future<void> _resumeAudioAfterDrag() async {
    await _setClippedAudioSource();
    await _audioPlayer.play();
  }

  void _extractWaveform() {
    final sound = widget.sound;

    if (sound.isBundled && sound.assetPath != null) {
      _waveformBloc.add(
        SoundWaveformExtract(
          path: sound.assetPath!,
          soundId: sound.id,
          isAsset: true,
        ),
      );
    } else if (sound.url != null) {
      _waveformBloc.add(
        SoundWaveformExtract(
          path: sound.url!,
          soundId: sound.id,
        ),
      );
    }
  }

  Future<void> _deleteAudio() async {
    await _audioPlayer.stop();
    if (mounted) context.pop<AudioTimingResult>(const AudioTimingDeleted());
  }

  Future<void> _confirmSelection() async {
    await _audioPlayer.stop();
    // Calculate the actual start time from the normalized offset
    final audioDurationSecs = _audioDuration ?? 0;
    final maxDurationSecs =
        VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;
    final scrollableAudioSecs = (audioDurationSecs - maxDurationSecs).clamp(
      0.0,
      double.infinity,
    );
    final startTimeMs = (_startOffset * scrollableAudioSecs * 1000).toInt();
    final updatedSound = widget.sound.copyWith(
      startOffset: Duration(milliseconds: startTimeMs),
    );
    if (mounted) {
      context.pop<AudioTimingResult>(AudioTimingConfirmed(updatedSound));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _waveformBloc,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                    _TopBar(
                      sound: widget.sound,
                      onDelete: _deleteAudio,
                      onConfirm: _confirmSelection,
                    ),

                    const Spacer(),

                    // Bottom controls
                    _BottomControls(
                      startOffset: _startOffset,
                      audioDuration: _audioDuration,
                      onOffsetChanged: _handleOffsetChanged,
                      onFling: _handleFling,
                      onDragStart: _handleDragStart,
                      onDragEnd: _handleDragEnd,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top navigation bar with delete button, audio chip, and confirm button.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.sound,
    required this.onDelete,
    required this.onConfirm,
  });

  final AudioEvent sound;
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

          // Audio chip (centered, flexible) - display only, not interactive
          Flexible(
            child: IgnorePointer(
              child: VideoEditorAudioChip(
                selectedSound: sound,
                onSoundChanged: (_) {},
              ),
            ),
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
    required this.onFling,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final double startOffset;

  /// Audio duration in seconds, or null if unknown.
  final double? audioDuration;
  final ValueChanged<double> onOffsetChanged;
  final ValueChanged<double> onFling;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  /// Calculates the selection width ratio based on video maxDuration vs audio duration.
  ///
  /// The selection always represents [VideoEditorConstants.maxDuration] (6.3s).
  /// - If audio is shorter than maxDuration: returns 1.0 (100% width, fills entire area)
  /// - If audio is longer: returns the proportional ratio (e.g., 33% for ~19s audio)
  /// - Minimum 10% to keep the selection visible and draggable
  double get _selectionWidthRatio {
    final audioDurationSecs = audioDuration;
    if (audioDurationSecs == null || audioDurationSecs <= 0) {
      return 1.0; // Unknown duration, assume full width
    }

    final maxDurationSecs =
        VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;

    // If audio is shorter than video max duration, use full width (100%)
    if (audioDurationSecs <= maxDurationSecs) {
      return 1.0;
    }

    // Ratio of video duration to audio duration, clamped to [0.1, 1.0]
    return (maxDurationSecs / audioDurationSecs).clamp(0.1, 1.0);
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

        const SizedBox(height: 28),

        // Video duration timeline (top bar with green segment)
        _VideoDurationTimeline(
          startOffset: startOffset,
          selectionWidthRatio: selectionRatio,
          audioDuration: audioDuration,
          onOffsetChanged: onOffsetChanged,
          onFling: onFling,
          onDragStart: onDragStart,
          onDragEnd: onDragEnd,
        ),

        const SizedBox(height: 18),

        // Audio waveform with draggable selection
        _AudioWaveformSelector(
          startOffset: startOffset,
          selectionWidthRatio: selectionRatio,
          audioDuration: audioDuration,
          onOffsetChanged: onOffsetChanged,
          onFling: onFling,
          onDragStart: onDragStart,
          onDragEnd: onDragEnd,
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
    required this.audioDuration,
    required this.onOffsetChanged,
    required this.onFling,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final double startOffset;

  /// The ratio of the segment width to the total timeline width.
  final double selectionWidthRatio;

  /// Audio duration in seconds, or null if unknown.
  final double? audioDuration;

  final ValueChanged<double> onOffsetChanged;
  final ValueChanged<double> onFling;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width - 32;
    final segmentWidth = screenWidth * selectionWidthRatio;

    // Calculate scrollable distance based on audio duration
    final maxDurationSecs =
        VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;
    final audioDurationSecs = audioDuration ?? 0;

    // Short audio: no scrolling (segment fills timeline relative to audio)
    // Long audio: scrollable distance proportional to excess audio
    final double maxScrollableDistance;
    if (audioDurationSecs <= 0 || audioDurationSecs <= maxDurationSecs) {
      maxScrollableDistance = 0;
    } else {
      maxScrollableDistance = screenWidth - segmentWidth;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => onDragStart(),
      onHorizontalDragUpdate: (details) {
        // Don't allow scrolling if selection fills the timeline
        if (maxScrollableDistance < 1) return;

        final delta = details.delta.dx;
        // Dragging right increases offset (moves segment right)
        final newOffset = (startOffset + delta / maxScrollableDistance).clamp(
          0.0,
          1.0,
        );
        onOffsetChanged(newOffset);
      },
      onHorizontalDragEnd: (details) {
        onDragEnd();
        if (maxScrollableDistance < 1) {
          // No scrolling possible, but still resume audio
          onFling(0);
          return;
        }
        // Convert velocity from pixels to normalized offset units
        final velocityInOffset =
            details.primaryVelocity! / maxScrollableDistance / 1000;
        onFling(velocityInOffset);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: kMinInteractiveDimension,
          child: Center(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: VineTheme.scrim65,
                borderRadius: .circular(4),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: startOffset * maxScrollableDistance,
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
            ),
          ),
        ),
      ),
    );
  }
}

/// Audio waveform with draggable green selection area.
class _AudioWaveformSelector extends StatelessWidget {
  const _AudioWaveformSelector({
    required this.startOffset,
    required this.selectionWidthRatio,
    required this.audioDuration,
    required this.onOffsetChanged,
    required this.onFling,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final double startOffset;

  /// The ratio of the selection width to the total waveform width.
  final double selectionWidthRatio;

  /// Audio duration in seconds, or null if unknown.
  final double? audioDuration;
  final ValueChanged<double> onOffsetChanged;
  final ValueChanged<double> onFling;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width - 32;
    // Selection area represents portion of audio that fits video duration
    final selectionWidth = screenWidth * selectionWidthRatio;
    // Selection is always centered
    final selectionLeft = (screenWidth - selectionWidth) / 2;

    // Calculate actual waveform width based on audio duration
    final double fullWaveformWidth;
    final maxDurationSecs =
        VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;
    final audioDurationSecs = audioDuration ?? 0;

    if (audioDurationSecs <= 0 || audioDurationSecs <= maxDurationSecs) {
      // Short audio: waveform fits exactly within selection
      fullWaveformWidth = selectionWidth;
    } else {
      // Long audio: waveform extends beyond selection proportionally
      fullWaveformWidth =
          selectionWidth * (audioDurationSecs / maxDurationSecs);
    }

    // Calculate how far the waveform can scroll
    final maxScrollableDistance = (fullWaveformWidth - selectionWidth).clamp(
      0.0,
      double.infinity,
    );
    // Waveform position: at offset 0, waveform starts at selection left edge
    // at offset 1, waveform ends at selection right edge
    final waveformLeft = selectionLeft - startOffset * maxScrollableDistance;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => onDragStart(),
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
      onHorizontalDragEnd: (details) {
        onDragEnd();
        if (maxScrollableDistance < 1) {
          // No scrolling possible, but still resume audio
          onFling(0);
          return;
        }
        // Convert velocity from pixels to normalized offset units
        // Invert velocity to match inverted drag direction
        final velocityInOffset =
            -details.primaryVelocity! / maxScrollableDistance / 1000;
        onFling(velocityInOffset);
      },
      child: Container(
        padding: const .fromLTRB(16, 8, 16, 11),
        height: 85,
        color: VineTheme.backgroundColor,
        child: ClipRect(
          child: BlocBuilder<SoundWaveformBloc, SoundWaveformState>(
            builder: (context, waveformState) {
              final (leftChannel, rightChannel) = switch (waveformState) {
                SoundWaveformLoaded(
                  :final leftChannel,
                  :final rightChannel,
                ) =>
                  (leftChannel, rightChannel),
                _ => (null, null),
              };

              return Stack(
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

                  // Scrollable waveform (stereo bars) - offset based on selection
                  Positioned(
                    left: waveformLeft,
                    top: 10,
                    bottom: 10,
                    width: fullWaveformWidth,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(leftChannel != null),
                      tween: Tween(begin: 0, end: 1),
                      duration: WaveformConstants.animationDuration,
                      curve: WaveformConstants.animationCurve,
                      builder: (context, heightFactor, child) {
                        return ClipRRect(
                          borderRadius: .circular(24),
                          child: SizedBox.expand(
                            child: CustomPaint(
                              painter: StereoWaveformPainter(
                                leftChannel: leftChannel ?? Float32List(0),
                                rightChannel: rightChannel,
                                progress: 1.0, // No progress indicator needed
                                activeColor: VineTheme.whiteText,
                                inactiveColor: VineTheme.whiteText,
                                audioDuration: Duration(
                                  milliseconds: ((audioDuration ?? 0) * 1000)
                                      .toInt(),
                                ),
                                maxDuration: VideoEditorConstants.maxDuration,
                                heightFactor: heightFactor,
                              ),
                            ),
                          ),
                        );
                      },
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
              );
            },
          ),
        ),
      ),
    );
  }
}
