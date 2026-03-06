// ABOUTME: Imports one local audio file into app-owned storage for video editing.
// ABOUTME: Uses the existing file picker, copies the file into documents storage,
// ABOUTME: and returns a SelectedAudioTrack with basic metadata.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:openvine/models/video_editor/selected_audio_track.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:sound_service/sound_service.dart';

typedef PickAudioFile = Future<FilePickerResult?> Function();
typedef LoadAudioDuration = Future<Duration?> Function(String filePath);
typedef CurrentTimeFactory = DateTime Function();

/// Imports local audio files into app-owned storage for the video editor.
class AudioTrackImportService {
  /// Creates an [AudioTrackImportService].
  AudioTrackImportService({
    PickAudioFile? pickAudioFile,
    LoadAudioDuration? loadAudioDuration,
    Future<String> Function()? getDocumentsDirectoryPath,
    CurrentTimeFactory? now,
  }) : _pickAudioFile = pickAudioFile ?? _defaultPickAudioFile,
       _loadAudioDuration = loadAudioDuration ?? _defaultLoadAudioDuration,
       _getDocumentsDirectoryPath =
           getDocumentsDirectoryPath ?? getDocumentsPath,
       _now = now ?? DateTime.now;

  /// Supported audio file extensions for the upload-first editor flow.
  static const allowedExtensions = ['m4a', 'aac', 'mp3', 'wav'];

  final PickAudioFile _pickAudioFile;
  final LoadAudioDuration _loadAudioDuration;
  final Future<String> Function() _getDocumentsDirectoryPath;
  final CurrentTimeFactory _now;

  /// Opens the system picker and imports the selected file.
  ///
  /// Returns null when the user cancels the picker or the picked result
  /// does not contain a readable file path.
  Future<SelectedAudioTrack?> pickAndImport() async {
    final result = await _pickAudioFile();
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final sourcePath = file.path;
    if (sourcePath == null || sourcePath.isEmpty) return null;

    return importFile(
      sourcePath: sourcePath,
      originalFileName: file.name,
    );
  }

  /// Imports [sourcePath] into documents storage and returns the local track.
  Future<SelectedAudioTrack> importFile({
    required String sourcePath,
    String? originalFileName,
  }) async {
    final now = _now();
    final documentsPath = await _getDocumentsDirectoryPath();
    final storageDir = Directory(p.join(documentsPath, 'audio_tracks'));
    await storageDir.create(recursive: true);

    final fileName = originalFileName ?? p.basename(sourcePath);
    final displayTitle = _displayTitleFromFileName(fileName);
    final fileExtension = p.extension(fileName).toLowerCase();
    final safeBaseName = _safeBaseName(displayTitle);
    final targetFileName =
        '${now.microsecondsSinceEpoch}_${safeBaseName.isEmpty ? 'audio' : safeBaseName}$fileExtension';
    final targetPath = p.join(storageDir.path, targetFileName);

    final importedFile = await File(sourcePath).copy(targetPath);
    final duration =
        await _loadAudioDuration(importedFile.path) ?? Duration.zero;

    return SelectedAudioTrack(
      id: 'audio-track-${now.microsecondsSinceEpoch}',
      localFilePath: importedFile.path,
      displayTitle: displayTitle.isEmpty ? 'Audio clip' : displayTitle,
      mimeType: _mimeTypeForExtension(fileExtension),
      duration: duration,
    );
  }

  static Future<FilePickerResult?> _defaultPickAudioFile() {
    return FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
  }

  static Future<Duration?> _defaultLoadAudioDuration(String filePath) async {
    final audioService = AudioPlaybackService();
    try {
      return await audioService.loadAudioFromFile(filePath);
    } finally {
      await audioService.dispose();
    }
  }

  static String _displayTitleFromFileName(String fileName) {
    return p.basenameWithoutExtension(fileName).trim();
  }

  static String _safeBaseName(String name) {
    final sanitized = name
        .trim()
        .replaceAll(RegExp('[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return sanitized;
  }

  static String? _mimeTypeForExtension(String extension) {
    return switch (extension) {
      '.aac' => 'audio/aac',
      '.m4a' => 'audio/mp4',
      '.mp3' => 'audio/mpeg',
      '.wav' => 'audio/wav',
      _ => null,
    };
  }
}
