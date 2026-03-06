# Video Editor Local Audio V1 Implementation Plan

**Date:** 2026-03-06
**Status:** Proposed
**Input:** `2026-03-06-video-editor-local-audio-v1-design.md`

## Goal

Ship the smallest production-ready version of "add audio after recording":

- upload one local audio file
- place it with a visual slider
- mix it with original video audio
- bake it into the final rendered video

This plan intentionally does not include voice-over recording, reusable audio
publishing, or existing Nostr sounds.

## Scope Lock

V1 is:

- upload-only
- one added audio track
- one visual placement slider
- two volume sliders
- baked-in export

V1 is not:

- record voice-over
- browse or reuse sounds
- publish Kind 1063 audio events
- multi-track audio
- sampler / fader / fades

## Current Branch Reality

The current branch already has:

- audio chip entry point in `mobile/lib/widgets/video_editor/audio_editor/video_editor_audio_chip.dart`
- a timing screen in `mobile/lib/screens/video_editor/video_audio_editor_timing_screen.dart`
- editor preview playback syncing in `mobile/lib/widgets/video_editor/main_editor/video_editor_canvas.dart`
- renderer support for `customAudioPath` and volume mix in `mobile/lib/services/video_editor/video_editor_render_service.dart`

The current branch does not yet have:

- local uploaded audio model support
- upload/import flow for audio files
- render-time audio preparation for `sourceStartOffset` + `videoStartOffset`
- safe draft persistence for local audio tracks
- correct publish behavior for local-only audio

## Strategy

Do not extend `AudioEvent` for upload-first local audio.

Instead:

1. Introduce a dedicated local editor model for uploaded audio
2. Replace the current selection flow with an upload-first flow
3. Reuse the existing timing screen and audio preview scaffolding where useful
4. Add an audio preparation step before final render
5. Remove Nostr audio publish/reference behavior from this path

## Phase 1: Model and State Refactor

### Objective

Separate editor-local uploaded audio from Nostr `AudioEvent`.

### Files

- Create: `mobile/lib/models/video_editor/selected_audio_track.dart`
- Update: `mobile/lib/models/video_editor/video_editor_provider_state.dart`
- Update: `mobile/lib/providers/video_editor_provider.dart`
- Update: `mobile/lib/models/divine_video_draft.dart`

### Tasks

1. Add `SelectedAudioTrack` model with:
   - `id`
   - `sourceType = uploaded`
   - `localFilePath`
   - `displayTitle`
   - `mimeType`
   - `duration`
   - `sourceStartOffset`
   - `videoStartOffset`
   - `addedAudioVolume`

2. Add `originalAudioVolume` to editor provider state.

3. Replace `selectedSound` in editor provider state with
   `selectedAudioTrack`.

4. Replace `selectSound`, `clearSound`, `updateSoundStartOffset` with:
   - `setSelectedAudioTrack`
   - `clearSelectedAudioTrack`
   - `updateSelectedAudioPlacement`
   - `updateSelectedAudioVolume`
   - `updateOriginalAudioVolume`

5. Persist the new model in `DivineVideoDraft`.

6. Add draft migration behavior:
   - old `selectedSound` remains readable for backward compatibility
   - upload-first flow writes only `selectedAudioTrack`

### Exit Criteria

- Editor state compiles without relying on `AudioEvent`
- Drafts can serialize/deserialize uploaded local audio tracks

## Phase 2: Audio Import Flow

### Objective

Let the user upload one local audio file and convert it into a canonical
app-owned file.

### Files

- Create: `mobile/lib/services/video_editor/audio_track_import_service.dart`
- Update: `mobile/lib/widgets/video_editor/audio_editor/video_editor_audio_chip.dart`
- Replace or delete: `mobile/lib/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart`

### Tasks

1. Add an import service that:
   - opens file picker
   - restricts types to `m4a`, `aac`, `mp3`, `wav`
   - copies the chosen file into app-owned storage
   - extracts metadata needed for UI and state
   - returns `SelectedAudioTrack`

2. Decide file-picker implementation:
   - preferred: use existing `file_picker` dependency cross-platform
   - fallback: wrap platform differences if desktop/mobile support is uneven

3. Replace the current audio chip flow:
   - no sound browser
   - `Add audio` opens upload flow
   - existing track shows `Replace` / `Remove`

4. Keep the chip label simple:
   - filename or derived display title

### Exit Criteria

- User can upload audio from the editor
- Imported file is copied into app-owned storage
- Replacing/removing works without touching the old Nostr sound flow

## Phase 3: Placement and Mix UI

### Objective

Reuse the current timing screen structure, but make it work for uploaded local
audio and the V1 visual slider behavior.

### Files

- Update: `mobile/lib/screens/video_editor/video_audio_editor_timing_screen.dart`
- Update: `mobile/lib/blocs/video_editor/audio_timing/audio_timing_cubit.dart`
- Update: `mobile/lib/widgets/video_editor/audio_editor/video_editor_audio_chip.dart`
- Update: `mobile/lib/widgets/video_editor/main_editor/video_editor_main_overlay_actions.dart`

### Tasks

