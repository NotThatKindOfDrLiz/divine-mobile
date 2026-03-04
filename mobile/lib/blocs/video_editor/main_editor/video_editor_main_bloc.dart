import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

part 'video_editor_main_event.dart';
part 'video_editor_main_state.dart';

/// BLoC for managing the video editor main screen state.
///
/// Handles:
/// - Undo/Redo availability and actions
/// - Layer interaction state (scaling/rotating)
/// - Sub-editor open state and navigation
/// - Close/Done actions
class VideoEditorMainBloc
    extends Bloc<VideoEditorMainEvent, VideoEditorMainState> {
  VideoEditorMainBloc() : super(const VideoEditorMainState()) {
    on<VideoEditorMainCapabilitiesChanged>(
      _onCapabilitiesChanged,
      transformer: sequential(),
    );
    on<VideoEditorLayerInteractionStarted>(
      _onLayerInteractionStarted,
      transformer: sequential(),
    );
    on<VideoEditorLayerInteractionEnded>(
      _onLayerInteractionEnded,
      transformer: sequential(),
    );
    on<VideoEditorLayerOverRemoveAreaChanged>(
      _onLayerOverRemoveAreaChanged,
      transformer: sequential(),
    );
    on<VideoEditorMainOpenSubEditor>(
      _onOpenSubEditor,
      transformer: sequential(),
    );
    on<VideoEditorMainSubEditorClosed>(
      _onSubEditorClosed,
      transformer: sequential(),
    );
    on<VideoEditorLayerAdded>(
      _onLayerAdded,
      transformer: sequential(),
    );
    on<VideoEditorLayerRemoved>(
      _onLayerRemoved,
      transformer: sequential(),
    );
    on<VideoEditorPlaybackChanged>(
      _onPlaybackChanged,
      transformer: sequential(),
    );
    on<VideoEditorPlayerReady>(
      _onPlayerReady,
      transformer: sequential(),
    );
    on<VideoEditorExternalPauseRequested>(
      _onExternalPauseRequested,
      transformer: sequential(),
    );
    on<VideoEditorPlaybackRestartRequested>(
      _onPlaybackRestartRequested,
      transformer: sequential(),
    );
    on<VideoEditorPlaybackToggleRequested>(
      _onPlaybackToggleRequested,
      transformer: sequential(),
    );
  }

  /// Updates undo/redo/subEditor state based on editor capabilities.
  void _onCapabilitiesChanged(
    VideoEditorMainCapabilitiesChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(
      state.copyWith(
        canUndo: event.canUndo,
        canRedo: event.canRedo,
        layers: event.layers,
      ),
    );
  }

  void _onLayerInteractionStarted(
    VideoEditorLayerInteractionStarted event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isLayerInteractionActive: true));
  }

  void _onLayerInteractionEnded(
    VideoEditorLayerInteractionEnded event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(
      state.copyWith(
        isLayerInteractionActive: false,
        isLayerOverRemoveArea: false,
      ),
    );
  }

  void _onLayerOverRemoveAreaChanged(
    VideoEditorLayerOverRemoveAreaChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    if (state.isLayerOverRemoveArea != event.isOver) {
      emit(state.copyWith(isLayerOverRemoveArea: event.isOver));
    }
  }

  void _onOpenSubEditor(
    VideoEditorMainOpenSubEditor event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(openSubEditor: event.type));
  }

  void _onSubEditorClosed(
    VideoEditorMainSubEditorClosed event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(clearOpenSubEditor: true));
  }

  void _onLayerAdded(
    VideoEditorLayerAdded event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(layers: [...state.layers, event.layer]));
  }

  void _onLayerRemoved(
    VideoEditorLayerRemoved event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(
      state.copyWith(
        layers: state.layers.where((l) => l != event.layer).toList(),
      ),
    );
  }

  void _onPlaybackChanged(
    VideoEditorPlaybackChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isPlaying: event.isPlaying));
  }

  void _onPlayerReady(
    VideoEditorPlayerReady event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isPlayerReady: true));
  }

  void _onExternalPauseRequested(
    VideoEditorExternalPauseRequested event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isExternalPauseRequested: event.isPaused));
  }

  void _onPlaybackRestartRequested(
    VideoEditorPlaybackRestartRequested event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(
      state.copyWith(playbackRestartCounter: state.playbackRestartCounter + 1),
    );
  }

  void _onPlaybackToggleRequested(
    VideoEditorPlaybackToggleRequested event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(
      state.copyWith(playbackToggleCounter: state.playbackToggleCounter + 1),
    );
  }
}
