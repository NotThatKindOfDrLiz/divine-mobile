import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:openvine/models/video_editor/selected_audio_track.dart';
import 'package:openvine/services/video_editor/local_audio_preview_controller.dart';
import 'package:openvine/widgets/stereo_waveform_painter.dart';
import 'package:sound_service/sound_service.dart';

sealed class LocalAudioTimingResult {
  const LocalAudioTimingResult();
}

class LocalAudioTimingConfirmed extends LocalAudioTimingResult {
  const LocalAudioTimingConfirmed({
    required this.track,
    required this.originalAudioVolume,
  });

  final SelectedAudioTrack track;
  final double originalAudioVolume;
}

class LocalAudioTimingDeleted extends LocalAudioTimingResult {
  const LocalAudioTimingDeleted();
}

/// Placement and mix screen for uploaded local audio.
class VideoLocalAudioTimingScreen extends StatefulWidget {
  const VideoLocalAudioTimingScreen({
    required this.track,
    required this.originalAudioVolume,
    required this.videoDuration,
    this.audioServiceFactory,
    super.key,
  });

  final SelectedAudioTrack track;
  final double originalAudioVolume;
  final Duration videoDuration;
  final AudioPlaybackService Function()? audioServiceFactory;

  @override
  State<VideoLocalAudioTimingScreen> createState() =>
      _VideoLocalAudioTimingScreenState();
}

