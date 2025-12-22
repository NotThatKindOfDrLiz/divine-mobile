// ABOUTME: Main service for video editing operations including player, audio, and clip management
// ABOUTME: Handles video initialization, thumbnail generation, trimming, and export functionality

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_editor/clips_previewer_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

import 'video_editor_audio_service.dart';
import 'video_editor_thumbnail_service.dart';

// TODO(@hm21): Write unit-tests
class VideoEditorService {
  VideoEditorService({
    required this.videoPath,
    required this.context,
    required this.onStateChanged,
  });

  final String videoPath;
  final BuildContext context;
  final VoidCallback onStateChanged;

  final _proVideoEditor = ProVideoEditor.instance;
  final editorKey = GlobalKey<ProImageEditorState>();
  final _updateClipsNotifier = ValueNotifier(false);
  final taskId = DateTime.now().microsecondsSinceEpoch.toString();

  /// The target format for the exported video.
  final outputFormat = VideoOutputFormat.mp4;

  /// Number of thumbnails to generate across the video timeline.
  final int _thumbnailCount = 7;

  /// The video currently loaded in the editor.
  late EditorVideo video = EditorVideo.file(videoPath);

  /// Holds information about the selected video.
  late VideoMetadata _videoMetadata;

  VideoPlayerController? videoController;
  late VideoEditorAudioService audioService;
  late VideoEditorThumbnailService thumbnailService;

  /// Stores generated thumbnails for the trimmer bar and filter background.
  List<ImageProvider>? _thumbnails;

  /// Controls video playback and trimming functionalities.
  ProVideoController? proVideoController;

  /// Indicates whether a seek operation is in progress.
  bool _isSeeking = false;

  /// Stores the currently selected trim duration span.
  TrimDurationSpan? _durationSpan;

  /// Temporarily stores a pending trim duration span.
  TrimDurationSpan? _tempDurationSpan;

  late final ProImageEditorConfigs configs = ProImageEditorConfigs(
    dialogConfigs: DialogConfigs(
      widgets: DialogWidgets(
        //TODO(@hm21): loadingDialog: (message, configs) =>
      ),
    ),
    mainEditor: MainEditorConfigs(
      tools: [
        .videoClips,
        .audio,
        .paint,
        .text,
        .cropRotate,
        .tune,
        .filter,
        .emoji,
        // .blur,
        // .sticker,
      ],
      widgets: MainEditorWidgets(
        removeLayerArea:
            (removeAreaKey, editor, rebuildStream, isLayerBeingTransformed) =>
                VideoEditorRemoveArea(
                  removeAreaKey: removeAreaKey,
                  editor: editor,
                  rebuildStream: rebuildStream,
                  isLayerBeingTransformed: isLayerBeingTransformed,
                ),
      ),
    ),
    textEditor: TextEditorConfigs(
      showSelectFontStyleBottomBar: true,
      defaultTextStyle: GoogleFonts.roboto(),
      customTextStyles: [
        GoogleFonts.roboto(),
        GoogleFonts.montserrat(),
        GoogleFonts.pacifico(),
        GoogleFonts.bebasNeue(),
        GoogleFonts.oswald(),
        GoogleFonts.playfairDisplay(),
        GoogleFonts.lobster(),
        GoogleFonts.anton(),
        GoogleFonts.permanentMarker(),
        GoogleFonts.bangers(),
        GoogleFonts.alfaSlabOne(),
        GoogleFonts.righteous(),
        /* TODO(@hm21): Before it was possible to search google fonts
        GoogleFonts.asMap().keys
                    .where((font) => font.toLowerCase().contains(searchQuery))
                    .take(50)
                    .toList(
         */
      ],
    ),
    paintEditor: const PaintEditorConfigs(
      tools: [
        PaintMode.freeStyle,
        PaintMode.arrow,
        PaintMode.line,
        PaintMode.rect,
        PaintMode.circle,
        PaintMode.dashLine,
        PaintMode.polygon,
        // Blur and pixelate are not supported.
        // PaintMode.pixelate,
        // PaintMode.blur,
        PaintMode.eraser,
      ],
    ),
    audioEditor: AudioEditorConfigs(audioTracks: []),
    clipsEditor: ClipsEditorConfigs(
      clips: [
        VideoClip(
          id: '001',
          title: 'My awesome video',
          // subtitle: 'Optional',
          duration: Duration.zero,
          clip: EditorVideoClip.autoSource(
            assetPath: video.assetPath,
            bytes: video.byteArray,
            file: video.file,
            networkUrl: video.networkUrl,
          ),
        ),
      ],
    ),
    videoEditor: const VideoEditorConfigs(
      initialMuted: false,
      initialPlay: false,
      isAudioSupported: true,
      minTrimDuration: Duration(seconds: 7),
      playTimeSmoothingDuration: Duration(milliseconds: 600),
    ),
  );

