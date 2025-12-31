import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/providers/video_recording_provider.dart';

void main() {
  group('VineRecordingUIState AspectRatio', () {
    test('includes aspectRatio in state', () {
      final state = VideoRecordingUIState(aspectRatio: AspectRatio.vertical);

      expect(state.aspectRatio, equals(AspectRatio.vertical));
    });

    test('default aspectRatio is vertical', () {
      final state = VideoRecordingUIState();

      expect(state.aspectRatio, equals(AspectRatio.vertical));
    });

    test('copyWith updates aspectRatio', () {
      final state = VideoRecordingUIState(aspectRatio: AspectRatio.square);

      final updated = state.copyWith(aspectRatio: AspectRatio.vertical);
      expect(updated.aspectRatio, equals(AspectRatio.vertical));
    });

    test('copyWith preserves aspectRatio when not provided', () {
      final state = VideoRecordingUIState(aspectRatio: AspectRatio.square);

      final updated = state.copyWith(canRecord: true);
      expect(updated.aspectRatio, equals(AspectRatio.square));
    });

    test('all AspectRatio values can be used', () {
      final squareState = VideoRecordingUIState(
        aspectRatio: AspectRatio.square,
      );
      expect(squareState.aspectRatio, equals(AspectRatio.square));

      final verticalState = VideoRecordingUIState(
        aspectRatio: AspectRatio.vertical,
      );
      expect(verticalState.aspectRatio, equals(AspectRatio.vertical));
    });
  });
}
