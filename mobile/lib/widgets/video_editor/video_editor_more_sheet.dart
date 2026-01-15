// ABOUTME: Bottom sheet for video editor options.
// ABOUTME: Provides actions to add clips from library, save to drafts, or delete all clips.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/bottom_sheet_list_tile.dart';
import 'package:openvine/widgets/bottom_sheets/vine_bottom_sheet_drag_handle.dart';

/// Bottom sheet for video editor more options.
///
/// Allows users to add clips from library, save to drafts, or delete all clips.
class VideoEditorMoreSheet extends ConsumerStatefulWidget {
  /// Creates a video editor more options sheet.
  const VideoEditorMoreSheet({super.key});

  @override
  ConsumerState<VideoEditorMoreSheet> createState() =>
      _VideoEditorMoreSheetState();
}

class _VideoEditorMoreSheetState extends ConsumerState<VideoEditorMoreSheet> {
  /// Deletes all clips and starts over.
  Future<void> _deleteAndStartOver() async {
    ref.read(videoRecorderProvider.notifier).reset();
    ref.read(videoEditorProvider.notifier).reset();
    ref.read(videoPublishProvider.notifier).reset();
    ref.read(clipManagerProvider.notifier).clearAll();
    ref.read(selectedSoundProvider.notifier).clear();

    /// Navigate back to the video-recorder page.
    context.pop();
  }

  Future<void> _saveClipToLibrary() async {
    final clipManager = ref.read(clipManagerProvider.notifier);

    final clipIndex = ref.read(videoEditorProvider).currentClipIndex;

    await clipManager.saveClipToLibrary(clipManager.clips[clipIndex]);
  }

  /// Opens the clip library screen in selection mode.
  ///
  /// Shows a modal bottom sheet with the clip library. When a clip is selected,
  /// it is imported into the current editing session.
  Future<void> _pickFromLibrary(BuildContext context) async {
    Log.info(
      '📹 Opening clip library in selection mode',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.surfaceBackground,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => const ClipLibraryScreen(selectionMode: true),
    );

    Log.info(
      '📹 Closed clip library',
      name: 'ClipManagerNotifier',
      category: .video,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: .fromLTRB(0, 8, 0, 24),
              child: VineBottomSheetDragHandle(),
            ),
            BottomSheetListTile(
              iconPath: 'assets/icon/folder_open.svg',
              // TODO(l10n): Replace with context.l10n when localization is added.
              title: 'Add clip from Library',
              onTap: () => _pickFromLibrary(context),
            ),
            BottomSheetListTile(
              iconPath: 'assets/icon/save.svg',
              // TODO(l10n): Replace with context.l10n when localization is added.
              title: 'Save selected clip',
              onTap: _saveClipToLibrary,
            ),
            BottomSheetListTile(
              iconPath: 'assets/icon/trash.svg',
              // TODO(l10n): Replace with context.l10n when localization is added.
              title: 'Delete clips & start over',
              onTap: _deleteAndStartOver,
              color: const Color(0xFFF44336),
            ),
          ],
        ),
      ),
    );
  }
}
