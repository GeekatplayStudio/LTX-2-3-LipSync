# GAP LTX 2.3 Motion

ComfyUI custom nodes and production workflows for LTX 2.3 image-to-video lip sync, storyboard scheduling, segmented audio rendering, and optional waveform-driven timing tools.

This repository is designed to be placed inside `ComfyUI/custom_nodes/`.

## What This Pack Does

This pack extends LTX 2.3 with tools for longer-form audio-driven rendering.

- Split long songs or dialogue into renderable chunks
- Reuse one image or rotate storyboard images across the full track
- Time image changes by duration, with waveform keyframe tools available for custom graphs
- Pair prompts to storyboard segments
- Save and requeue segments automatically until the full sequence is finished

If you want a quick starting point, begin with the storyboard workflows in the `workflows/` folder.

## Quick Start

1. Install this folder into `ComfyUI/custom_nodes/`.
2. Restart ComfyUI.
3. Run `install.bat` (Windows) or `./install.sh` (Linux/macOS) for the full setup, or `install_ltx23_motion_models.bat` / `./install_ltx23_motion_models.sh` if you only want the model downloads.
4. Open one of the shipped workflows from `workflows/`.
5. Load your audio, source image, and optional storyboard images.
6. Render a short test first, then run the full loop workflow.

For a setup checklist, see `docs/getting-started.md`.

## Included

- Custom nodes for audio slicing, storyboard scheduling, waveform timing, prompt rotation, and render looping
- Windows installer for required LTX 2.3 model files
- Safetensors shard merge utility for Gemma recovery
- Ready-to-use GAP workflows for lip-sync, storyboard, and first/last-frame setups

## Repository Layout

- `__init__.py`: ComfyUI package entry point
- `ltx_motion_audio_segments.py`: custom node implementations
- `js/`: frontend extensions for dynamic storyboard and waveform nodes
- `workflows/`: workflow JSON files
- `install.bat` / `install.sh`: Windows/Linux full installers for Python packages, ffmpeg, and models
- `install_ltx23_motion_models.bat` / `install_ltx23_motion_models.sh`: Windows/Linux model installers
- `merge_safetensors_shards.py`: safetensors merge helper
- `LTX-2.3_Image_To_Video_Motion_Transfer.json`: motion-transfer base workflow

## Installation

1. Clone or copy this folder into `ComfyUI/custom_nodes/LTX2-3-motion`.
2. Restart ComfyUI.
3. Run `install.bat` (or `./install.sh` on Linux) if you want the full setup handled automatically, including Python packages, ffmpeg, and the required model downloads.
4. Run `install_ltx23_motion_models.bat` (or `./install_ltx23_motion_models.sh` on Linux) only if your environment is already set up and you just need the model files.
5. Ensure `ffmpeg` is available if you plan to use segmented-audio or storyboard loop workflows.

## Required Models

Place these files in your ComfyUI models directories:

- `models/checkpoints/ltx-2.3-22b-dev.safetensors`
- `models/loras/ltx-2.3-22b-distilled-lora-384.safetensors`
- `models/loras/ltx-2.3-22b-ic-lora-motion-track-control-ref0.5.safetensors`
- `models/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors`

The workflows use a separate Gemma text encoder. A log such as `no CLIP/text encoder weights in checkpoint` is expected with this setup.

## Workflows

Reference and base workflows:

- `workflows/gap_ltx23_lipsync_range_stop.json`: lip-sync test render that stops on a selected audio range
- `workflows/gap_ltx23_lipsync_long_audio.json`: lip-sync loop for long audio with one main image
- `workflows/gap_ltx23_lipsync_long_audio_first_last.json`: long-audio lip-sync with first-frame and last-frame control
- `workflows/gap_ltx23_lipsync_long_audio_storyboard.json`: long-audio lip-sync that rotates through storyboard images
- `workflows/gap_ltx23_first_last_base.json`: original FLF2V first/last base graph
- `workflows/gap_ltx23_first_last_only_simple.json`: simple first/last-only guide setup
- `workflows/gap_ltx23_first_last_motion_track_looper.json`: loop-enabled motion-track workflow that alternates storyboard image pairs across long ranges

