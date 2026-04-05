#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_MODELS_ROOT="$(cd "${SCRIPT_DIR}/../../models" 2>/dev/null && pwd || echo "${SCRIPT_DIR}/../../models")"
DEFAULT_DOWNLOAD_ROOT="${HOME}/Downloads/LTX-2.3"

ARG_DOWNLOAD_ROOT="${1:-}"
ARG_MODELS_ROOT="${2:-}"
ARG_GEMMA_SHARD_DIR="${3:-}"

echo ""
echo "LTX 2.3 Motion Workflow Model Installer"
echo ""
echo "This installer downloads the shared LTX 2.3 workflow models into your ComfyUI models folders."
echo "It uses the Comfy-compatible Gemma 3 12B text encoder file by default."
echo "If that file is not present, it can still merge manually downloaded Gemma shards."
echo "It does not install ffmpeg; storyboard and waveform song-looper workflows still need ffmpeg available at runtime."
echo ""

if [[ -n "${ARG_DOWNLOAD_ROOT}" ]]; then
  DOWNLOAD_ROOT="${ARG_DOWNLOAD_ROOT}"
else
  read -p "Download cache folder [${DEFAULT_DOWNLOAD_ROOT}]: " DOWNLOAD_ROOT
  DOWNLOAD_ROOT="${DOWNLOAD_ROOT:-${DEFAULT_DOWNLOAD_ROOT}}"
fi

if [[ -n "${ARG_MODELS_ROOT}" ]]; then
  MODELS_ROOT="${ARG_MODELS_ROOT}"
else
  read -p "ComfyUI models folder [${DEFAULT_MODELS_ROOT}]: " MODELS_ROOT
  MODELS_ROOT="${MODELS_ROOT:-${DEFAULT_MODELS_ROOT}}"
fi

if [[ ! -d "${MODELS_ROOT}" ]]; then
  echo ""
  echo "ERROR: Models folder does not exist:"
  echo "  ${MODELS_ROOT}"
  exit 1
fi

mkdir -p "${DOWNLOAD_ROOT}"
mkdir -p "${MODELS_ROOT}/checkpoints"
mkdir -p "${MODELS_ROOT}/loras"
mkdir -p "${MODELS_ROOT}/text_encoders"
mkdir -p "${MODELS_ROOT}/upscale_models"

SUPPORTED_GEMMA_FILE="${MODELS_ROOT}/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors"
GEMMA_COMFY_ALIAS="${MODELS_ROOT}/text_encoders/comfy_gemma_3_12B_it.safetensors"
GEMMA_LEGACY_ALIAS="${MODELS_ROOT}/text_encoders/gemma_3_12B_it.safetensors"

GEMMA_SHARD_DIR="${ARG_GEMMA_SHARD_DIR:-}"
if [[ -z "${GEMMA_SHARD_DIR}" ]]; then
  read -p "Existing Gemma shard folder [${MODELS_ROOT}/text_encoders/gemma]: " GEMMA_SHARD_DIR
  GEMMA_SHARD_DIR="${GEMMA_SHARD_DIR:-${MODELS_ROOT}/text_encoders/gemma}"
fi

echo ""
echo "Download cache:"
echo "  ${DOWNLOAD_ROOT}"
echo "Models folder:"
echo "  ${MODELS_ROOT}"
echo "Gemma shard folder:"
echo "  ${GEMMA_SHARD_DIR}"
echo ""

download_public() {
  local url="$1"
  local dest="$2"
  if [[ -f "$dest" ]]; then
    echo "Found existing file:"
    echo "  $dest"
    return 0
  fi
  echo ""
  echo "Downloading:"
  echo "  $dest"
  curl -L --fail --progress-bar -o "$dest" "$url"
}

download_auth() {
  local url="$1"
  local dest="$2"
  if [[ -f "$dest" ]]; then
    echo "Found existing file:"
    echo "  $dest"
    return 0
  fi
  echo ""
  echo "Downloading gated file:"
  echo "  $dest"
  if ! curl -L --fail --progress-bar -H "Authorization: Bearer ${HF_TOKEN:-}" -o "$dest" "$url"; then
    echo "ERROR: Download failed for $dest"
    echo "Make sure the token has access to the Gemma repository."
    exit 1
  fi
}