class _VideoLocalAudioTimingScreenState
    extends State<VideoLocalAudioTimingScreen> {
  late final SoundWaveformBloc _waveformBloc;
  late SelectedAudioTrack _track;
  late double _originalAudioVolume;
  LocalAudioPreviewController? _previewController;
  bool _isPreviewPlaying = false;

  bool get _isShortTrack => _track.duration <= widget.videoDuration;

  Duration get _maxPlacementOffset {
    final raw = _isShortTrack
        ? widget.videoDuration - _track.duration
        : _track.duration - widget.videoDuration;
    return raw.isNegative ? Duration.zero : raw;
  }

  double get _placementValueMs {
    final activeOffset = _isShortTrack
        ? _track.videoStartOffset
        : _track.sourceStartOffset;
    return math.min(
      activeOffset.inMilliseconds.toDouble(),
      _maxPlacementOffset.inMilliseconds.toDouble(),
    );
  }

  @override
  void initState() {
    super.initState();
    _track = widget.track;
    _originalAudioVolume = widget.originalAudioVolume;
    _waveformBloc = SoundWaveformBloc()
      ..add(
        SoundWaveformExtract(
          path: _track.localFilePath,
          soundId: _track.id,
          isFile: true,
        ),
      );
  }

  @override
  void dispose() {
    _previewController?.isPlaying.removeListener(_handlePreviewPlaybackChanged);
    unawaited(_previewController?.dispose());
    _waveformBloc.close();
    super.dispose();
  }

  void _onPlacementChanged(double value) {
    final nextOffset = Duration(milliseconds: value.round());

    setState(() {
      _track = _isShortTrack
          ? _track.copyWith(videoStartOffset: nextOffset)
          : _track.copyWith(
              sourceStartOffset: nextOffset,
              videoStartOffset: Duration.zero,
            );
    });
    unawaited(
      _previewController?.loadTrack(
        track: _track,
        videoDuration: widget.videoDuration,
      ),
    );
  }

  void _onAddedAudioVolumeChanged(double value) {
    setState(() {
      _track = _track.copyWith(addedAudioVolume: value);
    });
    unawaited(
      _previewController?.loadTrack(
        track: _track,
        videoDuration: widget.videoDuration,
      ),
    );
  }

  Future<void> _confirmSelection() async {
    context.pop<LocalAudioTimingResult>(
      LocalAudioTimingConfirmed(
        track: _track,
        originalAudioVolume: _originalAudioVolume,
      ),
    );
  }

  void _deleteTrack() {
    context.pop<LocalAudioTimingResult>(const LocalAudioTimingDeleted());
  }

  LocalAudioPreviewController _ensurePreviewController() {
    final existingController = _previewController;
    if (existingController != null) {
      return existingController;
    }

    final controller = LocalAudioPreviewController(
      audioService: widget.audioServiceFactory?.call(),
    );
    controller.isPlaying.addListener(_handlePreviewPlaybackChanged);
    _previewController = controller;
    return controller;
  }

  void _handlePreviewPlaybackChanged() {
    final nextValue = _previewController?.isPlaying.value ?? false;
    if (!mounted || _isPreviewPlaying == nextValue) return;
    setState(() => _isPreviewPlaying = nextValue);
  }

  Future<void> _togglePreview() async {
    final controller = _ensurePreviewController();
    await controller.loadTrack(
      track: _track,
      videoDuration: widget.videoDuration,
    );
    await controller.togglePreview();
  }

  @override
  Widget build(BuildContext context) {
    final maxOffsetMs = _maxPlacementOffset.inMilliseconds.toDouble();
    final instruction = _isShortTrack
        ? 'Move where this audio starts in your video'
        : 'Choose which part of the audio plays with your video';
    final offsetLabel = _isShortTrack
        ? 'Starts at ${_formatDuration(_track.videoStartOffset)}'
        : 'Uses audio from ${_formatDuration(_track.sourceStartOffset)}';

    return BlocProvider.value(
      value: _waveformBloc,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xA6000000)),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      spacing: 12,
                      children: [
                        DivineIconButton(
                          semanticLabel: 'Remove audio',
                          icon: .trash,
                          size: .small,
                          type: .error,
                          onPressed: _deleteTrack,
                        ),
                        Expanded(
                          child: _AudioSummaryChip(title: _track.displayTitle),
                        ),
                        DivineIconButton(
                          semanticLabel: 'Confirm audio placement',
                          icon: .check,
                          size: .small,
                          type: .tertiary,
                          onPressed: _confirmSelection,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: VineTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              instruction,
                              textAlign: TextAlign.center,
                              style: VineTheme.bodyMediumFont(),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              offsetLabel,
                              textAlign: TextAlign.center,
                              style: VineTheme.labelLargeFont(
                                color: VineTheme.vineGreen,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              child: DivineIconButton(
                                semanticLabel: _isPreviewPlaying
                                    ? 'Pause audio preview'
                                    : 'Play audio preview',
                                icon: _isPreviewPlaying ? .pause : .play,
                                size: .small,
                                type: .secondary,
                                onPressed: _togglePreview,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _PlacementTimeline(
                              videoDuration: widget.videoDuration,
                              audioDuration: _track.duration,
                              videoStartOffset: _track.videoStartOffset,
                              sourceStartOffset: _track.sourceStartOffset,
                            ),
                            const SizedBox(height: 18),
                            const _TimelineLabels(),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 76,
                              child: _WaveformPreview(
                                track: _track,
                                videoDuration: widget.videoDuration,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: VineTheme.vineGreen,
                                inactiveTrackColor: VineTheme.scrim65,
                                thumbColor: VineTheme.whiteText,
                                overlayColor: VineTheme.vineGreen.withAlpha(40),
                              ),
                              child: Slider(
                                value: maxOffsetMs <= 0
                                    ? 0.0
                                    : _placementValueMs,
                                max: maxOffsetMs <= 0 ? 1.0 : maxOffsetMs,
                                onChanged: maxOffsetMs <= 0
                                    ? null
                                    : _onPlacementChanged,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Original video audio',
                              style: VineTheme.bodyMediumFont(),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: VineTheme.vineGreen,
                                inactiveTrackColor: VineTheme.scrim65,
                                thumbColor: VineTheme.whiteText,
                              ),
                              child: Slider(
                                value: _originalAudioVolume,
                                onChanged: (value) {
                                  setState(() {
                                    _originalAudioVolume = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Added audio',
                              style: VineTheme.bodyMediumFont(),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: VineTheme.vineGreen,
                                inactiveTrackColor: VineTheme.scrim65,
                                thumbColor: VineTheme.whiteText,
                              ),
                              child: Slider(
                                value: _track.addedAudioVolume,
                                onChanged: _onAddedAudioVolumeChanged,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalMilliseconds = duration.inMilliseconds;
    final seconds = totalMilliseconds / 1000;
    return '${seconds.toStringAsFixed(1)}s';
  }
}

class _AudioSummaryChip extends StatelessWidget {
  const _AudioSummaryChip({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: ShapeDecoration(
        color: VineTheme.scrim15,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DivineIcon(icon: .musicNotesSimple),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.labelLargeFont(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacementTimeline extends StatelessWidget {
  const _PlacementTimeline({
    required this.videoDuration,
    required this.audioDuration,
    required this.videoStartOffset,
    required this.sourceStartOffset,
  });

  final Duration videoDuration;
  final Duration audioDuration;
  final Duration videoStartOffset;
  final Duration sourceStartOffset;

  bool get _isShortTrack => audioDuration <= videoDuration;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final totalDurationMs = (_isShortTrack ? videoDuration : audioDuration)
            .inMilliseconds
            .toDouble();
        final selectedDurationMs =
            (_isShortTrack ? audioDuration : videoDuration).inMilliseconds
                .toDouble();
        final startOffsetMs =
            (_isShortTrack ? videoStartOffset : sourceStartOffset)
                .inMilliseconds
                .toDouble();

        final selectionWidth = totalDurationMs <= 0
            ? width
            : math
                  .max(width * (selectedDurationMs / totalDurationMs), 16)
                  .toDouble();
        final maxLeft = math.max(width - selectionWidth, 0).toDouble();
        final startRatio =
            totalDurationMs <= selectedDurationMs || totalDurationMs <= 0
            ? 0.0
            : startOffsetMs / (totalDurationMs - selectedDurationMs);
        final left = maxLeft * startRatio.clamp(0.0, 1.0);

        return Container(
          height: 10,
          decoration: BoxDecoration(
            color: VineTheme.scrim65,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Stack(
            children: [
              Positioned(
                left: left,
                child: Container(
                  width: selectionWidth,
                  height: 10,
                  decoration: BoxDecoration(
                    color: VineTheme.vineGreen,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: VineTheme.accentYellow,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineLabels extends StatelessWidget {
  const _TimelineLabels();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Start', style: VineTheme.bodySmallFont()),
        const Spacer(),
        Text('End', style: VineTheme.bodySmallFont()),
      ],
    );
  }
}

class _WaveformPreview extends StatelessWidget {
  const _WaveformPreview({
    required this.track,
    required this.videoDuration,
  });

  final SelectedAudioTrack track;
  final Duration videoDuration;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: VineTheme.scrim15,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

              return CustomPaint(
                painter: StereoWaveformPainter(
                  leftChannel: leftChannel ?? Float32List(0),
                  rightChannel: rightChannel,
                  progress: 0,
                  activeColor: VineTheme.whiteText,
                  inactiveColor: VineTheme.whiteText,
                  audioDuration: track.duration,
                  maxDuration: videoDuration,
                  startOffset: track.sourceStartOffset,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