Loop and storyboard workflows:

- `workflows/gap_ltx23_storyboard_lipsync.json`: storyboard lip-sync with duration-based image changes
- `workflows/gap_ltx23_storyboard_lipsync_music.json`: storyboard lip-sync that keeps the selected music in the final render
- `workflows/gap_ltx23_storyboard_first_last.json`: storyboard first/last transitions with overlapping image pairs
- `workflows/gap_ltx23_storyboard_first_last_music.json`: storyboard first/last transitions that keep the selected music in the final render
- `workflows/gap_ltx23_storyboard_first_last_lipsync_range_stop.json`: storyboard first/last lip-sync on a selected audio range
- `workflows/gap_ltx23_flf2v_storyboard_first_last_looper.json`: cleaner FLF2V-based storyboard first/last looper built from the `video_ltx2_3_flf2v.json` render path

Workflow selection help is in `docs/workflow-guide.md`.

## Shared Controls

Most loop-capable workflows use the same control pattern.

- `Song Range Selector`: limits the active render window. `start_time` and `end_time` define the window. `use_loaded_audio` switches between real audio slicing and silent time-only rendering. `silent_sample_rate` controls the silent buffer sample rate when real audio is disabled.
- `Storyboard First/Last Scheduler`: accepts a set of images plus the selected audio window and returns the current segment audio, the current start image, the current end image, and segment counters. `image_count` defines how many connected storyboard images are active. Duration fields control how long each storyboard slot is held before the next segment pair is chosen.
- `Storyboard Scheduler Dynamic`: similar to the pair selector, but outputs one current image instead of a start and end pair. Use it for plain storyboard holds instead of first/last transitions.
- `Storyboard Prompts`: maps `current_segment` to the active positive prompt text. Increase the prompt count only when you want different prompts per segment.
- `Segment Frame Count`: converts segment duration and FPS into an LTX-compatible latent frame count.
- `LTXMotionAudioSegmentLoop`: saves each rendered segment, checks whether more segments remain, and requeues the next pass until the selected window is finished.

## Workflow Tuning

- Change `fps` only when you understand the effect on `Segment Frame Count`; segment length is derived from duration and FPS together.
- Use `use_loaded_audio = false` when you want the loop timing to be driven only by time and storyboard durations, not by a loaded song.
- Keep unused storyboard image inputs disconnected. The schedulers only consider the connected images up to the active count.
- In the first/last storyboard workflows, each new segment advances by one image pair. With images `1, 2, 3`, the loop runs `1->2`, then `2->3`, then `3->1`.
- In the plain storyboard workflows, the active image rotates by duration instead of rendering paired transitions.
- If the final video should keep the original song instead of the decoded model audio, use one of the `*_music.json` variants.
- Use the range-stop variant when you want to validate only a short time slice before launching a full render.

## Workflow Matrix

| Goal | Best Workflow | Use When |
| --- | --- | --- |
| Test a short section quickly | `gap_ltx23_lipsync_range_stop.json` | You want to validate lip sync, prompt, or image behavior on a short audio slice |
| Render long audio with one visual | `gap_ltx23_lipsync_long_audio.json` | One main image should carry the whole track |
| Render long audio with stronger shot control | `gap_ltx23_lipsync_long_audio_first_last.json` | You want both first-frame and last-frame guidance across segments |
| Render long audio with storyboard changes | `gap_ltx23_lipsync_long_audio_storyboard.json` | You want segmented rendering plus a rotating image list |
| Storyboard lip sync | `gap_ltx23_storyboard_lipsync.json` | Each storyboard image should hold for a fixed duration and export model-decoded audio |
| Storyboard lip sync with original music | `gap_ltx23_storyboard_lipsync_music.json` | You want the same storyboard timing but the final video should keep the selected source music |
| Storyboard first/last | `gap_ltx23_storyboard_first_last.json` | Each segment should move through overlapping pairs like `1->2`, `2->3`, `3->4` |
| Storyboard first/last with original music | `gap_ltx23_storyboard_first_last_music.json` | You want the first/last storyboard workflow and the final video should keep the selected source music |
| Storyboard first/last on a selected range | `gap_ltx23_storyboard_first_last_lipsync_range_stop.json` | You want overlapping first/last storyboard pairs, but only for a chosen `start_time` to `end_time` window |
| Motion-track loop rendering | `gap_ltx23_first_last_motion_track_looper.json` | You want sparse motion paths plus looping first/last image alternation over a long audio or silent window |
| Cleaner FLF2V storyboard first/last loop | `gap_ltx23_flf2v_storyboard_first_last_looper.json` | You want the cleaner `video_ltx2_3_flf2v.json` render path plus storyboard first/last looping |
| Build silent first/last shots | `gap_ltx23_first_last_only_simple.json` | You are shaping motion without the segmented audio loop |

