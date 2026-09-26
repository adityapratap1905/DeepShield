"""Fine-tune a ResNet-18 using a labeled, split image dataset."""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

import torch
from torch import nn
from torch.utils.data import DataLoader
from torchvision import datasets, transforms

from deepshield_model.architecture import build_model
from deepshield_model.inference import IMAGE_MEAN, IMAGE_SIZE, IMAGE_STD


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, required=True)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "artifacts" / "deepfake_resnet18.pt",
    )
    parser.add_argument("--epochs", type=int, default=8)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--learning-rate", type=float, default=1e-4)
    parser.add_argument("--threshold", type=float, default=0.5)
    parser.add_argument("--workers", type=int, default=0)
    return parser.parse_args()


def run_epoch(model, loader, loss_fn, device, threshold=0.5, optimizer=None):
    training = optimizer is not None
    model.train(training)
    total_loss = 0.0
    all_predictions = []
    all_targets = []

    for images, targets in loader:
        images = images.to(device)
        targets = targets.to(device)
        if training:
            optimizer.zero_grad(set_to_none=True)

        with torch.set_grad_enabled(training):
            logits = model(images)
            loss = loss_fn(logits, targets)
            if training:
                loss.backward()
                optimizer.step()

        total_loss += loss.item() * images.size(0)
        fake_probability = torch.softmax(logits.detach(), dim=1)[:, 0]
        predictions = torch.where(
            fake_probability >= threshold,
            torch.zeros_like(targets),
            torch.ones_like(targets),
        )
        all_predictions.append(predictions.cpu())
        all_targets.append(targets.detach().cpu())

    predictions = torch.cat(all_predictions)
    targets = torch.cat(all_targets)
    fake_index = 0  # ImageFolder sorts "fake" before "real".
    true_positive = int(((predictions == fake_index) & (targets == fake_index)).sum())
    false_positive = int(((predictions == fake_index) & (targets != fake_index)).sum())
    false_negative = int(((predictions != fake_index) & (targets == fake_index)).sum())
    precision = true_positive / max(true_positive + false_positive, 1)
    recall = true_positive / max(true_positive + false_negative, 1)
    f1 = 2 * precision * recall / max(precision + recall, 1e-12)
    return {
        "loss": total_loss / len(loader.dataset),
        "accuracy": float((predictions == targets).float().mean()),
        "fake_precision": precision,
        "fake_recall": recall,
        "fake_f1": f1,
    }


def main() -> None:
    args = parse_args()
    if args.epochs < 1 or args.batch_size < 1:
        raise SystemExit("--epochs and --batch-size must be positive.")
    if not 0.0 < args.threshold < 1.0:
        raise SystemExit("--threshold must be between 0 and 1.")
    random.seed(42)
    torch.manual_seed(42)

    train_transform = transforms.Compose(
        [
            transforms.Resize(256),
            transforms.RandomCrop(IMAGE_SIZE),
            transforms.RandomHorizontalFlip(),
            transforms.ToTensor(),
            transforms.Normalize(IMAGE_MEAN, IMAGE_STD),
        ]
    )
    eval_transform = transforms.Compose(
        [
            transforms.Resize(256),
            transforms.CenterCrop(IMAGE_SIZE),
            transforms.ToTensor(),
            transforms.Normalize(IMAGE_MEAN, IMAGE_STD),
        ]
    )
    train_data = datasets.ImageFolder(args.data_dir / "train", transform=train_transform)
    validation_data = datasets.ImageFolder(args.data_dir / "val", transform=eval_transform)
    expected_classes = {"fake": 0, "real": 1}
    if train_data.class_to_idx != expected_classes:
        raise SystemExit("Training data must contain class folders 'fake' and 'real'.")
    if validation_data.class_to_idx != expected_classes:
        raise SystemExit("Validation data must contain class folders 'fake' and 'real'.")

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    if len(train_data) == 0 or len(validation_data) == 0:
        raise SystemExit("Both train/ and val/ must contain labeled fake/ and real/ images.")
    train_loader = DataLoader(
        train_data, batch_size=args.batch_size, shuffle=True, num_workers=args.workers
    )
    validation_loader = DataLoader(
        validation_data, batch_size=args.batch_size, shuffle=False, num_workers=args.workers
    )
    model = build_model(pretrained=True).to(device)
    class_counts = torch.bincount(torch.tensor(train_data.targets), minlength=2).float()
    validation_counts = torch.bincount(
        torch.tensor(validation_data.targets), minlength=2
    )
    if torch.any(class_counts == 0) or torch.any(validation_counts == 0):
        raise SystemExit("Both train/ and val/ must contain at least one fake and one real image.")
    class_weights = class_counts.sum() / (2 * class_counts)
    loss_fn = nn.CrossEntropyLoss(weight=class_weights.to(device))
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.learning_rate)

    best_f1 = -1.0
    best_metrics = None
    for epoch in range(1, args.epochs + 1):
        train_metrics = run_epoch(
            model, train_loader, loss_fn, device, args.threshold, optimizer
        )
        validation_metrics = run_epoch(
            model, validation_loader, loss_fn, device, args.threshold
        )
        print(
            json.dumps(
                {
                    "epoch": epoch,
                    "train": train_metrics,
                    "validation": validation_metrics,
                    "device": str(device),
                }
            )
        )
        if validation_metrics["fake_f1"] > best_f1:
            best_f1 = validation_metrics["fake_f1"]
            best_metrics = validation_metrics
            args.output.parent.mkdir(parents=True, exist_ok=True)
            torch.save(
                {
                    "state_dict": model.state_dict(),
                    "class_to_idx": train_data.class_to_idx,
                    "threshold": args.threshold,
                    "model_version": "resnet18-transfer-v1",
                    "validation_metrics": validation_metrics,
                },
                args.output,
            )

    metrics_path = args.output.with_suffix(".metrics.json")
    metrics_path.write_text(json.dumps(best_metrics, indent=2), encoding="utf-8")
    print(f"Saved best validation checkpoint to {args.output}")
    print(f"Saved validation metrics to {metrics_path}")


if __name__ == "__main__":
    main()
