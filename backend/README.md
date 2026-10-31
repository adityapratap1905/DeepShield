# DeepShield backend

FastAPI exposes the existing pretrained photo analysis endpoint and the new FF++ image/video detector. The FF++ route uses one trained image checkpoint for both images and sampled video frames. Raw uploads are not persisted: image bytes are handled in memory, and video uploads use a temporary file under `model/data/tmp_uploads/` that is removed after inference.

## Install and run

Use Python 3.11 or newer. To use the MySQL-backed social API locally, start its database and configure `backend/.env`:

```powershell
cd backend
Copy-Item .env.example .env
docker compose up -d mysql
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Replace `DEEPSHIELD_AUTH_SECRET` in `.env` with the generated value. The sample MySQL username and passwords are for local development only. The API loads `backend/.env` automatically; process environment variables take precedence. If `DEEPSHIELD_DATABASE_URL` is omitted, the API uses the existing SQLite auth database at `backend/data/auth.sqlite3` so an existing local account remains available.

To enable the moderation queue, set `DEEPSHIELD_MODERATOR_EMAILS` to one or more existing account emails separated by commas, then restart the API. The queue is available only to those signed-in accounts.

Install the backend, model, and training/inference dependencies:

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

The SQL schema can also be installed or updated with `python -m alembic upgrade head`. The API initializes any missing tables on startup and seeds the six starter communities once.

The image endpoint returns `503` until `model/artifacts/deepfake_image_best.pt` exists. The video endpoint also requires the validation-calibrated `model/artifacts/deepfake_video_config.json`. `GET /health` reports legacy image, FF++ image, and FF++ video model readiness separately.

## FF++ endpoints

- `POST /api/v2/detect/image` accepts JPEG or PNG using multipart field `file`.
- `POST /api/v2/detect/video` accepts MP4, MOV, AVI, MKV, or WebM using multipart field `file`.

The image result contains `media_type`, `prediction` (`REAL` or `FAKE`), `fake_probability`, `confidence`, and the validation-selected `threshold`, plus face count and model version. The video result has those fields plus `frames_analyzed`, `no_face_frames`, and the validation-selected aggregation method. Confidence is not calibrated and neither prediction proves authenticity.

The API rejects empty, unsupported, oversized, malformed, or corrupted uploads. Videos with fewer than the configured minimum number of decodable sampled frames return `422`. The default upload limits are 15 MB for images and 200 MB for videos; override them with `DEEPSHIELD_MAX_IMAGE_BYTES` and `DEEPSHIELD_MAX_VIDEO_BYTES`. Set `DEEPSHIELD_VIDEO_TEMP_DIR` to place temporary video files on another volume.

## Authentication and social API

The Flutter app uses `POST /api/v1/auth/register` and `POST /api/v1/auth/login`. Accounts are stored in MySQL when `DEEPSHIELD_DATABASE_URL` is set; otherwise the SQLite database at `backend/data/auth.sqlite3` is used. Passwords use PBKDF2-SHA256 with a random per-account salt. Successful requests return a signed bearer token. `GET /api/v1/auth/me` checks a bearer token, `POST /api/v1/auth/refresh` rotates it, and `POST /api/v1/auth/logout` revokes it.

Social endpoints require the same bearer token:

- Profiles: `GET/PATCH /api/v1/profiles/me`, `GET/PATCH /api/v1/profiles/me/settings`, `GET /api/v1/profiles/me/posts`, `GET /api/v1/profiles/me/communities`, `POST/DELETE /api/v1/profiles/me/avatar`, authenticated `GET /api/v1/profiles/{user_id}/avatar`, `POST /api/v1/profiles/me/password`, `GET /api/v1/profiles/{user_id}`, `GET /api/v1/users/search?q=...`.
- Posts and feeds: `GET /api/v1/social/feed?feed=for_you|following|trending`, `POST /api/v1/social/posts`, `GET/DELETE /api/v1/social/posts/{id}`.
- Engagement: `POST/DELETE /api/v1/social/posts/{id}/like`, `POST/DELETE /api/v1/social/posts/{id}/bookmark`, `GET/POST /api/v1/social/posts/{id}/comments` (send `parent_comment_id` for a reply), `DELETE /api/v1/social/comments/{id}`, `GET /api/v1/social/bookmarks`.
- Following: `POST/DELETE /api/v1/users/{user_id}/follow`.
- Blocking: `POST/DELETE /api/v1/users/{user_id}/block`, `GET /api/v1/users/blocked`.
- Moderation (moderator allowlist only): `GET /api/v1/moderation/reports?status=open|dismissed|actioned`, `POST /api/v1/moderation/reports/{report_id}/review` with `dismiss` or `remove_content`.
- Communities: `GET/POST /api/v1/communities`, `POST/DELETE /api/v1/communities/{id}/join`, `GET /api/v1/communities/{id}/feed?sort=latest|popular`.
- Notifications: `GET /api/v1/notifications`, `POST /api/v1/notifications/{id}/read`.

The social API stores text posts, profile details, reactions, threaded comments, follows, community membership, social notifications, account preferences, and scan summaries linked to posts. Replies are one level deep and must belong to the same post as their parent comment. Authenticated users can search post captions with `GET /api/v1/social/search?q=...`, report posts/comments, and block/unblock users; blocked creators are filtered from feeds and search. Account preferences control whether a creator appears in search and whether in-app like/comment/follow notifications are created. Writes use database-backed per-user rate limits: 10 posts/minute, 30 comments/minute, 8 media uploads/minute, 6 scan shares/5 minutes, 10 reports/hour, 20 block actions/hour, and 5 avatar uploads/5 minutes. A post can include one JPG/PNG image (up to 15 MB) or MP4/MOV/AVI/MKV/WebM video (up to 50 MB); uploads are kept under the private media directory and served by authenticated endpoints. The Flutter feed previews images and plays compatible videos inline and shares post text/media through the device share sheet. The Flutter scan-share flow uploads the original source file after the user explicitly chooses to share the report and media. Profile photos are private authenticated uploads, and signed-in users can change their password after confirming the current one. Allowlisted moderators can review reports and dismiss them or remove the reported post/comment. Email-backed password reset is pending.

Retain the database and signing secret to preserve accounts and sessions. Use HTTPS and a private long random secret for deployments. Email password reset is not implemented; the app reports this instead of claiming an email was sent.

Example requests:

```powershell
curl.exe -X POST http://127.0.0.1:8000/api/v2/detect/image -F "file=@photo.jpg"
curl.exe -X POST http://127.0.0.1:8000/api/v2/detect/video -F "file=@clip.mp4"
```

Override model files with `DEEPSHIELD_FFPP_IMAGE_MODEL_PATH` and `DEEPSHIELD_FFPP_VIDEO_CONFIG_PATH`. The YuNet path uses `DEEPSHIELD_FACE_DETECTOR_PATH`.

## Existing photo endpoint

The existing `POST /api/v1/scan/image` remains backed by the preserved Community Forensics and face-manipulation ONNX models. It returns separate AI-generation and face-manipulation signals and is not the FF++ `REAL`/`FAKE` classifier. Its model files are downloaded with `python ../model/scripts/download_pretrained.py`.

The Flutter client continues to use the existing photo endpoint; social post content does not change either scan pipeline. The separate Flask dashboard remains independent.

## Android emulator and CORS

The Flutter app defaults to `http://10.0.2.2:8000/api/v1` on Android and `http://127.0.0.1:8000/api/v1` on web, iOS simulators, and desktop. For a USB-connected Android phone, run `adb reverse tcp:8000 tcp:8000` and pass `--dart-define=DEEPSHIELD_API_BASE_URL=http://127.0.0.1:8000/api/v1`. For a physical iPhone or another host, use the computer's LAN address.

For browser clients, configure allowed origins with comma-separated `DEEPSHIELD_CORS_ORIGINS`. Local HTTP and broad host binding are for development only; deploy behind HTTPS and restrict CORS in production.
