// ABOUTME: Tests for ClipManagerService - business logic for clip operations
// ABOUTME: Validates add, delete, reorder, and thumbnail generation

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/services/clip_manager_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('ClipManagerService', () {
    late ClipManagerService service;

    setUp(() {
      service = ClipManagerService();
    });

    tearDown(() {
      service.dispose();
    });

    test('starts with empty clips', () {
      expect(service.clips, isEmpty);
      expect(service.hasClips, isFalse);
      expect(service.clipCount, equals(0));
    });

    test('addClip adds clip and notifies', () {
      var notified = false;
      service.addListener(() => notified = true);

      final clip = service.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
      );

      expect(service.clips.length, equals(1));
      expect(service.clips[0].id, equals(clip.id));
      expect(notified, isTrue);
    });

    test('addClip returns clip with correct properties', () async {
      final clip = service.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        thumbnailPath: '/path/to/thumb.jpg',
        aspectRatio: model.AspectRatio.square,
      );

      expect(clip.id, isNotNull);
      expect(await clip.video.safeFilePath(), equals('/path/to/video.mp4'));
      expect(clip.duration, equals(const Duration(seconds: 2)));
      expect(clip.thumbnailPath, equals('/path/to/thumb.jpg'));
      expect(clip.aspectRatio, equals(model.AspectRatio.square));
    });

    test('deleteClip removes clip by id', () {
      service.addClip(
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 2),
      );
      service.addClip(
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 1),
      );

      final clipToDelete = service.clips[0].id;
      service.deleteClip(clipToDelete);

      expect(service.clips.length, equals(1));
    });

    test('deleteClip with non-existent id does not crash', () {
      service.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 1),
      );

      expect(() => service.deleteClip('non_existent_id'), returnsNormally);
      expect(service.clips.length, equals(1));
    });

    test('reorderClips updates clip order in list', () {
      final clip1 = service.addClip(
        video: EditorVideo.file('/path/1.mp4'),
        duration: const Duration(seconds: 1),
      );
      final clip2 = service.addClip(
        video: EditorVideo.file('/path/2.mp4'),
        duration: const Duration(seconds: 1),
      );
      final clip3 = service.addClip(
        video: EditorVideo.file('/path/3.mp4'),
        duration: const Duration(seconds: 1),
      );

      // Reverse the order
      service.reorderClips([clip3.id, clip2.id, clip1.id]);

      expect(service.clips[0].id, equals(clip3.id));
      expect(service.clips[1].id, equals(clip2.id));
      expect(service.clips[2].id, equals(clip1.id));
    });

    test('totalDuration sums all clips', () {
      service.addClip(
        video: EditorVideo.file('/path/1.mp4'),
        duration: const Duration(seconds: 2),
      );
      service.addClip(
        video: EditorVideo.file('/path/2.mp4'),
        duration: const Duration(milliseconds: 1500),
      );

      expect(service.totalDuration, equals(const Duration(milliseconds: 3500)));
    });

    test('remainingDuration calculates correctly', () {
      service.addClip(
        video: EditorVideo.file('/path/1.mp4'),
        duration: const Duration(seconds: 2),
      );

      // Max is 6.3s = 6300ms, used is 2000ms, remaining is 4300ms
      expect(
        service.remainingDuration,
        equals(const Duration(milliseconds: 4300)),
      );
    });

    test('canRecordMore is true when under limit', () {
      service.addClip(
        video: EditorVideo.file('/path/1.mp4'),
        duration: const Duration(seconds: 2),
      );

      expect(service.canRecordMore, isTrue);
    });

    test('canRecordMore is false when at limit', () {
      service.addClip(
        video: EditorVideo.file('/path/1.mp4'),
        duration: const Duration(milliseconds: 6300),
      );

      expect(service.canRecordMore, isFalse);
    });

    test('canRecordMore is false when over limit', () {
      service.addClip(
        video: EditorVideo.file('/path/1.mp4'),
        duration: const Duration(milliseconds: 7000),
      );

      expect(service.canRecordMore, isFalse);
      expect(service.remainingDuration, equals(Duration.zero));
    });

    test('updateThumbnail updates clip thumbnail', () {
      final clip = service.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
      );

      service.updateThumbnail(clip.id, '/path/to/thumb.jpg');

      expect(service.clips[0].thumbnailPath, equals('/path/to/thumb.jpg'));
    });

    test('updateThumbnail with non-existent id does not crash', () {
      service.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
      );

      expect(
        () => service.updateThumbnail('non_existent_id', '/path/thumb.jpg'),
        returnsNormally,
      );
    });

    test('updateClipDuration updates clip duration', () {
      final clip = service.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
      );

      service.updateClipDuration(clip.id, const Duration(seconds: 3));

      expect(service.clips[0].duration, equals(const Duration(seconds: 3)));
      expect(service.totalDuration, equals(const Duration(seconds: 3)));
    });

    test('updateClipDuration with non-existent id does not crash', () {
      service.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
      );

      expect(
        () => service.updateClipDuration(
          'non_existent_id',
          const Duration(seconds: 3),
        ),
        returnsNormally,
      );
    });

    test('hasClips returns true when clips exist', () {
      expect(service.hasClips, isFalse);

      service.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 1),
      );

      expect(service.hasClips, isTrue);
    });

    test('clipCount returns correct count', () {
      expect(service.clipCount, equals(0));

      service.addClip(
        video: EditorVideo.file('/path/1.mp4'),
        duration: const Duration(seconds: 1),
      );
      expect(service.clipCount, equals(1));

      service.addClip(
        video: EditorVideo.file('/path/2.mp4'),
        duration: const Duration(seconds: 1),
      );
      expect(service.clipCount, equals(2));
    });

    test('clearAll removes all clips', () {
      service.addClip(
        video: EditorVideo.file('/path/1.mp4'),
        duration: const Duration(seconds: 1),
      );
      service.addClip(
        video: EditorVideo.file('/path/2.mp4'),
        duration: const Duration(seconds: 1),
      );

      service.clearAll();

      expect(service.clips, isEmpty);
      expect(service.hasClips, isFalse);
      expect(service.clipCount, equals(0));
      expect(service.totalDuration, equals(Duration.zero));
    });

    test('clearAll notifies listeners', () {
      var notified = false;
      service.addListener(() => notified = true);

      service.addClip(
        video: EditorVideo.file('/path/1.mp4'),
        duration: const Duration(seconds: 1),
      );

      notified = false; // Reset
      service.clearAll();

      expect(notified, isTrue);
    });

    test('clips list is unmodifiable', () {
      service.addClip(
        video: EditorVideo.file('/path/1.mp4'),
        duration: const Duration(seconds: 1),
      );

      expect(() => (service.clips as List).clear(), throwsUnsupportedError);
    });

    test('addClip generates unique IDs', () {
      final clip1 = service.addClip(
        video: EditorVideo.file('/path/1.mp4'),
        duration: const Duration(seconds: 1),
      );
      final clip2 = service.addClip(
        video: EditorVideo.file('/path/2.mp4'),
        duration: const Duration(seconds: 1),
      );

      expect(clip1.id, isNot(equals(clip2.id)));
    });
  });
}