## Recommended Starting Points

- Use `gap_ltx23_lipsync_range_stop.json` for fast lip-sync testing on a short audio range.
- Use `gap_ltx23_lipsync_long_audio.json` when one image should drive a long full-song or long-dialogue render.
- Use `gap_ltx23_lipsync_long_audio_storyboard.json` when you want long segmented rendering but still need storyboard image rotation.
- Use `gap_ltx23_storyboard_lipsync.json` when each image should run for a fixed duration and model-decoded audio is acceptable.
- Use `gap_ltx23_storyboard_lipsync_music.json` when you want the same plain storyboard workflow but the final output must keep the selected music track.
- Use `gap_ltx23_storyboard_first_last.json` when each storyboard segment should move through overlapping first/last pairs.
- Use `gap_ltx23_storyboard_first_last_music.json` when you want the storyboard first/last workflow and need the final output to keep the selected music track.
- Use `gap_ltx23_storyboard_first_last_lipsync_range_stop.json` when you want the storyboard first/last motion style but only on a selected audio window.
- Use `gap_ltx23_first_last_motion_track_looper.json` when you want sparse track motion plus long-form loop automation.
- Use `gap_ltx23_flf2v_storyboard_first_last_looper.json` when you want the cleaner upstream FLF2V render path with storyboard first/last looping and per-segment prompts.

## Custom Nodes

The main nodes added by this package are:

- `LTX Motion Storyboard Segment Selector`
- `LTX Motion Storyboard Pair Selector`
- `LTX Motion Storyboard Prompt Selector`
- `LTX Motion Audio Segment Loop`
- `LTX Motion Audio Range Extractor`
- Audio range and segmented-audio helper nodes

These nodes are built to work with the included workflows but can also be reused in custom ComfyUI graphs.

## Runtime Notes

- The workflows use a separate Gemma text encoder, so `no CLIP/text encoder weights in checkpoint` is expected.
- Storyboard workflows require `ffmpeg` for final segment concatenation.
- Final output length still depends on your LTX frame count and per-segment render settings.

## Troubleshooting

- If your workflow stops after one segment, verify that the loop node is enabled and that `ffmpeg` is available.
- If a plain storyboard render follows the right timings but exports the wrong soundtrack, use `gap_ltx23_storyboard_lipsync_music.json`.
- If a storyboard first/last render moves to the music but the exported soundtrack does not match your selected file, use `gap_ltx23_storyboard_first_last_music.json`.
- If a storyboard first/last workflow repeats the same prompt for every segment, confirm that `Storyboard Prompts` is connected to the positive `CLIPTextEncode` node.
- If model loading warns about missing CLIP weights in the checkpoint, keep the separate Gemma text encoder in place. That warning is normal for this setup.
- Workflow templates now leave image picker fields blank by default. Select your own files from the ComfyUI input folder before running them.

## More Docs

- `docs/getting-started.md`
- `docs/workflow-guide.md`
- `docs/release-notes-v1.0.0.md`

## Release Notes

Prepared release notes for the current public version are in `docs/release-notes-v1.0.0.md`.

## GitHub Release Checklist

- Use tag `v1.0.0` as the first public release target
- Paste `docs/release-notes-v1.0.0.md` into the GitHub release body
- Add screenshots or short GIF previews when they are available

## Notes

- Storyboard workflows require `ffmpeg` for final segment merging.
- The installer can also merge Gemma shard files when needed.

## License

This project is released under the MIT License. See `LICENSE`.