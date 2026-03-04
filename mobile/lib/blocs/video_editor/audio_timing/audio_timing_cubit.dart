// ABOUTME: Cubit for managing audio timing/offset selection in the video editor.
// ABOUTME: Handles audio playback, clipping, and offset normalization.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:sound_service/sound_service.dart';

part 'audio_timing_state.dart';

/// Cubit for managing audio timing state and playback in the video editor.
///
/// Handles:
/// - Audio playback with clipped source (looped)
/// - Start offset normalization (0.0-1.0 range)
/// - Audio clipping calculation based on offset
/// - Pause/resume during drag interactions
///
/// The fling physics animation remains in the widget layer since it
/// requires a [TickerProvider].
class AudioTimingCubit extends Cubit<AudioTimingState> {
  /// Creates an [AudioTimingCubit].
  ///
  /// The [sound] is the audio event to edit timing for.
  /// An optional [audioPlayer] can be injected for testing.
  AudioTimingCubit({
    required AudioEvent sound,
    AudioPlayer? audioPlayer,
  }) : _sound = sound,
       _audioPlayer = audioPlayer ?? AudioPlayer(),
       super(const AudioTimingState());

  final AudioEvent _sound;
  final AudioPlayer _audioPlayer;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  static const _logName = 'AudioTimingCubit';

  /// Maximum video duration in seconds.
  static double get _maxDurationSecs =>
      VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;

  /// The scrollable audio range in seconds.
  ///
  /// This is the amount of audio that extends beyond the video duration.
  /// Returns 0 if audio is shorter than the video duration.
  double get _scrollableAudioSecs {
    final audioDuration = state.audioDuration ?? 0;
    return (audioDuration - _maxDurationSecs).clamp(0.0, double.infinity);
  }

  /// Initializes the cubit: computes initial offset, starts playback.
  ///
  /// Should be called once after the cubit is created, typically in
  /// a post-frame callback.
  Future<void> initialize() async {
    final audioDuration = _sound.duration ?? 0;

    // Restore previous selection offset (normalized 0-1)
    var initialOffset = 0.0;
    final scrollableAudioSecs = (audioDuration - _maxDurationSecs).clamp(
      0.0,
      double.infinity,
    );
    if (scrollableAudioSecs > 0) {
      final startTimeSecs = _sound.startOffset.inMilliseconds / 1000.0;
      initialOffset = (startTimeSecs / scrollableAudioSecs).clamp(0.0, 1.0);
    }

    emit(
      AudioTimingState(
        startOffset: initialOffset,
        audioDuration: audioDuration,
      ),
    );

    // Listen for audio completion to restart loop
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(
      _onPlayerStateChanged,
    );

    await _loadAndPlayAudio();
  }

  /// Updates the start offset (e.g. from drag or fling animation).
  void updateOffset(double offset) {
    emit(state.copyWith(startOffset: offset.clamp(0.0, 1.0)));
  }

  /// Pauses audio playback (e.g. when drag starts).
  Future<void> pausePlayback() async {
    await _audioPlayer.pause();
    emit(state.copyWith(isPlaying: false));
  }

  /// Resumes audio playback from the current offset.
  ///
  /// Re-creates the clipped audio source to match the current offset
  /// and starts playback.
  Future<void> resumePlayback() async {
    await _setClippedAudioSource();
    await _audioPlayer.play();
    emit(state.copyWith(isPlaying: true));
  }

  /// Stops audio playback completely.
  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
    emit(state.copyWith(isPlaying: false));
  }

  /// Calculates the [Duration] start offset for the confirmed selection.
  ///
  /// Converts the normalized offset (0.0-1.0) back to an actual
  /// time position in the audio track.
  Duration calculateStartOffset() {
    final startTimeMs = (state.startOffset * _scrollableAudioSecs * 1000)
        .toInt();
    return Duration(milliseconds: startTimeMs);
  }

  /// Called when player state changes — handles looping.
  void _onPlayerStateChanged(PlayerState playerState) {
    // When playback completes, restart from the beginning
    if (playerState.processingState == ProcessingState.completed) {
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
      emit(state.copyWith(isPlaying: true));
    } catch (e, s) {
      Log.error(
        'Failed to load audio: $e',
        name: _logName,
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Creates a clipped audio source for the current selection.
  Future<void> _setClippedAudioSource() async {
    final audioDurationSecs = state.audioDuration ?? 0;
    if (audioDurationSecs <= 0) return;

    final startPositionSecs = state.startOffset * _scrollableAudioSecs;

    // Calculate clip boundaries
    final clipStart = Duration(
      milliseconds: (startPositionSecs * 1000).toInt(),
    );
    // End is either maxDuration after start, or end of audio
    final clipEndSecs = (startPositionSecs + _maxDurationSecs).clamp(
      0.0,
      audioDurationSecs,
    );
    final clipEnd = Duration(milliseconds: (clipEndSecs * 1000).toInt());

    // Create the appropriate audio source
    AudioSource audioSource;
    if (_sound.isBundled && _sound.assetPath != null) {
      audioSource = ClippingAudioSource(
        child: AudioSource.asset(_sound.assetPath!),
        start: clipStart,
        end: clipEnd,
      );
    } else if (_sound.url != null) {
      audioSource = ClippingAudioSource(
        child: AudioSource.uri(Uri.parse(_sound.url!)),
        start: clipStart,
        end: clipEnd,
      );
    } else {
      Log.warning(
        'No audio source available for sound: ${_sound.id}',
        name: _logName,
      );
      return;
    }

    await _audioPlayer.setAudioSource(audioSource);
  }

  @override
  Future<void> close() async {
    await _playerStateSubscription?.cancel();
    await _audioPlayer.dispose();
    return super.close();
  }
}
