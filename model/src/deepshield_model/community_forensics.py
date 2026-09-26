"""CPU inference for the pinned Community Forensics image detector."""

from __future__ import annotations

from dataclasses import dataclass
from io import BytesIO
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageOps, UnidentifiedImageError

IMAGE_SIZE = 384
RESIZE_SHORT_EDGE = 440
IMAGE_MEAN = np.asarray((0.48145466, 0.4578275, 0.40821073), dtype=np.float32)
IMAGE_STD = np.asarray((0.26862954, 0.26130258, 0.27577711), dtype=np.float32)
MODEL_VERSION = "community-forensics-vit-small-384-v1.1"


@dataclass(frozen=True)
class PhotoPrediction:
    prediction: str
    ai_generated_probability: float
    threshold: float
    model_version: str


class CommunityForensicsClassifier:
    """Detect AI-generated image signals. This model does not detect all edits."""

    def __init__(self, model_path: Path) -> None:
        if not model_path.is_file():
            raise FileNotFoundError(f"Model file not found: {model_path}")

        options = ort.SessionOptions()
        options.intra_op_num_threads = 4
        options.inter_op_num_threads = 1
        options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        self.session = ort.InferenceSession(
            str(model_path),
            sess_options=options,
            providers=["CPUExecutionProvider"],
        )
        inputs = self.session.get_inputs()
        if len(inputs) != 1:
            raise ValueError("The configured model must have one image input.")
        self.input_name = inputs[0].name
        self.model_version = MODEL_VERSION
        self.threshold = 0.5

    @staticmethod
    def _preprocess(image: Image.Image) -> np.ndarray:
        width, height = image.size
        scale = RESIZE_SHORT_EDGE / min(width, height)
        resized_size = (max(IMAGE_SIZE, int(width * scale)), max(IMAGE_SIZE, int(height * scale)))
        image = image.resize(resized_size, Image.Resampling.BICUBIC)
        left = (image.width - IMAGE_SIZE) // 2
        top = (image.height - IMAGE_SIZE) // 2
        image = image.crop((left, top, left + IMAGE_SIZE, top + IMAGE_SIZE))

        pixels = np.asarray(image, dtype=np.float32) / 255.0
        pixels = (pixels - IMAGE_MEAN) / IMAGE_STD
        return np.expand_dims(pixels.transpose(2, 0, 1), axis=0).astype(np.float32)

    def predict(self, image_bytes: bytes) -> PhotoPrediction:
        try:
            with Image.open(BytesIO(image_bytes)) as source:
                image = ImageOps.exif_transpose(source).convert("RGB")
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            raise ValueError("The uploaded file is not a readable image.") from exc

        tensor = self._preprocess(image)
        output = self.session.run(None, {self.input_name: tensor})[0]
        logit = float(np.asarray(output).reshape(-1)[0])
        probability = float(1.0 / (1.0 + np.exp(-np.clip(logit, -80.0, 80.0))))
        prediction = "ai_generated" if probability >= self.threshold else "no_ai_generation_signal"
        return PhotoPrediction(
            prediction=prediction,
            ai_generated_probability=probability,
            threshold=self.threshold,
            model_version=self.model_version,
        )
