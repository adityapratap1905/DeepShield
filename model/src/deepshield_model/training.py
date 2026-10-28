"""Video-separated transfer-learning experiments for FF++ frame images."""

from __future__ import annotations

import csv
import io
import json
import os
import platform
import random
import shutil
import time
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

import numpy as np
import torch
from PIL import Image, ImageFile
from torch import nn
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler
from torchvision import transforms

from .architecture import (
    ARCHITECTURES,
    build_model,
    classifier_head,
    freeze_backbone,
    unfreeze_backbone_block,
)
from .metrics import binary_metrics, choose_f1_threshold

IMAGE_MEAN = (0.485, 0.456, 0.406)
IMAGE_STD = (0.229, 0.224, 0.225)
CLASS_TO_IDX = {"real": 0, "fake": 1}
ImageFile.LOAD_TRUNCATED_IMAGES = False


class JpegCompression:
    """Apply mild, realistic JPEG recompression to training images only."""

    def __init__(self, probability: float = 0.25) -> None:
        self.probability = probability

    def __call__(self, image: Image.Image) -> Image.Image:
        if random.random() >= self.probability:
            return image
        buffer = io.BytesIO()
        image.save(buffer, format="JPEG", quality=random.choice((78, 86, 94)))
        buffer.seek(0)
        with Image.open(buffer) as compressed:
            return compressed.convert("RGB")


class ManifestImageDataset(Dataset):
    def __init__(self, rows: list[dict[str, str]], root: Path, view: str, transform) -> None:
        self.rows = rows
        self.root = root
        self.view = view
        self.transform = transform

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int):
        row = self.rows[index]
        column = "image_path" if self.view == "face" else "full_image_path"
        relative = row.get(column, "").strip()
        if not relative:
            raise ValueError(f"Manifest row has no {column}: {row}")
        path = (self.root / relative).resolve()
        if not path.is_file():
            raise FileNotFoundError(f"Prepared image is missing: {path}")
        with Image.open(path) as source:
            image = source.convert("RGB")
        return self.transform(image), CLASS_TO_IDX[row["class"]]


def read_prepared_rows(data_dir: Path, view: str) -> tuple[list[dict[str, str]], Path, Path]:
    data_dir = data_dir.resolve()
    manifest_path = data_dir.parent / "image_manifest.csv"
    if not manifest_path.is_file():
        raise FileNotFoundError(
            f"The FF++ image manifest is missing: {manifest_path}. Run scripts/prepare_ffpp.py first."
        )
    rows: list[dict[str, str]] = []
    root = data_dir.parent
    split_ids: dict[str, set[str]] = defaultdict(set)
    split_classes: dict[str, set[str]] = defaultdict(set)
    with manifest_path.open("r", newline="", encoding="utf-8") as stream:
        for row in csv.DictReader(stream):
            split = row.get("split", "").strip()
            media_class = row.get("class", "").strip().casefold()
            if split not in {"train", "val", "test"} or media_class not in CLASS_TO_IDX:
                raise ValueError(f"Unexpected row in FF++ manifest: {row}")
            column = "image_path" if view == "face" else "full_image_path"
            relative_path = row.get(column, "").strip()
            if relative_path:
                rows.append(row)
                split_classes[split].add(media_class)
            try:
                source_ids = json.loads(row.get("source_video_ids", "[]"))
            except json.JSONDecodeError as exc:
                raise ValueError(f"Invalid source_video_ids in manifest row: {row}") from exc
            split_ids[split].update(str(value) for value in source_ids)

    if not rows:
        raise ValueError(f"No {view} images are listed in {manifest_path}.")
    for split in ("train", "val", "test"):
        if split_classes[split] != {"real", "fake"}:
            raise ValueError(
                f"{split} image manifest must contain both real and fake samples; found {sorted(split_classes[split])}."
            )
    for first, second in (("train", "val"), ("train", "test"), ("val", "test")):
        overlap = split_ids[first] & split_ids[second]
        if overlap:
            raise ValueError(
                f"Source-video leakage detected between {first} and {second}: {sorted(overlap)[:5]}"
            )
    return rows, root, manifest_path


