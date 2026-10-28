"""Compare frame aggregations and calibrate video decisions using FF++ videos."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import math
import platform
import sys
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
import torch

MODEL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODEL_ROOT / "src"))

from deepshield_model.metrics import binary_metrics, choose_f1_threshold, write_confusion_matrix, write_curves
from deepshield_model.multimedia_inference import (
    VIDEO_AGGREGATIONS,
    DeepfakeImageClassifier,
    aggregate_frame_probabilities,
)
from deepshield_model.ffpp_data import read_sampled_frames


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--split", choices=("val", "test"), required=True)
    parser.add_argument(
        "--video-manifest", type=Path, default=MODEL_ROOT / "data" / "processed" / "video_manifest.csv"
    )
    parser.add_argument(
        "--preparation-report", type=Path,
        default=MODEL_ROOT / "data" / "processed" / "preparation_report.json",
    )
    parser.add_argument(
        "--image-checkpoint", type=Path,
        default=MODEL_ROOT / "artifacts" / "deepfake_image_best.pt",
    )
    parser.add_argument(
        "--face-detector", type=Path,
        default=MODEL_ROOT / "artifacts" / "face_swap" / "yunet.onnx",
    )
    parser.add_argument(
        "--video-config", type=Path,
        default=MODEL_ROOT / "artifacts" / "deepfake_video_config.json",
    )
    parser.add_argument("--output-dir", type=Path, default=MODEL_ROOT / "reports" / "video")
    parser.add_argument("--sampling-fps", type=float, default=1.0)
    parser.add_argument("--frames-per-video", type=int, default=8)
    parser.add_argument("--maximum-frames", type=int, default=8)
    parser.add_argument("--minimum-frames", type=int, default=3)
    parser.add_argument("--top-k-fraction", type=float, default=0.2)
    return parser.parse_args()


def _read_rows(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise SystemExit(f"Video manifest not found: {path}. Run scripts/prepare_ffpp.py first.")
    with path.open("r", newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def _check_video_split_ids(rows: list[dict[str, str]]) -> None:
    by_split: dict[str, set[str]] = defaultdict(set)
    for row in rows:
        try:
            ids = json.loads(row["source_video_ids"])
        except (KeyError, json.JSONDecodeError) as exc:
            raise ValueError("Video manifest is missing valid source_video_ids metadata.") from exc
        by_split[row["split"]].update(str(value) for value in ids)
    for first, second in (("train", "val"), ("train", "test"), ("val", "test")):
        overlap = by_split[first] & by_split[second]
        if overlap:
            raise ValueError(f"Source videos cross {first}/{second}: {sorted(overlap)[:5]}.")


def _evaluate_rows(args: argparse.Namespace, rows: list[dict[str, str]], image_classifier):
    preparation = json.loads(args.preparation_report.read_text(encoding="utf-8"))
    dataset_root = Path(preparation["dataset_root"])
    chosen_rows = [row for row in rows if row.get("split") == args.split]
    if not chosen_rows:
        raise SystemExit(f"No {args.split} videos were found in {args.video_manifest}.")
    labels: list[int] = []
    probabilities_by_method = {method: [] for method in VIDEO_AGGREGATIONS}
    video_outputs: list[dict[str, object]] = []
    errors: list[dict[str, str]] = []
    no_face_frames = 0
    start = time.perf_counter()
    image_threshold = image_classifier.threshold

    for index, row in enumerate(chosen_rows, start=1):
        video_path = dataset_root / Path(row["source_video"])
        try:
            frames, _ = read_sampled_frames(
                video_path,
                sampling_fps=args.sampling_fps,
                frames_per_video=args.frames_per_video,
                maximum_frames=args.maximum_frames,
            )
            if len(frames) < args.minimum_frames:
                errors.append(
                    {"video_id": row.get("video_id", ""), "error": f"Only {len(frames)} usable frames; minimum is {args.minimum_frames}."}
                )
                continue
            frame_predictions = image_classifier.predict_rgb_batch([rgb for _, _, rgb in frames])
            frame_probabilities = [prediction.fake_probability for prediction in frame_predictions]
            no_face_frames += sum(prediction.faces_detected == 0 for prediction in frame_predictions)
            method_values = {
                method: aggregate_frame_probabilities(
                    frame_probabilities,
                    method,
                    image_threshold=image_threshold,
                    top_k_fraction=args.top_k_fraction,
                )
                for method in VIDEO_AGGREGATIONS
            }
            labels.append(1 if row["class"].casefold() == "fake" else 0)
            for method in VIDEO_AGGREGATIONS:
                probabilities_by_method[method].append(method_values[method])
            video_outputs.append(
                {
                    "video_id": row["video_id"],
                    "class": row["class"],
                    "manipulation_type": row["manipulation_type"],
                    "split": args.split,
                    "frames_analyzed": len(frame_probabilities),
                    "selected_frame_numbers": [frame_number for frame_number, _, _ in frames],
                    "selected_frame_timestamps_seconds": [
                        round(timestamp, 6) for _, timestamp, _ in frames
                    ],
                    "frame_fake_probabilities": frame_probabilities,
                    **{f"{method}_fake_probability": value for method, value in method_values.items()},
                }
            )
        except Exception as exc:  # Preserve the bad file and report it without inventing a score.
            errors.append({"video_id": row.get("video_id", ""), "error": str(exc)})
        if index % 50 == 0 or index == len(chosen_rows):
            print(f"Scored {index}/{len(chosen_rows)} {args.split} videos; usable={len(labels)}; errors={len(errors)}")

    elapsed = time.perf_counter() - start
    if not labels:
        raise SystemExit(f"No {args.split} videos could be evaluated; no metrics were produced.")
    return labels, probabilities_by_method, video_outputs, errors, no_face_frames, elapsed


def _write_comparison(path: Path, methods: list[dict[str, object]]) -> None:
    fields = [
        "Method", "Accuracy", "Precision", "Recall", "F1", "ROC-AUC", "PR-AUC",
        "False Positive Rate", "False Negative Rate", "Videos", "Frames", "Inference Time (s/video)", "Threshold",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for result in methods:
            metrics = result["metrics"]
            writer.writerow(
                {
                    "Method": result["method"],
                    "Accuracy": metrics["accuracy"],
                    "Precision": metrics["precision"],
                    "Recall": metrics["recall"],
                    "F1": metrics["f1"],
                    "ROC-AUC": metrics["roc_auc"],
                    "PR-AUC": metrics["pr_auc"],
                    "False Positive Rate": metrics["false_positive_rate"],
                    "False Negative Rate": metrics["false_negative_rate"],
                    "Videos": metrics["samples"],
                    "Frames": result["frames_analyzed"],
                    "Inference Time (s/video)": result["inference_seconds_per_video"],
                    "Threshold": result["threshold"],
                }
            )


def main() -> None:
    args = parse_args()
    if min(args.frames_per_video, args.maximum_frames, args.minimum_frames) < 1:
        raise SystemExit("Frame limits must be positive.")
    if (
        not math.isfinite(args.sampling_fps)
        or args.sampling_fps <= 0
        or not math.isfinite(args.top_k_fraction)
        or not 0 < args.top_k_fraction <= 1
    ):
        raise SystemExit("Sampling FPS and top-k fraction must be positive.")
    if not args.image_checkpoint.is_file():
        raise SystemExit(f"Image checkpoint not found: {args.image_checkpoint}")
    rows = _read_rows(args.video_manifest)
    _check_video_split_ids(rows)
    if args.split == "test" and not args.video_config.is_file():
        raise SystemExit("Video config is missing. Calibrate aggregation and threshold with --split val first.")
    if args.split == "test":
        config = json.loads(args.video_config.read_text(encoding="utf-8"))
        actual_hash = hashlib.sha256(args.image_checkpoint.read_bytes()).hexdigest()
        if config.get("image_checkpoint_sha256") != actual_hash:
            raise SystemExit("Video validation config was selected for a different image checkpoint.")
        expected_sampling = {
            "sampling_fps": args.sampling_fps,
            "frames_per_video": args.frames_per_video,
            "maximum_frames": args.maximum_frames,
            "minimum_frames": args.minimum_frames,
            "top_k_fraction": args.top_k_fraction,
        }
        mismatched_sampling = {
            key: {"configured": config.get(key), "requested": requested}
            for key, requested in expected_sampling.items()
            if config.get(key) != requested
        }
        if mismatched_sampling:
            raise SystemExit(
                "Test sampling settings differ from validation calibration: "
                f"{mismatched_sampling}. Rerun with the validation settings."
            )

    image_classifier = DeepfakeImageClassifier(args.image_checkpoint, args.face_detector)
    preparation = json.loads(args.preparation_report.read_text(encoding="utf-8"))
    if args.split == "test" and config.get("face_detection_threshold") != image_classifier.detection_threshold:
        raise SystemExit("Video validation config uses a different face-detection threshold.")
    if image_classifier.device.type == "cuda":
        torch.cuda.reset_peak_memory_stats(image_classifier.device)
    labels, probabilities_by_method, video_outputs, errors, no_face_frames, elapsed = _evaluate_rows(
        args, rows, image_classifier
    )
    inference_seconds_per_video = elapsed / max(len(labels), 1)
    if image_classifier.device.type == "cuda":
        torch.cuda.synchronize(image_classifier.device)
    gpu_peak_memory_mb = (
        round(torch.cuda.max_memory_allocated(image_classifier.device) / (1024 * 1024), 2)
        if image_classifier.device.type == "cuda" else None
    )
    methods: list[dict[str, object]] = []

    if args.split == "val":
        thresholds = {
            method: choose_f1_threshold(labels, probabilities_by_method[method])
            for method in VIDEO_AGGREGATIONS
        }
        for method in VIDEO_AGGREGATIONS:
            metrics = binary_metrics(labels, probabilities_by_method[method], thresholds[method])
            methods.append(
                {
                    "method": method,
                    "threshold": thresholds[method],
                    "metrics": metrics,
                    "frames_analyzed": sum(int(item["frames_analyzed"]) for item in video_outputs),
                    "inference_seconds_per_video": inference_seconds_per_video,
                }
            )
        selected = max(
            methods,
            key=lambda item: (
                float(item["metrics"]["f1"]),
                float(item["metrics"]["roc_auc"] or 0.0),
                -float(item["inference_seconds_per_video"]),
            ),
        )
        config = {
            "dataset": "FaceForensics++",
            "compression": preparation.get("compression", "unknown"),
            "official_split_commit": preparation.get("official_split_commit"),
            "aggregation_method": selected["method"],
            "threshold": selected["threshold"],
            "aggregation_thresholds": thresholds,
            "image_threshold": image_classifier.threshold,
            "face_detection_threshold": image_classifier.detection_threshold,
            "sampling_fps": args.sampling_fps,
            "frames_per_video": args.frames_per_video,
            "maximum_frames": args.maximum_frames,
            "minimum_frames": args.minimum_frames,
            "top_k_fraction": args.top_k_fraction,
            "selected_on": "official validation videos only",
            "validation_metrics": selected["metrics"],
            "image_checkpoint": str(args.image_checkpoint.resolve()),
            "image_checkpoint_sha256": hashlib.sha256(args.image_checkpoint.read_bytes()).hexdigest(),
            "temporal_model": None,
            "temporal_model_status": "not trained: this machine has no CUDA GPU",
        }
        args.video_config.parent.mkdir(parents=True, exist_ok=True)
        args.video_config.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
        results = {
            "split": "validation",
            "thresholds_tuned_on_this_split": True,
            "selected_method": selected["method"],
            "methods": methods,
            "videos_scored": len(labels),
            "video_errors": errors,
            "no_face_frames": no_face_frames,
            "video_config": str(args.video_config),
        }
    else:
        config = json.loads(args.video_config.read_text(encoding="utf-8"))
        thresholds = config.get("aggregation_thresholds", {})
        selected_method = config["aggregation_method"]
        for method in VIDEO_AGGREGATIONS:
            threshold = float(thresholds[method])
            metrics = binary_metrics(labels, probabilities_by_method[method], threshold)
            methods.append(
                {
                    "method": method,
                    "threshold": threshold,
                    "metrics": metrics,
                    "frames_analyzed": sum(int(item["frames_analyzed"]) for item in video_outputs),
                    "inference_seconds_per_video": inference_seconds_per_video,
                }
            )
        selected = next(item for item in methods if item["method"] == selected_method)
        results = {
            "split": "test",
            "thresholds_tuned_on_this_split": False,
            "selected_method_from_validation": selected_method,
            "selected_video_threshold_from_validation": selected["threshold"],
            "selected_metrics": selected["metrics"],
            "methods": methods,
            "videos_scored": len(labels),
            "video_errors": errors,
            "no_face_frames": no_face_frames,
        }
        write_confusion_matrix(
            labels,
            probabilities_by_method[selected_method],
            float(selected["threshold"]),
            args.output_dir / "video_test_confusion_matrix.png",
            "Video test",
        )
        write_curves(labels, probabilities_by_method[selected_method], args.output_dir, "Video test")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    requested_video_count = sum(row.get("split") == args.split for row in rows)
    results["videos_requested"] = requested_video_count
    results["videos_excluded_due_to_errors"] = len(errors)
    results["experiment"] = {
        "image_encoder": image_classifier.architecture,
        "image_model_version": image_classifier.model_version,
        "image_checkpoint": str(args.image_checkpoint.resolve()),
        "image_checkpoint_sha256": hashlib.sha256(args.image_checkpoint.read_bytes()).hexdigest(),
        "dataset": preparation.get("dataset_source", "FaceForensics++"),
        "compression": preparation.get("compression", "unknown"),
        "official_split_commit": preparation.get("official_split_commit"),
        "manipulation_types": preparation.get("manipulation_types", []),
        "split": args.split,
        "frame_sampling_method": "evenly spaced frames constrained by sampling FPS and frame limits",
        "sampling_fps": args.sampling_fps,
        "frames_per_video": args.frames_per_video,
        "maximum_frames": args.maximum_frames,
        "minimum_frames": args.minimum_frames,
        "top_k_fraction": args.top_k_fraction,
        "face_detection_threshold": image_classifier.detection_threshold,
        "thresholds_tuned_on_this_split": args.split == "val",
        "inference_seconds_per_video": inference_seconds_per_video,
        "gpu_peak_memory_mb": gpu_peak_memory_mb,
        "hardware": {
            "platform": platform.platform(),
            "processor": platform.processor() or platform.machine(),
            "logical_cpu_count": os.cpu_count(),
            "device": str(image_classifier.device),
            "gpu_name": (
                torch.cuda.get_device_name(image_classifier.device)
                if image_classifier.device.type == "cuda" else None
            ),
        },
    }
    (args.output_dir / f"video_{args.split}_results.json").write_text(
        json.dumps(results, indent=2) + "\n", encoding="utf-8"
    )
    (args.output_dir / f"video_{args.split}_predictions.json").write_text(
        json.dumps(video_outputs, indent=2) + "\n", encoding="utf-8"
    )
    _write_comparison(args.output_dir / f"video_{args.split}_model_comparison.csv", methods)
    if args.split == "val":
        write_confusion_matrix(
            labels,
            probabilities_by_method[selected["method"]],
            float(selected["threshold"]),
            args.output_dir / "video_val_confusion_matrix.png",
            "Video validation",
        )
        write_curves(labels, probabilities_by_method[selected["method"]], args.output_dir, "Video validation")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
