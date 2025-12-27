import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

class VideoRecorderMoreSheet extends ConsumerStatefulWidget {
  const VideoRecorderMoreSheet({super.key});

  @override
  ConsumerState<VideoRecorderMoreSheet> createState() =>
      _VideoRecorderMoreSheetState();
}

class _VideoRecorderMoreSheetState
    extends ConsumerState<VideoRecorderMoreSheet> {
  Future<void> _showClipLibrary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClipLibraryScreen(
          selectionMode: true,
          onClipSelected: (clip) async {
            await _importClipFromLibrary(clip);
          },
        ),
      ),
    );
  }

  Future<void> _importClipFromLibrary(SavedClip clip) async {
    try {
      Log.info('📹 Importing clip from library: ${clip.id}', category: .video);

      // Verify the file exists
      final videoFile = File(clip.filePath);
      if (!await videoFile.exists()) {
        throw Exception('Video file not found');
      }

      if (!mounted) return;

      // Add to clip manager
      ref
          .read(clipManagerProvider.notifier)
          .addClip(
            filePath: clip.filePath,
            duration: clip.duration,
            thumbnailPath: clip.thumbnailPath,
          );

      Log.info(
        '📹 Added clip from library: ${clip.filePath}, duration: ${clip.duration.inMilliseconds}ms',
        category: .video,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clip added'),
          backgroundColor: VineTheme.vineGreen,
        ),
      );
    } catch (e) {
      Log.error('📹 Failed to import clip: $e', category: .video);

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
    final hasSegments = ref.watch(
      vineRecordingProvider.select((p) => p.hasSegments),
    );
    final clipsNotifier = ref.read(clipManagerProvider.notifier);

    return SafeArea(
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
            enabled: hasSegments,
            onTap: clipsNotifier.saveClipToLibrary,
          ),
          _buildMenuItem(
            icon: Icons.undo,
            title: 'Remove last clip',
            enabled: hasSegments,
            onTap: clipsNotifier.removeLastClip,
            color: Color(0xFFF44336),
          ),
          _buildMenuItem(
            icon: Icons.delete_outline,
            title: 'Clear all clips',
            enabled: hasSegments,
            onTap: clipsNotifier.clearAll,
            color: Color(0xFFF44336),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
    bool enabled = true,
    Color color = Colors.white,
  }) {
    return ListTile(
      iconColor: color,
      textColor: color,
      enabled: enabled,
      minTileHeight: 64.0,
      leading: Icon(icon, size: 32),
      title: Text(title, style: TextStyle(fontSize: 22, fontWeight: .w600)),
      onTap: () {
        Navigator.pop(context);
        onTap?.call();
      },
    );
  }
}
