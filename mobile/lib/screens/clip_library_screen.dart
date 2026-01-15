// ABOUTME: Screen for browsing and managing saved video clips
// ABOUTME: Shows grid of clip thumbnails with preview, delete, and import options

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/divine_icon_button.dart';
import 'package:openvine/widgets/masonary_grid.dart';
import 'package:openvine/widgets/video_clip/video_clip_preview_sheet.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class ClipLibraryScreen extends ConsumerStatefulWidget {
  const ClipLibraryScreen({
    super.key,
    this.selectionMode = false,
    this.onClipSelected,
  });

  /// When true, tapping a clip calls onClipSelected instead of previewing
  final bool selectionMode;

  /// Called when a clip is selected in selection mode
  final void Function(SavedClip clip)? onClipSelected;

  @override
  ConsumerState<ClipLibraryScreen> createState() => _ClipLibraryScreenState();
}

class _ClipLibraryScreenState extends ConsumerState<ClipLibraryScreen> {
  List<SavedClip> _clips = [];
  bool _isLoading = true;
  // Always show selection checkboxes when not in single-selection mode
  // This makes multi-select the default behavior for better UX
  final Set<String> _selectedClipIds = {};

  Duration _selectedDuration = .zero;

  @override
  void initState() {
    super.initState();
    _loadClips();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadClips() async {
    try {
      final clipService = ref.read(clipLibraryServiceProvider);
      final clips = await clipService.getAllClips();

      if (mounted) {
        setState(() {
          _clips = clips;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Duration get _remainingDuration {
    final remainingDuration = widget.selectionMode
        ? ref.watch(clipManagerProvider.select((s) => s.remainingDuration))
        : const Duration(milliseconds: 6300);
    return remainingDuration - _selectedDuration;
  }

  String _buildAppBarTitle() {
    if (widget.selectionMode) {
      return 'Select Clip';
    } else if (_selectedClipIds.isNotEmpty) {
      return '${_selectedClipIds.length} selected';
    } else {
      return 'Clips';
    }
  }

  void _clearSelection() {
    setState(_selectedClipIds.clear);
    _selectedDuration = .zero;
  }

  void _toggleClipSelection(SavedClip clip) {
    setState(() {
      if (_selectedClipIds.contains(clip.id)) {
        _selectedClipIds.remove(clip.id);
        _selectedDuration -= clip.duration;
      } else {
        _selectedClipIds.add(clip.id);
        _selectedDuration += clip.duration;
      }
    });
  }

  Future<void> _createVideoFromSelected() async {
    final selectedClips = _clips
        .where((clip) => _selectedClipIds.contains(clip.id))
        .toList();
    if (selectedClips.isEmpty) return;

    // Add selected clips to ClipManager
    final clipManagerNotifier = ref.read(clipManagerProvider.notifier);

    if (!widget.selectionMode) {
      // Clear existing clips first
      clipManagerNotifier.clearAll();
    }

    // Add each selected clip
    for (final clip in selectedClips) {
      // Skip if clip already exists in clip-manager
      if (!clipManagerNotifier.clips.any((el) => el.id == clip.id)) {
        clipManagerNotifier.addClip(
          video: EditorVideo.file(clip.filePath),
          duration: clip.duration,
          thumbnailPath: clip.thumbnailPath,
          aspectRatio: model.AspectRatio.values.firstWhere(
            (el) => el.name == clip.aspectRatio,
            orElse: () => .vertical,
          ),
        );
      }
    }

    if (widget.selectionMode) {
      context.pop();
    } else {
      // Navigate to editor with fromLibrary flag so back goes to recorder
      await context.pushVideoEditor(fromLibrary: true);

      // Clear selection
      _clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101111),
    appBar: widget.selectionMode
        ? null
        : AppBar(
            backgroundColor: const Color(0xFF101111),
            foregroundColor: VineTheme.whiteText,
            title: Text(_buildAppBarTitle()),
            actions: [
              // Clear selection button when clips are selected
              if (_selectedClipIds.isNotEmpty && !widget.selectionMode)
                TextButton(
                  onPressed: _clearSelection,
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: VineTheme.whiteText),
                  ),
                ),
              if (_selectedClipIds.isEmpty &&
                  _clips.isNotEmpty &&
                  !widget.selectionMode)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: VineTheme.whiteText),
                  onSelected: (value) async {
                    if (value == 'clear_all') {
                      await _showClearAllConfirmation();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Clear All Clips'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
    body: Column(
      children: [
        ?_buildClipSelectionHeader(),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: VineTheme.vineGreen),
                )
              : _clips.isEmpty
              ? _buildEmptyState()
              : _buildMasonryLayout(),
        ),
      ],
    ),
    floatingActionButton: !widget.selectionMode && _selectedClipIds.isNotEmpty
        ? FloatingActionButton.extended(
            onPressed: _createVideoFromSelected,
            icon: const Icon(Icons.movie_creation),
            label: const Text('Create Video'),
            backgroundColor: VineTheme.vineGreen,
          )
        : null,
  );

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[800],
            border: Border.all(color: Colors.grey[600]!, width: 2),
          ),
          child: const Icon(
            Icons.video_library_outlined,
            size: 60,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'No Clips Yet',
          style: TextStyle(
            color: VineTheme.whiteText,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your recorded video clips will appear here',
          style: TextStyle(color: Colors.grey[400], fontSize: 16),
        ),
        if (!widget.selectionMode) ...[
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              await context.pushVideoRecorder();
            },
            icon: const Icon(Icons.videocam),
            label: const Text('Record a Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
              foregroundColor: VineTheme.whiteText,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget? _buildClipSelectionHeader() {
    if (!widget.selectionMode) return null;

    final remainingDuration = widget.selectionMode
        ? ref.watch(clipManagerProvider.select((s) => s.remainingDuration))
        : const Duration(milliseconds: 6300);

    return Container(
      padding: const .fromLTRB(16, 0, 16, 16),
      decoration: const BoxDecoration(color: Color(0xFF101111)),
      child: Row(
        mainAxisSize: .min,
        spacing: 16,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'BricolageGrotesque',
                    fontWeight: FontWeight.w800,
                    height: 1.33,
                    letterSpacing: 0.15,
                  ),
                ),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: .w400,
                      height: 1.43,
                      letterSpacing: 0.25,
                    ),
                    children: [
                      TextSpan(
                        text: '${remainingDuration.toFormattedSeconds()}s',
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: _selectedClipIds.isNotEmpty ? 0.50 : 1,
                          ),
                          decoration: _selectedClipIds.isNotEmpty
                              ? .lineThrough
                              : null,
                        ),
                      ),
                      if (_selectedClipIds.isNotEmpty)
                        TextSpan(
                          text: ' ${_remainingDuration.toFormattedSeconds()}s',
                        ),
                      const TextSpan(text: ' left'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          DivineIconButton(
            semanticLabel: 'Add clips',
            backgroundColor: const Color(0xFF000000),
            iconSize: 32,
            iconPath: 'assets/icon/add.svg',
            onTap: _selectedClipIds.isNotEmpty
                ? _createVideoFromSelected
                : context.pop,
          ),
        ],
      ),
    );
  }

  Widget _buildMasonryLayout() {
    return Padding(
      padding: const .symmetric(horizontal: 8),
      child: MasonryGrid(
        columnCount: 2,
        rowGap: 4,
        columnGap: 4,
        itemAspectRatios: _clips
            .map((clip) => clip.aspectRatio == 'vertical' ? 9 / 16 : 1.0)
            .toList(),
        children: _clips.map((clip) {
          final isSelected = _selectedClipIds.contains(clip.id);
          return VideoClipThumbnailCard(
            clip: clip,
            isSelected: isSelected,
            disabled: !isSelected && clip.duration > _remainingDuration,
            onTap: () => _toggleClipSelection(clip),
            onLongPress: () => _showClipPreview(clip),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _showClipPreview(SavedClip clip) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VideoClipPreviewSheet(
        clip: clip,
        onDelete: () async {
          Navigator.of(context).pop();
          await _confirmDeleteClip(clip);
        },
      ),
    );
  }

  Future<void> _confirmDeleteClip(SavedClip clip) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Clip?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          'This will permanently delete this ${clip.durationInSeconds.toStringAsFixed(1)}s clip.',
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteClip(clip);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClip(SavedClip clip) async {
    try {
      final clipService = ref.read(clipLibraryServiceProvider);
      await clipService.deleteClip(clip.id);

      // Delete video file
      final videoFile = File(clip.filePath);
      if (await videoFile.exists()) {
        await videoFile.delete();
      }

      // Delete thumbnail if exists
      if (clip.thumbnailPath != null) {
        final thumbFile = File(clip.thumbnailPath!);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      }

      setState(() {
        _clips.removeWhere((c) => c.id == clip.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clip deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete clip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showClearAllConfirmation() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Clear All Clips?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          'This will permanently delete all ${_clips.length} clip(s). This action cannot be undone.',
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearAllClips();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllClips() async {
    try {
      final clipService = ref.read(clipLibraryServiceProvider);

      // Delete all video and thumbnail files
      for (final clip in _clips) {
        try {
          final videoFile = File(clip.filePath);
          if (await videoFile.exists()) {
            await videoFile.delete();
          }
          if (clip.thumbnailPath != null) {
            final thumbFile = File(clip.thumbnailPath!);
            if (await thumbFile.exists()) {
              await thumbFile.delete();
            }
          }
        } catch (_) {
          // Continue even if individual file deletion fails
        }
      }

      await clipService.clearAllClips();

      setState(() {
        _clips.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All clips cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear clips: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
