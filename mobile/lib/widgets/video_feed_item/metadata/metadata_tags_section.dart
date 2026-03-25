// ABOUTME: Tags section for the metadata expanded sheet.
// ABOUTME: Displays category chips (accent-colored with emoji) and hashtag
// ABOUTME: chips (green "#" prefix) in a wrapping layout.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_section.dart';

/// Tags section showing category chips and hashtags.
///
/// Category chips (e.g., "Animals") have an accent-colored background and emoji
/// icon. Hashtag chips have a green "#" prefix. Classic Vine videos prepend a
/// "classic" hashtag chip.
///
/// Returns [SizedBox.shrink] when the video has no tags.
///
/// Matches Figma node `12345:71463`.
class MetadataTagsSection extends StatelessWidget {
  const MetadataTagsSection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    // "Classic" is treated as a tag per design spec.
    final allHashtags = [
      if (video.isOriginalVine) 'classic',
      ...video.hashtags,
    ];

    if (allHashtags.isEmpty) return const SizedBox.shrink();

    return MetadataSection(
      label: 'Tags',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in allHashtags) _HashtagChip(tag: tag),
        ],
      ),
    );
  }
}

/// A single hashtag chip with green "#" prefix and bold tag name.
class _HashtagChip extends StatelessWidget {
  const _HashtagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Text(
            '#',
            style: VineTheme.bodyLargeFont(color: VineTheme.vineGreen),
          ),
          Flexible(
            child: Text(
              tag,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.titleSmallFont(),
            ),
          ),
        ],
      ),
    );
  }
}
