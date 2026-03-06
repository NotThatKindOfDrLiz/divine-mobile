import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/video_editor/selected_audio_track.dart';
import 'package:openvine/services/video_editor/local_audio_preview_controller.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioPlaybackService extends Mock implements AudioPlaybackService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(0.0);
    registerFallbackValue('');
  });

  group('LocalAudioPreviewController', () {
    late _MockAudioPlaybackService mockAudioService;
    late StreamController<Duration> positionController;
    late LocalAudioPreviewController controller;

    setUp(() {
      mockAudioService = _MockAudioPlaybackService();
      positionController = StreamController<Duration>.broadcast();

      when(
        () => mockAudioService.positionStream,
      ).thenAnswer((_) => positionController.stream);
      when(
        () => mockAudioService.configureForMixedPlayback(),
      ).thenAnswer((_) async {});
      when(
        () => mockAudioService.loadAudioFromFile(any()),
      ).thenAnswer((_) async => const Duration(seconds: 12));
      when(() => mockAudioService.setVolume(any())).thenAnswer((_) async {});
      when(() => mockAudioService.seek(any())).thenAnswer((_) async {});
      when(() => mockAudioService.play()).thenAnswer((_) async {});
      when(() => mockAudioService.pause()).thenAnswer((_) async {});
      when(() => mockAudioService.dispose()).thenAnswer((_) async {});

      controller = LocalAudioPreviewController(audioService: mockAudioService);
    });

    tearDown(() async {
      await controller.dispose();
      await positionController.close();
    });

    test('loads track and seeks to selected source offset', () async {
      const track = SelectedAudioTrack(
        id: 'track-1',
        localFilePath: '/documents/audio-track.m4a',
        displayTitle: 'Audio Track',
        duration: Duration(seconds: 12),
        sourceStartOffset: Duration(seconds: 3),
        addedAudioVolume: 0.65,
      );

      await controller.loadTrack(
        track: track,
        videoDuration: const Duration(seconds: 6),
      );

      verify(() => mockAudioService.configureForMixedPlayback()).called(1);
      verify(
        () => mockAudioService.loadAudioFromFile(track.localFilePath),
      ).called(1);
      verify(
        () => mockAudioService.setVolume(track.addedAudioVolume),
      ).called(1);
      verify(() => mockAudioService.seek(track.sourceStartOffset)).called(1);
    });

    test(
      'stops preview when playback reaches the bounded preview end',
      () async {
        const track = SelectedAudioTrack(
          id: 'track-2',
          localFilePath: '/documents/audio-track-2.m4a',
          displayTitle: 'Long Track',
          duration: Duration(seconds: 12),
          sourceStartOffset: Duration(seconds: 2),
        );

        await controller.loadTrack(
          track: track,
          videoDuration: const Duration(seconds: 6),
        );
        await controller.togglePreview();

        expect(controller.isPlaying.value, isTrue);
        verify(() => mockAudioService.play()).called(1);

        positionController.add(const Duration(seconds: 8));
        await Future<void>.delayed(Duration.zero);

        expect(controller.isPlaying.value, isFalse);
        verify(() => mockAudioService.pause()).called(greaterThanOrEqualTo(1));
        verify(
          () => mockAudioService.seek(track.sourceStartOffset),
        ).called(greaterThanOrEqualTo(2));
      },
    );
  });
}
