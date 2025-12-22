// ABOUTME: Audio service for managing sound selection, overlay tracks, and volume balancing
// ABOUTME: Handles audio playback synchronization with video and custom sound integration

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

/// A helper service that manages audio playback alongside video playback,
/// including sound selection and overlay audio tracks.
class VideoEditorAudioService {
  /// Creates an instance of [VideoEditorAudioService] for the
  /// given [videoController].
  VideoEditorAudioService({
    required this.videoController,
    required this.onStateChanged,
  });

  /// The internal audio player used to handle audio playback.
  final _audioPlayer = AudioPlayer();

  /// The controller managing video playback.
  final VideoPlayerController videoController;

  /// Callback when state changes (for sound selection)
  final VoidCallback onStateChanged;

  /// Stores the last applied audio balance between video and overlay.
  double _lastVolumeBalance = 0;

  /// The ID of the currently selected sound for the video
  String? selectedSoundId;

  /// The ID of the currently playing sound
  String? _currentSoundId;

  /// Initializes the audio player with platform-specific audio context
  /// settings.
  Future<void> initialize() {
    return _audioPlayer.setAudioContext(
      const AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: [
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.duckOthers,
          ],
        ),
      ),
    );
  }

  /// Disposes of the audio player and releases resources.
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }

  /// Select a sound for the video
  void selectSound(String? soundId) {
    selectedSoundId = soundId;
    onStateChanged();
  }

  /// Load and play the selected sound, synced with video
  Future<void> loadAndPlaySound(String? soundId) async {
    if (soundId == _currentSoundId) return;
    _currentSoundId = soundId;

    // Stop current audio
    await _audioPlayer.stop();

    if (soundId == null) {
      // No sound selected - unmute video
      await videoController.setVolume(1.0);
      return;
    }

    // Mute video's original audio when playing selected sound
    await videoController.setVolume(0.0);

    // For now, we'll need to pass in the sound service from outside
    // This will be called from the screen with the sound object
    Log.info('Loading sound: $soundId', category: LogCategory.video);
  }

  /// Actually play the sound file
  Future<void> playSound(String filePath, String soundTitle) async {
    try {
      await _audioPlayer.setSourceDeviceFile(filePath);

      // Set looping to match video
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      // Play the audio
      await _audioPlayer.resume();

      Log.info('Playing sound: $soundTitle', category: LogCategory.video);
    } catch (e) {
      Log.error('Failed to play sound: $e', category: LogCategory.video);
      // Unmute video on error
      await videoController.setVolume(1.0);
    }
  }

  /// Stop the audio player
  Future<void> stopAudio() async {
    await _audioPlayer.stop();
  }

  /// Pause the audio player
  Future<void> pauseAudio() async {
    await _audioPlayer.pause();
  }

  /// Resume the audio player
  Future<void> resumeAudio() async {
    await _audioPlayer.resume();
  }

  /// Plays the given [AudioTrack] with looping enabled.
  Future<void> play(AudioTrack track) async {
    final audio = track.audio;
    Source source;
    if (audio.hasAssetPath) {
      source = AssetSource(audio.assetPath!);
    } else if (audio.hasFile) {
      source = DeviceFileSource(audio.file!.path);
    } else if (audio.hasNetworkUrl) {
      source = UrlSource(audio.networkUrl!);
    } else {
      source = BytesSource(audio.bytes!);
    }

    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(source, position: track.startTime);
  }

  /// Pauses the current audio playback.
  Future<void> pause() {
    return _audioPlayer.pause();
  }

  /// Sets the playback volume.
  ///
  /// The [volume] should be a value between `0.0` (muted) and `1.0` (maximum).
  Future<void> setVolume(double volume) {
    return _audioPlayer.setVolume(volume);
  }

  /// Seeks the audio playback to the specified [startTime].
  Future<void> seek(Duration startTime) {
    return _audioPlayer.seek(startTime);
  }

  /// Adjusts the balance between video and overlay audio.
  ///
  /// A negative [volumeBalance] lowers the overlay volume,
  /// while a positive value lowers the video volume.
  Future<void> balanceAudio([double? volumeBalance]) async {
    volumeBalance ??= _lastVolumeBalance;

    double overlayVolume = 1;
    double originalVolume = 1;
    if (volumeBalance < 0) {
      overlayVolume += volumeBalance;
    } else {
      originalVolume -= volumeBalance;
    }
    await Future.wait([
      setVolume(overlayVolume),
      videoController.setVolume(originalVolume),
    ]);
    _lastVolumeBalance = volumeBalance;
  }

  /// Returns a local file path for the given [track]'s audio source.
  ///
  /// - If the audio already exists as a file, its path is returned.
  /// - Otherwise, the audio is written to a temporary file from
  ///   assets, network, or memory bytes.
  Future<String?> safeCustomAudioPath(AudioTrack? track) async {
    final directory = await getTemporaryDirectory();

    final EditorAudio? audio = track?.audio;
    if (audio == null) return null;

    if (audio.hasFile) {
      return audio.file!.path;
    } else {
      String filePath = '${directory.path}/temp-audio.mp3';

      if (audio.hasNetworkUrl) {
        return (await fetchVideoToFile(audio.networkUrl!, filePath)).path;
      } else if (audio.hasAssetPath) {
        return (await writeAssetVideoToFile(
          'assets/${audio.assetPath!}',
          filePath,
        )).path;
      } else {
        return (await writeMemoryVideoToFile(audio.bytes!, filePath)).path;
      }
    }
  }
}
