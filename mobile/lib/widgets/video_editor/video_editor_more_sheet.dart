// ABOUTME: Bottom sheet for video editor options.
// ABOUTME: Provides actions to add clips from library, save to drafts, or delete all clips.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/bottom_sheet_list_tile.dart';

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
    ref.read(clipManagerProvider.notifier).clearAll();

    /// Navigate back to the video-recorder page.
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BottomSheetListTile(
              iconPath: 'assets/icon/folder_open.svg',
              title: 'Add clip from Library',
              onTap: () => ref
                  .read(clipManagerProvider.notifier)
                  .pickFromLibrary(context),
            ),
            BottomSheetListTile(
              iconPath: 'assets/icon/save.svg',
              title: 'Save to Drafts',
              onTap: hasClips
                  ? () => ref
                        .read(clipManagerProvider.notifier)
                        .saveToDrafts(context)
                  : null,
            ),
            BottomSheetListTile(
              iconPath: 'assets/icon/trash.svg',
              title: 'Delete clips & start over',
              onTap: hasClips ? _deleteAndStartOver : null,
              color: const Color(0xFFF44336),
            ),
          ],
        ),
      ),
    );
  }
}
