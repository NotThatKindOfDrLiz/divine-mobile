part of 'sound_waveform_bloc.dart';

/// Base event for sound waveform actions.
sealed class SoundWaveformEvent extends Equatable {
  const SoundWaveformEvent();

  @override
  List<Object?> get props => [];
}

/// Extract waveform data from a sound URL or asset path.
class SoundWaveformExtract extends SoundWaveformEvent {
  const SoundWaveformExtract({
    required this.path,
    required this.soundId,
    this.isAsset = false,
    this.isFile = false,
  });

  /// The URL or asset path of the sound to extract waveform from.
  final String path;

  /// The sound ID for logging purposes.
  final String soundId;

  /// Whether this is an asset path (true) or network URL (false).
  final bool isAsset;

  /// Whether this is a local file path.
  final bool isFile;

  @override
  List<Object?> get props => [path, soundId, isAsset, isFile];
}

/// Clear the current waveform data.
class SoundWaveformClear extends SoundWaveformEvent {
  const SoundWaveformClear();
}
