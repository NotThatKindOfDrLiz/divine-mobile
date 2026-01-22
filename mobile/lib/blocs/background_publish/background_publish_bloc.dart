import 'dart:async';

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
    on<BackgroundPublishVanished>(_onBackgroundPublishVanished);
  }

  final List<Timer> _vanishTimers = [];

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

    late final Timer timer;

    timer = Timer(const Duration(seconds: 5), () {
      add(BackgroundPublishVanished(draftId: event.draft.id));
      _vanishTimers.remove(timer);
    });
    _vanishTimers.add(timer);
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

  void _onBackgroundPublishVanished(
    BackgroundPublishVanished event,
    Emitter<BackgroundPublishState> emit,
  ) {
    final remainingUploads = state.uploads.where((upload) {
      return upload.draft.id != event.draftId;
    }).toList();
    emit(state.copyWith(uploads: remainingUploads));
  }

  @override
  Future<void> close() {
    for (final timer in _vanishTimers) {
      timer.cancel();
    }
    return super.close();
  }
}
