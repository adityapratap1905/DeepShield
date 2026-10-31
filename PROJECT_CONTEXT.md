# DeepShield project context

Read this file before making project changes. Keep it current when the project purpose, architecture, major features, dependencies, or workflow change.

## Project goal

DeepShield aims to detect potentially manipulated or AI-generated photos and videos so people can assess media before sharing it and reduce misinformation. Development starts with the Flutter mobile app. A backend and ML model/inference service will support analysis, and a separate browser dashboard is planned later.

## Monorepo layout

- `mobile_app/`: Flutter mobile client. Its `web/` directory is Flutter's platform runner, not the separate browser dashboard.
- `backend/`: FastAPI photo upload/inference API with the existing ONNX photo route and FF++ image/video detection routes. Uploaded videos are stored temporarily for decoding and removed after inference.
- `model/`: pinned pretrained Community Forensics and face-manipulation ONNX classifiers, YuNet face detector, FaceForensics++ C23 preparation, image training/evaluation, video aggregation, and inference scripts. Model weights, raw videos, and processed frames stay local and are not committed.
- `web_app/`: standalone Flask image dashboard using the separately bundled Keras binary classifier. Its training provenance is not documented; do not make performance or authenticity claims for it. Setup is in `web_app/README.md`.
- `PROJECT_CONTEXT.md`: shared project orientation.

## Current state

- Product UI is being transformed to DeepShield Social: the Flutter shell has Home, Explore, Scan, Learn, and Profile tabs with a light blue/white theme. Home and community feeds use authenticated API calls. Explore includes API-backed creator search/follow and community join; Learn uses bundled educational guides. The separate Flask dashboard and all scan model paths remain independent.
- FastAPI social APIs now persist text posts, profile names/bios, feed filters, likes, bookmarks, comments, follows, community memberships, notifications, and scan summaries linked to published posts using SQLAlchemy. Configure `DEEPSHIELD_DATABASE_URL` to use MySQL; the default SQLite file remains the local fallback and preserves the earlier auth account database. MySQL local setup is in `backend/docker-compose.yml`; `backend/.env` is ignored by Git.
- Social posts now support one private, authenticated image or video attachment per post, with API-backed previews in the Flutter home and community feeds. Sharing a completed scan report attaches the original local scan file to its linked post after the user taps the explicit share action. Profiles support server-backed photos and password changes. Posts/comments can be reported; users can block creators from post menus and manage blocked accounts in Settings. Authenticated writes have database-backed rate limits. Allowlisted moderators can review and resolve reports from Settings. Email-backed password reset is pending.

- The mobile app uses Flutter/Dart, Riverpod, GoRouter, and Dio. Photo selection supports JPG and PNG and can capture from the camera; video selection supports MP4, MOV, AVI, MKV, and WebM and can record from the camera. Photo scans call `POST /api/v1/scan/image`.
- The backend has a health endpoint at `/health`. The legacy photo route requires the AI-generation ONNX model, the face-manipulation ONNX model and external weights, and the YuNet face detector. Download the pinned ONNX artifacts with `python model/scripts/download_pretrained.py`.
- Email/password authentication is served by `/api/v1/auth/{register,login,me,logout}`. SQLite accounts default to `backend/data/auth.sqlite3`, anchored to the backend source path, and require a stable `DEEPSHIELD_AUTH_SECRET`.
- The new FF++ pipeline uses only official FaceForensics++ C23 `Original`, `Deepfakes`, `Face2Face`, `FaceSwap`, and `NeuralTextures` videos. It loads the official train/validation/test split JSON, assigns both IDs of each manipulated sequence to one split, and rejects cross-split pairs before frame extraction. Never split extracted frames randomly.
- `python model/scripts/prepare_ffpp.py` discovers the dataset by its folder structure, samples a small even spread of frames per video, writes padded face crops and full-frame comparison images, and records source-video, manipulation, split, frame, and face metadata. Raw and processed data are ignored by Git.
- `python model/scripts/train.py` compares ImageNet-initialized ResNet-18 and EfficientNet-B0; it attempts ConvNeXt-Tiny only when CUDA is available. `python model/scripts/select_image_model.py` selects the final checkpoint using validation results only. The image threshold is also selected from validation data only.
- `python model/scripts/evaluate_video.py --split val` compares mean, median, top-k mean, and percentage-fake aggregation using validation videos, then saves the selected video aggregation and threshold. `--split test` evaluates those frozen choices on held-out test videos. A temporal model is not included unless resources and validation results justify it.
- `model/artifacts/deepfake_image_best.pt` and `model/artifacts/deepfake_video_config.json` are produced by the training/calibration commands. The FF++ backend routes return `503` when their required trained artifact is missing. The existing `/api/v1/scan/image` route remains available for the separate pretrained ONNX signals; `/api/v2/detect/image` and `/api/v2/detect/video` provide the FF++ `REAL`/`FAKE` interface.
- Each photo scan returns separate whole-image AI-generation and face-manipulation check results, plus scores. The AI model does not identify the source service (such as ChatGPT). The face classifier includes synthetic faces as well as multiple face-swap methods, so its result is a manipulation signal, not proof of a specific swap. YuNet uses a 0.65 confidence threshold; small, obscured, or low-quality faces may still be missed. No detected face means that check was not run. Neither model proves authenticity; scores are not calibrated probabilities and can fail outside their evaluation data.
- The optional ResNet-18 training script expects source-separated `train/`, `val/`, and `test/` folders with `fake/` and `real/` classes. It trains on train/val and saves a checkpoint plus validation metrics. This experimental training pipeline is separate from the pretrained ONNX models used by the backend.
- The mobile home screen is a social feed; photo/video scans remain accessible from the prominent Scan tab and retain their current backend pipelines. URL and QR scanning are not implemented and are marked unavailable. Photo upload shows the selected file and size, and analysis uses real upload progress with retry guidance. Auth is backend-backed; the splash screen validates saved tokens. Sign out now routes directly to login. Scan history and scan counts remain local to the device. Notifications are server-backed for likes, comments, and follows. Exportable reports still show honest empty states. Profile scan counts come from local history; do not interpret them as safety statistics.
- The mobile client supports JPG/PNG photo uploads through `/api/v1/scan/image` and MP4/MOV/AVI/MKV/WebM video uploads through `/api/v2/detect/video`. The UI presents video results as sampled-frame estimates and does not treat a `REAL` label as proof of authenticity.
- The standalone browser dashboard is still planned. Pretrained and trained model artifacts are ignored by Git and must be downloaded or trained separately on each machine.

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

Run the API using `backend/README.md`; dataset, training, evaluation, and local inference instructions are in `model/README.md`. Flutter defaults to `http://10.0.2.2:8000/api/v1` on Android and `http://127.0.0.1:8000/api/v1` on web, iOS simulators, and desktop. Override with `DEEPSHIELD_API_BASE_URL` for physical devices.

When a change affects a folder's purpose, architecture, actual-vs-demo behavior, or setup, update this context and the relevant README. Keep claims tied to the current code and be clear whenever analysis is still mock.