  /// Creates ProImageEditorCallbacks with all necessary video, audio, and clips callbacks
  ProImageEditorCallbacks getEditorCallbacks() {
    return ProImageEditorCallbacks(
      videoEditorCallbacks: VideoEditorCallbacks(
        onPause: videoController?.pause,
        onPlay: videoController?.play,
        onMuteToggle: (isMuted) {
          if (isMuted) {
            audioService.setVolume(0);
            videoController?.setVolume(0);
          } else {
            audioService.balanceAudio();
          }
        },
        onTrimSpanUpdate: (durationSpan) {
          if (videoController!.value.isPlaying) {
            proVideoController!.pause();
          }
        },
        onTrimSpanEnd: (span) async {
          await _seekToPosition(span);
        },
      ),
      audioEditorCallbacks: AudioEditorCallbacks(
        onBalanceChange: audioService.balanceAudio,
        onStartTimeChange: (startTime) async {
          await Future.wait([
            audioService.seek(startTime),
            videoController!.seekTo(Duration.zero),
          ]);
        },
        onPlay: audioService.play,
        onStop: (audio) => audioService.pause(),
      ),
      clipsEditorCallbacks: ClipsEditorCallbacks(
        onBuildPlayer: (controller, videoClip) {
          return ClipsPreviewer(
            videoConfigs: configs.videoEditor,
            proController: controller,
            videoClip: videoClip,
          );
        },
        onMergeClips: mergeClips,
        onReadKeyFrame: (source) => thumbnailService.getKeyFrame(source),
        onReadKeyFrames: (source) => thumbnailService.getKeyFrames(source),
        onAddClip: addClip,
      ),
    );
  }

  Future<void> initializePlayer() async {
    Log.info(
      '🎬 VideoEditorService.initializePlayer() START - videoPath: $videoPath',
      category: LogCategory.video,
    );

    await _setMetadata();

    configs.clipsEditor.clips.first = configs.clipsEditor.clips.first.copyWith(
      duration: _videoMetadata.duration,
    );

    // Initialize services
    thumbnailService = VideoEditorThumbnailService(
      context: context,
      thumbnailCount: _thumbnailCount,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateThumbnails();
    });

    Log.info(
      '🎬 VideoEditorService.initializePlayer() - Creating VideoPlayerController...',
      category: LogCategory.video,
    );
    videoController = VideoPlayerController.file(File(videoPath));

    Log.info(
      '🎬 VideoEditorService.initializePlayer() - Creating AudioService...',
      category: LogCategory.video,
    );
    audioService = VideoEditorAudioService(
      videoController: videoController!,
      onStateChanged: onStateChanged,
    );

    Log.info(
      '🎬 VideoEditorService.initializePlayer() - Initializing player and audio...',
      category: LogCategory.video,
    );
    await Future.wait([
      videoController!.initialize(),
      videoController!.setLooping(false),
      videoController!.setVolume(configs.videoEditor.initialMuted ? 0 : 100),
      configs.videoEditor.initialPlay
          ? videoController!.play()
          : videoController!.pause(),
      audioService.initialize(),
    ]);

    if (!context.mounted) {
      Log.warning(
        '🎬 VideoEditorService.initializePlayer() - Widget unmounted after initialization',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      '🎬 VideoEditorService.initializePlayer() - Creating ProVideoController...',
      category: LogCategory.video,
    );
    proVideoController = ProVideoController(
      videoPlayer: _buildVideoPlayer(),
      initialResolution: _videoMetadata.resolution,
      videoDuration: _videoMetadata.duration,
      fileSize: _videoMetadata.fileSize,
      thumbnails: _thumbnails,
    );

    Log.info(
      '🎬 VideoEditorService.initializePlayer() - Adding duration change listener...',
      category: LogCategory.video,
    );
    videoController!.addListener(_onDurationChange);

    onStateChanged();

    Log.info(
      '🎬 VideoEditorService.initializePlayer() COMPLETE - Video ready',
      category: LogCategory.video,
    );
  }

