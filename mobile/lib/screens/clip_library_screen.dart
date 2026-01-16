// ABOUTME: Screen for browsing and managing saved video clips
// ABOUTME: Shows grid of clip thumbnails with preview, delete, and import options

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/bottom_sheets/vine_bottom_sheet_drag_handle.dart';
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
    unawaited(_loadClips());
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
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle(
      statusBarColor: Colors.red,
      statusBarIconBrightness: .light,
      statusBarBrightness: .dark,
    ),
    child: Scaffold(
      backgroundColor: widget.selectionMode
          ? VineTheme.surfaceBackground
          : const Color(0xFF101111),
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
              ],
            ),
      body: Column(
        children: [
          if (widget.selectionMode)
            _SelectionHeader(
              isSelectionMode: widget.selectionMode,
              selectedClipIds: _selectedClipIds,
              remainingDuration: _remainingDuration,
              onCreate: _createVideoFromSelected,
            )
          else
            const SizedBox(height: 4),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: VineTheme.vineGreen,
                    ),
                  )
                : _clips.isEmpty
                ? _EmptyClips(isSelectionMode: widget.selectionMode)
                : _MasonryLayout(
                    clips: _clips,
                    selectedClipIds: _selectedClipIds,
                    remainingDuration: _remainingDuration,
                    onTapClip: _toggleClipSelection,
                    onLongPressClip: _showClipPreview,
                  ),
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
    ),
  );

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
              unawaited(_deleteClip(clip));
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
}

class _SelectionHeader extends ConsumerWidget {
  _SelectionHeader({
    required this.isSelectionMode,
    required this.selectedClipIds,
    required this.onCreate,
    required this.remainingDuration,
  });

  final bool isSelectionMode;
  final Set<String> selectedClipIds;
  final VoidCallback onCreate;
  final Duration remainingDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const Padding(
          padding: .fromLTRB(0, 8, 0, 16),
          child: VineBottomSheetDragHandle(),
        ),
        Row(
          mainAxisSize: .min,
          spacing: 4,
          children: [
            const Spacer(),
            Column(
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              children: [
                Text(
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  'Clips',
                  style: VineTheme.titleFont(
                    color: VineTheme.onSurface,
                    fontSize: 18,
                    height: 1.33,
                    letterSpacing: 0.15,
                  ),
                ),
                Text(
                  '${remainingDuration.toFormattedSeconds()}s remaining',
                  style: VineTheme.bodyFont(
                    color: const Color(0xBEFFFFFF),
                    fontSize: 12,
                    height: 1.33,
                    letterSpacing: 0.40,
                  ).copyWith(fontFeatures: [const .tabularFigures()]),
                ),
              ],
            ),
            Expanded(
              child: Align(
                alignment: .centerRight,
                child: _AddClipButton(
                  onTap: selectedClipIds.isNotEmpty ? onCreate : context.pop,
                  enable: selectedClipIds.isNotEmpty,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _MasonryLayout extends StatelessWidget {
  const _MasonryLayout({
    required this.clips,
    required this.selectedClipIds,
    required this.remainingDuration,
    required this.onTapClip,
    required this.onLongPressClip,
  });

  final List<SavedClip> clips;
  final Set<String> selectedClipIds;
  final Duration remainingDuration;
  final ValueChanged<SavedClip> onTapClip;
  final ValueChanged<SavedClip> onLongPressClip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 8),
      child: MasonryGrid(
        columnCount: 2,
        rowGap: 4,
        columnGap: 4,
        itemAspectRatios: clips.map((clip) => clip.aspectRatioValue).toList(),
        children: clips.map((clip) {
          final isSelected = selectedClipIds.contains(clip.id);
          return VideoClipThumbnailCard(
            clip: clip,
            isSelected: isSelected,
            disabled: !isSelected && clip.duration > remainingDuration,
            onTap: () => onTapClip(clip),
            onLongPress: () => onLongPressClip(clip),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyClips extends StatelessWidget {
  const _EmptyClips({required this.isSelectionMode});

  final bool isSelectionMode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
              border: .all(color: Colors.grey[600]!, width: 2),
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
              fontWeight: .bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recorded video clips will appear here',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          if (!isSelectionMode) ...[
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.pushVideoRecorder(),
              icon: const Icon(Icons.videocam),
              label: const Text('Record a Video'),
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.whiteText,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(borderRadius: .circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddClipButton extends StatelessWidget {
  const _AddClipButton({required this.onTap, this.enable = true});

  final VoidCallback? onTap;
  final bool enable;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Add',
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: enable ? 1 : 0.32,
          child: Container(
            margin: const .only(right: 16),
            padding: const .symmetric(horizontal: 16, vertical: 8),
            decoration: ShapeDecoration(
              color: VineTheme.tabIndicatorGreen,
              shape: RoundedRectangleBorder(borderRadius: .circular(16)),
            ),
            child: const Text(
              // TODO(l10n): Replace with context.l10n when localization is added.
              'Add',
              textAlign: .center,
              style: TextStyle(
                color: Color(0xFF002C1C),
                fontSize: 18,
                fontFamily: 'BricolageGrotesque',
                fontWeight: .w800,
                height: 1.33,
                letterSpacing: 0.15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
