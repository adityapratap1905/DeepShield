"""DeepShield photo analysis API."""

from __future__ import annotations

import logging
import os
import tempfile
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path
from dataclasses import asdict
from uuid import uuid4

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, UnidentifiedImageError
from starlette.concurrency import run_in_threadpool
try:
    from .auth import router as auth_router
    from .database import initialize_database
    from .social import router as social_router
except ImportError:  # Support running as `uvicorn main:app` from backend/app.
    from auth import router as auth_router
    from database import initialize_database
    from social import router as social_router

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger("deepshield.api")

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MODEL_PATH = (
    REPOSITORY_ROOT / "model" / "artifacts" / "community_forensics" / "model.onnx"
)
MODEL_PATH = Path(os.getenv("DEEPSHIELD_MODEL_PATH", str(DEFAULT_MODEL_PATH)))
FACE_MODEL_PATH = Path(
    os.getenv(
        "DEEPSHIELD_FACE_MODEL_PATH",
        str(REPOSITORY_ROOT / "model" / "artifacts" / "face_swap" / "deepfake_hybrid_final.onnx"),
    )
)
FACE_DETECTOR_PATH = Path(
    os.getenv(
        "DEEPSHIELD_FACE_DETECTOR_PATH",
        str(REPOSITORY_ROOT / "model" / "artifacts" / "face_swap" / "yunet.onnx"),
    )
)
MAX_UPLOAD_BYTES = int(os.getenv("DEEPSHIELD_MAX_IMAGE_BYTES", str(15 * 1024 * 1024)))
MAX_VIDEO_UPLOAD_BYTES = int(os.getenv("DEEPSHIELD_MAX_VIDEO_BYTES", str(200 * 1024 * 1024)))
MAX_IMAGE_PIXELS = 40_000_000
FFPP_IMAGE_CHECKPOINT_PATH = Path(
    os.getenv(
        "DEEPSHIELD_FFPP_IMAGE_MODEL_PATH",
        str(REPOSITORY_ROOT / "model" / "artifacts" / "deepfake_image_best.pt"),
    )
)
FFPP_VIDEO_CONFIG_PATH = Path(
    os.getenv(
        "DEEPSHIELD_FFPP_VIDEO_CONFIG_PATH",
        str(REPOSITORY_ROOT / "model" / "artifacts" / "deepfake_video_config.json"),
    )
)
VIDEO_UPLOAD_TEMP_DIR = Path(
    os.getenv("DEEPSHIELD_VIDEO_TEMP_DIR", str(REPOSITORY_ROOT / "model" / "data" / "tmp_uploads"))
)
SUPPORTED_VIDEO_SUFFIXES = {".mp4", ".mov", ".avi", ".mkv", ".webm"}
Image.MAX_IMAGE_PIXELS = MAX_IMAGE_PIXELS


@asynccontextmanager
async def lifespan(app: FastAPI):
    initialize_database()
    app.state.classifier = None
    app.state.face_classifier = None
    app.state.model_error = None
    app.state.deepfake_image_classifier = None
    app.state.deepfake_video_analyzer = None
    app.state.deepfake_model_error = None

    missing_paths = [
        path
        for path in (MODEL_PATH, FACE_MODEL_PATH, FACE_DETECTOR_PATH)
        if not path.is_file()
    ]
    if missing_paths:
        app.state.model_error = (
            "One or more pretrained image models are missing. Run "
            "python ../model/scripts/download_pretrained.py from the backend folder."
        )
        logger.warning("Photo analysis is unavailable: %s (%s)", app.state.model_error, missing_paths)
    else:
        try:
            from deepshield_model.community_forensics import CommunityForensicsClassifier
            from deepshield_model.face_manipulation import FaceManipulationClassifier

            app.state.classifier = CommunityForensicsClassifier(MODEL_PATH)
            app.state.face_classifier = FaceManipulationClassifier(
                FACE_MODEL_PATH, FACE_DETECTOR_PATH
            )
            logger.info("Loaded %s from %s", app.state.classifier.model_version, MODEL_PATH)
            logger.info("Loaded %s from %s", app.state.face_classifier.model_version, FACE_MODEL_PATH)
        except Exception:
            app.state.model_error = "The configured pretrained photo models could not be loaded."
            logger.exception("Pretrained photo analysis is unavailable")

    if not FACE_DETECTOR_PATH.is_file():
        app.state.deepfake_model_error = (
            "The YuNet face detector is missing. Run python model/scripts/download_pretrained.py."
        )
    elif not FFPP_IMAGE_CHECKPOINT_PATH.is_file():
        app.state.deepfake_model_error = (
            "The FF++ image checkpoint is not available yet. Train and select it with "
            "model/scripts/train.py and model/scripts/select_image_model.py."
        )
    else:
        try:
            from deepshield_model.multimedia_inference import DeepfakeImageClassifier

            app.state.deepfake_image_classifier = DeepfakeImageClassifier(
                FFPP_IMAGE_CHECKPOINT_PATH, FACE_DETECTOR_PATH
            )
            logger.info(
                "Loaded %s from %s",
                app.state.deepfake_image_classifier.model_version,
                FFPP_IMAGE_CHECKPOINT_PATH,
            )
            if FFPP_VIDEO_CONFIG_PATH.is_file():
                from deepshield_model.multimedia_inference import DeepfakeVideoAnalyzer

                app.state.deepfake_video_analyzer = DeepfakeVideoAnalyzer(
                    app.state.deepfake_image_classifier, FFPP_VIDEO_CONFIG_PATH
                )
            else:
                app.state.deepfake_model_error = (
                    "The FF++ image model is loaded, but the validation-calibrated video configuration "
                    "is missing. Run model/scripts/evaluate_video.py --split val."
                )
        except Exception:
            app.state.deepfake_model_error = "The configured FF++ model could not be loaded."
            logger.exception("FF++ image/video analysis is unavailable")
    yield