  /// Select a sound for the video
  void selectSound(String? soundId) => audioService.selectSound(soundId);

  /// Load and play the selected sound, synced with video
  Future<void> loadAndPlaySound(String? soundId) =>
      audioService.loadAndPlaySound(soundId);

  /// Actually play the sound file
  Future<void> playSound(String filePath, String soundTitle) =>
      audioService.playSound(filePath, soundTitle);

  /// Stop the audio player
  Future<void> stopAudio() => audioService.stopAudio();

  /// Pause the audio player
  Future<void> pauseAudio() => audioService.pauseAudio();

  /// Get the currently selected sound ID
  String? get selectedSoundId => audioService.selectedSoundId;

  void dispose() {
    Log.info(
      '🎬 VideoEditorService.dispose() - Cleaning up resources...',
      category: LogCategory.video,
    );
    videoController?.removeListener(_onDurationChange);
    videoController?.dispose();
    audioService.dispose();
    Log.info(
      '🎬 VideoEditorService.dispose() COMPLETE',
      category: LogCategory.video,
    );
  }

  Future<VideoClip?> addClip() async {
    Log.info(
      '🎬 VideoEditorService.addClip() START',
      category: LogCategory.video,
    );

    // Open video picker
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    // User cancelled picker
    if (!context.mounted || result == null || result.files.isEmpty) {
      Log.info(
        '🎬 VideoEditorService.addClip() - User cancelled or no file selected',
        category: LogCategory.video,
      );
      return null;
    }

    final file = result.files.single;
    final path = file.path;
    if (path == null) {
      Log.warning(
        '🎬 VideoEditorService.addClip() - File path is null',
        category: LogCategory.video,
      );
      return null;
    }

    Log.info(
      '🎬 VideoEditorService.addClip() - Selected file: $path',
      category: LogCategory.video,
    );

    // Extract file name for display
    final name = file.name;
    final title = name.split('.').first;
    LoadingDialog.instance.show(context, configs: configs);
    Log.info(
      '🎬 VideoEditorService.addClip() - Getting metadata...',
      category: LogCategory.video,
    );
    final meta = await _proVideoEditor.getMetadata(EditorVideo.file(path));
    Log.info(
      '🎬 VideoEditorService.addClip() - Metadata retrieved, duration: ${meta.duration}',
      category: LogCategory.video,
    );
    LoadingDialog.instance.hide();

    // Create and return your video clip
    Log.info(
      '🎬 VideoEditorService.addClip() COMPLETE - Clip created: $title',
      category: LogCategory.video,
    );
    return VideoClip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      clip: EditorVideoClip.file(path),
      duration: meta.duration,
    );
  }

  Future<void> mergeClips(List<VideoClip> clips) async {
    Log.info(
      '🎬 VideoEditorService.mergeClips() START - Merging ${clips.length} clips',
      category: LogCategory.video,
    );

    LoadingDialog.instance.show(context, configs: configs);
    final directory = await getApplicationCacheDirectory();
    final updatedFile = File('${directory.path}/temp.mp4');
    Log.info(
      '🎬 VideoEditorService.mergeClips() - Output path: ${updatedFile.path}',
      category: LogCategory.video,
    );

    _updateClipsNotifier.value = true;
    Log.info(
      '🎬 VideoEditorService.mergeClips() - Rendering video...',
      category: LogCategory.video,
    );
    await _proVideoEditor.renderVideoToFile(
      updatedFile.path,
      VideoRenderData(
        id: taskId,
        videoSegments: clips.map((el) {
          final clip = el.clip;
          return VideoSegment(
            video: EditorVideo.autoSource(
              networkUrl: clip.networkUrl,
              assetPath: clip.assetPath,
              byteArray: clip.bytes,
              file: clip.file,
            ),
            startTime: el.trimSpan?.start,
            endTime: el.trimSpan?.end,
          );
        }).toList(),
      ),
    );
    if (!context.mounted) {
      Log.warning(
        '🎬 VideoEditorService.mergeClips() - Widget unmounted during merge',
        category: LogCategory.video,
      );
      LoadingDialog.instance.hide();
      return;
    }

    Log.info(
      '🎬 VideoEditorService.mergeClips() - Video rendered successfully',
      category: LogCategory.video,
    );
    video = EditorVideo.file(updatedFile.path);

    Log.info(
      '🎬 VideoEditorService.mergeClips() - Loading metadata and thumbnails...',
      category: LogCategory.video,
    );
    await _setMetadata();
    thumbnailService.clearCache();
    await _generateThumbnails(updateClipThumbnails: false);
    await initializePlayer();

    final editor = editorKey.currentState!;

    proVideoController =
        ProVideoController(
          videoPlayer: _buildVideoPlayer(),
          initialResolution: _videoMetadata.resolution,
          videoDuration: _videoMetadata.duration,
          fileSize: _videoMetadata.fileSize,
          thumbnails: _thumbnails,
        )..initialize(
          configsFunction: () => configs.videoEditor,
          callbacksAudioFunction: () =>
              editor.audioEditorCallbacks ?? const AudioEditorCallbacks(),
          callbacksFunction: () =>
              editor.callbacks.videoEditorCallbacks ?? VideoEditorCallbacks(),
        );

    /// Load the new video
    final controller = VideoPlayerController.file(File(updatedFile.path));
    await controller.initialize();
    LoadingDialog.instance.hide();

    if (!context.mounted) return;

    videoController = controller;
    videoController!.addListener(_onDurationChange);
    editor.initializeVideoEditor();

    _updateClipsNotifier.value = false;
    onStateChanged();

    Log.info(
      '🎬 VideoEditorService.mergeClips() COMPLETE',
      category: LogCategory.video,
    );
  }

  void _onDurationChange() {
    var totalVideoDuration = _videoMetadata.duration;
    var duration = videoController!.value.position;
    proVideoController!.setPlayTime(duration);

    if (_durationSpan != null && duration >= _durationSpan!.end) {
      _seekToPosition(_durationSpan!);
    } else if (duration >= totalVideoDuration) {
      _seekToPosition(
        TrimDurationSpan(start: Duration.zero, end: totalVideoDuration),
      );
    }
  }

  Future<void> _seekToPosition(TrimDurationSpan span) async {
    _durationSpan = span;

    if (_isSeeking) {
      _tempDurationSpan = span; // Store the latest seek request
      return;
    }
    _isSeeking = true;

    proVideoController!.pause();
    proVideoController!.setPlayTime(_durationSpan!.start);

    await videoController!.pause();
    await videoController!.seekTo(span.start);

    _isSeeking = false;

    // Check if there's a pending seek request
    if (_tempDurationSpan != null) {
      TrimDurationSpan nextSeek = _tempDurationSpan!;
      _tempDurationSpan = null; // Clear the pending seek
      await _seekToPosition(nextSeek); // Process the latest request
    }
  }

  /// Loads and sets [_videoMetadata] for the given [video].
  Future<void> _setMetadata() async {
    Log.info(
      '🎬 VideoEditorService._setMetadata() - Loading metadata...',
      category: LogCategory.video,
    );
    _videoMetadata = await _proVideoEditor.getMetadata(video);
    Log.info(
      '🎬 VideoEditorService._setMetadata() - Metadata loaded: duration=${_videoMetadata.duration}, resolution=${_videoMetadata.resolution}',
      category: LogCategory.video,
    );
  }

  /// Generates thumbnails for the given [video].
  Future<void> _generateThumbnails({bool updateClipThumbnails = true}) async {
    final temporaryThumbnails = await thumbnailService.generateThumbnails(
      video: video,
      videoMetadata: _videoMetadata,
    );

    if (temporaryThumbnails == null) return;

    if (updateClipThumbnails) {
      configs.clipsEditor.clips.first = configs.clipsEditor.clips.first
          .copyWith(thumbnails: temporaryThumbnails);
    }

    _thumbnails = temporaryThumbnails;

    if (proVideoController != null) {
      proVideoController!.thumbnails = _thumbnails;
    }
  }

  Widget _buildVideoPlayer() {
    return ValueListenableBuilder(
      valueListenable: _updateClipsNotifier,
      builder: (_, isLoading, __) {
        return Center(
          child: isLoading
              ? const CircularProgressIndicator.adaptive()
              : AspectRatio(
                  aspectRatio: videoController!.value.size.aspectRatio,
                  child: VideoPlayer(videoController!),
                ),
        );
      },
    );
  }
}
