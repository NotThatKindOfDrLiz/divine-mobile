// ABOUTME: Service for managing recorded video clips in the Clip Manager
// ABOUTME: Handles add, delete, reorder operations with ChangeNotifier pattern

import 'package:flutter/foundation.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class ClipManagerService extends ChangeNotifier {
  final List<RecordingClip> _clips = [];
  int _clipCounter = 0;

  List<RecordingClip> get clips => List.unmodifiable(_clips);

  bool get hasClips => _clips.isNotEmpty;

  int get clipCount => _clips.length;

  Duration get totalDuration {
    return _clips.fold(Duration.zero, (sum, clip) => sum + clip.duration);
  }

  static const Duration maxDuration = Duration(milliseconds: 6300);

  Duration get remainingDuration {
    final remaining = maxDuration - totalDuration;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get canRecordMore => remainingDuration > Duration.zero;

  RecordingClip addClip({
    required EditorVideo video,
    required Duration duration,
    String? thumbnailPath,
    model.AspectRatio? aspectRatio,
  }) {
    final clip = RecordingClip(
      id: 'clip_${DateTime.now().millisecondsSinceEpoch}_${_clipCounter++}',
      video: video,
      duration: duration,
      recordedAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
      aspectRatio: aspectRatio,
    );

    _clips.add(clip);
    Log.info(
      '📎 Added clip: ${clip.id}, duration: ${clip.durationInSeconds}s',
      name: 'ClipManagerService',
    );
    notifyListeners();

    return clip;
  }

  void deleteClip(String clipId) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index == -1) {
      Log.warning(
        '📎 Clip not found for deletion: $clipId',
        name: 'ClipManagerService',
      );
      return;
    }

    _clips.removeAt(index);
    Log.info(
      '📎 Deleted clip: $clipId, remaining: ${_clips.length}',
      name: 'ClipManagerService',
    );
    notifyListeners();
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
      name: 'ClipManagerService',
    );
    notifyListeners();
  }

  void updateThumbnail(String clipId, String thumbnailPath) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(thumbnailPath: thumbnailPath);
      notifyListeners();
    }
  }

  void updateClipDuration(String clipId, Duration duration) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(duration: duration);
      notifyListeners();
    }
  }

  void clearAll() {
    _clips.clear();
    Log.info('📎 Cleared all clips', name: 'ClipManagerService');
    notifyListeners();
  }

  @override
  void dispose() {
    _clips.clear();
    super.dispose();
  }
}
