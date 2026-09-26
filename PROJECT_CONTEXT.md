# DeepShield project context

Read this file before making project changes. Keep it current when the project purpose, architecture, major features, dependencies, or workflow change.

## Project goal

DeepShield aims to detect potentially manipulated or AI-generated photos and videos so people can assess media before sharing it and reduce misinformation. Development starts with the Flutter mobile app. A backend and ML model/inference service will support analysis, and a separate browser dashboard is planned later.

## Monorepo layout

- `mobile_app/`: Flutter mobile client. Its `web/` directory is Flutter's platform runner, not the separate browser dashboard.
- `backend/`: FastAPI photo upload/inference API. It validates JPEG/PNG uploads and runs an AI-generation classifier plus a face-crop manipulation classifier using ONNX Runtime and YuNet face detection.
- `model/`: pinned pretrained Community Forensics and face-manipulation ONNX classifiers, YuNet face detector, download script, and optional ResNet-18 training pipeline. The model weights and training data are not committed. Avoid committing model artifacts or datasets.
- `web_app/`: planned standalone browser dashboard.
- `PROJECT_CONTEXT.md`: shared project orientation.

## Current state

- The mobile app uses Flutter/Dart, Riverpod, GoRouter, and Dio. Photo selection supports JPG and PNG; photo scans call `POST /api/v1/scan/image`.
- The backend has a health endpoint at `/health`. It requires the AI-generation ONNX model, the face-manipulation ONNX model and external weights, and the YuNet face detector. Download all pinned artifacts with `python model/scripts/download_pretrained.py`. The backend does not require a user-supplied dataset.
- Each photo scan returns separate whole-image AI-generation and face-manipulation check results, plus scores. The AI model does not identify the source service (such as ChatGPT). The face classifier includes synthetic faces as well as multiple face-swap methods, so its result is a manipulation signal, not proof of a specific swap. YuNet uses a 0.65 confidence threshold; small, obscured, or low-quality faces may still be missed. No detected face means that check was not run. Neither model proves authenticity; scores are not calibrated probabilities and can fail outside their evaluation data.
- The optional ResNet-18 training script expects source-separated `train/`, `val/`, and `test/` folders with `fake/` and `real/` classes. It trains on train/val and saves a checkpoint plus validation metrics. This experimental training pipeline is separate from the pretrained ONNX models used by the backend.
- Video analysis is planned after the photo flow has a trained and evaluated model.
- The mobile home screen keeps the existing emerald/glass visual style and centers on photo checks without fabricated safety scores or recent scans. Photo upload shows the selected file and size, and the analysis screen uses real upload progress with retry guidance on errors. Auth, history, and notifications still include local/demo data; photo scans return both pretrained model outputs when the backend is running and all model artifacts have been downloaded.
- No project training dataset or browser dashboard implementation exists yet. Pretrained model artifacts are ignored by Git and must be downloaded separately on a new machine.

## Working on the mobile app

Run Flutter commands from `mobile_app/`:

```sh
cd mobile_app
flutter pub get
flutter run
flutter analyze
flutter test
```

For Android Studio or another Flutter IDE, open `mobile_app/` as the Flutter project root (the directory containing `pubspec.yaml`), not the monorepo root. The Android Gradle configuration uses a 2 GB heap and one worker for lower-memory Windows builds, and disables Kotlin incremental compilation to avoid stale cross-drive caches after moving the app into the monorepo. Gradle can reuse unchanged task outputs on later runs, but changed Kotlin sources will compile without incremental mode. If Dart reports out of memory or Gradle reports insufficient disk space on Windows, check committed memory and free space on `C:` (Flutter/Gradle caches and the paging file are there), then close unused IDE/browser or development processes before retrying.

Run the API using `backend/README.md`; optional training instructions are in `model/README.md`. The Flutter app defaults to `http://127.0.0.1:8000/api/v1`; for a USB-connected Android phone, run `adb reverse tcp:8000 tcp:8000`. Android emulators use `http://10.0.2.2:8000/api/v1` through `DEEPSHIELD_API_BASE_URL`.

When a change affects a folder's purpose, architecture, actual-vs-demo behavior, or setup, update this context and the relevant README. Keep claims tied to the current code and be clear whenever analysis is still mock.
