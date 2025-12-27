import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/vine_recording_provider.dart';

class VideoRecorderCountdownOverlay extends ConsumerWidget {
  const VideoRecorderCountdownOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdownValue = ref.watch(
      vineRecordingProvider.select((p) => p.countdownValue),
    );

    final bool isActive = countdownValue > 0;

    return IgnorePointer(
      ignoring: !isActive,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 100),
        opacity: isActive ? 1 : 0,
        child: Container(
          color: const Color(0xB3000000),
          child: Center(
            child: Text(
              countdownValue.toString(),
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 100,
                fontWeight: .bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
