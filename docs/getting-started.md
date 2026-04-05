# Getting Started

## Install Location

Place this repository inside your `ComfyUI/custom_nodes` folder. For example:

```bash
cd ComfyUI/custom_nodes
git clone https://github.com/GeekatplayStudio/LTX-2-3-LipSync LTX2-3-motion
```

Restart ComfyUI after copying or cloning the folder.

## Required Models

Make sure these files are available in your ComfyUI `models` folders:

- `models/checkpoints/ltx-2.3-22b-distilled-fp8.safetensors`
- `models/loras/ltx-2.3-22b-distilled-lora-384.safetensors`
- `models/loras/ltx-2.3-22b-ic-lora-motion-track-control-ref0.5.safetensors`
- `models/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors`

If you prefer, run `install_ltx23_motion_models.bat` (or `./install_ltx23_motion_models.sh` on Linux) to place the files automatically.

## System Requirements

- A working ComfyUI install with LTX 2.3 support
- `ffmpeg` available on your system for segment merging workflows
- Enough VRAM and disk space for long segmented renders

## First Run Checklist

1. Open `gap_ltx23_lipsync_range_stop.json`.
2. Load a source image.
3. Load a short audio clip or select a short range from a longer clip.
4. Confirm the Gemma text encoder loads correctly.
5. Run a short render to validate that the pipeline works.

After that:

1. Move to a segmented audio workflow for long audio.
2. Move to a storyboard workflow if you want image rotation or first/last pair animation.
3. Move to `gap_ltx23_first_last_motion_track_looper.json` when you want sparse motion guidance plus looping.
4. Move to `gap_ltx23_flf2v_storyboard_first_last_looper.json` when you want the cleaner FLF2V render path with storyboard prompting.

## Common Setup Mistakes

- Missing `ffmpeg`, which prevents final segment concatenation
- Missing Gemma text encoder file
- Using a long full-song workflow before validating a short test render
- Using per-image prompts without connecting the prompt selector to the segment index path
- Forgetting to switch `use_loaded_audio` off when you want a silent time-only render window
- Leaving workflow image slots blank instead of selecting your own files from the ComfyUI input folder

## Expected Log Message

This setup uses a separate text encoder, so a log similar to the following is expected:

`no CLIP/text encoder weights in checkpoint`

That message does not mean the workflow is broken if the Gemma text encoder is present.