@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..\models") do set "DEFAULT_MODELS_ROOT=%%~fI"
set "DEFAULT_DOWNLOAD_ROOT=%UserProfile%\OneDrive\Downloads\LTX-2.3"
if not exist "%UserProfile%\OneDrive" set "DEFAULT_DOWNLOAD_ROOT=%UserProfile%\Downloads\LTX-2.3"
set "ARG_DOWNLOAD_ROOT=%~1"
set "ARG_MODELS_ROOT=%~2"
set "ARG_GEMMA_SHARD_DIR=%~3"

echo.
echo LTX 2.3 Motion Workflow Model Installer
echo.
echo This installer downloads the shared LTX 2.3 workflow models into your ComfyUI models folders.
echo It uses the Comfy-compatible Gemma 3 12B text encoder file by default.
echo If that file is not present, it can still merge manually downloaded Gemma shards.
echo It does not install ffmpeg; storyboard and waveform song-looper workflows still need ffmpeg available at runtime.
echo.

if defined ARG_DOWNLOAD_ROOT (
  set "DOWNLOAD_ROOT=%ARG_DOWNLOAD_ROOT%"
) else (
  set /p "DOWNLOAD_ROOT=Download cache folder [%DEFAULT_DOWNLOAD_ROOT%]: "
  if not defined DOWNLOAD_ROOT set "DOWNLOAD_ROOT=%DEFAULT_DOWNLOAD_ROOT%"
)

if defined ARG_MODELS_ROOT (
  set "MODELS_ROOT=%ARG_MODELS_ROOT%"
) else (
  set /p "MODELS_ROOT=ComfyUI models folder [%DEFAULT_MODELS_ROOT%]: "
  if not defined MODELS_ROOT set "MODELS_ROOT=%DEFAULT_MODELS_ROOT%"
)

if not exist "%MODELS_ROOT%" (
  echo.
  echo ERROR: Models folder does not exist:
  echo   %MODELS_ROOT%
  exit /b 1
)

call :ensure_dir "%DOWNLOAD_ROOT%"
call :ensure_dir "%MODELS_ROOT%\checkpoints"
call :ensure_dir "%MODELS_ROOT%\loras"
call :ensure_dir "%MODELS_ROOT%\text_encoders"
call :ensure_dir "%MODELS_ROOT%\upscale_models"

set "SUPPORTED_GEMMA_FILE=%MODELS_ROOT%\text_encoders\gemma_3_12B_it_fp4_mixed.safetensors"
set "GEMMA_COMFY_ALIAS=%MODELS_ROOT%\text_encoders\comfy_gemma_3_12B_it.safetensors"
set "GEMMA_LEGACY_ALIAS=%MODELS_ROOT%\text_encoders\gemma_3_12B_it.safetensors"

set "GEMMA_SHARD_DIR=%MODELS_ROOT%\text_encoders\gemma"
if defined ARG_GEMMA_SHARD_DIR set "GEMMA_SHARD_DIR=%ARG_GEMMA_SHARD_DIR%"
if not defined ARG_GEMMA_SHARD_DIR (
  set /p "GEMMA_SHARD_DIR=Existing Gemma shard folder [%GEMMA_SHARD_DIR%]: "
  if not defined GEMMA_SHARD_DIR set "GEMMA_SHARD_DIR=%MODELS_ROOT%\text_encoders\gemma"
)

echo.
echo Download cache:
echo   %DOWNLOAD_ROOT%
echo Models folder:
echo   %MODELS_ROOT%
echo Gemma shard folder:
echo   %GEMMA_SHARD_DIR%
echo.

call :download_public "https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-22b-dev.safetensors?download=true" "%MODELS_ROOT%\checkpoints\ltx-2.3-22b-dev.safetensors"
if errorlevel 1 exit /b 1

