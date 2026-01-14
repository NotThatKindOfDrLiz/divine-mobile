// ABOUTME: Overlay widget showing processing indicator for video clips
// ABOUTME: Displays circular progress indicator while clip is being processed/rendered

import 'package:flutter/material.dart';
import 'package:openvine/models/recording_clip.dart';

class VideoEditorClipProcessingOverlay extends StatelessWidget {
  const VideoEditorClipProcessingOverlay({required this.clip, super.key});

  final RecordingClip clip;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: clip.isProcessing
          ? const ColoredBox(
              color: Color.fromARGB(140, 0, 0, 0),
              child: Center(
                // Without RepaintBoundary, the progress indicator repaints
                // the entire screen while it's running.
                child: RepaintBoundary(
                  child: CircularProgressIndicator.adaptive(),
                ),
                /* Optional progress tracking: 
                   
                   StreamBuilder<ProgressModel>(
                      stream: ProVideoEditor.instance.progressStreamById(widget.clip.id),
                      builder: (context, snapshot) {
                        final progress = snapshot.data?.progress ?? 0;
                        return CircularProgressIndicator(value: progress);
                      },
                    ), 
                */
              ),
            )
          : SizedBox.shrink(),
    );
  }
}
