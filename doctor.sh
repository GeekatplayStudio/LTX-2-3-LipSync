#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd || echo "${SCRIPT_DIR}/../..")"
MODELS_ROOT="${COMFY_ROOT}/models"

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       LTX 2.3 Motion - Doctor            ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""

ISSUES=0

print_ok() {
  echo -e "  [${GREEN}✓${NC}] $1"
}

print_fail() {
  echo -e "  [${RED}✗${NC}] $1"
  ISSUES=$((ISSUES + 1))
}

print_warn() {
  echo -e "  [${YELLOW}!${NC}] $1"
}

echo -e "🩺 ${YELLOW}Checking System Environment...${NC}"

# 1. Dependency: Python
PYTHON_EXE=""
if [[ -f "${COMFY_ROOT}/.venv/bin/python" ]]; then
  PYTHON_EXE="${COMFY_ROOT}/.venv/bin/python"
elif [[ -f "${COMFY_ROOT}/python_embeded/bin/python" ]]; then
  PYTHON_EXE="${COMFY_ROOT}/python_embeded/bin/python"
elif [[ -f "${SCRIPT_DIR}/.venv/bin/python" ]]; then
  PYTHON_EXE="${SCRIPT_DIR}/.venv/bin/python"
elif command -v python3 >/dev/null 2>&1; then
  PYTHON_EXE="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_EXE="python"
fi

if [[ -n "${PYTHON_EXE}" ]]; then
  print_ok "Python found: ${PYTHON_EXE}"
else
  print_fail "Python executable not found in standard ComfyUI or system paths."
fi

# 2. Dependency: Python Packages
if [[ -n "${PYTHON_EXE}" ]]; then
  MISSING_PKGS=()
  for pkg in numpy PIL aiohttp imageio_ffmpeg; do
    if ! "${PYTHON_EXE}" -c "import ${pkg}" >/dev/null 2>&1; then
      MISSING_PKGS+=("$pkg")
    fi
  done
  
  if [[ ${#MISSING_PKGS[@]} -eq 0 ]]; then
    print_ok "Python packages (numpy, pillow, aiohttp, imageio-ffmpeg) are installed."
  else
    print_fail "Missing Python packages: ${MISSING_PKGS[*]}. Run ./install.sh to fix."
  fi
fi

# 3. Dependency: ffmpeg
if command -v ffmpeg >/dev/null 2>&1; then
  print_ok "ffmpeg found in PATH"
elif [[ -f "${COMFY_ROOT}/ffmpeg" ]]; then
  print_ok "ffmpeg found in ComfyUI root: ${COMFY_ROOT}/ffmpeg"
else
  print_fail "ffmpeg not found! Required for segmented-audio and storyboard loop workflows."
fi

echo ""
echo -e "🩺 ${YELLOW}Checking ComfyUI Models...${NC}"

if [[ ! -d "${MODELS_ROOT}" ]]; then
  print_fail "ComfyUI models folder not found at ${MODELS_ROOT}!"
else
  # Model checks
  check_model() {
    local path="$1"
    local desc="$2"
    if [[ -f "${MODELS_ROOT}/${path}" ]]; then
      print_ok "${desc} found"
    else
      print_fail "Missing ${desc}"
    fi
  }

  check_model "checkpoints/ltx-2.3-22b-dev.safetensors" "Checkpoint (ltx-2.3-22b-dev)"
  check_model "checkpoints/ltx-2.3-22b-dev-fp8.safetensors" "Checkpoint (ltx-2.3-22b-dev-fp8)"
  check_model "checkpoints/ltx-2.3-22b-distilled-fp8.safetensors" "Checkpoint (ltx-2.3-22b-distilled-fp8)"
  check_model "loras/ltx-2.3-22b-distilled-lora-384.safetensors" "Distilled LoRA"
  check_model "loras/ltx-2.3-22b-ic-lora-motion-track-control-ref0.5.safetensors" "Motion Track IC-LoRA"
  check_model "loras/gemma-3-12b-it-abliterated_lora_rank64_bf16.safetensors" "Gemma Abliterated LoRA"
  check_model "upscale_models/ltx-2.3-spatial-upscaler-x2-1.0.safetensors" "Spatial Upscaler"
  check_model "text_encoders/gemma_3_12B_it_fp4_mixed.safetensors" "Gemma text encoder"
  check_model "text_encoders/comfy_gemma_3_12B_it.safetensors" "Gemma comfy alias"
  check_model "text_encoders/gemma_3_12B_it.safetensors" "Gemma legacy alias"
fi

echo ""
echo -e "${GREEN}==========================================${NC}"
if [[ ${ISSUES} -eq 0 ]]; then
  echo -e "${GREEN}All checks passed! Your environment looks great for LTX 2.3 Motion.${NC}"
else
  echo -e "${RED}Found ${ISSUES} issue(s). Please review the errors above.${NC}"
  echo -e "Recommendation: Run ${YELLOW}./install.sh${NC} to install packages and download missing models."
fi
echo -e "${GREEN}==========================================${NC}"
echo ""