def _transforms(image_size: int):
    train = transforms.Compose(
        [
            transforms.RandomResizedCrop(image_size, scale=(0.82, 1.0), ratio=(0.85, 1.18)),
            transforms.RandomHorizontalFlip(p=0.5),
            transforms.RandomApply([transforms.ColorJitter(0.08, 0.08, 0.06, 0.025)], p=0.45),
            transforms.RandomRotation(degrees=5),
            transforms.RandomApply([transforms.GaussianBlur(kernel_size=3, sigma=(0.1, 0.8))], p=0.12),
            JpegCompression(probability=0.25),
            transforms.ToTensor(),
            transforms.Normalize(IMAGE_MEAN, IMAGE_STD),
        ]
    )
    evaluate = transforms.Compose(
        [
            transforms.Resize(image_size + 32),
            transforms.CenterCrop(image_size),
            transforms.ToTensor(),
            transforms.Normalize(IMAGE_MEAN, IMAGE_STD),
        ]
    )
    return train, evaluate


def _check_source_video_separation(rows: list[dict[str, str]]) -> None:
    sources: dict[str, set[str]] = defaultdict(set)
    for row in rows:
        sources[row["split"]].update(str(item) for item in json.loads(row["source_video_ids"]))
    for first, second in (("train", "val"), ("train", "test"), ("val", "test")):
        overlap = sources[first] & sources[second]
        if overlap:
            raise ValueError(f"Source video ids cross {first}/{second}: {sorted(overlap)[:5]}.")


def _set_stage(model: nn.Module, architecture: str, stage: int, stage2_epoch: int = 0) -> None:
    if stage == 1:
        freeze_backbone(model, architecture)
    else:
        if stage2_epoch == 0:
            freeze_backbone(model, architecture)
        unfreeze_backbone_block(model, architecture, stage2_epoch)


def _optimizer(model: nn.Module, architecture: str, *, stage: int, learning_rate: float, weight_decay: float):
    head = classifier_head(model, architecture)
    head_ids = {id(parameter) for parameter in head.parameters()}
    head_parameters = [parameter for parameter in model.parameters() if parameter.requires_grad and id(parameter) in head_ids]
    backbone_parameters = [parameter for parameter in model.parameters() if id(parameter) not in head_ids]
    groups: list[dict[str, Any]] = [{"params": head_parameters, "lr": learning_rate}]
    if stage == 2 and backbone_parameters:
        groups.append({"params": backbone_parameters, "lr": learning_rate * 0.1})
    return torch.optim.AdamW(groups, weight_decay=weight_decay)


def _run_train_epoch(model, loader, loss_fn, optimizer, device, scaler, amp_enabled: bool) -> float:
    model.train()
    for module in model.modules():
        direct_parameters = list(module.parameters(recurse=False))
        if direct_parameters and not any(parameter.requires_grad for parameter in direct_parameters):
            module.eval()
    total_loss = 0.0
    total_items = 0
    for images, labels in loader:
        images = images.to(device, non_blocking=device.type == "cuda")
        labels = labels.to(device, non_blocking=device.type == "cuda")
        optimizer.zero_grad(set_to_none=True)
        with torch.autocast(device_type="cuda", dtype=torch.float16, enabled=amp_enabled):
            logits = model(images)
            loss = loss_fn(logits, labels)
        if amp_enabled:
            scaler.scale(loss).backward()
            scaler.step(optimizer)
            scaler.update()
        else:
            loss.backward()
            optimizer.step()
        total_loss += float(loss.detach().item()) * int(images.size(0))
        total_items += int(images.size(0))
    return total_loss / max(total_items, 1)


@torch.inference_mode()
def _predict_loader(model, loader, device, amp_enabled: bool) -> tuple[np.ndarray, np.ndarray, float]:
    model.eval()
    probabilities: list[torch.Tensor] = []
    targets: list[torch.Tensor] = []
    started = time.perf_counter()
    for images, labels in loader:
        images = images.to(device, non_blocking=device.type == "cuda")
        with torch.autocast(device_type="cuda", dtype=torch.float16, enabled=amp_enabled):
            logits = model(images)
        probabilities.append(torch.softmax(logits, dim=1)[:, CLASS_TO_IDX["fake"]].float().cpu())
        targets.append(labels.cpu())
    if device.type == "cuda":
        torch.cuda.synchronize(device)
    elapsed = time.perf_counter() - started
    target_array = torch.cat(targets).numpy().astype(np.int64)
    probability_array = torch.cat(probabilities).numpy().astype(np.float64)
    return target_array, probability_array, elapsed / max(len(target_array), 1)


