// ABOUTME: Bottom sheet for clip management options during video recording
// ABOUTME: Provides actions to add, save, remove, and clear recording clips

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

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
      name: 'VideoRecorderMoreSheet',
      category: .video,
    );
  }

  /// Imports a saved [clip] from the library into the current recording.
  ///
  /// Verifies the file exists, adds it to the clip manager, and shows a
  /// confirmation.
  Future<void> _importClipFromLibrary(SavedClip clip) async {
    try {
      Log.info(
        '📹 Importing clip from library: ${clip.id}',
        name: 'VideoRecorderMoreSheet',
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
        name: 'VideoRecorderMoreSheet',
        category: .video,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clip added'),
          backgroundColor: VineTheme.vineGreen,
        ),
      );
    } catch (e) {
      Log.error(
        '📹 Failed to import clip: $e',
        name: 'VideoRecorderMoreSheet',
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
