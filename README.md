# DeepShield

DeepShield is a project to detect potentially manipulated or AI-generated photos and videos and help people assess media before sharing it. The first focus is a Flutter mobile app; a separate browser dashboard is planned for later.

## Repository structure

- [`mobile_app/`](mobile_app/): Flutter mobile client and its platform folders.
- [`backend/`](backend/): FastAPI photo upload and inference API.
- [`model/`](model/): pretrained ONNX image and face-manipulation classifiers, face detector, download script, and optional ResNet-18 training pipeline.
- [`web_app/`](web_app/): planned browser dashboard.
- [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md): shared project context and workflow notes.

The `mobile_app/web/` folder is generated as part of Flutter's platform support. It is not the separate `web_app/` dashboard.

## Current status

The Flutter photo scan uploads to the FastAPI service in `backend/`, which runs pinned pretrained models without requiring a user-supplied dataset. It estimates AI-generation signals and checks detected face crops for face-manipulation signals, including some swaps. These outputs cannot prove authenticity or detect every edit. Model files are downloaded locally by the setup script and are excluded from Git. See [backend setup](backend/README.md) and [model details](model/README.md).
# DeepShield