app = FastAPI(
    title="DeepShield Social API",
    version="0.2.0",
    description=(
        "AI-generation and face-manipulation signals for photos, with optional "
        "FaceForensics++ image and sampled-video deepfake detection."
    ),
    lifespan=lifespan,
)
app.include_router(auth_router)
app.include_router(social_router)

cors_origins = [
    origin.strip()
    for origin in os.getenv(
        "DEEPSHIELD_CORS_ORIGINS", "http://localhost:3000,http://localhost:5173"
    ).split(",")
    if origin.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, object]:
    classifier = app.state.classifier
    face_classifier = app.state.face_classifier
    return {
        "status": "ok" if classifier is not None and face_classifier is not None else "model_unavailable",
        "model_loaded": classifier is not None and face_classifier is not None,
        "model_version": classifier.model_version if classifier is not None else None,
        "face_model_version": face_classifier.model_version if face_classifier is not None else None,
        "model_task": "ai_generated_image_detection",
        "face_model_task": "face_manipulation_detection",
        "model_error": app.state.model_error,
        "ffpp_image_model_loaded": app.state.deepfake_image_classifier is not None,
        "ffpp_video_model_loaded": app.state.deepfake_video_analyzer is not None,
        "ffpp_image_model_version": (
            app.state.deepfake_image_classifier.model_version
            if app.state.deepfake_image_classifier is not None else None
        ),
        "ffpp_model_error": app.state.deepfake_model_error,
    }


@app.post("/api/v1/scan/image")
async def scan_image(file: UploadFile = File(...)) -> dict[str, object]:
    classifier = app.state.classifier
    face_classifier = app.state.face_classifier
    if classifier is None or face_classifier is None:
        raise HTTPException(
            status_code=503,
            detail=app.state.model_error or "The image detector is not ready.",
        )

    started_at = time.perf_counter()
    contents = await file.read(MAX_UPLOAD_BYTES + 1)
    if not contents:
        raise HTTPException(status_code=400, detail="The uploaded file is empty.")
    if len(contents) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Image exceeds the {MAX_UPLOAD_BYTES // (1024 * 1024)} MB upload limit.",
        )

    try:
        with Image.open(BytesIO(contents)) as image:
            if image.format not in {"JPEG", "PNG"}:
                raise HTTPException(status_code=415, detail="Only JPEG and PNG photos are supported.")
            if image.width * image.height > MAX_IMAGE_PIXELS:
                raise HTTPException(status_code=413, detail="Image dimensions are too large.")
            image.verify()
    except HTTPException:
        raise
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError) as exc:
        raise HTTPException(status_code=400, detail="The uploaded photo is invalid or unreadable.") from exc
    try:
        prediction = await run_in_threadpool(classifier.predict, contents)
        face_prediction = await run_in_threadpool(face_classifier.predict, contents)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    is_ai_generated = prediction.prediction == "ai_generated"
    has_face_manipulation_signal = face_prediction.prediction == "face_manipulation_signal"
    any_manipulation_signal = is_ai_generated or has_face_manipulation_signal
    threat_level = (
        "high"
        if any_manipulation_signal
        else "low"
        if face_prediction.faces_analyzed > 0
        else "medium"
    )
    filename = Path((file.filename or "photo").replace("\\", "/").rsplit("/", 1)[-1]).name
    duration_ms = round((time.perf_counter() - started_at) * 1000)
    return {
        "id": str(uuid4()),
        "scan_type": "file",
        "target": filename,
        "threat_level": threat_level,
        "confidence_score": prediction.ai_generated_probability,
        # A non-generated estimate cannot establish that an image is authentic.
        "is_safe": False,
        "reasons": [
            "The detector estimates this image is AI-generated."
            if is_ai_generated
            else "The detector found no strong AI-generation signal in this image.",
            "A face crop received a face-manipulation signal."
            if has_face_manipulation_signal
            else "The face model found no strong manipulation signal in the analyzed face crops."
            if face_prediction.faces_analyzed > 0
            else "No face was detected, so the face-manipulation check could not run.",
        ],
        "recommendation": (
            "These are automated model estimates, not proof of authenticity. Face analysis only covers "
            "the detected face crops and may miss unfamiliar manipulations. Check the original source "
            "and other evidence before sharing."
        ),
        "scan_duration_ms": duration_ms,
        "scanned_at": datetime.now(timezone.utc).isoformat(),
        "extra_data": {
            "prediction": prediction.prediction,
            "ai_generated_probability": prediction.ai_generated_probability,
            "decision_threshold": prediction.threshold,
            "model_version": prediction.model_version,
            "model_task": "ai_generated_image_detection",
            "face_manipulation_prediction": face_prediction.prediction,
            "face_manipulation_probability": face_prediction.manipulation_probability,
            "face_detection_threshold": face_classifier.detection_threshold,
            "faces_detected": face_prediction.face_count,
            "faces_analyzed": face_prediction.faces_analyzed,
            "face_model_version": face_prediction.model_version,
            "face_model_task": "face_swap_and_synthetic_face_detection",
        },
        "is_demo": False,
    }


