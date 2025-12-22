// ABOUTME: Service for exporting video clips with FFmpeg operations
// ABOUTME: Handles concatenation, text overlays, audio mixing, and thumbnail generation

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/utils/ffmpeg_encoder.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import 'video_thumbnail_service.dart';

/// Export stages for progress reporting
enum ExportStage {
  concatenating,
  applyingTextOverlay,
  mixingAudio,
  generatingThumbnail,
  complete,
}

/// Result of video export operation
class ExportResult {
  const ExportResult({
    required this.videoPath,
    required this.duration,
    this.thumbnailPath,
  });

  final String videoPath;
  final String? thumbnailPath;
  final Duration duration;
}

/// Service for exporting video clips with FFmpeg operations
class VideoExportService {
  /// Concatenates multiple video segments into a single video with optional aspect ratio crop
  ///
  /// If [aspectRatio] is provided, applies the crop filter to the final output.
  /// If not provided but any clip has [needsCrop] = true, uses that clip's aspectRatio.
  /// This supports deferred encoding on Android where crop is skipped during capture.
  /// If [muteAudio] is true, strips all audio from the output.
  /// Otherwise uses lossless copy mode.
  Future<String> concatenateSegments(
    List<RecordingClip> clips, {
    AspectRatio? aspectRatio,
    bool muteAudio = false,
  }) async {
    if (clips.isEmpty) {
      throw ArgumentError('Cannot concatenate empty clip list');
    }

    // Check if any clip needs deferred cropping (Android deferred encoding)
    final clipsNeedingCrop = clips.where((c) => c.needsCrop).toList();
    AspectRatio? effectiveAspectRatio = aspectRatio;

    if (effectiveAspectRatio == null && clipsNeedingCrop.isNotEmpty) {
      // Use the aspect ratio from the first clip that needs cropping
      effectiveAspectRatio = clipsNeedingCrop.first.aspectRatio;
      Log.info(
        'Deferred crop detected: ${clipsNeedingCrop.length}/${clips.length} clips need cropping, '
        'using aspectRatio=${effectiveAspectRatio?.name ?? "default"}',
        name: 'VideoExportService',
        category: LogCategory.system,
      );
    }

    // Determine if cropping is needed AFTER resolving effective aspect ratio
    final bool needsCrop = effectiveAspectRatio != null;

    // If only one clip and no processing needed, return it directly
    // If crop or mute is needed, we still need to process even a single clip
    if (clips.length == 1 && !needsCrop && !muteAudio) {
      Log.info(
        'Single clip detected, no processing needed, returning original file',
        name: 'VideoExportService',
        category: LogCategory.system,
      );
      return clips.first.filePath;
    }

    try {
      Log.info(
        'Processing ${clips.length} clips${needsCrop ? " with ${effectiveAspectRatio.name} crop" : ""}${muteAudio ? " (muted)" : ""}',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      // Get temp directory for concat list file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/concatenated_$timestamp.mp4';

      // Create concat list file
      final sortedClips = List<RecordingClip>.from(clips)
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      final videoSegments = sortedClips.map((clip) {
        return VideoSegment(video: EditorVideo.file(clip.filePath));
      }).toList();

      ExportTransform? renderTransform;

      if (needsCrop) {
        final metaData = await ProVideoEditor.instance.getMetadata(
          videoSegments.first.video,
        );
        final resolution = metaData.resolution;

        Log.info(
          'Calculating crop for ${effectiveAspectRatio.name} from resolution: ${resolution.width}x${resolution.height}',
          name: 'VideoExportService',
          category: LogCategory.system,
        );

        double cropX, cropY, cropWidth, cropHeight;

        switch (effectiveAspectRatio) {
          case AspectRatio.square:
            // Center crop to 1:1 (minimum dimension)
            final minDimension = resolution.width < resolution.height
                ? resolution.width
                : resolution.height;
            cropWidth = minDimension;
            cropHeight = minDimension;
            cropX = (resolution.width - cropWidth) / 2;
            cropY = (resolution.height - cropHeight) / 2;
            break;

          case AspectRatio.vertical:
            // Center crop to 9:16 (portrait)
            final inputAspectRatio = resolution.width / resolution.height;
            const targetAspectRatio = 9.0 / 16.0;

            if (inputAspectRatio > targetAspectRatio) {
              // Input is wider than 9:16 - crop width, keep height
              cropHeight = resolution.height;
              cropWidth = cropHeight * targetAspectRatio;
              cropX = (resolution.width - cropWidth) / 2;
              cropY = 0;
            } else {
              // Input is taller than 9:16 - keep width, crop height
              cropWidth = resolution.width;
              cropHeight = cropWidth / targetAspectRatio;
              cropX = 0;
              cropY = (resolution.height - cropHeight) / 2;
            }
            break;
        }

        Log.info(
          'Crop params: x=$cropX, y=$cropY, w=$cropWidth, h=$cropHeight',
          name: 'VideoExportService',
          category: LogCategory.system,
        );

        renderTransform = ExportTransform(
          x: cropX.round(),
          y: cropY.round(),
          width: cropWidth.round(),
          height: cropHeight.round(),
        );
      }

      final task = VideoRenderData(
        videoSegments: videoSegments,
        endTime: Duration(milliseconds: 6_300),
        enableAudio: !muteAudio,
        transform: renderTransform,
      );

      await ProVideoEditor.instance.renderVideoToFile(outputPath, task);

      Log.info(
        'Successfully processed clips to: $outputPath',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      return outputPath;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to process clips: $e',
        name: 'VideoExportService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mixes background audio with video
  ///
  /// For bundled assets, copies from Flutter assets to temp file.
  /// For custom sounds (file paths), uses the file directly.
  /// Runs: `ffmpeg -i video.mp4 -i audio.mp3 -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest output.mp4`
  Future<String> mixAudio(String videoPath, String audioPath) async {
    // TODO(@hm21): Replace with pro_video_editor

    try {
      Log.info(
        'Mixing audio: $audioPath with video: $videoPath',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      // Get temp directory for output
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/with_audio_$timestamp.mp4';

      String audioFilePath;

      // Check if it's a file path (custom sound) or asset path (bundled sound)
      if (audioPath.startsWith('/') || audioPath.startsWith('file://')) {
        // Custom sound - use file path directly
        audioFilePath = audioPath.replaceFirst('file://', '');
        Log.info(
          'Using custom sound file: $audioFilePath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );
      } else {
        // Bundled asset - copy to temp file
        audioFilePath = '${tempDir.path}/audio_$timestamp.mp3';
        final audioBytes = await rootBundle.load(audioPath);
        await File(audioFilePath).writeAsBytes(audioBytes.buffer.asUint8List());
        Log.info(
          'Copied asset to: $audioFilePath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );
      }

      // Run FFmpeg audio mixing command
      // -y = overwrite output file
      // -c:v copy = copy video codec (no re-encoding)
      // -c:a aac = encode audio to AAC
      // -map 0:v:0 = use video from first input
      // -map 1:a:0 = use audio from second input
      // -shortest = finish when shortest stream ends
      final command =
          '-y -i "$videoPath" -i "$audioFilePath" -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest "$outputPath"';

      Log.info(
        'Running FFmpeg audio mix: $command',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clear sessions to free memory
      await FFmpegEncoder.clearSessions();

      if (ReturnCode.isSuccess(returnCode)) {
        Log.info(
          'Successfully mixed audio to: $outputPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );

        // Clean up temp audio file only if we copied from assets
        if (!audioPath.startsWith('/') && !audioPath.startsWith('file://')) {
          await File(audioFilePath).delete();
        }

        return outputPath;
      } else {
        final output = await session.getOutput();
        throw Exception('FFmpeg audio mix failed: $output');
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to mix audio: $e',
        name: 'VideoExportService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Generates a thumbnail from a video file
  Future<String?> generateThumbnail(
    String videoPath, {
    Duration timestamp = const Duration(milliseconds: 500),
  }) async {
    try {
      Log.info(
        'Generating thumbnail from video: $videoPath',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      final thumbnailPath = await VideoThumbnailService.extractThumbnail(
        videoPath: videoPath,
        timestamp: timestamp,
      );

      if (thumbnailPath != null) {
        Log.info(
          'Generated thumbnail: $thumbnailPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          'Failed to generate thumbnail for: $videoPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );
      }

      return thumbnailPath;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to generate thumbnail: $e',
        name: 'VideoExportService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
