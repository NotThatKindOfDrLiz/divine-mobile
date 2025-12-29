// ABOUTME: Riverpod provider for Clip Manager state management
// ABOUTME: Wraps ClipManagerService with reactive state updates

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/services/clip_manager_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

final clipManagerServiceProvider = Provider<ClipManagerService>((ref) {
  final service = ClipManagerService();
  ref.onDispose(() => service.dispose());
  return service;
});

final clipManagerProvider =
    StateNotifierProvider<ClipManagerNotifier, ClipManagerState>((ref) {
      final service = ref.watch(clipManagerServiceProvider);
      return ClipManagerNotifier(service);
    });

class ClipManagerNotifier extends StateNotifier<ClipManagerState> {
  ClipManagerNotifier(this._service) : super(ClipManagerState()) {
    _service.addListener(_updateState);
    _updateState();
  }

  Timer? _recordingDurationTimer;
  Stopwatch _recordStopwatch = Stopwatch();

  final ClipManagerService _service;

  void startRecording() {
    _recordStopwatch
      ..reset()
      ..start();

    // Start timer to update activeRecordingDuration
    _recordingDurationTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        if (_recordStopwatch.isRunning) {
          state = state.copyWith(
            activeRecordingDuration: _recordStopwatch.elapsed,
          );
        }
      },
    );
  }

  void stopRecording() {
    _recordStopwatch.stop();
    _recordingDurationTimer?.cancel();
  }

  void resetRecording() {
    _recordStopwatch.reset();
  }

  void _updateState() {
    state = state.copyWith(
      clips: _service.clips,
      activeRecordingDuration: .zero,
    );
  }

  RecordingClip addClip({
    required EditorVideo video,
    Duration? duration,
    String? thumbnailPath,
    model.AspectRatio? aspectRatio,
  }) {
    final clip = _service.addClip(
      video: video,
      duration:
          duration ??
          Duration(microseconds: _recordStopwatch.elapsedMicroseconds),
      thumbnailPath: thumbnailPath,
      aspectRatio: aspectRatio,
    );
    if (duration == null) {
      resetRecording();
    }
    return clip;
  }

  void deleteClip(String clipId) {
    _service.deleteClip(clipId);
  }

  void reorderClips(List<String> orderedIds) {
    _service.reorderClips(orderedIds);
  }

  void updateThumbnail(String clipId, String thumbnailPath) {
    _service.updateThumbnail(clipId, thumbnailPath);
  }

  void updateClipDuration(String clipId, Duration duration) {
    _service.updateClipDuration(clipId, duration);
  }

  void selectClip(String? clipId) {
    state = state.copyWith(selectedClipId: clipId);
  }

  void setPreviewingClip(String? clipId) {
    state = state.copyWith(previewingClipId: clipId);
  }

  void clearPreview() {
    state = state.copyWith(clearPreview: true);
  }

  void setProcessing(bool processing) {
    state = state.copyWith(isProcessing: processing);
  }

  void setError(String? message) {
    state = state.copyWith(errorMessage: message, clearError: message == null);
  }

  void toggleMuteOriginalAudio() {
    state = state.copyWith(muteOriginalAudio: !state.muteOriginalAudio);
  }

  void setMuteOriginalAudio(bool mute) {
    state = state.copyWith(muteOriginalAudio: mute);
  }

  void removeLastClip() {
    final lastClip = _service.clips.last;
    _service.deleteClip(lastClip.id);
  }

  void clearAll() {
    _service.clearAll();
    state = ClipManagerState();
  }

  void saveClipToLibrary() {
    // TODO(@hm21): Implement save to Library feature.
    // Ask design-team first if only the last clip or all clips?
  }

  @override
  void dispose() {
    _recordStopwatch.stop();
    _service.removeListener(_updateState);
    _recordingDurationTimer?.cancel();
    super.dispose();
  }
}
