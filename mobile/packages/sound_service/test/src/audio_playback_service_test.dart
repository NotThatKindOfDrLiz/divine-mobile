// ABOUTME: Tests for AudioPlaybackService audio playback/ headphone detection
// ABOUTME: Validates playback controls, position streams, audio session config

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _FakeAudioSource extends Fake implements AudioSource {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(_FakeAudioSource());
    registerFallbackValue(Duration.zero);
    registerFallbackValue('');
    registerFallbackValue(0.0);
  });

  group(AudioPlaybackService, () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;

    setUp(() {
      mockPlayer = _MockAudioPlayer();

      // Set up default mock behaviors for just_audio API
      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test('creates with audio player dependency', () {
      service = AudioPlaybackService(audioPlayer: mockPlayer);
      expect(service, isNotNull);
    });

    test('loadAudio loads audio from URL', () async {
      const testUrl = 'https://example.com/audio.aac';
      when(
        () => mockPlayer.setUrl(testUrl),
      ).thenAnswer((_) async => const Duration(seconds: 10));

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      final duration = await service.loadAudio(testUrl);

      verify(() => mockPlayer.setUrl(testUrl)).called(1);
      expect(duration, const Duration(seconds: 10));
    });

    test('loadAudio loads bundled audio from asset:// URL', () async {
      const assetUrl = 'asset://assets/sounds/bruh-sound-effect.mp3';
      const expectedAssetPath = 'assets/sounds/bruh-sound-effect.mp3';
      when(
        () => mockPlayer.setAsset(expectedAssetPath),
      ).thenAnswer((_) async => const Duration(seconds: 5));

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      final duration = await service.loadAudio(assetUrl);

      verify(() => mockPlayer.setAsset(expectedAssetPath)).called(1);
      expect(duration, const Duration(seconds: 5));
    });

    test('loadAudioFromFile loads audio from file path', () async {
      const testPath = '/path/to/audio.aac';
      when(
        () => mockPlayer.setFilePath(testPath),
      ).thenAnswer((_) async => const Duration(seconds: 15));

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      final duration = await service.loadAudioFromFile(testPath);

      verify(() => mockPlayer.setFilePath(testPath)).called(1);
      expect(duration, const Duration(seconds: 15));
    });

    test('setAudioSource sets audio source directly', () async {
      final source = _FakeAudioSource();
      when(
        () => mockPlayer.setAudioSource(source),
      ).thenAnswer((_) async => const Duration(seconds: 20));

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      final duration = await service.setAudioSource(source);

      verify(() => mockPlayer.setAudioSource(source)).called(1);
      expect(duration, const Duration(seconds: 20));
    });

    test('play starts playback', () async {
      when(() => mockPlayer.play()).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.play();

      verify(() => mockPlayer.play()).called(1);
    });

    test('pause pauses playback', () async {
      when(() => mockPlayer.pause()).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.pause();

      verify(() => mockPlayer.pause()).called(1);
    });

    test('stop stops playback', () async {
      when(() => mockPlayer.stop()).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.stop();

      verify(() => mockPlayer.stop()).called(1);
    });

    test('seek seeks to position', () async {
      const position = Duration(seconds: 5);
      when(() => mockPlayer.seek(position)).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.seek(position);

      verify(() => mockPlayer.seek(position)).called(1);
    });

    test('positionStream exposes player position stream', () async {
      final positionController = BehaviorSubject<Duration>.seeded(
        Duration.zero,
      );
      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => positionController.stream);

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(service.positionStream, emits(Duration.zero));

      await positionController.close();
    });

    test('durationStream exposes player duration stream', () async {
      final durationController = BehaviorSubject<Duration?>.seeded(
        const Duration(seconds: 10),
      );
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => durationController.stream);

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(service.durationStream, emits(const Duration(seconds: 10)));

      await durationController.close();
    });

    test('playingStream exposes player playing stream', () async {
      final playingController = BehaviorSubject<bool>.seeded(false);
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => playingController.stream);

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(service.playingStream, emits(false));

      await playingController.close();
    });

    test('duration returns current duration from player', () {
      when(() => mockPlayer.duration).thenReturn(const Duration(seconds: 10));

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(service.duration, const Duration(seconds: 10));
    });

    test('dispose cleans up resources', () async {
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.dispose();

      verify(() => mockPlayer.dispose()).called(1);
    });

    test('isPlaying returns current playing state', () {
      when(() => mockPlayer.playing).thenReturn(true);

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(service.isPlaying, isTrue);
    });

    test('setVolume sets the volume', () async {
      when(() => mockPlayer.setVolume(0.5)).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.setVolume(0.5);

      verify(() => mockPlayer.setVolume(0.5)).called(1);
    });

    test('setVolume clamps volume above 1.0', () async {
      when(() => mockPlayer.setVolume(1)).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.setVolume(1.5);

      verify(() => mockPlayer.setVolume(1)).called(1);
    });

    test('setVolume clamps volume below 0.0', () async {
      when(() => mockPlayer.setVolume(0)).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.setVolume(-0.5);

      verify(() => mockPlayer.setVolume(0)).called(1);
    });

    test('dispose does nothing if already disposed', () async {
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.dispose();
      await service.dispose(); // Second call should be no-op

      verify(() => mockPlayer.dispose()).called(1);
    });
  });

  group('$AudioPlaybackService error handling', () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test('loadAudio rethrows on error', () async {
      when(
        () => mockPlayer.setUrl(any()),
      ).thenThrow(Exception('Network error'));

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(
        () => service.loadAudio('https://example.com/audio.mp3'),
        throwsException,
      );
    });

    test('loadAudioFromFile rethrows on error', () async {
      when(
        () => mockPlayer.setFilePath(any()),
      ).thenThrow(Exception('File not found'));

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(
        () => service.loadAudioFromFile('/path/to/file.mp3'),
        throwsException,
      );
    });

    test('setAudioSource rethrows on error', () async {
      when(
        () => mockPlayer.setAudioSource(any()),
      ).thenThrow(Exception('Invalid source'));

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(
        () => service.setAudioSource(_FakeAudioSource()),
        throwsException,
      );
    });

    test('play rethrows on error', () async {
      when(() => mockPlayer.play()).thenThrow(Exception('Playback failed'));

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(() => service.play(), throwsException);
    });

    test('pause rethrows on error', () async {
      when(() => mockPlayer.pause()).thenThrow(Exception('Pause failed'));

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(() => service.pause(), throwsException);
    });

    test('stop rethrows on error', () async {
      when(() => mockPlayer.stop()).thenThrow(Exception('Stop failed'));

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(() => service.stop(), throwsException);
    });

    test('seek rethrows on error', () async {
      when(
        () => mockPlayer.seek(any()),
      ).thenThrow(Exception('Seek failed'));

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(() => service.seek(Duration.zero), throwsException);
    });

    test('setVolume rethrows on error', () async {
      when(
        () => mockPlayer.setVolume(any()),
      ).thenThrow(Exception('Volume failed'));

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(() => service.setVolume(0.5), throwsException);
    });

    test('loadAudio from asset rethrows on error', () async {
      when(
        () => mockPlayer.setAsset(any()),
      ).thenThrow(Exception('Asset not found'));

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(
        () => service.loadAudio('asset://assets/sounds/test.mp3'),
        throwsException,
      );
    });
  });

  group('AudioPlaybackService headphone detection', () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test('headphonesConnectedStream emits headphone state', () async {
      service = AudioPlaybackService(audioPlayer: mockPlayer);

      // The service should expose a stream for headphone state
      expect(service.headphonesConnectedStream, isA<Stream<bool>>());
    });

    test('areHeadphonesConnected returns current state', () {
      service = AudioPlaybackService(audioPlayer: mockPlayer);

      // Should return a boolean indicating current headphone state
      expect(service.areHeadphonesConnected, isA<bool>());
    });
  });

  group('AudioPlaybackService audio session configuration', () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test(
      'configureForRecording sets up audio session for recording mode',
      () async {
        service = AudioPlaybackService(audioPlayer: mockPlayer);

        // Should not throw
        await expectLater(service.configureForRecording(), completes);
      },
    );

    test('resetAudioSession resets to default configuration', () async {
      service = AudioPlaybackService(audioPlayer: mockPlayer);

      // Should not throw
      await expectLater(service.resetAudioSession(), completes);
    });
  });
}
