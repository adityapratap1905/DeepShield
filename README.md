# DeepShield Social

DeepShield Social combines community discussions and digital safety education with the existing image and video analysis pipelines. The repository keeps the Flutter client, FastAPI backend, model pipeline, and standalone browser dashboard in separate top-level folders.

## Repository structure

- [`mobile_app/`](mobile_app/): Flutter client for community feeds, profiles, learning guides, photo analysis, and sampled-frame video detection.
- [`backend/`](backend/): FastAPI social API and upload/inference API, including preserved pretrained photo analysis and FF++ image/video routes.
- [`model/`](model/): preserved pretrained ONNX models plus the FaceForensics++ C23 frame preparation, training, evaluation, and inference pipeline.
- [`web_app/`](web_app/): standalone Flask image dashboard. `mobile_app/web/` is Flutter platform support, not that dashboard.
- [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md): shared architecture and workflow notes.

## Model status and setup

The new pipeline trains one frame-level image detector using the official FaceForensics++ video splits, then analyzes sampled video frames with validation-calibrated aggregation. Raw videos, processed frames, and model weights are local artifacts and are excluded from Git. Experiment comparisons and metrics are written under `model/reports/`. No metrics should be reported until the corresponding training or evaluation command has produced them.

Start with [`model/README.md`](model/README.md) for the official v4 EU2 C23 download, source-separated preparation, image model comparison, video aggregation calibration, test evaluation, and local inference commands. The existing pretrained ONNX models and their licenses are listed in [`model/THIRD_PARTY_MODEL.md`](model/THIRD_PARTY_MODEL.md).

The backend setup and endpoints are documented in [`backend/README.md`](backend/README.md). The FF++ endpoints need a trained image checkpoint and a video config calibrated on validation videos. Until those artifacts exist, they report that the model is unavailable. The legacy photo route remains a separate pretrained ONNX analysis.

The standalone dashboard setup and upload flow are documented in [`web_app/README.md`](web_app/README.md). Its bundled Keras model is a separate binary classifier; its training provenance is not documented here, so no performance claims are made for it.

DeepShield Social's current API-backed slice includes text and image/video posts, feed filters, comments, likes, bookmarks, follows, editable profiles, starter communities, notifications, search, post sharing, scan-report sharing, reports, blocking, and an allowlisted moderation queue. Social media is stored privately and served only to authenticated users; each post allows one attachment (images up to 15 MB, videos up to 50 MB). Feed sharing passes the selected post text and attachment to the device share sheet. Sharing a scan report attaches the original scan file after the user explicitly chooses to share it. Run MySQL locally with `docker compose up -d mysql` from `backend/`; copy `backend/.env.example` to `backend/.env` and set a private `DEEPSHIELD_AUTH_SECRET`. See [`backend/README.md`](backend/README.md) for setup and current implementation limits.
