# DeepShield backend

FastAPI exposes the existing pretrained photo analysis endpoint and the new FF++ image/video detector. The FF++ route uses one trained image checkpoint for both images and sampled video frames. Raw uploads are not persisted: image bytes are handled in memory, and video uploads use a temporary file under `model/data/tmp_uploads/` that is removed after inference.

## Install and run

Use Python 3.11 or newer. Install the backend, model, and training/inference dependencies:

```powershell
cd backend
py -3 -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
python -m pip install -r requirements.txt
python ../model/scripts/download_pretrained.py
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The example installs CPU-only PyTorch. For a CUDA machine, choose the matching PyTorch and TorchVision command in the [official PyTorch installer](https://pytorch.org/get-started/locally/) before installing `requirements.txt`.

The image endpoint returns `503` until `model/artifacts/deepfake_image_best.pt` exists. The video endpoint also requires the validation-calibrated `model/artifacts/deepfake_video_config.json`. `GET /health` reports legacy image, FF++ image, and FF++ video model readiness separately.

## FF++ endpoints

- `POST /api/v2/detect/image` accepts JPEG or PNG using multipart field `file`.
- `POST /api/v2/detect/video` accepts MP4, MOV, AVI, MKV, or WebM using multipart field `file`.

The image result contains `media_type`, `prediction` (`REAL` or `FAKE`), `fake_probability`, `confidence`, and the validation-selected `threshold`, plus face count and model version. The video result has those fields plus `frames_analyzed`, `no_face_frames`, and the validation-selected aggregation method. Confidence is not calibrated and neither prediction proves authenticity.

The API rejects empty, unsupported, oversized, malformed, or corrupted uploads. Videos with fewer than the configured minimum number of decodable sampled frames return `422`. The default upload limits are 15 MB for images and 200 MB for videos; override them with `DEEPSHIELD_MAX_IMAGE_BYTES` and `DEEPSHIELD_MAX_VIDEO_BYTES`. Set `DEEPSHIELD_VIDEO_TEMP_DIR` to place temporary video files on another volume.

Example requests:

```powershell
curl.exe -X POST http://127.0.0.1:8000/api/v2/detect/image -F "file=@photo.jpg"
curl.exe -X POST http://127.0.0.1:8000/api/v2/detect/video -F "file=@clip.mp4"
```

Override model files with `DEEPSHIELD_FFPP_IMAGE_MODEL_PATH` and `DEEPSHIELD_FFPP_VIDEO_CONFIG_PATH`. The YuNet path uses `DEEPSHIELD_FACE_DETECTOR_PATH`.

## Existing photo endpoint

The existing `POST /api/v1/scan/image` remains backed by the preserved Community Forensics and face-manipulation ONNX models. It returns separate AI-generation and face-manipulation signals and is not the FF++ `REAL`/`FAKE` classifier. Its model files are downloaded with `python ../model/scripts/download_pretrained.py`.

The Flutter client continues to use the existing photo endpoint; the Flutter and web interfaces were not redesigned as part of this model pipeline work.

## Android emulator and CORS

The Flutter app defaults to `http://127.0.0.1:8000/api/v1`. For a USB-connected phone, run `adb reverse tcp:8000 tcp:8000`. Android emulators can use `DEEPSHIELD_API_BASE_URL=http://10.0.2.2:8000/api/v1`.

For browser clients, configure allowed origins with comma-separated `DEEPSHIELD_CORS_ORIGINS`. Local HTTP and broad host binding are for development only; deploy behind HTTPS and restrict CORS in production.
