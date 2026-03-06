# Video Editor Local Audio V1 Design

**Date:** 2026-03-06
**Status:** Proposed
**Scope:** Limited first pass

## Overview

This document defines the smallest useful version of "add audio after recording"
for the mobile video editor.

The feature allows a user to:

1. Upload a single local audio file after capturing video
2. Position that track against the edited video timeline
3. Adjust the mix between original video audio and the added track
4. Bake the result into the final rendered video file

This is intentionally not a full audio editor.

## Related Issues

- Addresses [#1923](https://github.com/divinevideo/divine-mobile/issues/1923)
- Covers the main user need from [#1593](https://github.com/divinevideo/divine-mobile/issues/1593)
- Satisfies a narrow subset of [#1457](https://github.com/divinevideo/divine-mobile/issues/1457)
- Explicitly defers reusable/remix audio work from [#1733](https://github.com/divinevideo/divine-mobile/issues/1733)

## Product Goal

Make it possible to add a custom soundtrack after video capture without
requiring external editing tools.

## Non-Goals

The following are out of scope for V1:

- Multiple added audio tracks
- Record voice-over inside the editor
- Browse/use existing Nostr sounds
- Publish a separate remixable audio event
- Sampler mode
- Fader mode
- Audio stickers / multiple regions
- Fades, ducking curves, or envelopes
- Beat sync or waveform snapping
- Per-clip audio editing
- Live voice monitoring while recording

## User Flow

```text
Record clips -> Clip manager -> Video editor -> Add audio
                                           -> Upload audio
                                           -> Place + Mix
                                           -> Metadata
                                           -> Render
                                           -> Upload + Publish
```

## User Experience

### Entry Point

In the video editor, the existing "Add audio" affordance opens a simple source
picker with:

- `Upload audio`
- `Cancel`

If an audio track already exists, the sheet shows:

- `Replace audio`
- `Remove audio`
- `Cancel`

### Upload Audio

When the user chooses `Upload audio`:

1. The app opens the native file picker
2. The user selects one local audio file
3. The file is copied into app-owned storage
4. The copied file becomes the canonical source file
5. The user proceeds to the placement/mix screen

Supported types for V1:

- `m4a`
- `aac`
- `mp3`
- `wav`

## Audio Placement Model

V1 needs to support both of these cases:

1. Audio is longer than the video
2. Audio is shorter than the video

That requires two offsets:

- `sourceStartOffset`
  Meaning: where playback starts inside the source audio file
- `videoStartOffset`
  Meaning: where the added audio begins inside the video timeline

### Behavior

If audio is longer than the video:

- User selects the window inside the source audio
- `videoStartOffset` remains `0`
- `sourceStartOffset` changes

If audio is shorter than the video:

- User positions the audio block within the video timeline
- `sourceStartOffset` remains `0`
- `videoStartOffset` changes

If audio and video are equal length:

- Both offsets default to `0`

### V1 Placement Rules

- Added audio never loops
- Added audio never repeats automatically
- Added audio may end before the video ends
- The remainder of the video plays with only original video audio
- Added audio may start after the video begins

## Audio Mix Model

V1 exposes two sliders:

- `Original video audio`
- `Added audio`

Defaults:

- `originalAudioVolume = 0.2`
- `addedAudioVolume = 1.0`

Rationale:

- This works reasonably for uploaded tracks
- It avoids requiring a separate ducking system in V1

The user may set either slider from `0.0` to `1.0`.

## UI Proposal

### Screen 1: Source Picker

Simple bottom sheet:

- `Upload audio`
- `Cancel`

### Screen 2: Audio Adjustment

Single full-screen editor mode with:

- Close button
- Confirm button
- Video preview
- Audio chip with current track name
- Placement control
- `Original video audio` slider
- `Added audio` slider
- Remove button

This screen combines the useful parts of the design mocks while avoiding
separate `Adjust`, `Sampler`, and `Fader` tabs.

### Placement UI

Placement UI should adapt to track length:

- Long audio:
  Show a visual slider for choosing the start point within the audio
- Short audio:
  Show a visual slider for placing the audio block on the video timeline

For V1, this control should be a simple visual timeline slider rather than
numeric input or a multi-handle editor.

Placement defaults:

- Uploaded audio starts at `0s` in the video by default
- The user may drag the slider to move the audio later in the video
- Changes should be reflected immediately in preview playback

The current branch's timing screen is a reasonable starting point for the
"long audio" case, but it must be extended for the "short audio" case.

## Data Model

V1 should not use `AudioEvent` as editor state.

Instead, add a dedicated local editor model:

```dart
enum SelectedAudioTrackSourceType {
  uploaded,
}

class SelectedAudioTrack {
  final String id;
  final SelectedAudioTrackSourceType sourceType;
  final String localFilePath;
  final String displayTitle;
  final String? mimeType;
  final Duration duration;
  final Duration sourceStartOffset;
  final Duration videoStartOffset;
  final double addedAudioVolume;
}
```

Editor state also needs:

```dart
final SelectedAudioTrack? selectedAudioTrack;
final double originalAudioVolume;
```

## Draft Persistence

Drafts must persist:

- selected audio file path
- source type
- display title
- duration
- `sourceStartOffset`
- `videoStartOffset`
- `addedAudioVolume`
- `originalAudioVolume`

The stored file path must point to the app-owned copied file, not to a
temporary picker URI.

## Render Behavior

The final published video must contain the mixed audio baked into the file.

This is the core requirement for V1.

### Render Inputs

The video renderer already supports:

- `customAudioPath`
- `originalAudioVolume`
- `customAudioVolume`

But it does not support timeline offsets directly.

### Required Preparation Step

Before final render, the app prepares a temporary audio file:

1. Load the canonical source file
2. Trim from `sourceStartOffset`
3. Limit duration to fit remaining video time
4. If `videoStartOffset > 0`, prepend silence
5. Output a prepared local file matching the video timeline
6. Pass that prepared file to the renderer as `customAudioPath`

This preparation step is mandatory because the renderer only accepts a single
audio file path, not independent source/video offsets.

## Playback Behavior In Editor

Editor preview must reflect the same timing model used at render time.

That means preview playback must:

- Start added audio at `videoStartOffset`
- Seek into the file at `sourceStartOffset`
- Respect `addedAudioVolume`
- Respect `originalAudioVolume`

Preview and export must use the same semantics.

## Publish Behavior

For V1, publish behavior is simple:

- Upload the final rendered video
- Publish the video event as usual
- Do not publish a separate audio event
- Do not add a Nostr audio reference tag for uploaded local tracks

This keeps V1 focused on local editing, not remix distribution.

## Error Handling

### Record Audio

- Not applicable in V1

### Upload Audio

- If file selection is cancelled, do nothing
- If file copy/import fails, show an error and do not update editor state
- If the file type is unsupported, show an error

### Render

- If prepared audio generation fails, block final publish and show an error
- If the selected audio file is missing, clear the selection and ask the user
  to re-add audio

## Acceptance Criteria

- User can add one audio track after recording video
- User can choose `Upload audio`
- Uploaded audio is saved into app-owned local storage
- User can place long audio by choosing where playback begins inside the track
- User can place short audio by choosing where it begins in the video timeline
- User can adjust original and added audio volumes independently
- Preview reflects the same timing and mix used in final export
- Exported video contains the added audio baked into the file
- Draft restore preserves the selected local audio track and mix settings
- Removing audio returns the editor to a normal no-audio state

## Deferred Follow-Ups

These are good V2 candidates:

- Use existing Nostr sounds in the same UI
- Add voice-over recording inside the editor
- Publish a separate reusable Kind 1063 audio event
- Add "Allow remix" toggle in metadata
- Add fades
- Add sampler mode
- Add multiple audio segments
- Add waveform snapping / finer editing
- Add headphones-specific voice-over behavior

## Implementation Notes

- The current branch's timing screen and audio chip are reusable as scaffolding
  but the state model is too tied to `AudioEvent`
- A dedicated `SelectedAudioTrack` model should land before deeper UI work
- Deferring recording removes the need for an audio-recorder dependency in the
  first pass
