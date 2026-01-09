import 'package:flutter/material.dart';
import 'package:openvine/models/recording_clip.dart';

class VideoEditorClipProcessingOverlay extends StatelessWidget {
  const VideoEditorClipProcessingOverlay({required this.clip, super.key});

  final RecordingClip clip;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: clip.isProcessing ? 1 : 0,
      child: const ColoredBox(
        color: Color.fromARGB(140, 0, 0, 0),
        child: Center(
          child: CircularProgressIndicator.adaptive(),
          /* Optional progress tracking: 
          StreamBuilder<ProgressModel>(
            stream: ProVideoEditor.instance.progressStreamById(widget.clip.id),
            builder: (context, snapshot) {
              final progress = snapshot.data?.progress ?? 0;
              return CircularProgressIndicator(value: progress);
            },
          ), */
        ),
      ),
    );
  }
}
