"""Face-crop detection for face-swap and synthetic-face signals."""

from __future__ import annotations

from dataclasses import dataclass
from io import BytesIO
from pathlib import Path

import cv2
import numpy as np
import onnxruntime as ort
from PIL import Image, ImageOps, UnidentifiedImageError

IMAGE_SIZE = 260
IMAGE_MEAN = np.asarray((0.485, 0.456, 0.406), dtype=np.float32)
IMAGE_STD = np.asarray((0.229, 0.224, 0.225), dtype=np.float32)
MODEL_VERSION = "deepfake-hybrid-onnx-2a766f2"
DEFAULT_FACE_DETECTION_THRESHOLD = 0.65
MAX_FACES_TO_ANALYZE = 10


@dataclass(frozen=True)
class FaceManipulationPrediction:
    prediction: str
    manipulation_probability: float | None
    face_count: int
    faces_analyzed: int
    model_version: str


class FaceManipulationClassifier:
    """Find faces, then score each face crop for manipulation signals."""

    def __init__(
        self,
        classifier_path: Path,
        detector_path: Path,
        detection_threshold: float = DEFAULT_FACE_DETECTION_THRESHOLD,
    ) -> None:
        for model_path in (classifier_path, detector_path):
            if not model_path.is_file():
                raise FileNotFoundError(f"Model file not found: {model_path}")
        if not 0.0 < detection_threshold <= 1.0:
            raise ValueError("Face detection threshold must be between 0 and 1.")

        self.detection_threshold = float(detection_threshold)
        self.detector = cv2.FaceDetectorYN.create(
            str(detector_path), "", (320, 320), self.detection_threshold, 0.3, 5000
        )
        options = ort.SessionOptions()
        options.intra_op_num_threads = 2
        options.inter_op_num_threads = 1
        options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        self.session = ort.InferenceSession(
            str(classifier_path),
            sess_options=options,
            providers=["CPUExecutionProvider"],
        )
        inputs = self.session.get_inputs()
        outputs = self.session.get_outputs()
        if len(inputs) != 1 or not outputs:
            raise ValueError("The face-manipulation model has an unsupported input/output layout.")
        self.input_name = inputs[0].name
        self.output_name = outputs[0].name
        self.model_version = MODEL_VERSION
        self.threshold = 0.5

    @staticmethod
    def _preprocess_face(rgb: np.ndarray) -> np.ndarray:
        image = Image.fromarray(rgb).resize(
            (IMAGE_SIZE, IMAGE_SIZE), Image.Resampling.BICUBIC
        )
        pixels = np.asarray(image, dtype=np.float32) / 255.0
        pixels = (pixels - IMAGE_MEAN) / IMAGE_STD
        return pixels.transpose(2, 0, 1)[np.newaxis, ...].astype(np.float32)

    def _face_boxes(self, image: np.ndarray) -> tuple[list[tuple[int, int, int, int]], tuple[int, int]]:
        height, width = image.shape[:2]
        max_side = max(width, height)
        scale = min(1.0, 1600.0 / max_side)
        if scale < 1.0:
            detection_image = cv2.resize(
                image,
                (round(width * scale), round(height * scale)),
                interpolation=cv2.INTER_AREA,
            )
        else:
            detection_image = image

        self.detector.setInputSize((detection_image.shape[1], detection_image.shape[0]))
        _, detections = self.detector.detect(detection_image)
        if detections is None:
            return [], (width, height)

        detections = sorted(
            detections,
            key=lambda row: float(row[2] * row[3]),
            reverse=True,
        )
        boxes = []
        for row in detections:
            if float(row[14]) < self.detection_threshold:
                continue
            x, y, face_width, face_height = (int(round(value / scale)) for value in row[:4])
            boxes.append((x, y, face_width, face_height))
        return boxes, (width, height)

    def predict(self, image_bytes: bytes) -> FaceManipulationPrediction:
        try:
            with Image.open(BytesIO(image_bytes)) as source:
                rgb = np.asarray(ImageOps.exif_transpose(source).convert("RGB"))
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            raise ValueError("The uploaded photo could not be decoded for face analysis.") from exc
        image = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)

        boxes, (width, height) = self._face_boxes(image)
        if not boxes:
            return FaceManipulationPrediction(
                prediction="no_face_detected",
                manipulation_probability=None,
                face_count=0,
                faces_analyzed=0,
                model_version=self.model_version,
            )

        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        face_tensors = []
        for x, y, face_width, face_height in boxes[:MAX_FACES_TO_ANALYZE]:
            left = min(width, max(0, x - 25))
            top = min(height, max(0, y - 25))
            right = min(width, max(0, x + face_width + 25))
            bottom = min(height, max(0, y + face_height + 25))
            if right <= left or bottom <= top:
                continue
            crop = rgb[top:bottom, left:right]
            if crop.size == 0:
                continue

            face_tensors.append(self._preprocess_face(crop))

        if not face_tensors:
            return FaceManipulationPrediction(
                prediction="no_face_detected",
                manipulation_probability=None,
                face_count=len(boxes),
                faces_analyzed=0,
                model_version=self.model_version,
            )

        batch = np.concatenate(face_tensors, axis=0)
        logits = self.session.run(
            [self.output_name], {self.input_name: batch}
        )[0]
        logits = np.asarray(logits, dtype=np.float32)
        if logits.size != len(face_tensors) * 2:
            raise ValueError("The face-manipulation model must return fake and real logits.")
        logits = logits.reshape(len(face_tensors), 2)
        shifted = logits - np.max(logits, axis=1, keepdims=True)
        exponentials = np.exp(shifted)
        probabilities = exponentials[:, 0] / exponentials.sum(axis=1)

        probability = float(np.max(probabilities))
        prediction = (
            "face_manipulation_signal"
            if probability >= self.threshold
            else "no_face_manipulation_signal"
        )
        return FaceManipulationPrediction(
            prediction=prediction,
            manipulation_probability=probability,
            face_count=len(boxes),
            faces_analyzed=len(face_tensors),
            model_version=self.model_version,
        )
