// ABOUTME: Horizontal scrolling clip selector with depth animations
// ABOUTME: PageView with scale, offset transforms and center overlay for z-ordering

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_clip_preview.dart';

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.8);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Calculates the scale factor for a clip based on its distance from center.
  ///
  /// Returns 1.0 for the centered clip and 0.85 for clips far from center,
  /// with linear interpolation in between.
  double _calculateScale(int index, int currentClipIndex) {
    if (!_pageController.hasClients ||
        !_pageController.position.haveDimensions) {
      return index == currentClipIndex ? 1 : 0.85;
    }

    final page = _pageController.page ?? currentClipIndex.toDouble();
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
  ///
  /// Uses cubic easing to make the effect stronger as clips approach center.
  /// The offset is calculated as a percentage of screen width (20% max).
  /// Calculates the horizontal offset for a clip to create depth effect.
  ///
  /// Uses cubic easing to make the effect stronger as clips approach center.
  /// The offset is calculated as a percentage of screen width (20% max).
  double _calculateXOffset(
    int index,
    int currentClipIndex,
    double screenWidth,
  ) {
    // Calculate maxOffset as percentage of screen width (10%)
    final maxOffset = screenWidth * 0.2;

    if (!_pageController.hasClients ||
        !_pageController.position.haveDimensions) {
      if (index < currentClipIndex) return maxOffset;
      if (index > currentClipIndex) return -maxOffset;
      return 0;
    }

    final page = _pageController.page ?? currentClipIndex.toDouble();
    final difference = index - page;
    // Clips left of center: positive offset (move right, closer to center)
    // Clips right of center: negative offset (move left, closer to center)
    // Center clip: 0 offset

    // Cubic interpolation: strongest effect at ±1, zero at 0
    final effectStrength = difference.abs().clamp(0.0, 1.0);
    final eased = effectStrength * effectStrength * effectStrength; // cubic
    final scaledEased = eased * 0.8; // scale to max 0.8
    return -(difference.sign * scaledEased * maxOffset);
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(clipManagerProvider.select((state) => state.clips));
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (currentClipIndex: s.currentClipIndex, isEditing: s.isEditing),
      ),
    );
    final isEditing = state.isEditing;
    final currentClipIndex = state.currentClipIndex;

    if (clips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisAlignment: .center,
      crossAxisAlignment: .stretch,
      children: [
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  // Calculate common values once
                  final hasClients =
                      _pageController.hasClients &&
                      _pageController.position.haveDimensions;
                  final page = hasClients
                      ? (_pageController.page ?? currentClipIndex.toDouble())
                      : currentClipIndex.toDouble();
                  final centerIndex = page.round();
                  final difference = (centerIndex - page).abs();
                  final showCenterOverlay =
                      difference < 0.2 && centerIndex < clips.length;
                  final shadowOpacity = showCenterOverlay
                      ? 1.0 - (difference / 0.2)
                      : 0.0;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // PageView for smooth snap scrolling
                      IgnorePointer(
                        ignoring: isEditing,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (page) {
                            ref
                                .read(videoEditorProvider.notifier)
                                .selectClip(page);
                          },
                          itemCount: clips.length,
                          itemBuilder: (context, index) => _buildPageViewItem(
                            clip: clips[index],
                            index: index,
                            currentClipIndex: currentClipIndex,
                            page: page,
                            screenWidth: constraints.maxWidth,
                          ),
                        ),
                      ),

                      // Center clip overlay - rendered on top
                      if (showCenterOverlay)
                        _buildCenterOverlay(
                          clip: clips[centerIndex],
                          centerIndex: centerIndex,
                          currentClipIndex: currentClipIndex,
                          page: page,
                          shadowOpacity: shadowOpacity,
                          maxWidth: constraints.maxWidth,
                        ),

                      // Gradient overlays on sides
                      if (showCenterOverlay)
                        ..._buildGradientOverlays(
                          shadowOpacity,
                          constraints.maxWidth,
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        _buildInstructionText(isEditing),
      ],
    );
  }

  /// Builds the instruction text that appears below the clips.
  ///
  /// Uses AnimatedSwitcher with size and fade transitions.
  /// Hidden when editing is active.
  Widget _buildInstructionText(bool isEditing) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
      child: isEditing
          ? const SizedBox(width: .infinity)
          : Align(
              child: Padding(
                padding: const EdgeInsets.only(top: 25),
                child: Text(
                  'Tap to edit. Drag to reorder.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
    );
  }

  /// Builds a single clip item for the PageView.
  ///
  /// Applies scale, offset transformations and opacity based on distance
  /// from center.
  /// Clips near center (< 0.2 distance) are faded out to be replaced by the
  /// overlay.
  Widget _buildPageViewItem({
    required RecordingClip clip,
    required int index,
    required int currentClipIndex,
    required double page,
    required double screenWidth,
  }) {
    final scale = _calculateScale(index, currentClipIndex);
    final xOffset = _calculateXOffset(index, currentClipIndex, screenWidth);
    final clipDifference = (index - page).abs();
    final opacity = (clipDifference / 0.2).clamp(0.0, 1.0);

    return RepaintBoundary(
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(xOffset, 0),
          child: Transform.scale(
            scale: scale,
            child: VideoClipPreview(
              clip: clip,
              onTap: () async {
                if (index != currentClipIndex) {
                  await _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
                } else {
                  ref.read(videoEditorProvider.notifier).startClipEditing();
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the center clip overlay that appears on top of the PageView.
  ///
  /// This overlay ensures the centered clip renders **above** adjacent clips.
  /// Includes animated shadows that fade in as the clip approaches center.
  Widget _buildCenterOverlay({
    required RecordingClip clip,
    required int centerIndex,
    required int currentClipIndex,
    required double page,
    required double shadowOpacity,
    required double maxWidth,
  }) {
    final pageViewOffset = -(page - centerIndex) * maxWidth * 0.8;
    final scale = _calculateScale(centerIndex, currentClipIndex);
    final xOffset = _calculateXOffset(centerIndex, currentClipIndex, maxWidth);

    return RepaintBoundary(
      child: IgnorePointer(
        child: Center(
          child: Transform.translate(
            offset: Offset(xOffset + pageViewOffset, 0),
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: maxWidth * 0.8,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.32 * shadowOpacity),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.16 * shadowOpacity),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: VideoClipPreview(clip: clip),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds left and right gradient overlays that darken the edges.
  ///
  /// These gradients are only visible when a clip is near center,
  /// helping to focus attention on the centered clip.
  List<Widget> _buildGradientOverlays(double opacity, double screenWidth) {
    // Calculate gradient width as 10% of screen width
    final gradientWidth = screenWidth * 0.1;

    return [
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: gradientWidth,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: gradientWidth,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: .centerRight,
                  end: .centerLeft,
                  colors: [
                    Colors.black.withValues(alpha: 1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}
