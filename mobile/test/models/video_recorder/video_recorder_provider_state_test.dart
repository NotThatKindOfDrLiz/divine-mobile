// ABOUTME: Tests for VideoRecorderProviderState ghost mode fields
// ABOUTME: Validates ghost state defaults, copyWith, and hasGhostFrame getter

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_recorder/video_recorder_provider_state.dart';

void main() {
  group(VideoRecorderProviderState, () {
    group('ghost mode defaults', () {
      test('isGhostEnabled defaults to false', () {
        const state = VideoRecorderProviderState();
        expect(state.isGhostEnabled, isFalse);
      });

      test('ghostFramePath defaults to null', () {
        const state = VideoRecorderProviderState();
        expect(state.ghostFramePath, isNull);
      });

      test('hasGhostFrame is false by default', () {
        const state = VideoRecorderProviderState();
        expect(state.hasGhostFrame, isFalse);
      });
    });

    group('hasGhostFrame', () {
      test('returns true when ghost is enabled and frame path exists', () {
        const state = VideoRecorderProviderState(
          isGhostEnabled: true,
          ghostFramePath: '/path/to/ghost.jpg',
        );
        expect(state.hasGhostFrame, isTrue);
      });

      test('returns false when ghost is enabled but no frame path', () {
        const state = VideoRecorderProviderState(isGhostEnabled: true);
        expect(state.hasGhostFrame, isFalse);
      });

      test('returns false when ghost is disabled but frame path exists', () {
        const state = VideoRecorderProviderState(
          ghostFramePath: '/path/to/ghost.jpg',
        );
        expect(state.hasGhostFrame, isFalse);
      });
    });

    group('copyWith', () {
      test('preserves ghost fields when not specified', () {
        const state = VideoRecorderProviderState(
          isGhostEnabled: true,
          ghostFramePath: '/path/to/ghost.jpg',
        );
        final copied = state.copyWith(zoomLevel: 2.0);

        expect(copied.isGhostEnabled, isTrue);
        expect(copied.ghostFramePath, equals('/path/to/ghost.jpg'));
        expect(copied.zoomLevel, equals(2.0));
      });

      test('updates isGhostEnabled', () {
        const state = VideoRecorderProviderState(isGhostEnabled: true);
        final copied = state.copyWith(isGhostEnabled: false);

        expect(copied.isGhostEnabled, isFalse);
      });

      test('updates ghostFramePath', () {
        const state = VideoRecorderProviderState();
        final copied = state.copyWith(ghostFramePath: '/new/path.jpg');

        expect(copied.ghostFramePath, equals('/new/path.jpg'));
      });

      test('clears ghostFramePath with clearGhostFrame flag', () {
        const state = VideoRecorderProviderState(
          ghostFramePath: '/path/to/ghost.jpg',
        );
        final copied = state.copyWith(clearGhostFrame: true);

        expect(copied.ghostFramePath, isNull);
      });

      test('clearGhostFrame takes precedence over ghostFramePath', () {
        const state = VideoRecorderProviderState();
        final copied = state.copyWith(
          ghostFramePath: '/new/path.jpg',
          clearGhostFrame: true,
        );

        expect(copied.ghostFramePath, isNull);
      });
    });
  });
}
