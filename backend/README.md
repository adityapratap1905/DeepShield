# DeepShield backend

FastAPI service that validates uploaded JPEG/PNG photos and analyzes them with two pretrained ONNX classifiers. The first estimates AI-generation signals across the image. The second analyzes detected face crops for face-manipulation signals, including some face swaps. The application does not persist uploaded photos; the multipart parser may temporarily spool uploads while handling the request. Neither classifier establishes image authenticity or detects every kind of edit.

## Run locally

Use Python 3.11 or newer. From this directory, create a virtual environment and install dependencies:

```powershell
py -3 -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python ../model/scripts/download_pretrained.py
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API docs are available at `http://127.0.0.1:8000/docs`. `GET /health` reports whether both classifiers loaded. `POST /api/v1/scan/image` accepts multipart form data with a `file` field and returns separate AI-generation and face-manipulation results and scores in `extra_data`. The face score is `null` when no face is detected; that check was not run. YuNet uses a 0.65 detection-confidence threshold; the response includes that threshold. OpenCV and ONNX Runtime are installed through the model package dependency.

The default paths are `../model/artifacts/community_forensics/model.onnx`, `../model/artifacts/face_swap/deepfake_hybrid_final.onnx`, and `../model/artifacts/face_swap/yunet.onnx`. Override them with `DEEPSHIELD_MODEL_PATH`, `DEEPSHIELD_FACE_MODEL_PATH`, and `DEEPSHIELD_FACE_DETECTOR_PATH`. For browser clients, configure allowed origins with comma-separated `DEEPSHIELD_CORS_ORIGINS`.

## Connect the Android emulator

The Flutter app defaults to `http://127.0.0.1:8000/api/v1`. For a USB-connected physical phone, keep USB debugging enabled and run this from a terminal after connecting the phone:

```powershell
adb reverse tcp:8000 tcp:8000
```

Then run the app normally from Android Studio. For an Android emulator, override the URL to its host route:

```powershell
flutter run --dart-define=DEEPSHIELD_API_BASE_URL=http://10.0.2.2:8000/api/v1
```

For a phone connected over Wi-Fi instead of USB, pass the computer's reachable LAN IP and keep both devices on the same network. Local HTTP and broad host binding are for development only; deploy behind HTTPS and restrict CORS before production use.

For an iOS simulator, override the URL to `http://localhost:8000/api/v1`. For a physical iOS device, use the same LAN-address override as a physical Android phone.
