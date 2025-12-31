// ABOUTME: Riverpod provider for Clip Manager state management
// ABOUTME: Manages recorded video clips with modern Notifier pattern

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

final clipManagerProvider =
    NotifierProvider<ClipManagerNotifier, ClipManagerState>(
      ClipManagerNotifier.new,
    );

class ClipManagerNotifier extends Notifier<ClipManagerState> {
  static const Duration maxDuration = Duration(milliseconds: 6_300);

  int _clipCounter = 0;
  Timer? _recordingDurationTimer;
  final _recordStopwatch = Stopwatch();
  final List<RecordingClip> _clips = [];

  @override
  ClipManagerState build() {
    ref.onDispose(() {
      _recordingDurationTimer?.cancel();
      _recordStopwatch.stop();
      _clips.clear();
    });
    return ClipManagerState();
  }

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

  RecordingClip addClip({
    required EditorVideo video,
    Duration? duration,
    String? thumbnailPath,
    model.AspectRatio? aspectRatio,
  }) {
    final clip = RecordingClip(
      id: 'clip_${DateTime.now().millisecondsSinceEpoch}_${_clipCounter++}',
      video: video,
      duration:
          duration ??
          Duration(microseconds: _recordStopwatch.elapsedMicroseconds),
      recordedAt: .now(),
      thumbnailPath: thumbnailPath,
      aspectRatio: aspectRatio,
    );

    _clips.add(clip);
    Log.info(
      '📎 Added clip: ${clip.id}, duration: ${clip.durationInSeconds}s',
      name: 'ClipManagerNotifier',
      category: LogCategory.video,
    );

    state = state.copyWith(clips: List.unmodifiable(_clips));

    if (duration == null) {
      resetRecording();
    }
    return clip;
  }

  void deleteClip(String clipId) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index == -1) {
      Log.warning(
        '📎 Clip not found for deletion: $clipId',
        name: 'ClipManagerNotifier',
        category: LogCategory.video,
      );
      return;
    }

    _clips.removeAt(index);
    Log.info(
      '📎 Deleted clip: $clipId, remaining: ${_clips.length}',
      name: 'ClipManagerNotifier',
      category: LogCategory.video,
    );
    state = state.copyWith(clips: List.unmodifiable(_clips));
  }

  void reorderClips(List<String> orderedIds) {
    final reorderedClips = <RecordingClip>[];
    for (final id in orderedIds) {
      final clip = _clips.firstWhere((c) => c.id == id);
      reorderedClips.add(clip);
    }
    _clips
      ..clear()
      ..addAll(reorderedClips);
    Log.info(
      '📎 Reordered ${orderedIds.length} clips',
      name: 'ClipManagerNotifier',
      category: LogCategory.video,
    );
    state = state.copyWith(clips: List.unmodifiable(_clips));
  }

  void updateThumbnail(String clipId, String thumbnailPath) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(thumbnailPath: thumbnailPath);
      state = state.copyWith(clips: List.unmodifiable(_clips));
    }
  }

  void updateClipDuration(String clipId, Duration duration) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(duration: duration);
      state = state.copyWith(clips: List.unmodifiable(_clips));
    }
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
    if (_clips.isEmpty) return;
    final lastClip = _clips.last;
    deleteClip(lastClip.id);
  }

  void clearAll() {
    _clips.clear();
    Log.info(
      '📎 Cleared all clips',
      name: 'ClipManagerNotifier',
      category: LogCategory.video,
    );
    state = ClipManagerState();
  }

  void saveClipToLibrary() {
    // TODO(@hm21): Implement save to Library feature.
    // Ask design-team first if only the last clip or all clips?
  }
}
