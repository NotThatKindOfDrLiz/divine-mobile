import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_clip_preview.dart';

class VideoEditorClips extends ConsumerStatefulWidget {
  const VideoEditorClips({super.key});

  @override
  ConsumerState<VideoEditorClips> createState() => _VideoEditorClipsState();
}

class _VideoEditorClipsState extends ConsumerState<VideoEditorClips> {
  late PageController _pageController;
  int _currentPage = 0;

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

  double _calculateScale(int index) {
    if (!_pageController.hasClients ||
        !_pageController.position.haveDimensions) {
      return index == _currentPage ? 1 : 0.85;
    }

    final page = _pageController.page ?? _currentPage.toDouble();
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

  double _calculateXOffset(int index) {
    if (!_pageController.hasClients ||
        !_pageController.position.haveDimensions) {
      if (index < _currentPage) return 50;
      if (index > _currentPage) return -50;
      return 0;
    }

    final page = _pageController.page ?? _currentPage.toDouble();
    final difference = index - page;
    // Clips left of center: positive offset (move right, closer to center)
    // Clips right of center: negative offset (move left, closer to center)
    // Center clip: 0 offset
    const maxOffset = 50.0;

    // Cubic interpolation: strongest effect at ±1, zero at 0
    final effectStrength = difference.abs().clamp(0.0, 1.0);
    final eased = effectStrength * effectStrength * effectStrength; // cubic
    final scaledEased = eased * 0.8; // scale to max 0.8
    return -(difference.sign * scaledEased * maxOffset);
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(clipManagerProvider.select((state) => state.clips));

    if (clips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // PageView for smooth snap scrolling
        AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            return PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
              },
              itemCount: clips.length,
              itemBuilder: (context, index) {
                final clip = clips[index];
                final scale = _calculateScale(index);
                final xOffset = _calculateXOffset(index);

                // Fade out center clip in PageView, we'll render it on top
                final page = _pageController.page ?? _currentPage.toDouble();
                final difference = (index - page).abs();
                // Smooth fade: 0.0 at center, 1.0 at 0.2+ distance
                final opacity = (difference / 0.2).clamp(0.0, 1.0);

                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(xOffset, 0),
                    child: Transform.scale(
                      scale: scale,
                      child: VideoClipPreview(
                        clip: clip,
                        onTap: () {
                          if (index != _currentPage) {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),

        // Center clip overlay - rendered on top
        LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                if (!_pageController.hasClients ||
                    !_pageController.position.haveDimensions) {
                  return const SizedBox.shrink();
                }

                final page = _pageController.page ?? _currentPage.toDouble();
                final centerIndex = page.round();
                final difference = (centerIndex - page).abs();

                // Only show when very close to an actual page
                if (difference >= 0.2 || centerIndex >= clips.length) {
                  return const SizedBox.shrink();
                }

                final clip = clips[centerIndex];

                // Calculate transform based on current page position, not rounded index
                // This makes it scroll smoothly with PageView
                final pageViewOffset =
                    -(page - centerIndex) * constraints.maxWidth * 0.8;
                final scale = _calculateScale(centerIndex);
                final xOffset = _calculateXOffset(centerIndex);

                return IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(xOffset + pageViewOffset, 0),
                      child: Transform.scale(
                        scale: scale,
                        child: SizedBox(
                          width: constraints.maxWidth * 0.8,
                          child: VideoClipPreview(clip: clip, onTap: () {}),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),

        // Gradient overlays on sides
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 65,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 64,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
