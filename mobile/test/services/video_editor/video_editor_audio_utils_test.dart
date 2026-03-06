import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/selected_audio_track.dart';
import 'package:openvine/services/video_editor/video_editor_audio_utils.dart';

void main() {
  const track = SelectedAudioTrack(
    id: 'track-1',
    localFilePath: '/documents/audio-track.m4a',
    displayTitle: 'Audio Track',
    duration: Duration(seconds: 5),
  );

  group('resolveEditorPreviewVideoVolume', () {
    test('returns muted volume when editor is muted', () {
      final volume = resolveEditorPreviewVideoVolume(
        isMuted: true,
        selectedAudioTrack: track,
        originalAudioVolume: 0.3,
      );

      expect(volume, 0);
    });

    test('returns full volume when no local track is selected', () {
      final volume = resolveEditorPreviewVideoVolume(
        isMuted: false,
        selectedAudioTrack: null,
        originalAudioVolume: 0.2,
      );

      expect(volume, 1);
    });

    test('returns original audio mix volume when local track is selected', () {
      final volume = resolveEditorPreviewVideoVolume(
        isMuted: false,
        selectedAudioTrack: track,
        originalAudioVolume: 0.35,
      );

      expect(volume, 0.35);
    });
  });

  group('calculateSelectedAudioPreviewEnd', () {
    test('uses full audio duration for short tracks', () {
      final previewEnd = calculateSelectedAudioPreviewEnd(
        track: track,
        videoDuration: const Duration(seconds: 8),
      );

      expect(previewEnd, const Duration(seconds: 5));
    });

    test('caps long-track preview to video duration from source offset', () {
      const longTrack = SelectedAudioTrack(
        id: 'track-2',
        localFilePath: '/documents/audio-track-2.m4a',
        displayTitle: 'Long Track',
        duration: Duration(seconds: 12),
        sourceStartOffset: Duration(seconds: 4),
      );

      final previewEnd = calculateSelectedAudioPreviewEnd(
        track: longTrack,
        videoDuration: const Duration(seconds: 6),
      );

      expect(previewEnd, const Duration(seconds: 10));
    });
  });
}
