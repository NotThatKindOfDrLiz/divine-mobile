// ABOUTME: Tests for DivineVideoDraft uploaded local audio persistence.
// ABOUTME: Covers new selectedAudioTrack fields and backward compatibility.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/selected_audio_track.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _testClip() => DivineVideoClip(
  id: 'test_clip',
  video: EditorVideo.file('/path/to/video.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2025),
  targetAspectRatio: AspectRatio.square,
  originalAspectRatio: 9 / 16,
);

void main() {
  group('DivineVideoDraft selectedAudioTrack', () {
    const track = SelectedAudioTrack(
      id: 'track-1',
      localFilePath: '/documents/audio_tracks/audio.m4a',
      displayTitle: 'audio.m4a',
      mimeType: 'audio/mp4',
      duration: Duration(seconds: 4),
      sourceStartOffset: Duration(milliseconds: 300),
      videoStartOffset: Duration(seconds: 2),
      addedAudioVolume: 0.6,
    );

    test('create stores selectedAudioTrack and originalAudioVolume', () {
      final draft = DivineVideoDraft.create(
        clips: [_testClip()],
        title: 'Test',
        description: '',
        hashtags: const {},
        selectedApproach: 'video',
        originalAudioVolume: 0.35,
        selectedAudioTrack: track,
      );

      expect(draft.selectedAudioTrack, equals(track));
      expect(draft.originalAudioVolume, 0.35);
    });

    test('toJson and fromJson preserve selectedAudioTrack', () {
      final draft = DivineVideoDraft.create(
        clips: [_testClip()],
        title: 'Test',
        description: '',
        hashtags: const {},
        selectedApproach: 'video',
        selectedAudioTrack: track,
      );

      final json = draft.toJson();
      final restored = DivineVideoDraft.fromJson(json, '/new-documents');

      expect(restored.selectedAudioTrack, isNotNull);
      expect(restored.selectedAudioTrack!.id, equals(track.id));
      expect(
        restored.selectedAudioTrack!.localFilePath,
        equals('/new-documents/audio_tracks/audio.m4a'),
      );
      expect(
        restored.selectedAudioTrack!.videoStartOffset,
        equals(track.videoStartOffset),
      );
      expect(
        restored.selectedAudioTrack!.addedAudioVolume,
        equals(track.addedAudioVolume),
      );
      expect(restored.originalAudioVolume, 0.2);
    });

    test('copyWith can update and clear selectedAudioTrack', () {
      final draft = DivineVideoDraft.create(
        clips: [_testClip()],
        title: 'Test',
        description: '',
        hashtags: const {},
        selectedApproach: 'video',
        selectedAudioTrack: track,
      );

      final updated = draft.copyWith(originalAudioVolume: 0.5);
      expect(updated.selectedAudioTrack, equals(track));
      expect(updated.originalAudioVolume, 0.5);

      final cleared = updated.copyWith(clearSelectedAudioTrack: true);
      expect(cleared.selectedAudioTrack, isNull);
    });

    test('older drafts without selectedAudioTrack load with defaults', () {
      final json = {
        'id': 'old_draft',
        'videoFilePath': 'video.mp4',
        'title': 'Old Draft',
        'description': 'Before local audio tracks',
        'hashtags': ['old'],
        'selectedApproach': 'video',
        'createdAt': '2025-01-01T00:00:00.000Z',
        'lastModified': '2025-01-01T00:00:00.000Z',
        'publishStatus': 'draft',
        'publishAttempts': 0,
      };

      final draft = DivineVideoDraft.fromJson(json, '/path/to');

      expect(draft.selectedAudioTrack, isNull);
      expect(draft.originalAudioVolume, 0.2);
    });

    test('older selectedSound payloads remain readable', () {
      final json = {
        'id': 'old_sound_draft',
        'videoFilePath': 'video.mp4',
        'title': 'Old Draft',
        'description': 'Has old sound payload',
        'hashtags': ['old'],
        'selectedApproach': 'video',
        'createdAt': '2025-01-01T00:00:00.000Z',
        'lastModified': '2025-01-01T00:00:00.000Z',
        'publishStatus': 'draft',
        'publishAttempts': 0,
        'selectedSound': {
          'id': 'sound-1',
          'pubkey': 'pubkey-1',
          'createdAt': 123,
          'url': 'https://example.com/sound.m4a',
          'title': 'Old sound',
          'duration': 4.0,
        },
      };

      final draft = DivineVideoDraft.fromJson(json, '/path/to');

      expect(draft.selectedAudioTrack, isNull);
      expect(draft.selectedSound, isNotNull);
      expect(draft.selectedSound!.id, equals('sound-1'));
    });
  });
}
