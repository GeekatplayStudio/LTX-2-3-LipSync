#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd || echo "${SCRIPT_DIR}/../..")"
DEFAULT_MODELS_ROOT="${COMFY_ROOT}/models"

DEFAULT_DOWNLOAD_ROOT="${HOME}/Downloads/LTX-2.3"

ARG_DOWNLOAD_ROOT="${1:-}"
ARG_MODELS_ROOT="${2:-}"
ARG_GEMMA_SHARD_DIR="${3:-}"
ARG_SKIP_FFMPEG="${4:-}"

echo ""
echo "LTX 2.3 Motion Full Installer"
echo ""
echo "This script installs Python dependencies, configures ffmpeg, and downloads"
echo "the required workflow models into your ComfyUI folders."
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

GEMMA_SHARD_DIR="${ARG_GEMMA_SHARD_DIR:-}"
if [[ -z "${GEMMA_SHARD_DIR}" ]]; then
  GEMMA_SHARD_DIR="${MODELS_ROOT}/text_encoders/gemma"
fi

mkdir -p "${DOWNLOAD_ROOT}"
mkdir -p "${COMFY_ROOT}/tools"

echo ""
echo "ComfyUI root:"
echo "  ${COMFY_ROOT}"
echo "Download cache:"
echo "  ${DOWNLOAD_ROOT}"
echo "Models root:"
echo "  ${MODELS_ROOT}"
echo "Gemma shard folder:"
echo "  ${GEMMA_SHARD_DIR}"

PYTHON_EXE=""
find_python() {
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
  else
    echo ""
    echo "ERROR: No Python executable was found."
    echo "Install Python or use the ComfyUI .venv / python_embeded distribution."
    exit 1
  fi
}

find_python

echo ""
echo "Using Python:"
echo "  ${PYTHON_EXE}"

echo ""
echo "Installing Python packages required by this custom node..."
if ! "${PYTHON_EXE}" -m pip --version >/dev/null 2>&1; then
  echo ""
  echo "pip is not available in the selected Python environment."
  echo "Install pip for that environment, then rerun install.sh."
  exit 1
fi

"${PYTHON_EXE}" -m pip install --upgrade pip
"${PYTHON_EXE}" -m pip install --upgrade "numpy<2.3.0" pillow aiohttp imageio-ffmpeg

ensure_ffmpeg() {
  echo ""
  echo "Checking ffmpeg..."
  if command -v ffmpeg >/dev/null 2>&1; then
    FFMPEG_EXE="$(command -v ffmpeg)"
    echo "Using ffmpeg:"
    echo "  ${FFMPEG_EXE}"
  elif [[ -f "${COMFY_ROOT}/ffmpeg" ]]; then
    FFMPEG_EXE="${COMFY_ROOT}/ffmpeg"
    echo "Using ffmpeg:"
    echo "  ${FFMPEG_EXE}"
  else
    echo "ERROR: ffmpeg was not found in PATH."
    echo "Please install ffmpeg using your system's package manager, e.g.:"
    echo "  sudo apt update && sudo apt install ffmpeg"
    exit 1
  fi
}

if [[ "$(echo "${ARG_SKIP_FFMPEG:-}" | tr '[:upper:]' '[:lower:]')" == "skip-ffmpeg" ]]; then
  echo ""
  echo "Skipping ffmpeg setup because skip-ffmpeg was requested."
else
  ensure_ffmpeg
fi

echo ""
echo "Running model installer..."

if [[ ! -x "${SCRIPT_DIR}/install_ltx23_motion_models.sh" ]]; then
  chmod +x "${SCRIPT_DIR}/install_ltx23_motion_models.sh" || true
fi

if [[ ! -f "${SCRIPT_DIR}/install_ltx23_motion_models.sh" ]]; then
  echo "ERROR: ${SCRIPT_DIR}/install_ltx23_motion_models.sh not found."
  exit 1
fi

bash "${SCRIPT_DIR}/install_ltx23_motion_models.sh" "${DOWNLOAD_ROOT}" "${MODELS_ROOT}" "${GEMMA_SHARD_DIR}"

echo ""
echo "Finished. Restart ComfyUI before opening the workflows."