call :download_public "https://huggingface.co/Lightricks/LTX-2.3-fp8/resolve/main/ltx-2.3-22b-dev-fp8.safetensors?download=true" "%MODELS_ROOT%\checkpoints\ltx-2.3-22b-dev-fp8.safetensors"
if errorlevel 1 exit /b 1

call :download_public "https://huggingface.co/Lightricks/LTX-2.3-fp8/resolve/main/ltx-2.3-22b-distilled-fp8.safetensors?download=true" "%MODELS_ROOT%\checkpoints\ltx-2.3-22b-distilled-fp8.safetensors"
if errorlevel 1 exit /b 1

call :download_public "https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-22b-distilled-lora-384.safetensors?download=true" "%MODELS_ROOT%\loras\ltx-2.3-22b-distilled-lora-384.safetensors"
if errorlevel 1 exit /b 1

call :download_public "https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Motion-Track-Control/resolve/main/ltx-2.3-22b-ic-lora-motion-track-control-ref0.5.safetensors?download=true" "%MODELS_ROOT%\loras\ltx-2.3-22b-ic-lora-motion-track-control-ref0.5.safetensors"
if errorlevel 1 exit /b 1

call :download_public "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/loras/gemma-3-12b-it-abliterated_lora_rank64_bf16.safetensors?download=true" "%MODELS_ROOT%\loras\gemma-3-12b-it-abliterated_lora_rank64_bf16.safetensors"
if errorlevel 1 exit /b 1

call :download_public "https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-spatial-upscaler-x2-1.0.safetensors?download=true" "%MODELS_ROOT%\upscale_models\ltx-2.3-spatial-upscaler-x2-1.0.safetensors"
if errorlevel 1 exit /b 1

if exist "%SUPPORTED_GEMMA_FILE%" (
  echo.
  echo Supported Gemma text encoder already exists. Skipping Gemma download and merge.
  call :ensure_gemma_aliases
  goto :verify_install
)

call :download_public "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors?download=true" "%SUPPORTED_GEMMA_FILE%"
if not errorlevel 1 (
  call :ensure_gemma_aliases
  goto :verify_install
)

echo.
echo Falling back to manual Gemma shard merge because the Comfy-compatible Gemma file was not available.

call :resolve_gemma_index "%GEMMA_SHARD_DIR%"
if defined GEMMA_INDEX_FILE goto :merge_gemma

set "HF_TOKEN=%HF_TOKEN%"
if not defined HF_TOKEN (
  echo.
  echo Gemma 3 12B is gated on Hugging Face.
  echo You must already have access to https://huggingface.co/google/gemma-3-12b-it
  echo and provide a read token with that access.
  set /p "HF_TOKEN=Hugging Face token for Gemma download [leave blank to skip]: "
)

if not defined HF_TOKEN (
  echo.
  echo Skipping Gemma download. The workflow will still need:
  echo   %SUPPORTED_GEMMA_FILE%
  goto :verify_install
)

set "GEMMA_CACHE=%DOWNLOAD_ROOT%\google_gemma-3-12b-it"
call :ensure_dir "%GEMMA_CACHE%"

call :download_auth "https://huggingface.co/google/gemma-3-12b-it/resolve/main/model.safetensors.index.json?download=true" "%GEMMA_CACHE%\model.safetensors.index.json"
if errorlevel 1 exit /b 1

call :download_auth "https://huggingface.co/google/gemma-3-12b-it/resolve/main/model-00001-of-00005.safetensors?download=true" "%GEMMA_CACHE%\model-00001-of-00005.safetensors"
if errorlevel 1 exit /b 1
call :download_auth "https://huggingface.co/google/gemma-3-12b-it/resolve/main/model-00002-of-00005.safetensors?download=true" "%GEMMA_CACHE%\model-00002-of-00005.safetensors"
if errorlevel 1 exit /b 1
call :download_auth "https://huggingface.co/google/gemma-3-12b-it/resolve/main/model-00003-of-00005.safetensors?download=true" "%GEMMA_CACHE%\model-00003-of-00005.safetensors"
if errorlevel 1 exit /b 1
call :download_auth "https://huggingface.co/google/gemma-3-12b-it/resolve/main/model-00004-of-00005.safetensors?download=true" "%GEMMA_CACHE%\model-00004-of-00005.safetensors"
if errorlevel 1 exit /b 1
call :download_auth "https://huggingface.co/google/gemma-3-12b-it/resolve/main/model-00005-of-00005.safetensors?download=true" "%GEMMA_CACHE%\model-00005-of-00005.safetensors"
if errorlevel 1 exit /b 1

