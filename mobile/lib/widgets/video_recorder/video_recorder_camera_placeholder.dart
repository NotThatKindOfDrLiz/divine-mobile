import 'package:flutter/material.dart';

/// Fallback preview widget for when camera is not available
class VideoRecorderCameraPlaceholder extends StatelessWidget {
  final bool isRecording;

  const VideoRecorderCameraPlaceholder({super.key, this.isRecording = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRecording ? Icons.fiber_manual_record : Icons.videocam,
              size: 64,
              color: isRecording ? Colors.red : Colors.white54,
            ),
            const SizedBox(height: 8),
            Text(
              isRecording ? 'Recording...' : 'Camera Preview',
              style: TextStyle(
                color: isRecording ? Colors.red : Colors.white54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
