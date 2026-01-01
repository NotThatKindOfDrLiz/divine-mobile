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
  List<RecordingClip> get clips => List.unmodifiable(_clips);

  @override
  ClipManagerState build() {
    ref.onDispose(() {
      _recordingDurationTimer?.cancel();
      _recordStopwatch.stop();
      _clips.clear();
    });
    return ClipManagerState();
  }

  /// Start recording timer for active clip duration tracking.
  void startRecording() {
    _recordStopwatch
      ..reset()
      ..start();

    Log.debug(
      '▶️  Recording timer started',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    // Update activeRecordingDuration every 16ms (~60fps).
    // We ONLY rebuild with that logic, the progress inside of the segment-bar.
    _recordingDurationTimer = Timer.periodic(const Duration(milliseconds: 16), (
      _,
    ) {
      if (_recordStopwatch.isRunning) {
        state = state.copyWith(
          activeRecordingDuration: _recordStopwatch.elapsed,
        );
      }
    });
  }

  /// Stop recording timer and freeze duration.
  void stopRecording() {
    _recordStopwatch.stop();
    _recordingDurationTimer?.cancel();

    Log.debug(
      '⏸️  Recording timer stopped at ${_recordStopwatch.elapsed.inMilliseconds}ms',
      name: 'ClipManagerNotifier',
      category: .video,
    );
  }

  /// Reset recording stopwatch to zero.
  void resetRecording() {
    _recordStopwatch.reset();
  }

  /// Add a new recorded clip to the list.
  ///
  /// Returns the created clip with unique ID.
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
      category: .video,
    );

    if (duration == null) {
      resetRecording();
    }
    state = state.copyWith(
      clips: List.unmodifiable(_clips),
      activeRecordingDuration: .zero,
    );

    return clip;
  }

  /// Delete a clip by ID.
  void deleteClip(String clipId) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index == -1) {
      Log.warning(
        '⚠️ Cannot delete - clip not found: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
      return;
    }

    _clips.removeAt(index);
    Log.info(
      '🗑️  Deleted clip: $clipId (${_clips.length} remaining)',
      name: 'ClipManagerNotifier',
      category: .video,
    );
    state = state.copyWith(clips: List.unmodifiable(_clips));
  }

  /// Reorder clips by providing ordered list of IDs.
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
      category: .video,
    );
    state = state.copyWith(clips: List.unmodifiable(_clips));
  }

  /// Update thumbnail path for a clip.
  void updateThumbnail(String clipId, String thumbnailPath) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(thumbnailPath: thumbnailPath);
      state = state.copyWith(clips: List.unmodifiable(_clips));
      Log.debug(
        '🖼️  Updated thumbnail for clip: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Cannot update thumbnail - clip not found: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    }
  }

  /// Update duration for a clip (from metadata extraction).
  void updateClipDuration(String clipId, Duration duration) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(duration: duration);
      state = state.copyWith(clips: List.unmodifiable(_clips));
      Log.debug(
        '⏱️  Updated duration for clip: $clipId → ${duration.inMilliseconds}ms',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Cannot update duration - clip not found: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    }
  }

  /// Select a clip for editing.
  void selectClip(String? clipId) {
    state = state.copyWith(selectedClipId: clipId);
  }

  /// Set clip for preview playback.
  void setPreviewingClip(String? clipId) {
    state = state.copyWith(previewingClipId: clipId);
  }

  /// Clear preview state.
  void clearPreview() {
    state = state.copyWith(clearPreview: true);
  }

  /// Set processing state (e.g. exporting).
  void setProcessing(bool processing) {
    state = state.copyWith(isProcessing: processing);
  }

  /// Set or clear error message.
  void setError(String? message) {
    state = state.copyWith(errorMessage: message, clearError: message == null);
  }

  /// Toggle original audio mute state.
  void toggleMuteOriginalAudio() {
    state = state.copyWith(muteOriginalAudio: !state.muteOriginalAudio);
  }

  /// Set original audio mute state.
  void setMuteOriginalAudio(bool mute) {
    state = state.copyWith(muteOriginalAudio: mute);
  }

  /// Remove the most recent clip (undo last recording).
  void removeLastClip() {
    if (_clips.isEmpty) {
      Log.debug(
        'Cannot remove last clip - no clips available',
        name: 'ClipManagerNotifier',
        category: .video,
      );
      return;
    }
    final lastClip = _clips.last;
    deleteClip(lastClip.id);
  }

  /// Remove all clips and reset state.
  void clearAll() {
    _clips.clear();
    Log.info(
      '📎 Cleared all clips',
      name: 'ClipManagerNotifier',
      category: .video,
    );
    state = ClipManagerState();
  }

  /// Save clip(s) to device library.
  ///
  /// TODO(@hm21): Implement save to Library feature.
  /// Ask design-team first if only the last clip or all clips?
  void saveClipToLibrary() {
    Log.info(
      '💾 Save to library requested (not yet implemented)',
      name: 'ClipManagerNotifier',
      category: .video,
    );
  }
}