set "GEMMA_SHARD_DIR=%GEMMA_CACHE%"
call :resolve_gemma_index "%GEMMA_SHARD_DIR%"
if not defined GEMMA_INDEX_FILE (
  echo.
  echo ERROR: Downloaded Gemma shards but could not find an index JSON file.
  exit /b 1
)

:merge_gemma
call :find_python
if errorlevel 1 exit /b 1

echo.
echo Merging Gemma shard files from:
echo   %GEMMA_SHARD_DIR%
echo Using index:
echo   %GEMMA_INDEX_FILE%
echo This can take a while and requires free disk space.
"%PYTHON_EXE%" %PYTHON_ARGS% "%SCRIPT_DIR%merge_safetensors_shards.py" --index "%GEMMA_INDEX_FILE%" --shard-dir "%GEMMA_SHARD_DIR%" --output "%MODELS_ROOT%\text_encoders\gemma_3_12B_it.safetensors"
if errorlevel 1 (
  echo.
  echo ERROR: Gemma shard merge failed.
  exit /b 1
)
call :ensure_gemma_aliases

:verify_install
set "VERIFY_FAILED=0"
echo.
echo Verifying required workflow model files...
call :verify_exists "%MODELS_ROOT%\checkpoints\ltx-2.3-22b-dev.safetensors" "Checkpoint"
call :verify_exists "%MODELS_ROOT%\checkpoints\ltx-2.3-22b-dev-fp8.safetensors" "Checkpoint FP8"
call :verify_exists "%MODELS_ROOT%\checkpoints\ltx-2.3-22b-distilled-fp8.safetensors" "Distilled Checkpoint FP8"
call :verify_exists "%MODELS_ROOT%\loras\ltx-2.3-22b-distilled-lora-384.safetensors" "Distilled LoRA"
call :verify_exists "%MODELS_ROOT%\loras\ltx-2.3-22b-ic-lora-motion-track-control-ref0.5.safetensors" "Motion Track IC-LoRA"
call :verify_exists "%MODELS_ROOT%\loras\gemma-3-12b-it-abliterated_lora_rank64_bf16.safetensors" "Gemma Abliterated LoRA"
call :verify_exists "%MODELS_ROOT%\upscale_models\ltx-2.3-spatial-upscaler-x2-1.0.safetensors" "LTX Spatial Upscaler"
call :verify_exists "%SUPPORTED_GEMMA_FILE%" "Gemma text encoder"
call :verify_exists "%GEMMA_COMFY_ALIAS%" "Gemma comfy alias"
call :verify_exists "%GEMMA_LEGACY_ALIAS%" "Gemma legacy alias"

:done
echo.
if "%VERIFY_FAILED%"=="0" (
  echo Finished. All required workflow model files are in the correct folders.
) else (
  echo Finished with missing required files. Review the verification output above.
)
echo Open workflow files from:
echo   %SCRIPT_DIR%workflows
echo Base motion-transfer workflow:
echo   %SCRIPT_DIR%LTX-2.3_Image_To_Video_Motion_Transfer.json
echo.
echo Storyboard and waveform workflows require ffmpeg during segment merge.
echo.
if not defined ARG_MODELS_ROOT pause
exit /b 0

:ensure_dir
if not exist "%~1" mkdir "%~1"
exit /b 0

