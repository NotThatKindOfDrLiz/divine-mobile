import 'dart:async';

import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

/// A masonry grid layout that displays children in columns with synchronized
/// scrolling.
///
/// Children are distributed evenly across columns, and each column can have
/// different heights based on its content. All columns scroll together as one.
class MasonryGrid extends StatefulWidget {
  /// Creates a masonry grid with the specified number of columns and children.
  const MasonryGrid({
    required this.columnCount,
    required this.children,
    this.columnGap = 0.0,
    this.rowGap = 0.0,
    super.key,
  });

  /// The number of columns in the grid.
  final int columnCount;

  /// Horizontal gap between columns.
  final double columnGap;

  /// Vertical gap between items in a column.
  final double rowGap;

  /// The widgets to display in the grid.
  final List<Widget> children;

  @override
  State<MasonryGrid> createState() => _MasonryGridState();
}

class _MasonryGridState extends State<MasonryGrid> {
  late LinkedScrollControllerGroup _controllers;
  late List<ScrollController> _scrollControllers;

  late List<double> helperRowHeight;
  late VoidCallback _scrollCallback;

  @override
  void initState() {
    super.initState();

    // Initialize linked scroll controller group for synchronized scrolling
    _controllers = LinkedScrollControllerGroup();

    // Initialize helper heights for each column
    // (used to equalize scroll extents)
    helperRowHeight = List.generate(widget.columnCount, (_) => 0.0);

    // Create individual scroll controllers for each column
    _scrollControllers = List.generate(
      widget.columnCount,
      (_) => _controllers.addAndGet(),
    );

    _scrollCallback = _calculateHelperRowHeights;

    // Listen to scroll changes across all linked controllers
    _controllers.addOffsetChangedListener(_scrollCallback);

    // Calculate initial heights after first frame when widgets are laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _calculateHelperRowHeights();
      }
    });
  }

  @override
  void dispose() {
    _controllers.removeOffsetChangedListener(_scrollCallback);

    for (final scrollController in _scrollControllers) {
      scrollController.dispose();
    }

    super.dispose();
  }

  void _calculateHelperRowHeights() {
    // Early return if all columns already have equal scroll extents
    final firstMaxExtent = _scrollControllers[0].position.maxScrollExtent;
    if (_scrollControllers.every(
      (c) => c.position.maxScrollExtent == firstMaxExtent,
    )) {
      return;
    }

    var hasReachedEnd = false;
    var maxContentOffset = 0.0;

    // Find the tallest column (excluding helper boxes) and check if scrolled
    // to end
    for (var i = 0; i < _scrollControllers.length; i++) {
      final maxExtent = _scrollControllers[i].position.maxScrollExtent;
      final contentOffset = maxExtent - helperRowHeight[i];

      if (contentOffset > maxContentOffset) {
        maxContentOffset = contentOffset;
      }

      if (_controllers.offset >= maxExtent) {
        hasReachedEnd = true;
      }
    }

    // Only recalculate heights when user has scrolled near or to the bottom
    // Check if within 100 pixels of the end to prepare helper boxes early
    const threshold = 100.0;
    final isNearEnd = _controllers.offset >= (firstMaxExtent - threshold);
    if (!hasReachedEnd && !isNearEnd) return;

    // Calculate required helper box heights to equalize all columns
    List<double>? updatedHeights;
    for (var i = 0; i < _scrollControllers.length; i++) {
      final maxExtent = _scrollControllers[i].position.maxScrollExtent;
      final contentOffset = maxExtent - helperRowHeight[i];
      final requiredHeight = maxContentOffset - contentOffset;

      if (requiredHeight > 0) {
        updatedHeights ??= List.filled(widget.columnCount, 0);
        updatedHeights[i] = requiredHeight;
      }
    }

    // Update state only if heights changed
    if (updatedHeights != null && mounted) {
      setState(() {
        helperRowHeight = updatedHeights!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final childrenCount = widget.children.length;
    final columnCount = widget.columnCount;

    // Calculate items per column: distribute children evenly
    final baseItemCount = childrenCount ~/ columnCount;
    final remainder = childrenCount % columnCount;

    return Row(
      spacing: widget.columnGap,
      crossAxisAlignment: .start,
      children: List.generate(
        columnCount,
        (row) {
          final hasExtraItem = row < remainder;
          // +1 for helper height
          final itemCount = baseItemCount + (hasExtraItem ? 1 : 0) + 1;

          return Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              controller: _scrollControllers[row],
              itemCount: itemCount,
              separatorBuilder: (_, _) => SizedBox(height: widget.rowGap),
              itemBuilder: (_, int col) {
                // Last item is a helper box to equalize column heights for
                // synchronized scrolling
                if (col == itemCount - 1) {
                  return SizedBox(height: helperRowHeight[row]);
                }

                return widget.children[(col * widget.columnCount) + row];
              },
            ),
          );
        },
      ),
    );
  }
}
