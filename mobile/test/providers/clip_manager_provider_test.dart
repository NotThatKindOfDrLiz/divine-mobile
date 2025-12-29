// ABOUTME: Tests for ClipManagerProvider - Riverpod state management
// ABOUTME: Validates state updates and provider lifecycle

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('ClipManagerProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has no clips', () {
      final state = container.read(clipManagerProvider);

      expect(state.clips, isEmpty);
      expect(state.hasClips, isFalse);
    });

    test('addClip updates state with new clip', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
      );

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
      expect(state.totalDuration, equals(const Duration(seconds: 2)));
    });

    test('deleteClip removes clip from state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 2),
      );
      notifier.addClip(
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 1),
      );

      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.deleteClip(clipId);

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
    });

    test('setPreviewingClip updates preview state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
      );

      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.setPreviewingClip(clipId);

      final state = container.read(clipManagerProvider);
      expect(state.previewingClipId, equals(clipId));
    });

    test('clearPreview removes preview state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
      );
      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.setPreviewingClip(clipId);
      notifier.clearPreview();

      final state = container.read(clipManagerProvider);
      expect(state.previewingClipId, isNull);
    });

    test('selectClip updates selected clip state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
      );
      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.selectClip(clipId);

      final state = container.read(clipManagerProvider);
      expect(state.selectedClipId, equals(clipId));
    });

    test('reorderClips updates clip order', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 1),
      );
      notifier.addClip(
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 2),
      );

      final clips = container.read(clipManagerProvider).clips;
      final clip1Id = clips[0].id;
      final clip2Id = clips[1].id;

      notifier.reorderClips([clip2Id, clip1Id]);

      final state = container.read(clipManagerProvider);
      expect(state.clips[0].id, equals(clip2Id));
      expect(state.clips[1].id, equals(clip1Id));
    });

    test('updateThumbnail updates clip thumbnail', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
      );
      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.updateThumbnail(clipId, '/path/to/thumb.jpg');

      final state = container.read(clipManagerProvider);
      expect(state.clips[0].thumbnailPath, equals('/path/to/thumb.jpg'));
    });

    test('updateClipDuration updates clip duration', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
      );
      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.updateClipDuration(clipId, const Duration(seconds: 3));

      final state = container.read(clipManagerProvider);
      expect(state.clips[0].duration, equals(const Duration(seconds: 3)));
      expect(state.totalDuration, equals(const Duration(seconds: 3)));
    });

    test('setProcessing updates processing state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.setProcessing(true);
      expect(container.read(clipManagerProvider).isProcessing, isTrue);

      notifier.setProcessing(false);
      expect(container.read(clipManagerProvider).isProcessing, isFalse);
    });

    test('setError updates error message', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.setError('Test error');
      expect(
        container.read(clipManagerProvider).errorMessage,
        equals('Test error'),
      );

      notifier.setError(null);
      expect(container.read(clipManagerProvider).errorMessage, isNull);
    });

    test('toggleMuteOriginalAudio toggles mute state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      expect(container.read(clipManagerProvider).muteOriginalAudio, isFalse);

      notifier.toggleMuteOriginalAudio();
      expect(container.read(clipManagerProvider).muteOriginalAudio, isTrue);

      notifier.toggleMuteOriginalAudio();
      expect(container.read(clipManagerProvider).muteOriginalAudio, isFalse);
    });

    test('setMuteOriginalAudio sets mute state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.setMuteOriginalAudio(true);
      expect(container.read(clipManagerProvider).muteOriginalAudio, isTrue);

      notifier.setMuteOriginalAudio(false);
      expect(container.read(clipManagerProvider).muteOriginalAudio, isFalse);
    });

    test('removeLastClip removes last clip', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 1),
      );
      notifier.addClip(
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 2),
      );

      expect(container.read(clipManagerProvider).clips.length, equals(2));

      notifier.removeLastClip();

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
    });

    test('clearAll removes all clips and resets state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 1),
      );
      notifier.addClip(
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 2),
      );
      notifier.setError('Some error');
      notifier.setProcessing(true);

      notifier.clearAll();

      final state = container.read(clipManagerProvider);
      expect(state.clips, isEmpty);
      expect(state.hasClips, isFalse);
      expect(state.totalDuration, equals(Duration.zero));
      expect(state.errorMessage, isNull);
      expect(state.isProcessing, isFalse);
    });

    test('canRecordMore is true when under limit', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
      );

      final state = container.read(clipManagerProvider);
      expect(state.canRecordMore, isTrue);
    });

    test('canRecordMore is false when at limit', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(milliseconds: 6300),
      );

      final state = container.read(clipManagerProvider);
      expect(state.canRecordMore, isFalse);
    });
  });
}
