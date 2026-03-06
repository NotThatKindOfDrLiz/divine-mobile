// ABOUTME: Local uploaded audio track model for the video editor.
// ABOUTME: Stores placement and volume data independently from Nostr AudioEvent.

import 'dart:io';

import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;

/// Source types supported for local editor audio tracks.
enum SelectedAudioTrackSourceType {
  /// Audio file chosen from the device by the user.
  uploaded,
}

/// Local audio track selected for the video editor.
class SelectedAudioTrack {
  /// Creates a selected audio track for editor use.
  const SelectedAudioTrack({
    required this.id,
    required this.localFilePath,
    required this.displayTitle,
    required this.duration,
    this.sourceType = SelectedAudioTrackSourceType.uploaded,
    this.mimeType,
    this.sourceStartOffset = Duration.zero,
    this.videoStartOffset = Duration.zero,
    this.addedAudioVolume = 1.0,
  });

  /// Rebuilds a selected audio track from persisted JSON.
  factory SelectedAudioTrack.fromJson(
    Map<String, dynamic> json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    final rawLocalFilePath = json['localFilePath'] as String;
    return SelectedAudioTrack(
      id: json['id'] as String,
      sourceType: SelectedAudioTrackSourceType.values.byName(
        json['sourceType'] as String? ??
            SelectedAudioTrackSourceType.uploaded.name,
      ),
      localFilePath: _resolveStoredPath(
        rawPath: rawLocalFilePath,
        documentsPath: documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      displayTitle: json['displayTitle'] as String,
      mimeType: json['mimeType'] as String?,
      duration: Duration(milliseconds: json['durationMs'] as int),
      sourceStartOffset: Duration(
        milliseconds: json['sourceStartOffsetMs'] as int? ?? 0,
      ),
      videoStartOffset: Duration(
        milliseconds: json['videoStartOffsetMs'] as int? ?? 0,
      ),
      addedAudioVolume: (json['addedAudioVolume'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Unique ID for editor state and draft persistence.
  final String id;

  /// Source type for the local audio track.
  final SelectedAudioTrackSourceType sourceType;

  /// Canonical app-owned audio file path.
  final String localFilePath;

  /// Display title shown in editor UI.
  final String displayTitle;

  /// MIME type for the audio file, when known.
  final String? mimeType;

  /// Full source duration.
  final Duration duration;

  /// Position inside the source file where playback should begin.
  final Duration sourceStartOffset;

  /// Position in the video timeline where the added audio should begin.
  final Duration videoStartOffset;

  /// Relative volume of the added track.
  final double addedAudioVolume;

  /// Creates a copy with updated fields.
  SelectedAudioTrack copyWith({
    String? id,
    SelectedAudioTrackSourceType? sourceType,
    String? localFilePath,
    String? displayTitle,
    String? mimeType,
    bool clearMimeType = false,
    Duration? duration,
    Duration? sourceStartOffset,
    Duration? videoStartOffset,
    double? addedAudioVolume,
  }) {
    return SelectedAudioTrack(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      localFilePath: localFilePath ?? this.localFilePath,
      displayTitle: displayTitle ?? this.displayTitle,
      mimeType: clearMimeType ? null : (mimeType ?? this.mimeType),
      duration: duration ?? this.duration,
      sourceStartOffset: sourceStartOffset ?? this.sourceStartOffset,
      videoStartOffset: videoStartOffset ?? this.videoStartOffset,
      addedAudioVolume: addedAudioVolume ?? this.addedAudioVolume,
    );
  }

  /// Serializes the track to JSON for draft persistence.
  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceType': sourceType.name,
    // Store a relative path so imports under audio_tracks/ survive app restarts.
    'localFilePath': _storedPath(localFilePath),
    'displayTitle': displayTitle,
    'mimeType': mimeType,
    'durationMs': duration.inMilliseconds,
    'sourceStartOffsetMs': sourceStartOffset.inMilliseconds,
    'videoStartOffsetMs': videoStartOffset.inMilliseconds,
    'addedAudioVolume': addedAudioVolume,
  };

  @override
  String toString() {
    return 'SelectedAudioTrack('
        'id: $id, '
        'sourceType: ${sourceType.name}, '
        'displayTitle: $displayTitle, '
        'durationMs: ${duration.inMilliseconds}'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SelectedAudioTrack &&
        other.id == id &&
        other.sourceType == sourceType &&
        other.localFilePath == localFilePath &&
        other.displayTitle == displayTitle &&
        other.mimeType == mimeType &&
        other.duration == duration &&
        other.sourceStartOffset == sourceStartOffset &&
        other.videoStartOffset == videoStartOffset &&
        other.addedAudioVolume == addedAudioVolume;
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceType,
    localFilePath,
    displayTitle,
    mimeType,
    duration,
    sourceStartOffset,
    videoStartOffset,
    addedAudioVolume,
  );

  static String _resolveStoredPath({
    required String rawPath,
    required String documentsPath,
    required bool useOriginalPath,
  }) {
    if (useOriginalPath) {
      return rawPath;
    }
    if (p.isAbsolute(rawPath)) {
      return resolvePath(rawPath, documentsPath) ?? '';
    }
    if (p.dirname(rawPath) != '.') {
      return p.join(documentsPath, rawPath);
    }

    final resolvedPath = p.join(documentsPath, rawPath);
    if (resolvedPath.isEmpty) {
      return resolvedPath;
    }

    final legacyAudioTracksPath = p.join(
      documentsPath,
      'audio_tracks',
      rawPath,
    );
    if (File(legacyAudioTracksPath).existsSync()) {
      return legacyAudioTracksPath;
    }

    return resolvedPath;
  }

  static String _storedPath(String filePath) {
    final parentDirName = p.basename(p.dirname(filePath));
    final fileName = p.basename(filePath);
    if (parentDirName == 'audio_tracks') {
      return p.join(parentDirName, fileName);
    }
    return fileName;
  }
}
