// ABOUTME: Bottom sheet for clip management options during video recording
// ABOUTME: Provides actions to add, save, remove, and clear recording clips

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Bottom sheet for managing recording clips.
///
/// Allows users to add clips from library, save current clips, or
/// remove/clear clips.
class VideoRecorderMoreSheet extends ConsumerStatefulWidget {
  /// Creates a more options bottom sheet widget.
  const VideoRecorderMoreSheet({super.key});

  @override
  ConsumerState<VideoRecorderMoreSheet> createState() =>
      _VideoRecorderMoreSheetState();
}

class _VideoRecorderMoreSheetState
    extends ConsumerState<VideoRecorderMoreSheet> {
  /// Opens the clip library screen in selection mode.
  ///
  /// When a clip is selected, it is imported into the current recording.
  Future<void> _showClipLibrary() async {
    Log.info(
      '📹 Opening clip library in selection mode',
      name: 'VideoRecorderMoreSheet',
      category: .video,
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101111),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: .vertical(top: .circular(32)),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ClipLibraryScreen(selectionMode: true),
    );

    Log.info(
      '📹 Closed clip library',
      name: 'VideoRecorderMoreSheet',
      category: .video,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));
    final clipsNotifier = ref.read(clipManagerProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: .min,
          children: [
            _buildMenuItem(
              icon: Icons.folder_open_outlined,
              title: 'Add clip from Library',
              onTap: _showClipLibrary,
            ),
            _buildMenuItem(
              icon: Icons.download,
              title: 'Save clip to Library',
              enabled: hasClips,
              onTap: clipsNotifier.saveClipsToLibrary,
            ),
            _buildMenuItem(
              icon: Icons.undo,
              title: 'Remove last clip',
              enabled: hasClips,
              onTap: clipsNotifier.removeLastClip,
              color: const Color(0xFFF44336),
            ),
            _buildMenuItem(
              icon: Icons.delete_outline,
              title: 'Clear all clips',
              enabled: hasClips,
              onTap: clipsNotifier.clearAll,
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
          fontSize: 24,
          fontWeight: .w700,
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
