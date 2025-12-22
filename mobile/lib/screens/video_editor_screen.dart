// ABOUTME: Video editor screen for adding text overlays and sound to recorded videos
// ABOUTME: Dark-themed interface with video preview, text editing, and sound selection

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/platform_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/screens/pure/video_metadata_screen_pure.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/providers/vine_recording_provider.dart';

import '../services/video_editor/video_editor_service.dart';

class VideoEditorScreen extends ConsumerStatefulWidget {
  const VideoEditorScreen({
    super.key,
    required this.videoPath,
    this.onExport,
    this.onBack,
  });

  final String videoPath;
  final VoidCallback? onExport;
  final VoidCallback? onBack;

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  late final VideoEditorService _videoEditorService;

  bool _isVideoInitialized = false;
  AudioPlayer? _audioPlayer;
  String? _currentSoundId;

  @override
  void initState() {
    super.initState();
    Log.info(
      '📹 VideoEditorScreen.initState() START - videoPath: ${widget.videoPath}',
      category: LogCategory.video,
    );

    _videoEditorService = VideoEditorService(
      videoPath: widget.videoPath,
      context: context,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      mounted: () => mounted,
    );

    _videoEditorService.initializePlayer();
    _audioPlayer = AudioPlayer();
    Log.info(
      '📹 VideoEditorScreen.initState() END',
      category: LogCategory.video,
    );
  }

