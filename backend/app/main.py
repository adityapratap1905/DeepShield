"""DeepShield photo analysis API."""

from __future__ import annotations

import logging
import os
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path
from uuid import uuid4

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, UnidentifiedImageError
from starlette.concurrency import run_in_threadpool

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
MAX_IMAGE_PIXELS = 40_000_000
Image.MAX_IMAGE_PIXELS = MAX_IMAGE_PIXELS


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.classifier = None
    app.state.face_classifier = None
    app.state.model_error = None
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
        yield
        return

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
        app.state.model_error = "The configured model checkpoint could not be loaded."
        logger.exception("Photo analysis is unavailable")
    yield


app = FastAPI(
    title="DeepShield API",
    version="0.1.0",
    description="AI-generated image and face-manipulation signal analysis API.",
    lifespan=lifespan,
)

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
    allow_methods=["GET", "POST"],
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
    filename = (file.filename or "photo").replace("\\", "/").rsplit("/", 1)[-1]
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
