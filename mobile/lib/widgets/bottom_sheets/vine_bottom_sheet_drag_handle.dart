// ABOUTME: Drag handle indicator for bottom sheets
// ABOUTME: Shows a horizontal bar at the top to indicate draggable behavior

import 'package:flutter/material.dart';

/// Drag handle indicator shown at the top of bottom sheets.
///
/// This provides a visual affordance that the sheet can be dragged up or down.
/// Design matches Figma specifications: 64px wide, 4px height, rounded.
class VineBottomSheetDragHandle extends StatelessWidget {
  const VineBottomSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0x40FFFFFF),
          borderRadius: .circular(8),
        ),
      ),
    );
  }
}
