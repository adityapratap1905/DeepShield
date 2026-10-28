"""Shared FF++ image classifier with frame-based video aggregation inference."""

from __future__ import annotations

import json
import hashlib
import math
import threading
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path

import numpy as np
import torch
import cv2
from PIL import Image, ImageOps, UnidentifiedImageError

from .architecture import build_model
from .face_preprocessing import (
    DEFAULT_DETECTION_THRESHOLD,
    create_face_detector,
    detect_face_crops,
)
from .ffpp_data import read_sampled_frames

IMAGE_MEAN = (0.485, 0.456, 0.406)
IMAGE_STD = (0.229, 0.224, 0.225)
VIDEO_AGGREGATIONS = ("mean", "median", "top_k_mean", "percentage_fake")


def _padded_square_rgb(rgb: np.ndarray, resolution: int) -> np.ndarray:
    image = Image.fromarray(rgb.astype(np.uint8), mode="RGB")
    image.thumbnail((resolution, resolution), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (resolution, resolution), (127, 127, 127))
    canvas.paste(image, ((resolution - image.width) // 2, (resolution - image.height) // 2))
    return np.asarray(canvas)


class ModelNotReady(RuntimeError):
    """Raised when the trained FF++ model or its calibration is missing."""


class InvalidMedia(ValueError):
    """Raised when media cannot be decoded or is not supported."""


class InsufficientVideoFrames(ValueError):
    """Raised when a video does not contain enough decodable frames."""


@dataclass(frozen=True)
class ImagePrediction:
    media_type: str
    prediction: str
    fake_probability: float
    confidence: float
    threshold: float
    faces_detected: int
    faces_analyzed: int
    preprocessing_mode: str


@dataclass(frozen=True)
class VideoPrediction:
    media_type: str
    prediction: str
    fake_probability: float
    confidence: float
    frames_analyzed: int
    no_face_frames: int
    threshold: float
    aggregation_method: str


def aggregate_frame_probabilities(
    probabilities: list[float] | np.ndarray,
    method: str,
    *,
    image_threshold: float = 0.5,
    top_k_fraction: float = 0.2,
) -> float:
    values = np.asarray(probabilities, dtype=np.float64).reshape(-1)
    if values.size == 0 or not np.isfinite(values).all():
        raise ValueError("Video aggregation requires finite frame probabilities.")
    if np.any((values < 0.0) | (values > 1.0)):
        raise ValueError("Frame probabilities must be between zero and one.")
    if method == "mean":
        return float(np.mean(values))
    if method == "median":
        return float(np.median(values))
    if method == "top_k_mean":
        if not math.isfinite(top_k_fraction) or not 0.0 < top_k_fraction <= 1.0:
            raise ValueError("top_k_fraction must be greater than zero and at most one.")
        count = max(1, int(math.ceil(values.size * top_k_fraction)))
        return float(np.mean(np.partition(values, values.size - count)[-count:]))
    if method == "percentage_fake":
        if not math.isfinite(image_threshold) or not 0.0 <= image_threshold <= 1.0:
            raise ValueError("image_threshold must be between zero and one.")
        return float(np.mean(values >= image_threshold))
    raise ValueError(f"Unsupported video aggregation method: {method}.")


class DeepfakeImageClassifier:
    """Load one selected checkpoint and classify images or sampled video frames."""

    def __init__(
        self,
        checkpoint_path: Path,
        face_detector_path: Path,
        *,
        detection_threshold: float | None = None,
    ) -> None:
        if not checkpoint_path.is_file():
            raise ModelNotReady(f"Trained image checkpoint is missing: {checkpoint_path}")
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        try:
            checkpoint = torch.load(checkpoint_path, map_location=self.device, weights_only=True)
            self.checkpoint_path = checkpoint_path.resolve()
            self.checkpoint_sha256 = hashlib.sha256(checkpoint_path.read_bytes()).hexdigest()
            architecture = str(checkpoint["architecture"])
            class_to_idx = checkpoint["class_to_idx"]
            if class_to_idx.get("fake") != 1 or class_to_idx.get("real") != 0:
                raise ValueError("Checkpoint class mapping must be real=0 and fake=1.")
            self.model = build_model(pretrained=False, name=architecture).to(self.device)
            self.model.load_state_dict(checkpoint["state_dict"], strict=True)
            self.model.eval()
            self.architecture = architecture
            self.model_version = str(checkpoint.get("model_version", architecture))
            self.threshold = float(checkpoint["threshold"])
            if not 0.0 <= self.threshold <= 1.0:
                raise ValueError("Image threshold in checkpoint is invalid.")
            self.input_size = int(checkpoint.get("input_size", 224))
            if self.input_size < 64:
                raise ValueError("Checkpoint input size must be at least 64.")
            self.preprocessing_resolution = int(
                checkpoint.get("preprocessing_resolution", self.input_size)
            )
            if self.preprocessing_resolution < 32:
                raise ValueError("Checkpoint preprocessing resolution must be at least 32.")
            self.preprocessing_mode = str(checkpoint.get("preprocessing_mode", "face_crop"))
            if self.preprocessing_mode not in {"face_crop", "full_frame"}:
                raise ValueError("Checkpoint preprocessing mode must be face_crop or full_frame.")
            if detection_threshold is None:
                detection_threshold = float(
                    checkpoint.get("face_detection_threshold", DEFAULT_DETECTION_THRESHOLD)
                )
            mean = tuple(checkpoint.get("image_mean", IMAGE_MEAN))
            std = tuple(checkpoint.get("image_std", IMAGE_STD))
        except Exception as exc:
            raise ModelNotReady("The configured FF++ checkpoint is invalid or incompatible.") from exc

        try:
            from torchvision import transforms

            self.transform = transforms.Compose(
                [
                    transforms.Resize(self.input_size + 32),
                    transforms.CenterCrop(self.input_size),
                    transforms.ToTensor(),
                    transforms.Normalize(mean, std),
                ]
            )
            self.face_detector = create_face_detector(face_detector_path, detection_threshold)
        except Exception as exc:
            raise ModelNotReady("TorchVision preprocessing or YuNet face detection could not be loaded.") from exc
        self.detection_threshold = float(detection_threshold)
        self._lock = threading.RLock()

    def _probability_batch(self, rgb_images: list[np.ndarray]) -> list[float]:
        probabilities: list[float] = []
        for offset in range(0, len(rgb_images), 32):
            tensors = []
            for rgb in rgb_images[offset : offset + 32]:
                image = Image.fromarray(rgb.astype(np.uint8), mode="RGB")
                tensors.append(self.transform(image))
            batch = torch.stack(tensors).to(self.device)
            with torch.inference_mode():
                logits = self.model(batch)
                batch_probabilities = torch.softmax(logits, dim=1)[:, 1]
            probabilities.extend(float(value) for value in batch_probabilities.detach().cpu().tolist())
        return probabilities

    def predict_rgb(self, rgb_image: np.ndarray) -> ImagePrediction:
        return self.predict_rgb_batch([rgb_image])[0]

    def predict_rgb_batch(self, rgb_images: list[np.ndarray]) -> list[ImagePrediction]:
        """Classify a small frame batch with face predictions averaged per frame."""
        if not rgb_images:
            raise InvalidMedia("At least one RGB image is required.")
        for rgb_image in rgb_images:
            if rgb_image.ndim != 3 or rgb_image.shape[2] != 3 or rgb_image.size == 0:
                raise InvalidMedia("An image has no decodable RGB pixels.")
        with self._lock:
            face_detections = [
                detect_face_crops(
                    rgb_image,
                    self.face_detector,
                    detection_threshold=self.detection_threshold,
                    maximum_faces=10,
                )
                for rgb_image in rgb_images
            ]
            crops: list[np.ndarray] = []
            owners: list[int] = []
            preprocessing_modes: list[str] = []
            faces_analyzed = [0] * len(rgb_images)
            for index, (rgb_image, faces) in enumerate(zip(rgb_images, face_detections)):
                if self.preprocessing_mode == "face_crop" and faces:
                    preprocessing_modes.append("face_crop")
                    faces_analyzed[index] = len(faces)
                    selected_crops = [crop for crop, _ in faces]
                else:
                    preprocessing_modes.append(
                        "full_frame_fallback_no_face"
                        if self.preprocessing_mode == "face_crop" and not faces
                        else "full_frame"
                    )
                    selected_crops = [rgb_image]
                crops.extend(
                    _padded_square_rgb(crop, self.preprocessing_resolution)
                    for crop in selected_crops
                )
                owners.extend([index] * len(selected_crops))

            crop_probabilities = self._probability_batch(crops)
            per_frame: list[list[float]] = [[] for _ in rgb_images]
            for owner, probability in zip(owners, crop_probabilities):
                per_frame[owner].append(probability)

            predictions: list[ImagePrediction] = []
            for index, probabilities in enumerate(per_frame):
                fake_probability = float(np.mean(probabilities))
                predictions.append(
                    ImagePrediction(
                        media_type="image",
                        prediction="FAKE" if fake_probability >= self.threshold else "REAL",
                        fake_probability=fake_probability,
                        confidence=max(fake_probability, 1.0 - fake_probability),
                        threshold=self.threshold,
                        faces_detected=len(face_detections[index]),
                        faces_analyzed=faces_analyzed[index],
                        preprocessing_mode=preprocessing_modes[index],
                    )
                )
            return predictions

    def predict_image_bytes(self, image_bytes: bytes) -> ImagePrediction:
        try:
            with Image.open(BytesIO(image_bytes)) as source:
                rgb = np.asarray(ImageOps.exif_transpose(source).convert("RGB"))
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            raise InvalidMedia("The uploaded file is not a readable image.") from exc
        return self.predict_rgb(rgb)


class DeepfakeVideoAnalyzer:
    def __init__(
        self,
        image_classifier: DeepfakeImageClassifier,
        config_path: Path,
    ) -> None:
        if not config_path.is_file():
            raise ModelNotReady(
                f"Validation-selected video configuration is missing: {config_path}. "
                "Run scripts/evaluate_video.py --split val after training."
            )
        try:
            config = json.loads(config_path.read_text(encoding="utf-8"))
            method = str(config["aggregation_method"])
            if method not in VIDEO_AGGREGATIONS:
                raise ValueError("Unsupported aggregation method in video config.")
            threshold = float(config["threshold"])
            configured_checkpoint_hash = config.get("image_checkpoint_sha256")
            if configured_checkpoint_hash != image_classifier.checkpoint_sha256:
                raise ValueError("Video calibration was created for a different image checkpoint.")
            if not 0.0 <= threshold <= 1.0:
                raise ValueError("Video threshold in config is invalid.")
            self.sampling_fps = float(config["sampling_fps"])
            self.top_k_fraction = float(config.get("top_k_fraction", 0.2))
            self.frames_per_video = int(config["frames_per_video"])
            self.maximum_frames = int(config["maximum_frames"])
            self.minimum_frames = int(config["minimum_frames"])
            if (
                not math.isfinite(self.sampling_fps)
                or self.sampling_fps <= 0
                or not math.isfinite(self.top_k_fraction)
                or not 0.0 < self.top_k_fraction <= 1.0
                or min(self.frames_per_video, self.maximum_frames, self.minimum_frames) < 1
            ):
                raise ValueError("Video sampling settings in config are invalid.")
        except Exception as exc:
            raise ModelNotReady("The validation-selected video configuration is invalid.") from exc
        self.image_classifier = image_classifier
        self.aggregation_method = method
        self.threshold = threshold
        self.config_path = config_path

    def predict_video(self, video_path: Path) -> VideoPrediction:
        try:
            frames, _ = read_sampled_frames(
                video_path,
                sampling_fps=self.sampling_fps,
                frames_per_video=self.frames_per_video,
                maximum_frames=self.maximum_frames,
            )
        except (OSError, ValueError, cv2.error) as exc:
            raise InvalidMedia("The uploaded video is invalid, corrupted, or unsupported.") from exc
        if len(frames) < self.minimum_frames:
            raise InsufficientVideoFrames(
                f"The video has only {len(frames)} usable sampled frames; at least {self.minimum_frames} are required."
            )

        frame_predictions = self.image_classifier.predict_rgb_batch([rgb for _, _, rgb in frames])
        probabilities = [item.fake_probability for item in frame_predictions]
        no_face_frames = sum(item.faces_detected == 0 for item in frame_predictions)
        fake_probability = aggregate_frame_probabilities(
            probabilities,
            self.aggregation_method,
            image_threshold=self.image_classifier.threshold,
            top_k_fraction=self.top_k_fraction,
        )
        prediction = "FAKE" if fake_probability >= self.threshold else "REAL"
        return VideoPrediction(
            media_type="video",
            prediction=prediction,
            fake_probability=fake_probability,
            confidence=max(fake_probability, 1.0 - fake_probability),
            frames_analyzed=len(probabilities),
            no_face_frames=no_face_frames,
            threshold=self.threshold,
            aggregation_method=self.aggregation_method,
        )
