import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/providers/vine_recording_provider.dart';

void main() {
  group('VineRecordingUIState AspectRatio', () {
    test('includes aspectRatio in state', () {
      final state = VineRecordingUIState(aspectRatio: AspectRatio.vertical);

      expect(state.aspectRatio, equals(AspectRatio.vertical));
    });

    test('default aspectRatio is vertical', () {
      final state = VineRecordingUIState();

      expect(state.aspectRatio, equals(AspectRatio.vertical));
    });

    test('copyWith updates aspectRatio', () {
      final state = VineRecordingUIState(aspectRatio: AspectRatio.square);

      final updated = state.copyWith(aspectRatio: AspectRatio.vertical);
      expect(updated.aspectRatio, equals(AspectRatio.vertical));
    });

    test('copyWith preserves aspectRatio when not provided', () {
      final state = VineRecordingUIState(aspectRatio: AspectRatio.square);

      final updated = state.copyWith(canRecord: true);
      expect(updated.aspectRatio, equals(AspectRatio.square));
    });

    test('all AspectRatio values can be used', () {
      final squareState = VineRecordingUIState(aspectRatio: AspectRatio.square);
      expect(squareState.aspectRatio, equals(AspectRatio.square));

      final verticalState = VineRecordingUIState(
        aspectRatio: AspectRatio.vertical,
      );
      expect(verticalState.aspectRatio, equals(AspectRatio.vertical));
    });
  });
}