1. Change timing screen input from `AudioEvent` to `SelectedAudioTrack`.

2. Teach the timing screen to handle both:
   - long audio: slider chooses `sourceStartOffset`
   - short audio: slider chooses `videoStartOffset`

3. Add two volume sliders to the same screen:
   - `Original video audio`
   - `Added audio`

4. Keep the UI single-screen and simple:
   - close
   - confirm
   - remove
   - preview
   - one visual slider
   - two volume sliders

5. Return a fully updated `SelectedAudioTrack` plus volume state back to the
   provider.

### Exit Criteria

- User can position uploaded audio with a visual slider
- User can adjust both volumes
- UI matches the upload-first spec instead of the broader audio-editor mocks

## Phase 4: Preview Playback

### Objective

Make editor preview use the same timing semantics as export.

### Files

- Update: `mobile/lib/widgets/video_editor/main_editor/video_editor_canvas.dart`
- Optionally create: `mobile/lib/services/video_editor/audio_preview_service.dart`

### Tasks

1. Replace `selectedSound` preview logic with `selectedAudioTrack`.

2. Load audio from local file path rather than remote URL assumptions.

3. Apply preview behavior:
   - audio starts at `videoStartOffset`
   - seek into the file at `sourceStartOffset`
   - use `addedAudioVolume`
   - use `originalAudioVolume`

4. Ensure preview pauses/resumes cleanly with video playback.

### Exit Criteria

- Uploaded local audio previews correctly in the editor
- Preview timing matches what the user configured in the slider UI

## Phase 5: Render Preparation

### Objective

Prepare a temporary audio file that matches the target video timeline, then pass
it into the existing video renderer.

### Files

- Create: `mobile/lib/services/video_editor/audio_preparation_service.dart`
- Update: `mobile/lib/providers/video_editor_provider.dart`
- Update: `mobile/lib/services/video_editor/video_editor_render_service.dart`

### Tasks

1. Add `AudioPreparationService` that:
   - reads canonical local audio file
   - trims from `sourceStartOffset`
   - limits duration to available video length
   - prepends silence when `videoStartOffset > 0`
   - outputs a temporary prepared file

2. Update `VideoEditorNotifier.startRenderVideo()` to:
   - detect `selectedAudioTrack`
   - prepare audio before render
   - pass `customAudioPath`, `originalAudioVolume`, and `customAudioVolume`
     into `VideoEditorRenderService.renderVideoToClip(...)`

3. Clean up prepared temp files after render.

### Exit Criteria

- Exported video contains baked-in uploaded audio
- Render uses the configured placement and volume settings

## Phase 6: Publish and Draft Cleanup

### Objective

Make the upload-first local audio path publish safely without pretending there is
a reusable Nostr audio event.

### Files

- Update: `mobile/lib/services/video_publish/video_publish_service.dart`
- Update: `mobile/lib/services/video_event_publisher.dart`
- Update: `mobile/lib/models/divine_video_draft.dart`

### Tasks

1. Stop forwarding `selectedAudioEventId` for uploaded local audio.

2. Ensure no audio `e` tag is published for this path.

3. Keep publish flow video-only at the Nostr metadata layer.

4. Confirm draft restore uses `selectedAudioTrack`, not `selectedSound`.

### Exit Criteria

- Uploaded-audio videos publish without invalid audio event references
- Draft restore remains stable

## Phase 7: Testing

### Objective

Cover the new local-audio path where the branch is currently weakest.

### Suggested Tests

#### Model / Persistence

- `SelectedAudioTrack` JSON roundtrip
- `DivineVideoDraft` roundtrip with uploaded audio
- backward compatibility when old `selectedSound` is present

#### Import

- user cancels file picker
- unsupported extension is rejected
- selected file is copied into app-owned storage

#### Placement / Preview

- long audio updates `sourceStartOffset`
- short audio updates `videoStartOffset`
- volume settings persist back to provider state

#### Render

- `startRenderVideo()` prepares and passes custom audio into render
- render is skipped cleanly when preparation fails

#### Publish

- uploaded local audio does not produce `selectedAudioEventId`
- no audio `e` tag is emitted

## Execution Order

Recommended implementation order:

1. Phase 1: model/state refactor
2. Phase 2: upload/import flow
3. Phase 3: placement/mix UI
4. Phase 4: preview playback
5. Phase 5: render preparation
6. Phase 6: publish cleanup
7. Phase 7: tests and polish

## Risks

### Risk 1: Offset mismatch between preview and export

Mitigation:

- Treat `sourceStartOffset` and `videoStartOffset` as the canonical semantics
- Use the same semantics in both timing UI and render preparation

### Risk 2: Local file lifecycle issues

Mitigation:

- Copy every imported file into app-owned storage immediately
- Never depend on a transient picker URI after selection

### Risk 3: Scope creep back into full audio editor

Mitigation:

- Keep the upload-only entry point
- Do not add tabs, multiple tools, or remix publishing in this pass

## Deferred Work

- voice-over recording
- use existing sounds
- publish reusable audio events
- metadata remix toggle
- sampler/fader modes
- multi-segment audio editing
