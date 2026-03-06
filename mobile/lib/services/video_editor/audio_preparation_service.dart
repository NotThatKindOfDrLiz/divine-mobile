// ABOUTME: Prepares uploaded local audio for final video export.
// ABOUTME: Creates a render-ready audio file that already includes trim and
// ABOUTME: delayed-start silence so native video export can mix it correctly.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:openvine/models/video_editor/selected_audio_track.dart';

/// Native audio-preparation failure surfaced to the editor flow.
class AudioPreparationException implements Exception {
  /// Creates an [AudioPreparationException].
  const AudioPreparationException(this.message, [this.cause]);

  /// Human-readable failure message.
  final String message;

  /// Optional underlying platform error.
  final Object? cause;

  @override
  String toString() => 'AudioPreparationException(message: $message)';
}

/// A render-ready audio file prepared for final export.
class PreparedAudioTrack {
  /// Creates a [PreparedAudioTrack].
  const PreparedAudioTrack({
    required this.path,
    this.deleteAfterUse = false,
  });

  /// Local file path passed into video rendering.
  final String path;

  /// Whether the file should be deleted after render completes.
  final bool deleteAfterUse;
}

/// Prepares local audio files for final video rendering.
class AudioPreparationService {
  /// Creates an [AudioPreparationService].
  AudioPreparationService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'org.openvine/audio_preparation';

  final MethodChannel _channel;

  /// Prepares [track] for a final render of [videoDuration].
  ///
  /// Returns the original file directly when the source already matches the
  /// needed render window. Otherwise delegates to the native layer to create a
  /// temporary render-ready file.
  Future<PreparedAudioTrack> prepareForRender({
    required SelectedAudioTrack track,
    required Duration videoDuration,
  }) async {
    if (videoDuration <= Duration.zero) {
      throw const AudioPreparationException(
        'Video duration must be greater than zero.',
      );
    }

    final sourceFile = File(track.localFilePath);
    if (!sourceFile.existsSync()) {
      throw AudioPreparationException(
        'Audio source file not found: ${track.localFilePath}',
      );
    }

    if (_canUseSourceFileDirectly(track: track, videoDuration: videoDuration)) {
      return PreparedAudioTrack(path: track.localFilePath);
    }

    try {
      final preparedPath = await _channel.invokeMethod<String>(
        'prepareForRender',
        {
          'sourcePath': track.localFilePath,
          'sourceStartOffsetMs': track.sourceStartOffset.inMilliseconds,
          'videoStartOffsetMs': track.videoStartOffset.inMilliseconds,
          'videoDurationMs': videoDuration.inMilliseconds,
        },
      );

      if (preparedPath == null || preparedPath.isEmpty) {
        throw const AudioPreparationException(
          'Native audio preparation returned an empty path.',
        );
      }

      if (!File(preparedPath).existsSync()) {
        throw AudioPreparationException(
          'Prepared audio file was not created: $preparedPath',
        );
      }

      return PreparedAudioTrack(path: preparedPath, deleteAfterUse: true);
    } on MissingPluginException catch (error) {
      throw AudioPreparationException(
        'Audio preparation is not supported on this platform.',
        error,
      );
    } on PlatformException catch (error) {
      throw AudioPreparationException(
        error.message ?? 'Native audio preparation failed.',
        error,
      );
    }
  }

  static bool _canUseSourceFileDirectly({
    required SelectedAudioTrack track,
    required Duration videoDuration,
  }) {
    return track.videoStartOffset == Duration.zero &&
        track.sourceStartOffset == Duration.zero &&
        track.duration >= videoDuration;
  }
}