@app.post("/api/v2/detect/image")
async def detect_ffpp_image(file: UploadFile = File(...)) -> dict[str, object]:
    classifier = app.state.deepfake_image_classifier
    if classifier is None:
        raise HTTPException(
            status_code=503,
            detail=app.state.deepfake_model_error or "The FF++ image detector is not ready.",
        )
    contents = await file.read(MAX_UPLOAD_BYTES + 1)
    if not contents:
        raise HTTPException(status_code=400, detail="The uploaded file is empty.")
    if len(contents) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Image exceeds the {MAX_UPLOAD_BYTES // (1024 * 1024)} MB upload limit.",
        )
    try:
        with Image.open(BytesIO(contents)) as image:
            if image.format not in {"JPEG", "PNG"}:
                raise HTTPException(status_code=415, detail="Only JPEG and PNG images are supported.")
            if image.width * image.height > MAX_IMAGE_PIXELS:
                raise HTTPException(status_code=413, detail="Image dimensions are too large.")
            image.verify()
        prediction = await run_in_threadpool(classifier.predict_image_bytes, contents)
    except HTTPException:
        raise
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError, ValueError) as exc:
        raise HTTPException(status_code=400, detail="The uploaded image is invalid or unreadable.") from exc
    except Exception as exc:
        logger.exception("FF++ image inference failed")
        raise HTTPException(status_code=400, detail="The uploaded image could not be analyzed.") from exc

    response = asdict(prediction)
    response["model_version"] = classifier.model_version
    response["model_task"] = "face_deepfake_detection"
    response["confidence_is_calibrated"] = False
    return response


@app.post("/api/v2/detect/video")
async def detect_ffpp_video(file: UploadFile = File(...)) -> dict[str, object]:
    analyzer = app.state.deepfake_video_analyzer
    if analyzer is None:
        raise HTTPException(
            status_code=503,
            detail=app.state.deepfake_model_error or "The FF++ video detector is not ready.",
        )
    safe_filename = (file.filename or "video").replace("\\", "/").rsplit("/", 1)[-1]
    suffix = Path(safe_filename).suffix.casefold()
    if suffix not in SUPPORTED_VIDEO_SUFFIXES:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported video format. Supported formats: {', '.join(sorted(SUPPORTED_VIDEO_SUFFIXES))}.",
        )
    contents = await file.read(MAX_VIDEO_UPLOAD_BYTES + 1)
    if not contents:
        raise HTTPException(status_code=400, detail="The uploaded video is empty.")
    if len(contents) > MAX_VIDEO_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Video exceeds the {MAX_VIDEO_UPLOAD_BYTES // (1024 * 1024)} MB upload limit.",
        )

    VIDEO_UPLOAD_TEMP_DIR.mkdir(parents=True, exist_ok=True)
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb", suffix=suffix, prefix="deepshield_", dir=VIDEO_UPLOAD_TEMP_DIR, delete=False
        ) as temporary_file:
            temporary_file.write(contents)
            temporary_path = Path(temporary_file.name)
        prediction = await run_in_threadpool(analyzer.predict_video, temporary_path)
    except Exception as exc:
        from deepshield_model.multimedia_inference import InsufficientVideoFrames, InvalidMedia

        if isinstance(exc, InsufficientVideoFrames):
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        if isinstance(exc, InvalidMedia):
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        logger.exception("FF++ video inference failed")
        raise HTTPException(status_code=400, detail="The uploaded video could not be analyzed.") from exc
    finally:
        await file.close()
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)

    response = asdict(prediction)
    response["model_version"] = analyzer.image_classifier.model_version
    response["confidence_is_calibrated"] = False
    return response
