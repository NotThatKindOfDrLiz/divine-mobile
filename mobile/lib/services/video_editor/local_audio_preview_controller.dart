// ABOUTME: Controller for local audio preview on the upload-first timing screen.
// ABOUTME: Encapsulates audio loading, bounded preview playback, and volume sync.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvine/models/video_editor/selected_audio_track.dart';
import 'package:openvine/services/video_editor/video_editor_audio_utils.dart';
import 'package:sound_service/sound_service.dart';

/// Manages bounded preview playback for the local audio timing screen.
class LocalAudioPreviewController {
  /// Creates a preview controller.
  LocalAudioPreviewController({AudioPlaybackService? audioService})
    : _audioService = audioService ?? AudioPlaybackService() {
    _positionSubscription = _audioService.positionStream.listen(_onPosition);
  }

  final AudioPlaybackService _audioService;

  /// Exposes whether preview playback is active.
  final ValueNotifier<bool> isPlaying = ValueNotifier(false);

  StreamSubscription<Duration>? _positionSubscription;
  SelectedAudioTrack? _track;
  Duration? _videoDuration;
  String? _loadedFilePath;
  bool _isDisposed = false;

  /// Loads or updates the current track for preview.
  Future<void> loadTrack({
    required SelectedAudioTrack track,
    required Duration videoDuration,
  }) async {
    if (_isDisposed) return;

    final previousPath = _loadedFilePath;
    final previousStartOffset = _track?.sourceStartOffset;
    final shouldReloadFile = previousPath != track.localFilePath;
    final shouldRestartPreview =
        isPlaying.value && previousStartOffset != track.sourceStartOffset;

    _track = track;
    _videoDuration = videoDuration;

    await _audioService.configureForMixedPlayback();

    if (shouldReloadFile) {
      if (isPlaying.value) {
        isPlaying.value = false;
      }
      await _audioService.loadAudioFromFile(track.localFilePath);
      _loadedFilePath = track.localFilePath;
    }

    await _audioService.setVolume(track.addedAudioVolume);

    if (shouldReloadFile || !isPlaying.value) {
      await _audioService.seek(track.sourceStartOffset);
    } else if (shouldRestartPreview) {
      await _audioService.pause();
      await _audioService.seek(track.sourceStartOffset);
      await _audioService.play();
    }
  }

  /// Toggles bounded preview playback for the loaded track.
  Future<void> togglePreview() async {
    final track = _track;
    if (_isDisposed || track == null) return;

    if (isPlaying.value) {
      await pausePreview(resetToStart: true);
      return;
    }

    await _audioService.seek(track.sourceStartOffset);
    await _audioService.play();
    isPlaying.value = true;
  }

  /// Pauses preview playback.
  Future<void> pausePreview({bool resetToStart = false}) async {
    final track = _track;
    if (_isDisposed || track == null) return;

    await _audioService.pause();
    if (resetToStart) {
      await _audioService.seek(track.sourceStartOffset);
    }
    isPlaying.value = false;
  }

  void _onPosition(Duration position) {
    final track = _track;
    final videoDuration = _videoDuration;
    if (_isDisposed ||
        !isPlaying.value ||
        track == null ||
        videoDuration == null) {
      return;
    }

    final previewEnd = calculateSelectedAudioPreviewEnd(
      track: track,
      videoDuration: videoDuration,
    );
    if (position < previewEnd) return;

    unawaited(pausePreview(resetToStart: true));
  }

  /// Disposes preview resources.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await pausePreview();
    await _positionSubscription?.cancel();
    isPlaying.dispose();
    await _audioService.dispose();
  }
}