download_public "https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-22b-dev.safetensors?download=true" "${MODELS_ROOT}/checkpoints/ltx-2.3-22b-dev.safetensors"
download_public "https://huggingface.co/Lightricks/LTX-2.3-fp8/resolve/main/ltx-2.3-22b-dev-fp8.safetensors?download=true" "${MODELS_ROOT}/checkpoints/ltx-2.3-22b-dev-fp8.safetensors"
download_public "https://huggingface.co/Lightricks/LTX-2.3-fp8/resolve/main/ltx-2.3-22b-distilled-fp8.safetensors?download=true" "${MODELS_ROOT}/checkpoints/ltx-2.3-22b-distilled-fp8.safetensors"
download_public "https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-22b-distilled-lora-384.safetensors?download=true" "${MODELS_ROOT}/loras/ltx-2.3-22b-distilled-lora-384.safetensors"
download_public "https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Motion-Track-Control/resolve/main/ltx-2.3-22b-ic-lora-motion-track-control-ref0.5.safetensors?download=true" "${MODELS_ROOT}/loras/ltx-2.3-22b-ic-lora-motion-track-control-ref0.5.safetensors"
download_public "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/loras/gemma-3-12b-it-abliterated_lora_rank64_bf16.safetensors?download=true" "${MODELS_ROOT}/loras/gemma-3-12b-it-abliterated_lora_rank64_bf16.safetensors"
download_public "https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-spatial-upscaler-x2-1.0.safetensors?download=true" "${MODELS_ROOT}/upscale_models/ltx-2.3-spatial-upscaler-x2-1.0.safetensors"

replace_incompatible_alias() {
  local alias_file="$1"
  if [[ ! -f "$alias_file" ]]; then return 0; fi
  local supported_size
  supported_size=$(stat -c%s "$SUPPORTED_GEMMA_FILE" 2>/dev/null || stat -f%z "$SUPPORTED_GEMMA_FILE" 2>/dev/null || echo "0")
  local target_size
  target_size=$(stat -c%s "$alias_file" 2>/dev/null || stat -f%z "$alias_file" 2>/dev/null || echo "0")
  
  if [[ "$supported_size" == "$target_size" && "$supported_size" != "0" ]]; then return 0; fi

  local backup_path="${alias_file%.*}_raw_google_merged.${alias_file##*.}"
  if [[ -f "$backup_path" ]]; then
    rm -f "$alias_file"
  else
    mv "$alias_file" "$backup_path"
  fi
}

create_gemma_alias() {
  local alias_file="$1"
  if [[ -f "$alias_file" ]]; then return 0; fi
  ln -s "$SUPPORTED_GEMMA_FILE" "$alias_file" 2>/dev/null || ln "$SUPPORTED_GEMMA_FILE" "$alias_file" 2>/dev/null || cp "$SUPPORTED_GEMMA_FILE" "$alias_file"
}

ensure_gemma_aliases() {
  if [[ ! -f "$SUPPORTED_GEMMA_FILE" ]]; then return 0; fi
  replace_incompatible_alias "$GEMMA_COMFY_ALIAS"
  replace_incompatible_alias "$GEMMA_LEGACY_ALIAS"
  create_gemma_alias "$GEMMA_COMFY_ALIAS"
  create_gemma_alias "$GEMMA_LEGACY_ALIAS"
}

verify_install() {
  VERIFY_FAILED=0
  echo ""
  echo "Verifying required workflow model files..."

  verify_exists() {
    local pf="$1"
    local desc="$2"
    if [[ -f "$pf" ]]; then
      echo "  OK      $desc: $pf"
    else
      echo "  MISSING $desc: $pf"
      VERIFY_FAILED=1
    fi
  }

  verify_exists "${MODELS_ROOT}/checkpoints/ltx-2.3-22b-dev.safetensors" "Checkpoint"
  verify_exists "${MODELS_ROOT}/checkpoints/ltx-2.3-22b-dev-fp8.safetensors" "Checkpoint FP8"
  verify_exists "${MODELS_ROOT}/checkpoints/ltx-2.3-22b-distilled-fp8.safetensors" "Distilled Checkpoint FP8"
  verify_exists "${MODELS_ROOT}/loras/ltx-2.3-22b-distilled-lora-384.safetensors" "Distilled LoRA"
  verify_exists "${MODELS_ROOT}/loras/ltx-2.3-22b-ic-lora-motion-track-control-ref0.5.safetensors" "Motion Track IC-LoRA"
  verify_exists "${MODELS_ROOT}/loras/gemma-3-12b-it-abliterated_lora_rank64_bf16.safetensors" "Gemma Abliterated LoRA"
  verify_exists "${MODELS_ROOT}/upscale_models/ltx-2.3-spatial-upscaler-x2-1.0.safetensors" "LTX Spatial Upscaler"
  verify_exists "${SUPPORTED_GEMMA_FILE}" "Gemma text encoder"
  verify_exists "${GEMMA_COMFY_ALIAS}" "Gemma comfy alias"
  verify_exists "${GEMMA_LEGACY_ALIAS}" "Gemma legacy alias"

  echo ""
  if [[ "$VERIFY_FAILED" == "0" ]]; then
    echo "Finished. All required workflow model files are in the correct folders."
  else
    echo "Finished with missing required files. Review the verification output above."
  fi
  echo "Open workflow files from:"
  echo "  ${SCRIPT_DIR}/workflows"
  echo "Base motion-transfer workflow:"
  echo "  ${SCRIPT_DIR}/LTX-2.3_Image_To_Video_Motion_Transfer.json"
  echo ""
  echo "Storyboard and waveform workflows require ffmpeg during segment merge."
  echo ""
  if [[ -z "${ARG_MODELS_ROOT}" ]]; then
    read -p "Press Enter to continue..."
  fi
  exit 0
}

