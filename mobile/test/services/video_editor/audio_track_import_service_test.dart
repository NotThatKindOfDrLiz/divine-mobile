import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/selected_audio_track.dart';
import 'package:openvine/services/video_editor/audio_track_import_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group(AudioTrackImportService, () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'audio_track_import_service_test_',
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('pickAndImport returns null when picker is cancelled', () async {
      final service = AudioTrackImportService(
        pickAudioFile: () async => null,
        loadAudioDuration: (_) async => const Duration(seconds: 4),
        getDocumentsDirectoryPath: () async => tempDir.path,
        now: () => DateTime(2026),
      );

      final result = await service.pickAndImport();

      expect(result, isNull);
    });

    test('pickAndImport returns null when selected file has no path', () async {
      final service = AudioTrackImportService(
        pickAudioFile: () async => FilePickerResult([
          PlatformFile(name: 'clip.mp3', size: 123),
        ]),
        loadAudioDuration: (_) async => const Duration(seconds: 4),
        getDocumentsDirectoryPath: () async => tempDir.path,
        now: () => DateTime(2026),
      );

      final result = await service.pickAndImport();

      expect(result, isNull);
    });

    test('importFile copies file into app-owned audio storage', () async {
      final sourceFile = File(p.join(tempDir.path, 'My Upload.mp3'))
        ..writeAsBytesSync([0, 1, 2, 3]);
      final now = DateTime(2026, 3, 6, 12, 0, 0, 123, 456);

      final service = AudioTrackImportService(
        loadAudioDuration: (_) async => const Duration(seconds: 7),
        getDocumentsDirectoryPath: () async => tempDir.path,
        now: () => now,
      );

      final track = await service.importFile(
        sourcePath: sourceFile.path,
        originalFileName: 'My Upload.mp3',
      );

      expect(track.sourceType, SelectedAudioTrackSourceType.uploaded);
      expect(track.displayTitle, 'My Upload');
      expect(track.mimeType, 'audio/mpeg');
      expect(track.duration, const Duration(seconds: 7));
      expect(track.sourceStartOffset, Duration.zero);
      expect(track.videoStartOffset, Duration.zero);
      expect(track.addedAudioVolume, 1);
      expect(
        p.dirname(track.localFilePath),
        p.join(tempDir.path, 'audio_tracks'),
      );
      expect(
        p.basename(track.localFilePath),
        '${now.microsecondsSinceEpoch}_My_Upload.mp3',
      );
      expect(File(track.localFilePath).readAsBytesSync(), [0, 1, 2, 3]);
    });

    test(
      'importFile falls back to zero duration and maps m4a mime type',
      () async {
        final sourceFile = File(p.join(tempDir.path, 'voice-note.m4a'))
          ..writeAsBytesSync([4, 5, 6]);

        final service = AudioTrackImportService(
          loadAudioDuration: (_) async => null,
          getDocumentsDirectoryPath: () async => tempDir.path,
          now: () => DateTime(2026, 3, 6, 8, 30),
        );

        final track = await service.importFile(
          sourcePath: sourceFile.path,
        );

        expect(track.displayTitle, 'voice-note');
        expect(track.mimeType, 'audio/mp4');
        expect(track.duration, Duration.zero);
      },
    );
  });
}