:resolve_gemma_index
set "GEMMA_INDEX_FILE="
if exist "%~1\model.safetensors.index.json" set "GEMMA_INDEX_FILE=%~1\model.safetensors.index.json"
if not defined GEMMA_INDEX_FILE if exist "%~1\gemma-3-12B-it.json" set "GEMMA_INDEX_FILE=%~1\gemma-3-12B-it.json"
exit /b 0

:verify_exists
if exist "%~1" (
  echo   OK     %~2: %~1
) else (
  echo   MISSING %~2: %~1
  set "VERIFY_FAILED=1"
)
exit /b 0

:ensure_gemma_aliases
if not exist "%SUPPORTED_GEMMA_FILE%" exit /b 0

call :replace_incompatible_alias "%GEMMA_COMFY_ALIAS%" "comfy_gemma_3_12B_it.safetensors"
call :replace_incompatible_alias "%GEMMA_LEGACY_ALIAS%" "gemma_3_12B_it.safetensors"

call :create_gemma_alias "%GEMMA_COMFY_ALIAS%"
call :create_gemma_alias "%GEMMA_LEGACY_ALIAS%"
exit /b 0

:replace_incompatible_alias
if not exist "%~1" exit /b 0
for %%I in ("%SUPPORTED_GEMMA_FILE%") do set "SUPPORTED_SIZE=%%~zI"
for %%I in ("%~1") do set "TARGET_SIZE=%%~zI"
if "%SUPPORTED_SIZE%"=="%TARGET_SIZE%" exit /b 0
set "BACKUP_PATH=%~dpn1_raw_google_merged%~x1"
if exist "%BACKUP_PATH%" del "%~1"
if not exist "%BACKUP_PATH%" move "%~1" "%BACKUP_PATH%"
exit /b 0

:create_gemma_alias
if exist "%~1" exit /b 0
mklink /H "%~1" "%SUPPORTED_GEMMA_FILE%" >nul 2>nul
if errorlevel 1 copy /Y "%SUPPORTED_GEMMA_FILE%" "%~1" >nul
exit /b 0

:download_public
set "URL=%~1"
set "DEST=%~2"
if exist "%DEST%" (
  echo Found existing file:
  echo   %DEST%
  exit /b 0
)
echo.
echo Downloading:
echo   %DEST%
curl.exe -L --fail --progress-bar -o "%DEST%" "%URL%"
if errorlevel 1 (
  echo ERROR: Download failed for %DEST%
  exit /b 1
)
exit /b 0

:download_auth
set "URL=%~1"
set "DEST=%~2"
if exist "%DEST%" (
  echo Found existing file:
  echo   %DEST%
  exit /b 0
)
echo.
echo Downloading gated file:
echo   %DEST%
curl.exe -L --fail --progress-bar -H "Authorization: Bearer %HF_TOKEN%" -o "%DEST%" "%URL%"
if errorlevel 1 (
  echo ERROR: Download failed for %DEST%
  echo Make sure the token has access to the Gemma repository.
  exit /b 1
)
exit /b 0

:find_python
set "PYTHON_ARGS="
for %%I in ("%SCRIPT_DIR%..\..\.venv\Scripts\python.exe") do set "PYTHON_EXE=%%~fI"
if exist "%PYTHON_EXE%" exit /b 0
for %%I in ("%SCRIPT_DIR%..\..\python_embeded\python.exe") do set "PYTHON_EXE=%%~fI"
if exist "%PYTHON_EXE%" exit /b 0
where python >nul 2>nul
if not errorlevel 1 (
  set "PYTHON_EXE=python"
  exit /b 0
)
where py >nul 2>nul
if not errorlevel 1 (
  set "PYTHON_EXE=py"
  set "PYTHON_ARGS=-3"
  exit /b 0
)
echo.
echo ERROR: No Python executable was found.
echo Install Python or use the ComfyUI .venv / python_embeded distribution.
exit /b 1