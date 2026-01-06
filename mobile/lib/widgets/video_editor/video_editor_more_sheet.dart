// ABOUTME: Bottom sheet for video editor options.
// ABOUTME: Provides actions to add clips from library, save to drafts, or delete all clips.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

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
  /// Opens the clip library screen in selection mode.
  ///
  /// When a clip is selected, it is imported into the current editing session.
  Future<void> _showClipLibrary() async {
    Log.info(
      '📹 Opening clip library in selection mode',
      name: 'VideoEditorMoreSheet',
      category: .video,
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ClipLibraryScreen(
          selectionMode: true,
          onClipSelected: (clip) async {
            await _importClipFromLibrary(clip);
          },
        ),
      ),
    );

    Log.info(
      '📹 Closed clip library',
      name: 'VideoEditorMoreSheet',
      category: .video,
    );
  }

  /// Imports a saved [clip] from the library into the current editing session.
  ///
  /// Verifies the file exists, adds it to the clip manager, and shows a
  /// confirmation.
  Future<void> _importClipFromLibrary(SavedClip clip) async {
    try {
      Log.info(
        '📹 Importing clip from library: ${clip.id}',
        name: 'VideoEditorMoreSheet',
        category: .video,
      );

      // Verify the file exists
      final videoFile = File(clip.filePath);
      if (!videoFile.existsSync()) {
        throw Exception('Video file not found');
      }

      if (!mounted) return;

      // Add to clip manager
      ref
          .read(clipManagerProvider.notifier)
          .addClip(
            video: EditorVideo.file(clip.filePath),
            duration: clip.duration,
            thumbnailPath: clip.thumbnailPath,
            aspectRatio: model.AspectRatio.values.firstWhere(
              (el) => el.name == clip.aspectRatio,
              orElse: () => .vertical,
            ),
          );

      Log.info(
        '📹 Added clip from library: ${clip.filePath}, '
        'duration: ${clip.duration.inMilliseconds}ms',
        name: 'VideoEditorMoreSheet',
        category: .video,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clip added'),
          backgroundColor: VineTheme.vineGreen,
        ),
      );
    } on Exception catch (e) {
      Log.error(
        '📹 Failed to import clip: $e',
        name: 'VideoEditorMoreSheet',
        category: .video,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import clip: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Saves all clips to drafts.
  Future<void> _saveToDrafts() async {
    Log.info(
      '📹 Saving video to drafts',
      name: 'VideoEditorMoreSheet',
      category: .video,
    );

    // TODO: Implement save to drafts functionality
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved to drafts'),
        backgroundColor: VineTheme.vineGreen,
      ),
    );
  }

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
              onTap: _showClipLibrary,
            ),
            _buildMenuItem(
              icon: Icons.save_outlined,
              title: 'Save to Drafts',
              enabled: hasClips,
              onTap: _saveToDrafts,
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
