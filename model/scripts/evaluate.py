"""Evaluate a saved checkpoint against the held-out test split."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch
from torch.utils.data import DataLoader
from torchvision import datasets, transforms

from deepshield_model.architecture import build_model
from deepshield_model.inference import IMAGE_MEAN, IMAGE_SIZE, IMAGE_STD


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, required=True)
    parser.add_argument(
        "--checkpoint",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "artifacts" / "deepfake_resnet18.pt",
    )
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--workers", type=int, default=0)
    args = parser.parse_args()

    test_transform = transforms.Compose(
        [
            transforms.Resize(256),
            transforms.CenterCrop(IMAGE_SIZE),
            transforms.ToTensor(),
            transforms.Normalize(IMAGE_MEAN, IMAGE_STD),
        ]
    )
    test_data = datasets.ImageFolder(args.data_dir / "test", transform=test_transform)
    expected_classes = {"fake": 0, "real": 1}
    if test_data.class_to_idx != expected_classes or len(test_data) == 0:
        raise SystemExit("test/ must contain images under fake/ and real/ folders.")
    test_counts = torch.bincount(torch.tensor(test_data.targets), minlength=2)
    if torch.any(test_counts == 0):
        raise SystemExit("The test split must contain at least one fake and one real image.")

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    checkpoint = torch.load(args.checkpoint, map_location=device, weights_only=True)
    if checkpoint["class_to_idx"] != expected_classes:
        raise SystemExit("Checkpoint class labels do not match the expected fake/real labels.")
    model = build_model(pretrained=False).to(device)
    model.load_state_dict(checkpoint["state_dict"], strict=True)
    model.eval()

    predictions = []
    targets = []
    loader = DataLoader(
        test_data, batch_size=args.batch_size, shuffle=False, num_workers=args.workers
    )
    with torch.inference_mode():
        for images, labels in loader:
            fake_probability = torch.softmax(model(images.to(device)), dim=1)[:, 0]
            predicted_labels = torch.where(
                fake_probability >= float(checkpoint.get("threshold", 0.5)),
                torch.zeros_like(fake_probability, dtype=torch.long),
                torch.ones_like(fake_probability, dtype=torch.long),
            )
            predictions.append(predicted_labels.cpu())
            targets.append(labels)

    predicted = torch.cat(predictions)
    actual = torch.cat(targets)
    true_fake = int(((predicted == 0) & (actual == 0)).sum())
    fake_as_real = int(((predicted == 1) & (actual == 0)).sum())
    real_as_fake = int(((predicted == 0) & (actual == 1)).sum())
    true_real = int(((predicted == 1) & (actual == 1)).sum())
    precision = true_fake / max(true_fake + real_as_fake, 1)
    recall = true_fake / max(true_fake + fake_as_real, 1)
    f1 = 2 * precision * recall / max(precision + recall, 1e-12)
    metrics = {
        "model_version": checkpoint.get("model_version", "unknown"),
        "threshold": checkpoint.get("threshold", 0.5),
        "test_images": len(test_data),
        "accuracy": float((predicted == actual).float().mean()),
        "fake_precision": precision,
        "fake_recall": recall,
        "fake_f1": f1,
        "confusion_matrix_true_rows_fake_real_pred_columns_fake_real": [
            [true_fake, fake_as_real],
            [real_as_fake, true_real],
        ],
    }
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
