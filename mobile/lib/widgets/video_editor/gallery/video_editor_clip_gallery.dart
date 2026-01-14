// ABOUTME: Horizontal scrolling clip selector with depth animations
// ABOUTME: PageView with scale, offset transforms and center overlay for z-ordering

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_center_clip_overlay.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_gallery_edge_gradients.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_gallery_instruction_text.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_gallery_item.dart';

/// Horizontal scrolling clip selector with animated transitions.
class VideoEditorClipGallery extends ConsumerStatefulWidget {
  /// Creates a video editor clips widget.
  const VideoEditorClipGallery({super.key});

  @override
  ConsumerState<VideoEditorClipGallery> createState() =>
      _VideoEditorClipsState();
}

class _VideoEditorClipsState extends ConsumerState<VideoEditorClipGallery> {
  late PageController _pageController;
  late ScrollController _scrollController;
  final _dragOffsetNotifier = ValueNotifier<double>(0);
  int _reorderTargetIndex = 0;
  double _accumulatedDragOffset = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.8);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _dragOffsetNotifier.dispose();
    super.dispose();
  }

  /// Performs a hit test to check if the pointer is over the delete button.
  bool _isPointerOverDeleteButton(Offset globalPosition) {
    final deleteButtonKey = ref.read(videoEditorProvider).deleteButtonKey;

    if (deleteButtonKey.currentContext == null) {
      return false;
    }

    final renderBox =
        deleteButtonKey.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return false;
    }

    // Convert global position to local coordinates
    final localPosition = renderBox.globalToLocal(globalPosition);

    // Check if the local position is within the bounds
    return renderBox.paintBounds.contains(localPosition);
  }

  Future<void> _handleReorderEvent(
    PointerMoveEvent event,
    BoxConstraints constraints,
  ) async {
    final clips = ref.read(clipManagerProvider).clips;

    // Perform hit test on delete button
    final isOverDeleteZone = _isPointerOverDeleteButton(event.position);
    ref.read(videoEditorProvider.notifier).setOverDeleteZone(isOverDeleteZone);

    // If over delete zone, reset drag offset and skip reorder logic
    if (isOverDeleteZone) {
      _dragOffsetNotifier.value = 0;
      _accumulatedDragOffset = 0;
      return;
    }

    // Update visual drag offset (for rotation effect)
    _dragOffsetNotifier.value = (_dragOffsetNotifier.value + event.delta.dx)
        .clamp(-constraints.maxWidth * 0.3, constraints.maxWidth * 0.3);

    // Accumulate drag offset for page switching
    _accumulatedDragOffset += event.delta.dx;

    // Calculate threshold: 10% of screen width per clip
    final threshold = constraints.maxWidth * 0.10;

    // Check if we should switch pages
    if (_accumulatedDragOffset.abs() >= threshold) {
      var newTargetIndex = _reorderTargetIndex;

      if (_accumulatedDragOffset > 0 &&
          _reorderTargetIndex < clips.length - 1) {
        // Dragged right -> move to next clip (right)
        newTargetIndex = _reorderTargetIndex + 1;
      } else if (_accumulatedDragOffset < 0 && _reorderTargetIndex > 0) {
        // Dragged left -> move to previous clip (left)
        newTargetIndex = _reorderTargetIndex - 1;
      }

      if (newTargetIndex != _reorderTargetIndex) {
        // Reorder the clip in the manager
        ref
            .read(clipManagerProvider.notifier)
            .reorderClip(_reorderTargetIndex, newTargetIndex);

        _reorderTargetIndex = newTargetIndex;
        _accumulatedDragOffset = 0; // Reset accumulator

        // Update selected clip index to follow the clip
        ref.read(videoEditorProvider.notifier).selectClip(newTargetIndex);

        // Scroll the SingleChildScrollView to the new position
        if (_scrollController.hasClients) {
          await _scrollController.animateTo(
            newTargetIndex * constraints.maxWidth * 0.8,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  Future<void> _handleReorderCancel() async {
    // Check if clip should be deleted
    final isOverDeleteZone = ref.read(videoEditorProvider).isOverDeleteZone;

    if (isOverDeleteZone) {
      // Delete the clip if released over delete zone
      final clips = ref.read(clipManagerProvider).clips;
      if (_reorderTargetIndex >= 0 && _reorderTargetIndex < clips.length) {
        final clipToDelete = clips[_reorderTargetIndex];
        ref.read(clipManagerProvider.notifier).deleteClip(clipToDelete.id);

        if (ref.read(clipManagerProvider.notifier).clips.isEmpty) {
          context.pop();
          return;
        }

        // Update selected index after deletion
        final remainingClips = ref.read(clipManagerProvider).clips;
        final newIndex = _reorderTargetIndex >= remainingClips.length
            ? remainingClips.length - 1
            : _reorderTargetIndex;
        _reorderTargetIndex = newIndex;
        ref.read(videoEditorProvider.notifier).selectClip(newIndex);
      }
    }

    // Animate drag offset back to 0
    final startOffset = _dragOffsetNotifier.value;
    if (startOffset.abs() > 0.1) {
      const steps = 10;
      const duration = Duration(milliseconds: 200);
      final stepDuration = duration ~/ steps;

      for (var i = 1; i <= steps; i++) {
        final progress = Curves.easeOut.transform(i / steps);
        _dragOffsetNotifier.value = startOffset * (1 - progress);
        await Future<void>.delayed(stepDuration);
        if (!mounted) return;
      }
    }

    _dragOffsetNotifier.value = 0;
    _accumulatedDragOffset = 0;

    // Exit reorder mode
    ref.read(videoEditorProvider.notifier).stopClipReordering();

    // Recreate the PageController with the new position and trigger rebuild
    setState(() {
      _pageController.dispose();
      _pageController = PageController(
        initialPage: _reorderTargetIndex,
        viewportFraction: 0.8,
      );
    });
  }

  void _startReordering() {
    final currentClipIndex = ref.read(videoEditorProvider).currentClipIndex;

    _reorderTargetIndex = currentClipIndex;
    _accumulatedDragOffset = 0;

    // Store the current PageView offset
    final currentOffset = _pageController.hasClients
        ? _pageController.offset
        : 0.0;

    // Switch to reorder mode
    ref.read(videoEditorProvider.notifier).startClipReordering();

    // Recreate ScrollController and trigger rebuild
    setState(() {
      _scrollController.dispose();
      _scrollController = ScrollController(initialScrollOffset: currentOffset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(clipManagerProvider.select((state) => state.clips));

    if (clips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisAlignment: .center,
      crossAxisAlignment: .stretch,
      children: [
        Flexible(
          child: _GalleryViewer(
            scrollController: _scrollController,
            pageController: _pageController,
            clips: clips,
            onStartReordering: _startReordering,
            onReorderCancel: _handleReorderCancel,
            onReorderEvent: _handleReorderEvent,
            dragOffsetNotifier: _dragOffsetNotifier,
          ),
        ),
        const ClipGalleryInstructionText(),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _GalleryViewer extends ConsumerWidget {
  const _GalleryViewer({
    required this.scrollController,
    required this.pageController,
    required this.clips,
    required this.onStartReordering,
    required this.onReorderCancel,
    required this.onReorderEvent,
    required this.dragOffsetNotifier,
  });

  final ScrollController scrollController;
  final PageController pageController;
  final List<RecordingClip> clips;
  final VoidCallback onStartReordering;
  final VoidCallback onReorderCancel;
  final Function(PointerMoveEvent event, BoxConstraints constraints)
  onReorderEvent;
  final ValueNotifier<double> dragOffsetNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (
          currentClipIndex: s.currentClipIndex,
          isEditing: s.isEditing,
          isReordering: s.isReordering,
          isOverDeleteZone: s.isOverDeleteZone,
        ),
      ),
    );
    final currentClipIndex = state.currentClipIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerMove: (event) async {
            if (state.isReordering) onReorderEvent(event, constraints);
          },
          onPointerUp: (event) async {
            if (state.isReordering) onReorderCancel();
          },
          onPointerCancel: (event) async {
            if (state.isReordering) onReorderCancel();
          },
          child: AnimatedBuilder(
            animation: pageController,
            builder: (context, child) {
              // Calculate common values once
              final hasClients =
                  pageController.hasClients &&
                  pageController.position.haveDimensions;
              final page = hasClients
                  ? (pageController.page ?? currentClipIndex.toDouble())
                  : currentClipIndex.toDouble();
              final centerIndex = page.round();
              final difference = (centerIndex - page).abs();
              final showCenterOverlay =
                  difference < 0.2 && centerIndex < clips.length;
              final shadowOpacity = showCenterOverlay
                  ? 1.0 - (difference / 0.2)
                  : 0.0;

              return _ScrollStack(
                scrollController: scrollController,
                pageController: pageController,
                clips: clips,
                isEditing: state.isEditing,
                currentClipIndex: currentClipIndex,
                constraints: constraints,
                page: page,
                centerIndex: centerIndex,
                showCenterOverlay: showCenterOverlay,
                shadowOpacity: shadowOpacity,
                dragOffsetNotifier: dragOffsetNotifier,
                onStartReordering: onStartReordering,
              );
            },
          ),
        );
      },
    );
  }
}

class _ScrollStack extends ConsumerWidget {
  const _ScrollStack({
    required this.scrollController,
    required this.pageController,
    required this.clips,
    required this.onStartReordering,
    required this.dragOffsetNotifier,
    required this.isEditing,
    required this.currentClipIndex,
    required this.constraints,
    required this.page,
    required this.centerIndex,
    required this.showCenterOverlay,
    required this.shadowOpacity,
  });

  final ScrollController scrollController;
  final PageController pageController;
  final List<RecordingClip> clips;
  final VoidCallback onStartReordering;
  final ValueNotifier<double> dragOffsetNotifier;
  final BoxConstraints constraints;
  final bool isEditing;
  final int currentClipIndex;
  final double page;
  final int centerIndex;
  final bool showCenterOverlay;
  final double shadowOpacity;

  /// Calculates the scale factor for a clip based on its distance from center.
  ///
  /// Returns 1.0 for the centered clip and 0.85 for clips far from center,
  /// with linear interpolation in between.
  double _calculateScale(int index) {
    if (!pageController.hasClients || !pageController.position.haveDimensions) {
      return index == currentClipIndex ? 1 : 0.85;
    }

    final page = pageController.page ?? currentClipIndex.toDouble();
    final difference = (page - index).abs();
    // Scale from 1.0 (center) to 0.85 (far away)
    // difference 0.0 = scale 1.0
    // difference 1.0+ = scale 0.85
    const minScale = 0.85;
    const maxScale = 1;

    if (difference >= 1) {
      return minScale;
    }

    return maxScale - (difference * (maxScale - minScale));
  }

  /// Calculates the horizontal offset for a clip to create depth effect.
  double _calculateXOffset(int index) {
    // Calculate maxOffset as percentage of screen width (10%)
    final maxOffset = constraints.maxWidth * 0.2;

    if (!pageController.hasClients || !pageController.position.haveDimensions) {
      if (index < currentClipIndex) return maxOffset;
      if (index > currentClipIndex) return -maxOffset;
      return 0;
    }

    final page = pageController.page ?? currentClipIndex.toDouble();
    final difference = index - page;
    final absDifference = difference.abs();

    // Offset is 0 for clips beyond distance 1.3
    if (absDifference > 1.3) return 0;

    const offsetStart = 0.4;
    // X-Offset only applies from [offsetStart] to 1.0 distance
    // From 0.0 to [offsetStart]: no offset (clips wait)
    // From [offsetStart] to 1.0: offset increases to max
    // From 1.0 to 1.3: gradual falloff
    double effectStrength;
    if (absDifference < offsetStart) {
      // No offset until clip is almost at edge
      effectStrength = 0;
    } else if (absDifference <= 1.0) {
      // Remap [offsetStart, 1.0] to [0.0, 1.0]
      final remapped = (absDifference - offsetStart) / (1.0 - offsetStart);
      effectStrength = remapped * remapped * remapped;
    } else {
      // Gradual falloff: 1.0→0.0 over distance 1.0→1.3
      final falloff =
          (1.3 - absDifference) / 0.3; // 1.0 at distance 1.0, 0.0 at 1.3
      effectStrength = falloff;
    }

    final scaledEased = effectStrength * 0.8;
    return -(difference.sign * scaledEased * maxOffset);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (
          currentClipIndex: s.currentClipIndex,
          isEditing: s.isEditing,
          isReordering: s.isReordering,
          isOverDeleteZone: s.isOverDeleteZone,
        ),
      ),
    );

    return Stack(
      clipBehavior: .none,
      children: [
        // Use different scroll widget based on reorder state
        if (state.isReordering)
          _ReorderingView(
            scrollController: scrollController,
            clips: clips,
            isEditing: isEditing,
            currentClipIndex: currentClipIndex,
            constraints: constraints,
            onStartReordering: onStartReordering,
            calculateScale: _calculateScale,
            calculateXOffset: _calculateXOffset,
          )
        else
          _SwipeView(
            pageController: pageController,
            clips: clips,
            isEditing: isEditing,
            currentClipIndex: currentClipIndex,
            page: page,
            onStartReordering: onStartReordering,
            calculateScale: _calculateScale,
            calculateXOffset: _calculateXOffset,
          ),

        if (showCenterOverlay) ...[
          // Center clip overlay which rendered on top,
          // which imitate a higher z-index.
          VideoEditorCenterClipOverlay(
            clip: clips[centerIndex],
            centerIndex: centerIndex,
            currentClipIndex: currentClipIndex,
            page: page,
            shadowOpacity: shadowOpacity,
            maxWidth: constraints.maxWidth,
            isReordering: state.isReordering,
            isOverDeleteZone: state.isOverDeleteZone,
            dragOffsetNotifier: dragOffsetNotifier,
            scale: _calculateScale(centerIndex),
            xOffset: _calculateXOffset(centerIndex),
          ),

          // Gradient overlays on sides
          ClipGalleryEdgeGradients(
            opacity: shadowOpacity,
            gradientWidth: constraints.maxWidth * 0.1,
          ),
        ],
      ],
    );
  }
}

class _ReorderingView extends ConsumerWidget {
  const _ReorderingView({
    required this.clips,
    required this.isEditing,
    required this.currentClipIndex,
    required this.constraints,
    required this.onStartReordering,
    required this.scrollController,
    required this.calculateScale,
    required this.calculateXOffset,
  });

  final List<RecordingClip> clips;
  final bool isEditing;
  final int currentClipIndex;
  final BoxConstraints constraints;
  final VoidCallback onStartReordering;
  final ScrollController scrollController;
  final double Function(int index) calculateScale;
  final double Function(int index) calculateXOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: .symmetric(horizontal: constraints.maxWidth * 0.1),
        child: Row(
          children: List.generate(clips.length, (index) {
            final scale = calculateScale(index);
            final xOffset = calculateXOffset(index);

            return SizedBox(
              width: constraints.maxWidth * 0.8,
              child: VideoEditorGalleryItem(
                clip: clips[index],
                index: index,
                isCurrentClip: index == currentClipIndex,
                page: currentClipIndex.toDouble(),
                scale: scale,
                xOffset: xOffset,
                onTap: () {
                  if (index != currentClipIndex) {
                    ref.read(videoEditorProvider.notifier).selectClip(index);
                  } else {
                    ref.read(videoEditorProvider.notifier).toggleClipEditing();
                  }
                },
                onLongPress: index == currentClipIndex && !isEditing
                    ? onStartReordering
                    : null,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _SwipeView extends ConsumerWidget {
  const _SwipeView({
    required this.clips,
    required this.isEditing,
    required this.currentClipIndex,
    required this.page,
    required this.pageController,
    required this.onStartReordering,
    required this.calculateScale,
    required this.calculateXOffset,
  });

  final PageController pageController;
  final List<RecordingClip> clips;
  final bool isEditing;
  final int currentClipIndex;
  final double page;
  final VoidCallback onStartReordering;
  final double Function(int index) calculateScale;
  final double Function(int index) calculateXOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageView.builder(
      controller: pageController,
      onPageChanged: (page) {
        ref.read(videoEditorProvider.notifier).selectClip(page);
      },
      itemCount: clips.length,
      itemBuilder: (context, index) {
        final scale = calculateScale(index);
        final xOffset = calculateXOffset(index);
        return VideoEditorGalleryItem(
          clip: clips[index],
          index: index,
          isCurrentClip: index == currentClipIndex,
          page: page,
          scale: scale,
          xOffset: xOffset,
          onTap: () async {
            if (index != currentClipIndex) {
              await pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.ease,
              );
            } else {
              ref.read(videoEditorProvider.notifier).toggleClipEditing();
            }
          },
          onLongPress: index == currentClipIndex && !isEditing
              ? onStartReordering
              : null,
        );
      },
    );
  }
}
