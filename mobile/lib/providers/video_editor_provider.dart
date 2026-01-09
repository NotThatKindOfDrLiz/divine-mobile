// ABOUTME: Riverpod provider for managing video editor state with text overlays and export tracking
// ABOUTME: Exposes EditorNotifier for state mutations and reactive EditorState updates

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor/video_editor_meta.dart';
import 'package:openvine/models/video_editor_state.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_editor/meta/video_editor_meta_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_more_sheet.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

final videoEditorProvider = NotifierProvider<VideoEditorNotifier, EditorState>(
  VideoEditorNotifier.new,
);

class VideoEditorNotifier extends Notifier<EditorState> {
  String? _draftId;
  VideoEditorMeta _metadata = VideoEditorMeta.draft();

  @override
  EditorState build() {
    return const EditorState();
  }

  /// Initialize the video editor with an optional draft.
  ///
  /// Loads existing draft data if [draftId] is provided, including clips
  /// and metadata.
  Future<void> initialize({String? draftId}) async {
    reset();

    _draftId = draftId;
    if (draftId != null && draftId.isNotEmpty) {
      Log.info(
        '🎬 Initializing video editor with draft ID: $draftId',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);
      final draft = await draftService.getDraftById(_draftId!);
      if (draft != null) {
        _metadata = VideoEditorMeta.fromVineDraft(draft);
        ref.read(clipManagerProvider.notifier).addMultipleClips(draft.clips);
        Log.info(
          '✅ Draft loaded with ${draft.clips.length} clip(s)',
          name: 'VideoEditorNotifier',
          category: .video,
        );
      } else {
        Log.warning(
          '⚠️ Draft not found: $draftId',
          name: 'VideoEditorNotifier',
          category: .video,
        );
      }
    } else {
      Log.info(
        '🎬 Initializing video editor (no draft)',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    }
  }

  /// Select a clip by index and update the current position.
  ///
  /// Calculates the playback offset based on previous clips' durations.
  void selectClip(int index) {
    final clipManager = ref.read(clipManagerProvider.notifier);

    // Calculate offset from all previous clips
    final offset = clipManager.clips
        .take(index)
        .fold(Duration.zero, (sum, clip) => sum + clip.duration);

    Log.debug(
      '🎯 Selected clip $index (offset: ${offset.inSeconds}s)',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    state = state.copyWith(
      currentClipIndex: index,
      isPlaying: false,
      currentPosition: offset,
      splitPosition: .zero,
    );
  }

  /// Start clip reordering mode for drag-and-drop operations.
  void startClipReordering() {
    Log.debug(
      '🔄 Started clip reordering mode',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(isReordering: true);
  }

  /// Stop clip reordering mode and reset delete zone state.
  void stopClipReordering() {
    Log.debug(
      '✅ Stopped clip reordering mode',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(isReordering: false, isOverDeleteZone: false);
  }

  /// Update whether a clip is being dragged over the delete zone.
  void setOverDeleteZone(bool isOver) {
    state = state.copyWith(isOverDeleteZone: isOver);
  }

  /// Enter editing mode for the currently selected clip.
  ///
  /// Resets trim position to zero when entering edit mode.
  void startClipEditing() {
    Log.info(
      '✂️ Started editing clip ${state.currentClipIndex}',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    final clips = ref.read(clipManagerProvider).clips;
    state = state.copyWith(
      isEditing: true,
      isPlaying: false,
      splitPosition: clips[state.currentClipIndex].duration ~/ 2,
    );
  }

  /// Exit editing mode for the currently selected clip.
  void stopClipEditing() {
    Log.info(
      '✅ Stopped editing clip ${state.currentClipIndex}',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(isEditing: false, isPlaying: false);
  }

  /// Toggle between editing and viewing mode for the current clip.
  void toggleClipEditing() {
    if (state.isEditing) {
      stopClipEditing();
    } else {
      startClipEditing();
    }
  }

  /// Split the currently selected clip at the current split position.
  ///
  /// Creates two new clips and renders them in parallel. Both clips must
  /// meet the minimum duration requirement.
  Future<void> splitSelectedClip() async {
    final splitPosition = state.splitPosition;
    final clips = ref.read(clipManagerProvider).clips;
    final selectedClip = clips[state.currentClipIndex];

    // Validate split position
    if (!VideoEditorSplitService.isValidSplitPosition(
      selectedClip,
      splitPosition,
    )) {
      Log.warning(
        '⚠️ Invalid split position ${splitPosition.inSeconds}s - '
        'clips must be at least ${VideoEditorSplitService.minClipDuration.inMilliseconds}ms',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      return;
    }

    Log.info(
      '✂️ Splitting clip ${selectedClip.id} at ${splitPosition.inSeconds}s',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    stopClipEditing();

    final clipNotifier = ref.read(clipManagerProvider.notifier);

    try {
      await VideoEditorSplitService.splitClip(
        sourceClip: selectedClip,
        splitPosition: splitPosition,
        onClipsCreated: (startClip, endClip) {
          // Add clips to UI immediately so processing status is visible
          clipNotifier
            ..refreshClip(startClip)
            ..insertClip(state.currentClipIndex + 1, endClip);
        },
        onThumbnailExtracted: (clip, thumbnailPath) {
          if (ref.mounted) {
            clipNotifier.updateClipThumbnail(clip.id, thumbnailPath);
          }
        },
        onClipRendered: (clip, video) {
          if (ref.mounted) {
            clipNotifier.updateClipVideo(clip.id, video);
            Log.debug(
              '✅ Clip rendered: ${clip.id}',
              name: 'VideoEditorNotifier',
              category: .video,
            );
          }
        },
      );
      Log.info(
        '✅ Successfully split clip into 2 segments',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    } catch (e) {
      Log.error(
        '❌ Failed to split clip: $e',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    }
  }

  /// Pause video playback.
  void pauseVideo() {
    Log.debug('⏸️ Paused video', name: 'VideoEditorNotifier', category: .video);
    state = state.copyWith(isPlaying: false);
  }

  /// Toggle between playing and paused states.
  void togglePlayPause() {
    final newState = !state.isPlaying;
    Log.debug(
      newState ? '▶️ Playing video' : '⏸️ Paused video',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(isPlaying: newState);
  }

  /// Seek to a specific position within the trim range.
  void seekToTrimPosition(Duration value) {
    state = state.copyWith(splitPosition: value, isPlaying: false);
  }

  /// Toggle audio mute state.
  void toggleMute() {
    final newState = !state.isMuted;
    Log.debug(
      newState ? '🔇 Muted audio' : '🔊 Unmuted audio',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(isMuted: newState);
  }

  /// Reset editor state and metadata to defaults.
  void reset() {
    Log.debug(
      '🔄 Resetting editor state',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    _metadata = VideoEditorMeta.draft();
    state = const EditorState();
  }

  /// Update the current playback position.
  ///
  /// In editing mode, uses absolute position within the clip.
  /// In viewing mode, adds offset from previous clips.
  void updatePosition(Duration position) {
    final clipManager = ref.read(clipManagerProvider.notifier);

    // Calculate offset from all previous clips
    final offset = state.isEditing
        ? Duration.zero
        : clipManager.clips
              .take(state.currentClipIndex)
              .fold(Duration.zero, (sum, clip) => sum + clip.duration);

    state = state.copyWith(currentPosition: offset + position);
  }

  /// Update video metadata (title, description, hashtags, etc.).
  void setMetadata(VideoEditorMeta value) {
    Log.debug(
      '📝 Updated video metadata',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    _metadata = value;
  }

  /// Set the draft ID for saving/loading.
  void setDraftId(String id) {
    Log.debug(
      '💾 Set draft ID: $id',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    _draftId = id;
  }

  /// Show the more options bottom sheet.
  Future<void> showMoreOptions(BuildContext context) async {
    Log.debug(
      '⚙️ Showing more options sheet',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101111),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: .vertical(top: .circular(32)),
      ),
      builder: (context) => const VideoEditorMoreSheet(),
    );
  }

  /// Complete editing and render the final video.
  ///
  /// Shows metadata sheet for user input, renders video with all clips,
  /// and navigates to publish screen on success.
  void done(BuildContext context) async {
    Log.info(
      '🎬 Starting final video render',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(isProcessing: true);

    final completer = Completer<String?>();

    unawaited(_renderVideo(completer));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101111),
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => VideoEditorMetaSheet(draftId: _draftId),
    );

    final outputPath = await completer.future;

    final validToPublish = outputPath != null;

    final metaData = validToPublish
        ? await ProVideoEditor.instance.getMetadata(
            EditorVideo.file(outputPath),
          )
        : null;

    state = state.copyWith(isProcessing: false);

    if (!validToPublish) {
      Log.warning(
        '⚠️ Video render cancelled or failed',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      return;
    }

    if (!context.mounted) return;

    Log.info(
      '✅ Video rendered successfully - duration: ${metaData!.duration.inSeconds}s',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    final clipManager = ref.read(clipManagerProvider.notifier);
    final clips = clipManager.clips;

    final clip = RecordingClip(
      id: 'clip-${DateTime.now()}',
      video: EditorVideo.file(outputPath),
      duration: metaData.duration,
      recordedAt: .now(),
      aspectRatio: clips.first.aspectRatio,
    );

    ref.read(videoPublishProvider.notifier)
      ..reset()
      ..initialize(draft: await getDraft(clip));

    Log.info(
      '📤 Navigating to publish screen',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    if (!context.mounted) return;
    await context.pushVideoPublish();
  }

  /// Create a VineDraft from the rendered clip with metadata and proofmode data.
  Future<VineDraft> getDraft(RecordingClip clip) async {
    final filePath = await clip.video.safeFilePath();
    final proofData = await NativeProofModeService.proofFile(File(filePath));
    final proofManifestJson = proofData == null ? null : jsonEncode(proofData);

    return VineDraft.create(
      id: _draftId,
      clips: [clip],
      title: _metadata.title,
      description: _metadata.description,
      hashtags: _metadata.hashtags,
      allowAudioReuse: _metadata.allowAudioReuse,
      expireTime: _metadata.expireTime,
      proofManifestJson: proofManifestJson,
      selectedApproach: 'video',
    );
  }

  /// Render all clips into a single video file with aspect ratio cropping.
  ///
  /// Applies center cropping based on target aspect ratio (square or vertical).
  Future<void> _renderVideo(Completer<String?> completer) async {
    final clipManager = ref.read(clipManagerProvider.notifier);
    final clips = clipManager.clips;

    final outputPath = await VideoEditorRenderService.renderVideo(
      clips: clips,
      aspectRatio: clips.first.aspectRatio,
    );

    state = state.copyWith(isProcessing: false);
    completer.complete(outputPath);
  }
}
