// ABOUTME: Service for audio playback during recording with headphone detection
// ABOUTME: Manages audio session configuration and exposes playback streams

// No non-experimental alternative exists. Tracked upstream:
// https://github.com/ryanheise/audio_session/issues
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

/// Service for managing audio playback during lip sync recording mode.
///
/// This service handles:
/// - Playing selected audio tracks during recording
/// - Detecting headphone connection state
/// - Managing audio session configuration for recording scenarios
class AudioPlaybackService {
  /// Creates an AudioPlaybackService with an optional custom AudioPlayer.
  ///
  /// The [audioPlayer] parameter allows for dependency injection in tests.
  AudioPlaybackService({AudioPlayer? audioPlayer})
    : _audioPlayer = audioPlayer ?? AudioPlayer() {
    unawaited(_initializeHeadphoneDetection());
  }

  final AudioPlayer _audioPlayer;

  /// BehaviorSubject for headphone connection state.
  /// Starts with false (no headphones) until actual state is determined.
  final BehaviorSubject<bool> _headphonesConnectedSubject =
      BehaviorSubject<bool>.seeded(false);

  StreamSubscription<dynamic>? _deviceChangeSubscription;
  bool _isDisposed = false;

  /// Stream of playback position updates.
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  /// Stream of duration updates (null if not loaded).
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  /// Stream of playing state updates.
  Stream<bool> get playingStream => _audioPlayer.playingStream;

  /// Current duration of loaded audio (null if not loaded).
  Duration? get duration => _audioPlayer.duration;

  /// Whether audio is currently playing.
  bool get isPlaying => _audioPlayer.playing;

  /// Stream of headphone connection state changes.
  Stream<bool> get headphonesConnectedStream =>
      _headphonesConnectedSubject.stream;

  /// Current headphone connection state.
  bool get areHeadphonesConnected => _headphonesConnectedSubject.value;

