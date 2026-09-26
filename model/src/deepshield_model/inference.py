"""Load a trained checkpoint and score an uploaded photo."""

from __future__ import annotations

from dataclasses import dataclass
from io import BytesIO
from pathlib import Path

import torch
from PIL import Image
from torchvision import transforms

from .architecture import build_model

IMAGE_SIZE = 224
IMAGE_MEAN = (0.485, 0.456, 0.406)
IMAGE_STD = (0.229, 0.224, 0.225)


class ModelNotReady(RuntimeError):
    """Raised when the trained model checkpoint is missing or invalid."""


@dataclass(frozen=True)
class PhotoPrediction:
    prediction: str
    fake_probability: float
    model_score: float
    threshold: float
    model_version: str


class DeepfakeClassifier:
    """CPU/GPU inference wrapper around the trained binary image classifier."""

    def __init__(self, checkpoint_path: Path) -> None:
        if not checkpoint_path.is_file():
            raise ModelNotReady(f"Model checkpoint not found: {checkpoint_path}")

        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        try:
            checkpoint = torch.load(
                checkpoint_path, map_location=self.device, weights_only=True
            )
            class_to_idx = checkpoint["class_to_idx"]
            if set(class_to_idx) != {"fake", "real"}:
                raise ValueError("Checkpoint classes must be 'fake' and 'real'.")

            self.fake_index = int(class_to_idx["fake"])
            self.threshold = float(checkpoint.get("threshold", 0.5))
            self.model_version = str(checkpoint.get("model_version", "custom-resnet18"))
            self.model = build_model(pretrained=False).to(self.device)
            self.model.load_state_dict(checkpoint["state_dict"], strict=True)
            self.model.eval()
        except Exception as exc:
            raise ModelNotReady("The configured model checkpoint could not be loaded.") from exc

        self.transform = transforms.Compose(
            [
                transforms.Resize(256),
                transforms.CenterCrop(IMAGE_SIZE),
                transforms.ToTensor(),
                transforms.Normalize(IMAGE_MEAN, IMAGE_STD),
            ]
        )

    @torch.inference_mode()
    def predict(self, image_bytes: bytes) -> PhotoPrediction:
        try:
            with Image.open(BytesIO(image_bytes)) as source:
                image = source.convert("RGB")
        except Exception as exc:
            raise ValueError("The uploaded file is not a readable image.") from exc

        tensor = self.transform(image).unsqueeze(0).to(self.device)
        probabilities = torch.softmax(self.model(tensor), dim=1)[0]
        fake_probability = float(probabilities[self.fake_index].item())
        prediction = "fake" if fake_probability >= self.threshold else "real"
        model_score = fake_probability if prediction == "fake" else 1.0 - fake_probability
        return PhotoPrediction(
            prediction=prediction,
            fake_probability=fake_probability,
            model_score=model_score,
            threshold=self.threshold,
            model_version=self.model_version,
        )
