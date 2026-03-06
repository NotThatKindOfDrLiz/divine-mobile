// ABOUTME: Tests for SelectedAudioTrack local editor audio model.
// ABOUTME: Validates JSON persistence, equality, and copyWith behavior.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/selected_audio_track.dart';
import 'package:openvine/utils/path_resolver.dart';

void main() {
  group('SelectedAudioTrack', () {
    const track = SelectedAudioTrack(
      id: 'track-1',
      localFilePath: '/documents/audio_tracks/voiceover.m4a',
      displayTitle: 'voiceover.m4a',
      mimeType: 'audio/mp4',
      duration: Duration(seconds: 4),
      sourceStartOffset: Duration(milliseconds: 250),
      videoStartOffset: Duration(seconds: 1),
      addedAudioVolume: 0.8,
    );

    test('creates instance with expected values', () {
      expect(track.id, equals('track-1'));
      expect(track.sourceType, equals(SelectedAudioTrackSourceType.uploaded));
      expect(
        track.localFilePath,
        equals('/documents/audio_tracks/voiceover.m4a'),
      );
      expect(track.displayTitle, equals('voiceover.m4a'));
      expect(track.mimeType, equals('audio/mp4'));
      expect(track.duration, const Duration(seconds: 4));
      expect(track.sourceStartOffset, const Duration(milliseconds: 250));
      expect(track.videoStartOffset, const Duration(seconds: 1));
      expect(track.addedAudioVolume, 0.8);
    });

    test('copyWith updates only specified fields', () {
      final updated = track.copyWith(
        displayTitle: 'updated.m4a',
        addedAudioVolume: 0.5,
      );

      expect(updated.displayTitle, equals('updated.m4a'));
      expect(updated.addedAudioVolume, 0.5);
      expect(updated.localFilePath, equals(track.localFilePath));
      expect(updated.sourceStartOffset, equals(track.sourceStartOffset));
    });

    test('copyWith can clear mimeType', () {
      final updated = track.copyWith(clearMimeType: true);

      expect(updated.mimeType, isNull);
      expect(updated.displayTitle, equals(track.displayTitle));
    });

    test('toJson and fromJson preserve persisted fields', () {
      final json = track.toJson();
      final restored = SelectedAudioTrack.fromJson(json, '/new-documents');

      expect(restored.id, equals(track.id));
      expect(restored.sourceType, equals(track.sourceType));
      expect(
        restored.localFilePath,
        equals('/new-documents/audio_tracks/voiceover.m4a'),
      );
      expect(restored.displayTitle, equals(track.displayTitle));
      expect(restored.mimeType, equals(track.mimeType));
      expect(restored.duration, equals(track.duration));
      expect(restored.sourceStartOffset, equals(track.sourceStartOffset));
      expect(restored.videoStartOffset, equals(track.videoStartOffset));
      expect(restored.addedAudioVolume, equals(track.addedAudioVolume));
    });

    test(
      'fromJson falls back to audio_tracks directory for legacy basenames',
      () async {
        final documentsPath = await getDocumentsPath();
        final audioDir = Directory('$documentsPath/audio_tracks')
          ..createSync(recursive: true);
        final audioFile = File('${audioDir.path}/legacy-track.m4a')
          ..writeAsStringSync('legacy');
        addTearDown(() async {
          if (audioFile.existsSync()) {
            await audioFile.delete();
          }
        });

        final restored = SelectedAudioTrack.fromJson({
          'id': 'legacy-track',
          'localFilePath': 'legacy-track.m4a',
          'displayTitle': 'Legacy Track',
          'durationMs': 4000,
        }, documentsPath);

        expect(restored.localFilePath, audioFile.path);
      },
    );
  });
}
