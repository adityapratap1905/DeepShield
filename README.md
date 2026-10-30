# DeepShield

DeepShield analyzes potentially manipulated photos and videos. The repository keeps the Flutter client, FastAPI backend, model pipeline, and standalone browser dashboard in separate top-level folders.

## Repository structure

- [`mobile_app/`](mobile_app/): Flutter client for photo analysis and sampled-frame video detection.
- [`backend/`](backend/): FastAPI upload API, including the existing pretrained photo analysis route and the FF++ image/video routes.
- [`model/`](model/): preserved pretrained ONNX models plus the FaceForensics++ C23 frame preparation, training, evaluation, and inference pipeline.
- [`web_app/`](web_app/): standalone Flask image dashboard. `mobile_app/web/` is Flutter platform support, not that dashboard.
- [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md): shared architecture and workflow notes.

## Model status and setup

The new pipeline trains one frame-level image detector using the official FaceForensics++ video splits, then analyzes sampled video frames with validation-calibrated aggregation. Raw videos, processed frames, and model weights are local artifacts and are excluded from Git. Experiment comparisons and metrics are written under `model/reports/`. No metrics should be reported until the corresponding training or evaluation command has produced them.

Start with [`model/README.md`](model/README.md) for the official v4 EU2 C23 download, source-separated preparation, image model comparison, video aggregation calibration, test evaluation, and local inference commands. The existing pretrained ONNX models and their licenses are listed in [`model/THIRD_PARTY_MODEL.md`](model/THIRD_PARTY_MODEL.md).

The backend setup and endpoints are documented in [`backend/README.md`](backend/README.md). The FF++ endpoints need a trained image checkpoint and a video config calibrated on validation videos. Until those artifacts exist, they report that the model is unavailable. The legacy photo route remains a separate pretrained ONNX analysis.

The standalone dashboard setup and upload flow are documented in [`web_app/README.md`](web_app/README.md). Its bundled Keras model is a separate binary classifier; its training provenance is not documented here, so no performance claims are made for it.