  @override
  void dispose() {
    _videoEditorService.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }
  /* 
  /// Load and play the selected sound, synced with video
  Future<void> _loadAndPlaySound(String? soundId) async {
    if (soundId == _currentSoundId) return;
    _currentSoundId = soundId;

    // Stop current audio
    await _audioPlayer?.stop();

    if (soundId == null) {
      // No sound selected - unmute video
      await _videoController?.setVolume(1.0);
      return;
    }

    // Mute video's original audio when playing selected sound
    await _videoController?.setVolume(0.0);

    // Get the sound's asset path
    final soundService = await ref.read(soundLibraryServiceProvider.future);
    final sound = soundService.getSoundById(soundId);

    if (sound == null) {
      Log.warning('Sound not found: $soundId', category: LogCategory.video);
      return;
    }

    try {
      String filePath;

      // Load the audio - handle both asset paths and file paths
      if (sound.assetPath.startsWith('/') ||
          sound.assetPath.startsWith('file://')) {
        // Custom sound - file path
        filePath = sound.assetPath.replaceFirst('file://', '');
      } else {
        // Bundled asset - copy to temp file for reliable playback on desktop
        final tempDir = await getTemporaryDirectory();
        final extension = sound.assetPath.split('.').last;
        filePath = '${tempDir.path}/editor_${sound.id}.$extension';

        final tempFile = File(filePath);
        if (!await tempFile.exists()) {
          final assetData = await rootBundle.load(sound.assetPath);
          await tempFile.writeAsBytes(assetData.buffer.asUint8List());
        }
      }

      await _audioPlayer?.setFilePath(filePath);

      // Set looping to match video
      await _audioPlayer?.setLoopMode(LoopMode.one);

      // Play the audio
      await _audioPlayer?.play();

      Log.info('Playing sound: ${sound.title}', category: LogCategory.video);
    } catch (e) {
      Log.error('Failed to play sound: $e', category: LogCategory.video);
      // Unmute video on error
      await _videoController?.setVolume(1.0);
    }
  }

  void _handleAddSound() async {
    // Pause video and audio while selecting sound
    await _videoController?.pause();
    await _audioPlayer?.pause();

    // Wait for sounds to load
    final soundServiceAsync = await ref.read(
      soundLibraryServiceProvider.future,
    );

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SoundPickerModal(
          sounds: soundServiceAsync.sounds,
          selectedSoundId: ref
              .read(videoEditorProvider(widget.videoPath))
              .selectedSoundId,
          onSoundSelected: (soundId) {
            ref
                .read(videoEditorProvider(widget.videoPath).notifier)
                .selectSound(soundId);
            // Play the selected sound in preview
            _loadAndPlaySound(soundId);
            Navigator.of(context).pop();
          },
        ),
      ),
    );

    // Resume video after returning from sound picker
    if (mounted) {
      await _videoController?.play();
      // Audio will resume via _loadAndPlaySound if a sound is selected
    }
  }

  Future<void> _handleDone() async {
    // Stop audio preview before processing
    await _audioPlayer?.stop();

    try {
      Log.info(
        '📹 VideoEditorScreen: Creating draft for video: ${widget.videoPath}',
        category: LogCategory.video,
      );

      // Get the current editor state for text overlays
      final editorState = ref.read(videoEditorProvider(widget.videoPath));
      String finalVideoPath = widget.videoPath;

      // Apply text overlays if any exist
      if (editorState.textOverlays.isNotEmpty &&
          _isVideoInitialized &&
          _videoController != null) {
        Log.info(
          '📹 Burning ${editorState.textOverlays.length} text overlays into video',
          category: LogCategory.video,
        );

        // Use the actual video resolution for rendering overlays
        final videoSize = _videoController!.value.size;

        // Render text overlays to PNG, scaling fonts from preview to video size
        final renderer = TextOverlayRenderer();
        final overlayImage = await renderer.renderOverlays(
          editorState.textOverlays,
          videoSize,
          previewSize: _lastPreviewSize,
        );

        // Apply overlay to video using FFmpeg
        final exportService = VideoExportService();
        finalVideoPath = await exportService.applyTextOverlay(
          widget.videoPath,
          overlayImage,
        );

        Log.info(
          '📹 Text overlays burned into video: $finalVideoPath',
          category: LogCategory.video,
        );
      }

      // Apply sound overlay if one is selected
      if (editorState.selectedSoundId != null) {
        Log.info(
          '📹 Mixing sound: ${editorState.selectedSoundId}',
          category: LogCategory.video,
        );

        // Look up the sound's asset path from the sound library
        final soundService = await ref.read(soundLibraryServiceProvider.future);
        final sound = soundService.getSoundById(editorState.selectedSoundId!);

        if (sound != null) {
          final exportService = VideoExportService();
          final previousPath = finalVideoPath;
          finalVideoPath = await exportService.mixAudio(
            finalVideoPath,
            sound.assetPath,
          );

          // Clean up previous temp file if it was a temp file (not original)
          if (previousPath != widget.videoPath) {
            try {
              await File(previousPath).delete();
            } catch (e) {
              Log.warning(
                'Failed to delete temp file: $previousPath',
                category: LogCategory.video,
              );
            }
          }

          Log.info(
            '📹 Sound mixed into video: $finalVideoPath',
            category: LogCategory.video,
          );
        } else {
          Log.warning(
            '📹 Sound not found: ${editorState.selectedSoundId}',
            category: LogCategory.video,
          );
        }
      }

      // Create draft storage service
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);

      // Get the aspect ratio from recording state
      final recordingState = ref.read(vineRecordingProvider);
      final aspectRatio = recordingState.aspectRatio;

      // Create a draft for the edited video (with overlays burned in)
      final draft = VineDraft.create(
        videoFile: File(finalVideoPath),
        title: '',
        description: '',
        hashtags: [],
        frameCount: 0,
        selectedApproach: 'video',
        aspectRatio: aspectRatio,
      );

      await draftService.saveDraft(draft);

      Log.info(
        '📹 Created draft with ID: ${draft.id}',
        category: LogCategory.video,
      );

      if (mounted) {
        // Dispose video controller to free memory before navigating
        // The metadata screen will create its own player
        _videoController?.dispose();
        //TODO:    _videoController = null;
        _audioPlayer?.dispose();
        _audioPlayer = null;
        setState(() {
          _isVideoInitialized = false;
        });

        // Navigate to metadata screen
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoMetadataScreenPure(draftId: draft.id),
          ),
        );

        // Re-initialize video when returning from metadata screen
        if (mounted) {
          _audioPlayer = AudioPlayer();
          await _initializeVideo();
          // Re-apply sound if one was selected
          if (_currentSoundId != null) {
            await _loadAndPlaySound(_currentSoundId);
          }
        }
      }

      // Call original callback if exists
      widget.onExport?.call();
    } catch (e) {
      Log.error('Failed to create draft: $e', category: LogCategory.video);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

 */

