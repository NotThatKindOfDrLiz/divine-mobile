// ABOUTME: Bottom sheet for video editor options.
// ABOUTME: Provides actions to add clips from library, save to drafts, or delete all clips.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/clip_manager_provider.dart';

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
            _buildMenuItem(
              icon: Icons.folder_open_outlined,
              title: 'Add clip from Library',
              onTap: () => ref
                  .read(clipManagerProvider.notifier)
                  .pickFromLibrary(context),
            ),
            _buildMenuItem(
              icon: Icons.save_outlined,
              title: 'Save to Drafts',
              enabled: hasClips,
              onTap: () =>
                  ref.read(clipManagerProvider.notifier).saveToDrafts(context),
            ),
            _buildMenuItem(
              icon: Icons.delete_outline,
              title: 'Delete clips & start over',
              enabled: hasClips,
              onTap: _deleteAndStartOver,
              color: const Color(0xFFF44336),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a styled menu item with consistent appearance.
  ///
  /// Returns a [ListTile] with the specified [icon], [title], and [onTap]
  /// callback.
  /// The item can be disabled with [enabled] and colored with [color].
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool enabled = true,
    Color color = Colors.white,
  }) {
    return ListTile(
      iconColor: color,
      textColor: color,
      enabled: enabled,
      minTileHeight: 64,
      leading: Icon(icon, size: 32),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'BricolageGrotesque',
          fontWeight: FontWeight.w700,
          fontSize: 24,
          height: 1.33,
          letterSpacing: 0,
        ),
        maxLines: 1,
        overflow: .ellipsis,
      ),
      onTap: () {
        Navigator.pop(context);
        onTap.call();
      },
    );
  }
}
