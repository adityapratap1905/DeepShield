"""Shared YuNet face detection and padded face-crop preprocessing."""

from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np

DEFAULT_DETECTION_THRESHOLD = 0.65
MAX_DETECTION_SIDE = 1600
FACE_CONTEXT_RATIO = 0.25


def create_face_detector(
    detector_path: Path,
    detection_threshold: float = DEFAULT_DETECTION_THRESHOLD,
) -> cv2.FaceDetectorYN:
    if not detector_path.is_file():
        raise FileNotFoundError(f"YuNet face detector not found: {detector_path}")
    if not 0.0 < detection_threshold <= 1.0:
        raise ValueError("Face detection threshold must be greater than zero and at most one.")
    return cv2.FaceDetectorYN.create(
        str(detector_path), "", (320, 320), float(detection_threshold), 0.3, 5000
    )


def detect_face_crops(
    rgb_image: np.ndarray,
    detector: cv2.FaceDetectorYN,
    *,
    detection_threshold: float = DEFAULT_DETECTION_THRESHOLD,
    maximum_faces: int = 10,
) -> list[tuple[np.ndarray, tuple[int, int, int, int]]]:
    """Return padded RGB crops ordered from largest detected face to smallest."""
    if rgb_image.ndim != 3 or rgb_image.shape[2] != 3 or rgb_image.size == 0:
        raise ValueError("Face detection requires a non-empty RGB image.")
    if maximum_faces < 1:
        raise ValueError("maximum_faces must be positive.")

    height, width = rgb_image.shape[:2]
    scale = min(1.0, MAX_DETECTION_SIDE / max(width, height))
    bgr = cv2.cvtColor(rgb_image, cv2.COLOR_RGB2BGR)
    if scale < 1.0:
        detection_image = cv2.resize(
            bgr,
            (max(1, round(width * scale)), max(1, round(height * scale))),
            interpolation=cv2.INTER_AREA,
        )
    else:
        detection_image = bgr

    detector.setInputSize((detection_image.shape[1], detection_image.shape[0]))
    _, detections = detector.detect(detection_image)
    if detections is None:
        return []

    detections = sorted(detections, key=lambda row: float(row[2] * row[3]), reverse=True)
    found: list[tuple[np.ndarray, tuple[int, int, int, int]]] = []
    for row in detections:
        if float(row[14]) < detection_threshold:
            continue
        x, y, face_width, face_height = (int(round(value / scale)) for value in row[:4])
        x0 = max(0, x - int(round(face_width * FACE_CONTEXT_RATIO)))
        y0 = max(0, y - int(round(face_height * FACE_CONTEXT_RATIO)))
        x1 = min(width, x + face_width + int(round(face_width * FACE_CONTEXT_RATIO)))
        y1 = min(height, y + face_height + int(round(face_height * FACE_CONTEXT_RATIO)))
        if x1 <= x0 or y1 <= y0:
            continue
        crop = rgb_image[y0:y1, x0:x1]
        if crop.size:
            found.append((np.ascontiguousarray(crop), (x, y, face_width, face_height)))
        if len(found) >= maximum_faces:
            break
    return found