  /// Generates the final video based on the given [parameters].
  ///
  /// Applies blur, color filters, cropping, rotation, flipping, and trimming
  /// before exporting using FFmpeg. Measures and stores the generation time.
  Future<void> _generateVideo(CompleteParameters parameters) async {
    final stopwatch = Stopwatch()..start();

    Log.info(
      '📹 VideoEditorScreen: Creating draft for video: ${widget.videoPath}',
      category: LogCategory.video,
    );

    unawaited(_videoEditorService.videoController?.pause());
    unawaited(_videoEditorService.audioService.pause());
    final directory = await getTemporaryDirectory();

    final AudioTrack? customAudioTrack = parameters.customAudioTrack;
    final double volumeBalance = customAudioTrack?.volumeBalance ?? 0;
    double overlayVolume = 1;
    double originalVolume = 1;
    if (volumeBalance < 0) {
      overlayVolume += volumeBalance;
    } else {
      originalVolume -= volumeBalance;
    }

    final exportModel = VideoRenderData(
      id: _videoEditorService.taskId,
      video: _videoEditorService.video,
      outputFormat: _videoEditorService.outputFormat,
      enableAudio:
          _videoEditorService.proVideoController?.isAudioEnabled ?? true,
      imageBytes: parameters.layers.isNotEmpty ? parameters.image : null,
      blur: parameters.blur,
      colorMatrixList: parameters.colorFilters,
      startTime: parameters.startTime,
      endTime: parameters.endTime,
      transform: parameters.isTransformed
          ? ExportTransform(
              width: parameters.cropWidth,
              height: parameters.cropHeight,
              rotateTurns: parameters.rotateTurns,
              x: parameters.cropX,
              y: parameters.cropY,
              flipX: parameters.flipX,
              flipY: parameters.flipY,
            )
          : null,
      customAudioPath: await _videoEditorService.audioService
          .safeCustomAudioPath(customAudioTrack),
      originalAudioVolume: originalVolume,
      customAudioVolume: overlayVolume,
      // bitrate: _videoMetadata.bitrate,
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final finalVideoPath = await ProVideoEditor.instance.renderVideoToFile(
        '${directory.path}/my_video_$now.mp4',
        exportModel,
      );

      // Get the aspect ratio from recording state
      final recordingState = ref.read(vineRecordingProvider);
      final aspectRatio = recordingState.aspectRatio;

      // Create a draft for the edited video (with overlays burned in)
      final draft = VineDraft.create(
        videoFile: File(finalVideoPath),
        title: '',
        description: '',
        hashtags: [],
        frameCount: 0,
        selectedApproach: 'video',
        aspectRatio: aspectRatio,
      );

      // Create draft storage service
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);
      await draftService.saveDraft(draft);
      Log.info(
        '📹 Created draft with ID: ${draft.id}',
        category: LogCategory.video,
      );

      if (mounted) {
        // Dispose video controller to free memory before navigating
        // The metadata screen will create its own player
        _videoEditorService.videoController?.dispose();
        _audioPlayer?.dispose();
        _audioPlayer = null;
        setState(() {
          _isVideoInitialized = false;
        });

        // Navigate to metadata screen
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoMetadataScreenPure(draftId: draft.id),
          ),
        );

        // Re-initialize video when returning from metadata screen
        if (mounted) {
          _audioPlayer = AudioPlayer();
          await _videoEditorService.initializePlayer();
          // Re-apply sound if one was selected
          if (_currentSoundId != null) {
            // TODO:  await _loadAndPlaySound(_currentSoundId);
          }
        }
      }

      // Call original callback if exists
      widget.onExport?.call();
    } on RenderCanceledException {
      stopwatch.stop();
      return;
    }
  }

  /// Closes the video editor and opens a preview screen if a video was
  /// exported.
  ///
  /// If [_outputPath] is available, it navigates to [PreviewVideo].
  /// Afterwards, it pops the current editor page.
  void _handleCloseEditor(EditorMode editorMode) async {
    if (editorMode != EditorMode.main) return Navigator.pop(context);
    /* 
    if (_outputPath != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewVideo(
            filePath: _outputPath!,
            generationTime: _videoGenerationTime,
          ),
        ),
      );
      _outputPath = null;
    } else {
      // Stop audio preview when going back
      _audioPlayer?.stop();

      if (widget.onBack != null) {
        widget.onBack!();
      } else {
        // Pop back to ClipManager since we got here via push
        context.pop();
      }
    } */

    _audioPlayer?.stop();

    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      // Pop back to ClipManager since we got here via push
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    Log.info(
      '📹 VideoEditorScreen.build() START - isVideoInitialized: $_isVideoInitialized',
      category: LogCategory.video,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _videoEditorService.proVideoController == null
          ? const Center(child: CircularProgressIndicator())
          : _buildEditor(),
    );
  }

  Widget _buildEditor() {
    return ProImageEditor.video(
      _videoEditorService.proVideoController!,
      key: _videoEditorService.editorKey,
      configs: _videoEditorService.configs,
      callbacks: _videoEditorService.getEditorCallbacks().copyWith(
        onCompleteWithParameters: _generateVideo,
        onCloseEditor: _handleCloseEditor,
      ),
    );
  }
}
