import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';

part 'background_publish_event.dart';
part 'background_publish_state.dart';

class BackgroundPublishBloc
    extends Bloc<BackgroundPublishEvent, BackgroundPublishState> {
  BackgroundPublishBloc() : super(BackgroundPublishState()) {
    on<BackgroundPublishRequested>(_onBackgroundPublishRequested);
    on<BackgroundPublishProgressChanged>(_onBackgroundPublishProgressChanged);
  }

  Future<void> _onBackgroundPublishRequested(
    BackgroundPublishRequested event,
    Emitter<BackgroundPublishState> emit,
  ) async {
    final newUpload = BackgroundUpload(
      draft: event.draft,
      result: null,
      progress: 0,
    );
    emit(state.copyWith(uploads: [...state.uploads, newUpload]));

    final result = await event.publishmentProcess;

    final updatedUploads = state.uploads.map((upload) {
      if (upload.draft.id == event.draft.id) {
        return upload.copyWith(result: result, progress: 1.0);
      }
      return upload;
    }).toList();

    emit(state.copyWith(uploads: updatedUploads));
  }

  void _onBackgroundPublishProgressChanged(
    BackgroundPublishProgressChanged event,
    Emitter<BackgroundPublishState> emit,
  ) {
    final updatedUploads = state.uploads.map((upload) {
      if (upload.draft.id == event.draftId) {
        return upload.copyWith(progress: event.progress);
      }
      return upload;
    }).toList();

    emit(state.copyWith(uploads: updatedUploads));
  }
}