if [[ -f "${SUPPORTED_GEMMA_FILE}" ]]; then
  echo ""
  echo "Supported Gemma text encoder already exists. Skipping Gemma download and merge."
  ensure_gemma_aliases
  verify_install
fi

if download_public "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors?download=true" "${SUPPORTED_GEMMA_FILE}"; then
  ensure_gemma_aliases
  verify_install
fi

echo ""
echo "Falling back to manual Gemma shard merge because the Comfy-compatible Gemma file was not available."

resolve_gemma_index() {
  local dir="$1"
  GEMMA_INDEX_FILE=""
  if [[ -f "${dir}/model.safetensors.index.json" ]]; then
    GEMMA_INDEX_FILE="${dir}/model.safetensors.index.json"
  elif [[ -f "${dir}/gemma-3-12B-it.json" ]]; then
    GEMMA_INDEX_FILE="${dir}/gemma-3-12B-it.json"
  fi
}

resolve_gemma_index "${GEMMA_SHARD_DIR}"

if [[ -z "${GEMMA_INDEX_FILE}" ]]; then
  if [[ -z "${HF_TOKEN:-}" ]]; then
    echo ""
    echo "Gemma 3 12B is gated on Hugging Face."
    echo "You must already have access to https://huggingface.co/google/gemma-3-12b-it"
    echo "and provide a read token with that access."
    read -s -p "Hugging Face token for Gemma download [leave blank to skip]: " HF_TOKEN
    echo ""
  fi

  if [[ -z "${HF_TOKEN:-}" ]]; then
    echo ""
    echo "Skipping Gemma download. The workflow will still need:"
    echo "  ${SUPPORTED_GEMMA_FILE}"
    verify_install
  fi

  GEMMA_CACHE="${DOWNLOAD_ROOT}/google_gemma-3-12b-it"
  mkdir -p "${GEMMA_CACHE}"

  download_auth "https://huggingface.co/google/gemma-3-12b-it/resolve/main/model.safetensors.index.json?download=true" "${GEMMA_CACHE}/model.safetensors.index.json"
  download_auth "https://huggingface.co/google/gemma-3-12b-it/resolve/main/model-00001-of-00005.safetensors?download=true" "${GEMMA_CACHE}/model-00001-of-00005.safetensors"
  download_auth "https://huggingface.co/google/gemma-3-12b-it/resolve/main/model-00002-of-00005.safetensors?download=true" "${GEMMA_CACHE}/model-00002-of-00005.safetensors"
  download_auth "https://huggingface.co/google/gemma-3-12b-it/resolve/main/model-00003-of-00005.safetensors?download=true" "${GEMMA_CACHE}/model-00003-of-00005.safetensors"
  download_auth "https://huggingface.co/google/gemma-3-12b-it/resolve/main/model-00004-of-00005.safetensors?download=true" "${GEMMA_CACHE}/model-00004-of-00005.safetensors"
  download_auth "https://huggingface.co/google/gemma-3-12b-it/resolve/main/model-00005-of-00005.safetensors?download=true" "${GEMMA_CACHE}/model-00005-of-00005.safetensors"

  GEMMA_SHARD_DIR="${GEMMA_CACHE}"
  resolve_gemma_index "${GEMMA_SHARD_DIR}"
  if [[ -z "${GEMMA_INDEX_FILE}" ]]; then
    echo ""
    echo "ERROR: Downloaded Gemma shards but could not find an index JSON file."
    exit 1
  fi
fi

PYTHON_EXE=""
find_python() {
  if [[ -f "${SCRIPT_DIR}/../../.venv/bin/python" ]]; then
    PYTHON_EXE="${SCRIPT_DIR}/../../.venv/bin/python"
  elif [[ -f "${SCRIPT_DIR}/../../python_embeded/bin/python" ]]; then
    PYTHON_EXE="${SCRIPT_DIR}/../../python_embeded/bin/python"
  elif command -v python3 >/dev/null 2>&1; then
    PYTHON_EXE="python3"
  elif command -v python >/dev/null 2>&1; then
    PYTHON_EXE="python"
  else
    echo ""
    echo "ERROR: No Python executable was found."
    echo "Install Python or use the ComfyUI .venv distribution."
    exit 1
  fi
}

find_python

echo ""
echo "Merging Gemma shard files from:"
echo "  ${GEMMA_SHARD_DIR}"
echo "Using index:"
echo "  ${GEMMA_INDEX_FILE}"
echo "This can take a while and requires free disk space."

if ! "${PYTHON_EXE}" "${SCRIPT_DIR}/merge_safetensors_shards.py" --index "${GEMMA_INDEX_FILE}" --shard-dir "${GEMMA_SHARD_DIR}" --output "${MODELS_ROOT}/text_encoders/gemma_3_12B_it.safetensors"; then
  echo ""
  echo "ERROR: Gemma shard merge failed."
  exit 1
fi

ensure_gemma_aliases
verify_install
