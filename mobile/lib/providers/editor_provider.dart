// ABOUTME: Riverpod provider for managing video editor state with text overlays and export tracking
// ABOUTME: Exposes EditorNotifier for state mutations and reactive EditorState updates

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/editor_state.dart';

final editorProvider = NotifierProvider<EditorNotifier, EditorState>(() {
  return EditorNotifier();
});

class EditorNotifier extends Notifier<EditorState> {
  @override
  EditorState build() {
    return EditorState();
  }

  void setSound(String? soundId) {
    state = state.copyWith(selectedSoundId: soundId);
  }

  void setExportStage(ExportStage stage, double progress) {
    final isProcessing =
        stage != ExportStage.complete && stage != ExportStage.error;

    state = state.copyWith(
      exportStage: stage,
      exportProgress: progress,
      isProcessing: isProcessing,
      errorMessage: null,
    );
  }

  void setError(String? message) {
    state = state.copyWith(
      errorMessage: message,
      exportStage: message != null ? ExportStage.error : state.exportStage,
      isProcessing: false,
    );
  }

  void reset() {
    state = EditorState();
  }
}
