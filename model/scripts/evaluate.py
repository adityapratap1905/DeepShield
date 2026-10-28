"""Evaluate the selected image checkpoint once on the held-out FF++ test videos."""

from __future__ import annotations

import argparse
import json
import os
import platform
import sys
import time
from pathlib import Path

import numpy as np
import torch
from torch.utils.data import DataLoader

MODEL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODEL_ROOT / "src"))

from deepshield_model.architecture import build_model
from deepshield_model.metrics import binary_metrics, write_confusion_matrix, write_curves


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-dir", type=Path, default=MODEL_ROOT / "data" / "processed" / "images"
    )
    parser.add_argument(
        "--checkpoint", type=Path, default=MODEL_ROOT / "artifacts" / "deepfake_image_best.pt"
    )
    parser.add_argument("--output-dir", type=Path, default=MODEL_ROOT / "reports" / "image_test")
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--workers", type=int, default=0)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    from deepshield_model.training import ManifestImageDataset, _transforms, read_prepared_rows
    if not args.checkpoint.is_file():
        raise SystemExit(f"Image checkpoint not found: {args.checkpoint}")
    checkpoint = torch.load(args.checkpoint, map_location="cpu", weights_only=True)
    view = "face" if checkpoint.get("preprocessing_mode") == "face_crop" else "full"
    rows, manifest_root, _ = read_prepared_rows(args.data_dir, view)
    test_rows = [row for row in rows if row["split"] == "test"]
    if not test_rows:
        raise SystemExit("The FF++ test partition is empty; no test metrics were produced.")
    _, eval_transform = _transforms(int(checkpoint.get("input_size", 224)))
    dataset = ManifestImageDataset(test_rows, manifest_root, view, eval_transform)
    loader = DataLoader(
        dataset,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=args.workers,
        pin_memory=torch.cuda.is_available(),
        persistent_workers=args.workers > 0,
    )
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = build_model(pretrained=False, name=str(checkpoint["architecture"])).to(device)
    model.load_state_dict(checkpoint["state_dict"], strict=True)
    model.eval()
    threshold = float(checkpoint["threshold"])
    probabilities: list[torch.Tensor] = []
    targets: list[torch.Tensor] = []
    if device.type == "cuda":
        torch.cuda.reset_peak_memory_stats(device)
    started = time.perf_counter()
    with torch.inference_mode():
        for images, labels in loader:
            logits = model(images.to(device, non_blocking=device.type == "cuda"))
            probabilities.append(torch.softmax(logits, dim=1)[:, 1].float().cpu())
            targets.append(labels.cpu())
    if device.type == "cuda":
        torch.cuda.synchronize(device)
    elapsed = time.perf_counter() - started
    y_true = torch.cat(targets).numpy().astype(np.int64)
    y_prob = torch.cat(probabilities).numpy().astype(np.float64)
    metrics = binary_metrics(y_true, y_prob, threshold)
    metrics.update(
        {
            "media_type": "image",
            "model": checkpoint.get("architecture"),
            "model_version": checkpoint.get("model_version"),
            "dataset": checkpoint.get("dataset"),
            "compression": checkpoint.get("compression"),
            "manipulation_types": checkpoint.get("experiment", {}).get("manipulation_types", []),
            "face_detection_threshold": checkpoint.get("face_detection_threshold"),
            "official_split_commit": checkpoint.get("official_split_commit"),
            "view": view,
            "threshold_from_validation": threshold,
            "test_images": len(dataset),
            "test_images_by_class": {
                media_class: sum(row["class"] == media_class for row in test_rows)
                for media_class in ("real", "fake")
            },
            "test_videos": len({row["source_video"] for row in test_rows}),
            "test_videos_by_class": {
                media_class: len(
                    {row["source_video"] for row in test_rows if row["class"] == media_class}
                )
                for media_class in ("real", "fake")
            },
            "parameters": sum(parameter.numel() for parameter in model.parameters()),
            "inference_seconds_per_image": elapsed / max(len(dataset), 1),
            "inference_timing_scope": (
                "prepared test-image loading, deterministic transforms, and classifier forward pass; "
                "excludes upload decoding and YuNet face detection"
            ),
            "gpu_peak_memory_mb": (
                round(torch.cuda.max_memory_allocated(device) / (1024 * 1024), 2)
                if device.type == "cuda" else None
            ),
            "device": str(device),
            "hardware": {
                "platform": platform.platform(),
                "processor": platform.processor() or platform.machine(),
                "logical_cpu_count": os.cpu_count(),
                "gpu_name": torch.cuda.get_device_name(device) if device.type == "cuda" else None,
            },
            "test_threshold_tuned": False,
        }
    )
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "image_test_results.json").write_text(
        json.dumps(metrics, indent=2) + "\n", encoding="utf-8"
    )
    write_confusion_matrix(
        y_true, y_prob, threshold, args.output_dir / "image_test_confusion_matrix.png", "Image test"
    )
    write_curves(y_true, y_prob, args.output_dir, "Image test")
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