  /// Initializes headphone detection using audio_session.
  Future<void> _initializeHeadphoneDetection() async {
    if (_isDisposed) return;

    try {
      final session = await audio_session.AudioSession.instance;

      // Check initial headphone state
      final devices = await session.getDevices();
      final hasHeadphones = _checkForHeadphones(devices);
      if (!_isDisposed) {
        _headphonesConnectedSubject.add(hasHeadphones);
      }

      // Listen for device changes
      _deviceChangeSubscription = session.devicesChangedEventStream.listen(
        (event) {
          if (_isDisposed) return;

          // Re-check all connected devices for accuracy when any device changes
          unawaited(
            session.getDevices().then((allDevices) {
              if (!_isDisposed) {
                final hasHeadphones = _checkForHeadphones(allDevices);
                _headphonesConnectedSubject.add(hasHeadphones);
              }
            }),
          );
        },
        onError: (Object error) {
          log(
            'Error in device change stream: $error',
            name: 'AudioPlaybackService',
            level: 900,
          );
        },
      );

      log(
        'Headphone detection initialized. Connected: $hasHeadphones',
        name: 'AudioPlaybackService',
      );
    } on Exception catch (e) {
      log(
        'Failed to initialize headphone detection: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      // Default to false if detection fails
      if (!_isDisposed) {
        _headphonesConnectedSubject.add(false);
      }
    }
  }

  /// Checks if any of the given devices are headphones or external audio.
  bool _checkForHeadphones(Set<audio_session.AudioDevice> devices) {
    for (final device in devices) {
      // Check for wired headphones
      if (device.type == audio_session.AudioDeviceType.wiredHeadphones ||
          device.type == audio_session.AudioDeviceType.wiredHeadset) {
        return true;
      }

      // Check for Bluetooth audio devices
      if (device.type == audio_session.AudioDeviceType.bluetoothA2dp ||
          device.type == audio_session.AudioDeviceType.bluetoothSco) {
        return true;
      }

      // iOS-specific: Check for Bluetooth HFP
      if (Platform.isIOS &&
          device.type == audio_session.AudioDeviceType.bluetoothLe) {
        return true;
      }
    }
    return false;
  }

  /// Loads audio from a URL or asset path.
  ///
  /// Supports:
  /// - HTTP/HTTPS URLs for remote audio
  /// - `asset://` URLs for bundled sounds (e.g., "asset://assets/sounds/bruh.mp3")
  ///
  /// Returns the duration of the loaded audio.
  Future<Duration?> loadAudio(String url) async {
    try {
      Duration? loadedDuration;

      // Check if this is a bundled asset URL
      if (url.startsWith('asset://')) {
        final assetPath = url.substring('asset://'.length);
        loadedDuration = await _audioPlayer.setAsset(assetPath);
        log(
          'Loaded audio from asset: $assetPath',
          name: 'AudioPlaybackService',
        );
      } else {
        loadedDuration = await _audioPlayer.setUrl(url);
        log(
          'Loaded audio from URL: $url',
          name: 'AudioPlaybackService',
        );
      }

      return loadedDuration;
    } catch (e) {
      log(
        'Failed to load audio from $url: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    }
  }

  /// Loads audio from a local file path.
  ///
  /// Returns the duration of the loaded audio.
  Future<Duration?> loadAudioFromFile(String filePath) async {
    try {
      final loadedDuration = await _audioPlayer.setFilePath(filePath);
      log(
        'Loaded audio from file: $filePath',
        name: 'AudioPlaybackService',
      );
      return loadedDuration;
    } catch (e) {
      log(
        'Failed to load audio from file $filePath: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    }
  }

  /// Sets an audio source directly.
  ///
  /// This allows using advanced audio sources like [ClippingAudioSource].
  Future<Duration?> setAudioSource(AudioSource source) async {
    try {
      final loadedDuration = await _audioPlayer.setAudioSource(source);
      log(
        'Set audio source: ${source.runtimeType}',
        name: 'AudioPlaybackService',
      );
      return loadedDuration;
    } catch (e) {
      log(
        'Failed to set audio source: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    }
  }

  /// Starts audio playback.
  Future<void> play() async {
    try {
      await _audioPlayer.play();
      log('Started audio playback', name: 'AudioPlaybackService');
    } catch (e) {
      log(
        'Failed to start playback: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    }
  }

  /// Pauses audio playback.
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      log('Paused audio playback', name: 'AudioPlaybackService');
    } catch (e) {
      log(
        'Failed to pause playback: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    }
  }

  /// Stops audio playback and resets position to the beginning.
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      log('Stopped audio playback', name: 'AudioPlaybackService');
    } catch (e) {
      log(
        'Failed to stop playback: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    }
  }

  /// Seeks to a specific position in the audio.
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      log(
        'Seeked to position: ${position.inSeconds}s',
        name: 'AudioPlaybackService',
      );
    } catch (e) {
      log(
        'Failed to seek: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    }
  }

  /// Sets the playback volume.
  ///
  /// [volume] should be between 0.0 (muted) and 1.0 (full volume).
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
      log(
        'Set volume to: ${(volume * 100).toInt()}%',
        name: 'AudioPlaybackService',
      );
    } catch (e) {
      log(
        'Failed to set volume: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    }
  }

  /// Configures the audio session for recording mode.
  ///
  /// This sets up the audio session to:
  /// - Allow audio playback during recording via A2DP to Bluetooth headphones
  /// - Use built-in microphone for recording (NOT Bluetooth mic)
  /// - Route to speaker when no headphones connected
  ///
  /// IMPORTANT: Only uses allowBluetoothA2dp, NOT allowBluetooth.
  /// allowBluetooth enables HFP (phone call mode) which causes
  /// "call started/ended" sounds on Bluetooth headsets.
  Future<void> configureForRecording() async {
    try {
      final session = await audio_session.AudioSession.instance;

      await session.configure(
        audio_session.AudioSessionConfiguration(
          avAudioSessionCategory:
              audio_session.AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              audio_session.AVAudioSessionCategoryOptions.defaultToSpeaker |
              audio_session.AVAudioSessionCategoryOptions.allowBluetoothA2dp,
          avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions:
              audio_session.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.music,
            usage: audio_session.AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
              audio_session.AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );

      log(
        'Configured audio session for recording mode',
        name: 'AudioPlaybackService',
      );
    } on Exception catch (e) {
      log(
        'Failed to configure audio session for recording: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      // Don't rethrow - allow playback to continue even if session config fails
    }
  }

  /// Resets the audio session to default configuration.
  ///
  /// Call this when exiting recording mode.
  Future<void> resetAudioSession() async {
    try {
      final session = await audio_session.AudioSession.instance;

      await session.configure(
        const audio_session.AudioSessionConfiguration(
          avAudioSessionCategory: audio_session.AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              audio_session.AVAudioSessionCategoryOptions.none,
          avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions:
              audio_session.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.music,
            usage: audio_session.AndroidAudioUsage.media,
          ),
          androidWillPauseWhenDucked: true,
        ),
      );

      log(
        'Reset audio session to default',
        name: 'AudioPlaybackService',
      );
    } on Exception catch (e) {
      log(
        'Failed to reset audio session: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      // Don't rethrow - allow continued operation even if reset fails
    }
  }

  /// Disposes of all resources used by this service.
  ///
  /// Must be called when the service is no longer needed.
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    await _deviceChangeSubscription?.cancel();
    await _headphonesConnectedSubject.close();
    await _audioPlayer.dispose();

    log(
      'AudioPlaybackService disposed',
      name: 'AudioPlaybackService',
    );
  }
}