def _save_checkpoint(path: Path, checkpoint: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    torch.save(checkpoint, temporary)
    temporary.replace(path)


def train_one_model(
    *,
    architecture: str,
    data_dir: Path,
    output_path: Path,
    report_path: Path,
    view: str,
    image_size: int,
    stage1_epochs: int,
    stage2_epochs: int,
    batch_size: int,
    workers: int,
    learning_rate: float,
    weight_decay: float,
    patience: int,
    seed: int,
) -> dict[str, Any]:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)
    else:
        requested_threads = os.getenv("DEEPSHIELD_CPU_THREADS")
        torch.set_num_threads(
            max(1, int(requested_threads)) if requested_threads else min(os.cpu_count() or 1, 6)
        )

    rows, manifest_root, manifest_path = read_prepared_rows(data_dir, view)
    preparation_report_path = manifest_path.parent / "preparation_report.json"
    preparation_report = (
        json.loads(preparation_report_path.read_text(encoding="utf-8"))
        if preparation_report_path.is_file() else {}
    )
    _check_source_video_separation(rows)
    train_rows = [row for row in rows if row["split"] == "train"]
    validation_rows = [row for row in rows if row["split"] == "val"]
    if not train_rows or not validation_rows:
        raise ValueError("Training needs non-empty official train and validation partitions.")
    train_transform, eval_transform = _transforms(image_size)
    train_dataset = ManifestImageDataset(train_rows, manifest_root, view, train_transform)
    validation_dataset = ManifestImageDataset(validation_rows, manifest_root, view, eval_transform)
    training_video_counts = Counter(row["source_video"] for row in train_rows)
    videos_per_class = {
        media_class: len({row["source_video"] for row in train_rows if row["class"] == media_class})
        for media_class in CLASS_TO_IDX
    }
    video_inventory: dict[str, set[str]] = defaultdict(set)
    for row in rows:
        video_inventory[
            f"{row['split']}_{row['class']}_{row['manipulation_type']}"
        ].add(row["source_video"])
    video_inventory_counts = {
        key: len(video_paths) for key, video_paths in sorted(video_inventory.items())
    }
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    hardware = {
        "platform": platform.platform(),
        "processor": platform.processor() or platform.machine(),
        "logical_cpu_count": os.cpu_count(),
        "torch_cpu_threads": torch.get_num_threads() if device.type == "cpu" else None,
        "device": str(device),
        "gpu_name": torch.cuda.get_device_name(device) if device.type == "cuda" else None,
        "gpu_total_memory_mb": (
            round(torch.cuda.get_device_properties(device).total_memory / (1024 * 1024), 2)
            if device.type == "cuda" else None
        ),
    }
    experiment_config = {
        "architecture": architecture,
        "dataset": preparation_report.get("dataset_source", "FaceForensics++"),
        "compression": preparation_report.get("compression", "unknown"),
        "official_split_commit": preparation_report.get("official_split_commit"),
        "manipulation_types": preparation_report.get("manipulation_types", []),
        "image_view": "face crop with full-frame fallback" if view == "face" else "full frame",
        "face_detection_threshold": float(
            preparation_report.get("sampling", {}).get("face_detection_threshold", 0.65)
        ),
        "image_size": image_size,
        "preprocessing_resolution": int(
            preparation_report.get("sampling", {}).get("resolution", image_size)
        ),
        "batch_size": batch_size,
        "optimizer": "AdamW",
        "learning_rate_head": learning_rate,
        "learning_rate_backbone": learning_rate * 0.1,
        "weight_decay": weight_decay,
        "scheduler": "ReduceLROnPlateau(mode=max, factor=0.25, patience=2)",
        "early_stopping_patience": patience,
        "configured_epochs": {
            "stage1_frozen_backbone": stage1_epochs,
            "stage2_gradual_unfreeze": stage2_epochs,
        },
        "augmentations": [
            "RandomResizedCrop(scale=0.82..1.0)",
            "HorizontalFlip(p=0.5)",
            "mild ColorJitter(p=0.45)",
            "mild RandomRotation(5 degrees)",
            "GaussianBlur(kernel=3, sigma=0.1..0.8, p=0.12)",
            "JPEG recompression(quality=78, 86, or 94; p=0.25)",
        ],
        "train_images": len(train_dataset),
        "validation_images": len(validation_dataset),
        "videos_by_split_class_and_manipulation": video_inventory_counts,
        "training_videos_by_class": videos_per_class,
        "training_sampling": "equal class weight and equal total weight per source video",
        "inference_timing_scope": (
            "prepared image loading, deterministic transforms, and classifier forward pass; "
            "excludes upload decoding and YuNet face detection"
        ),
        "seed": seed,
        "hardware": hardware,
    }
    sample_weights = [
        1.0 / (training_video_counts[row["source_video"]] * videos_per_class[row["class"]])
        for row in train_rows
    ]
    sampler = WeightedRandomSampler(
        torch.as_tensor(sample_weights, dtype=torch.double),
        num_samples=len(train_dataset),
        replacement=True,
        generator=torch.Generator().manual_seed(seed),
    )
    train_loader = DataLoader(
        train_dataset, batch_size=batch_size, sampler=sampler, num_workers=workers,
        pin_memory=torch.cuda.is_available(), persistent_workers=workers > 0,
    )
    validation_loader = DataLoader(
        validation_dataset, batch_size=batch_size, shuffle=False, num_workers=workers,
        pin_memory=torch.cuda.is_available(), persistent_workers=workers > 0,
    )

    amp_enabled = device.type == "cuda"
    model = build_model(pretrained=True, name=architecture).to(device)
    parameter_count = sum(parameter.numel() for parameter in model.parameters())
    loss_fn = nn.CrossEntropyLoss()
    scaler = torch.amp.GradScaler("cuda", enabled=amp_enabled)
    best_score: tuple[float, float] | None = None
    best_checkpoint: dict[str, Any] | None = None
    best_epoch = 0
    stale_epochs = 0
    history: list[dict[str, Any]] = []
    stage_boundary = max(stage1_epochs, 0)
    total_epochs = max(1, stage1_epochs + stage2_epochs)
    if stage_boundary == 0:
        stage = 2
        _set_stage(model, architecture, stage, stage2_epoch=0)
        optimizer = _optimizer(model, architecture, stage=stage, learning_rate=learning_rate, weight_decay=weight_decay)
    else:
        stage = 1
        _set_stage(model, architecture, stage)
        optimizer = _optimizer(model, architecture, stage=stage, learning_rate=learning_rate, weight_decay=weight_decay)
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode="max", factor=0.25, patience=2)
    if device.type == "cuda":
        torch.cuda.reset_peak_memory_stats(device)

    for epoch in range(total_epochs):
        if epoch < stage_boundary:
            stage = 1
            _set_stage(model, architecture, stage)
        else:
            stage2_epoch = epoch - stage_boundary
            if stage == 1:
                stage = 2
                _set_stage(model, architecture, stage, stage2_epoch=stage2_epoch)
                optimizer = _optimizer(
                    model, architecture, stage=stage, learning_rate=learning_rate, weight_decay=weight_decay
                )
                scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
                    optimizer, mode="max", factor=0.25, patience=2
                )
            else:
                _set_stage(model, architecture, stage, stage2_epoch=stage2_epoch)
        train_loss = _run_train_epoch(model, train_loader, loss_fn, optimizer, device, scaler, amp_enabled)
        targets, probabilities, seconds_per_image = _predict_loader(
            model, validation_loader, device, amp_enabled
        )
        threshold = choose_f1_threshold(targets, probabilities)
        validation_metrics = binary_metrics(targets, probabilities, threshold)
        validation_metrics["threshold"] = threshold
        validation_metrics["inference_seconds_per_image"] = seconds_per_image
        row = {
            "epoch": epoch + 1,
            "stage": stage,
            "train_loss": train_loss,
            "validation": validation_metrics,
        }
        history.append(row)
        print(
            f"{architecture} epoch {epoch + 1}/{total_epochs} stage={stage} "
            f"loss={train_loss:.4f} val_f1={validation_metrics['f1']:.4f} "
            f"val_auc={validation_metrics['roc_auc']} threshold={threshold:.4f}"
        )
        f1 = float(validation_metrics["f1"])
        auc = float(validation_metrics["roc_auc"] or 0.0)
        score = (f1, auc)
        if best_score is None or score > best_score:
            best_score = score
            best_epoch = epoch + 1
            stale_epochs = 0
            best_checkpoint = {
                "model_version": (
                    f"faceforensicspp-{architecture}-{preparation_report.get('compression', 'unknown')}-v1"
                ),
                "architecture": architecture,
                "state_dict": model.state_dict(),
                "class_to_idx": CLASS_TO_IDX,
                "threshold": threshold,
                "preprocessing_mode": "face_crop" if view == "face" else "full_frame",
                "face_detection_threshold": experiment_config["face_detection_threshold"],
                "input_size": image_size,
                "preprocessing_resolution": experiment_config["preprocessing_resolution"],
                "image_mean": IMAGE_MEAN,
                "image_std": IMAGE_STD,
                "dataset": preparation_report.get("dataset_source", "FaceForensics++"),
                "compression": preparation_report.get("compression", "unknown"),
                "official_split_commit": preparation_report.get("official_split_commit"),
                "preparation_report": str(preparation_report_path),
                "validation_metrics": validation_metrics,
                "parameters": parameter_count,
                "best_epoch": best_epoch,
                "seed": seed,
                "experiment": experiment_config,
            }
            _save_checkpoint(output_path, best_checkpoint)
        else:
            stale_epochs += 1
        if stage == 2:
            scheduler.step(f1)
            if stale_epochs >= patience:
                print(f"Early stopping {architecture} after {epoch + 1} epochs.")
                break

    if best_checkpoint is None:
        raise RuntimeError(f"No checkpoint was produced for {architecture}.")
    best_state = torch.load(output_path, map_location=device, weights_only=True)
    model.load_state_dict(best_state["state_dict"], strict=True)
    _, _, seconds_per_image = _predict_loader(model, validation_loader, device, amp_enabled)
    result = {
        "architecture": architecture,
        "view": view,
        "dataset": preparation_report.get("dataset_source", "FaceForensics++"),
        "compression": preparation_report.get("compression", "unknown"),
        "manipulation_types": preparation_report.get("manipulation_types", []),
        "face_detection_threshold": experiment_config["face_detection_threshold"],
        "train_images": len(train_dataset),
        "validation_images": len(validation_dataset),
        "videos_by_split_class_and_manipulation": video_inventory_counts,
        "training_videos_by_class": videos_per_class,
        "training_sampling": "equal class weight and equal total weight per source video",
        "parameters": parameter_count,
        "device": str(device),
        "hardware": hardware,
        "image_size": image_size,
        "batch_size": batch_size,
        "optimizer": "AdamW",
        "learning_rate_head": learning_rate,
        "learning_rate_backbone": learning_rate * 0.1,
        "weight_decay": weight_decay,
        "scheduler": "ReduceLROnPlateau(mode=max, factor=0.25, patience=2)",
        "early_stopping_patience": patience,
        "configured_epochs": experiment_config["configured_epochs"],
        "augmentations": experiment_config["augmentations"],
        "seed": seed,
        "experiment": experiment_config,
        "gpu_peak_memory_mb": (
            round(torch.cuda.max_memory_allocated(device) / (1024 * 1024), 2)
            if device.type == "cuda" else None
        ),
        "inference_seconds_per_image": seconds_per_image,
        "best_epoch": best_epoch,
        "best_validation_metrics": best_checkpoint["validation_metrics"],
        "checkpoint": str(output_path),
        "history": history,
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def finalize_best_model(results: list[dict[str, Any]], output_path: Path) -> dict[str, Any]:
    eligible = [result for result in results if result.get("best_validation_metrics")]
    if not eligible:
        raise ValueError("No trained model candidate has validation metrics.")
    best = max(
        eligible,
        key=lambda result: (
            float(result["best_validation_metrics"].get("f1", 0.0)),
            float(result["best_validation_metrics"].get("roc_auc") or 0.0),
            -float(result.get("inference_seconds_per_image", float("inf"))),
        ),
    )
    source = Path(best["checkpoint"])
    output_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, output_path)
    return {
        "selected_architecture": best["architecture"],
        "selected_view": best.get("view"),
        "source": str(source),
        "checkpoint": str(output_path),
    }


def write_comparison_csv(results: list[dict[str, Any]], path: Path) -> None:
    fields = [
        "Model", "Accuracy", "Precision", "Recall", "F1", "ROC-AUC", "PR-AUC",
        "Params", "Inference Time (s/image)", "GPU Peak Memory (MB)",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for result in results:
            metrics = result.get("best_validation_metrics", {})
            writer.writerow(
                {
                    "Model": f"{result.get('architecture')} ({result.get('view', 'face')})",
                    "Accuracy": metrics.get("accuracy"),
                    "Precision": metrics.get("precision"),
                    "Recall": metrics.get("recall"),
                    "F1": metrics.get("f1"),
                    "ROC-AUC": metrics.get("roc_auc"),
                    "PR-AUC": metrics.get("pr_auc"),
                    "Params": result.get("parameters"),
                    "Inference Time (s/image)": result.get("inference_seconds_per_image"),
                    "GPU Peak Memory (MB)": result.get("gpu_peak_memory_mb"),
                }
            )
