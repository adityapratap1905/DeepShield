"""Extract a small, video-separated FF++ frame set for image and video work."""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
import threading
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import cv2
from PIL import Image

MODEL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODEL_ROOT / "src"))

from deepshield_model.face_preprocessing import create_face_detector, detect_face_crops
from deepshield_model.ffpp_data import (
    MANIPULATIONS,
    VideoRecord,
    find_ffpp_root,
    iter_ffpp_videos,
    load_official_splits,
    read_sampled_frames,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-dir", type=Path, default=MODEL_ROOT / "data",
        help="Search this directory recursively for the FF++ dataset root.",
    )
    parser.add_argument("--dataset-root", type=Path, help="Use this FF++ root directly.")
    parser.add_argument(
        "--split-dir", type=Path, default=MODEL_ROOT / "data" / "splits" / "official"
    )
    parser.add_argument(
        "--output-dir", type=Path, default=MODEL_ROOT / "data" / "processed"
    )
    parser.add_argument("--compression", choices=("c23", "c40", "raw"), default="c23")
    parser.add_argument("--sampling-fps", type=float, default=1.0)
    parser.add_argument("--frames-per-video", type=int, default=8)
    parser.add_argument("--maximum-frames", type=int, default=8)
    parser.add_argument("--resolution", type=int, default=224)
    parser.add_argument("--face-threshold", type=float, default=0.65)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument(
        "--face-detector", type=Path,
        default=MODEL_ROOT / "artifacts" / "face_swap" / "yunet.onnx",
    )
    parser.add_argument(
        "--full-image-view", action=argparse.BooleanOptionalAction, default=True,
        help="Also save full-frame images under processed/full_images for validation comparison.",
    )
    parser.add_argument(
        "--max-videos-per-split", type=int,
        help="Optional deterministic cap for pipeline smoke checks; omitted means every assigned video.",
    )
    parser.add_argument(
        "--allow-incomplete-inventory", action="store_true",
        help="Prepare downloaded videos before every requested dataset is complete.",
    )
    parser.add_argument(
        "--resume", action="store_true",
        help="Reuse compatible manifests and process only videos not already prepared.",
    )
    return parser.parse_args()


def _padded_square(rgb: np.ndarray, resolution: int) -> Image.Image:
    image = Image.fromarray(rgb, mode="RGB")
    image.thumbnail((resolution, resolution), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (resolution, resolution), (127, 127, 127))
    canvas.paste(image, ((resolution - image.width) // 2, (resolution - image.height) // 2))
    return canvas


def _relative(path: Path, base: Path) -> str:
    return path.resolve().relative_to(base.resolve()).as_posix()


def _image_destination(output_dir: Path, split: str, media_class: str, video_id: str, frame_number: int) -> Path:
    return output_dir / "images" / split / media_class / f"{video_id}__frame_{frame_number:06d}.jpg"


def _write_video_rows(path: Path, rows: list[dict[str, object]]) -> None:
    fieldnames = [
        "video_id", "source_video", "source_video_ids", "class", "manipulation_type",
        "split", "compression", "fps", "total_frames", "width", "height", "sampled_frames",
        "selected_frame_numbers", "selected_frame_timestamps_seconds",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _write_image_rows(path: Path, rows: list[dict[str, object]]) -> None:
    fieldnames = [
        "image_path", "full_image_path", "source_video", "video_id", "source_video_ids",
        "frame_number", "frame_timestamp_seconds", "class", "manipulation_type", "split",
        "compression", "faces_detected", "faces_analyzed", "preprocessing_mode",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _cap_records(records: list[VideoRecord], maximum: int | None) -> list[VideoRecord]:
    if maximum is None:
        return records
    if maximum < 1:
        raise SystemExit("--max-videos-per-split must be positive when supplied.")
    counts = Counter()
    selected: list[VideoRecord] = []
    for record in records:
        key = (record.split, record.media_class)
        if counts[key] < maximum:
            selected.append(record)
            counts[key] += 1
    return selected


def _process_record(
    record: VideoRecord,
    *,
    dataset_root: Path,
    output_dir: Path,
    detector,
    args: argparse.Namespace,
) -> tuple[list[dict[str, object]], dict[str, object]]:
    frames, video_info = read_sampled_frames(
        record.video_path,
        sampling_fps=args.sampling_fps,
        frames_per_video=args.frames_per_video,
        maximum_frames=args.maximum_frames,
    )
    if not frames:
        raise ValueError("No decodable frames were available at the configured sampling rate.")
    image_rows: list[dict[str, object]] = []
    frame_face_count = 0
    no_face_count = 0
    multiple_face_count = 0
    faces_detected_total = 0
    for frame_number, timestamp, rgb in frames:
        faces = detect_face_crops(
            rgb,
            detector,
            detection_threshold=args.face_threshold,
            maximum_faces=100,
        )
        face_count = len(faces)
        faces_detected_total += face_count
        if face_count == 0:
            no_face_count += 1
            model_image = rgb
            preprocessing_mode = "full_frame_no_face"
        else:
            frame_face_count += 1
            if face_count > 1:
                multiple_face_count += 1
            # YuNet sorts by area; use the largest face once per frame to avoid
            # overweighting a video merely because it contains more people.
            model_image = faces[0][0]
            preprocessing_mode = "largest_face_with_context"

        output_video_id = f"{record.manipulation_type.casefold()}__{record.video_id}"
        image_path = _image_destination(
            output_dir, record.split, record.media_class, output_video_id, frame_number
        )
        image_path.parent.mkdir(parents=True, exist_ok=True)
        _padded_square(model_image, args.resolution).save(
            image_path, format="JPEG", quality=95, optimize=True
        )
        full_image_path: Path | None = None
        if args.full_image_view:
            full_image_path = (
                output_dir / "full_images" / record.split / record.media_class
                / f"{output_video_id}__frame_{frame_number:06d}.jpg"
            )
            full_image_path.parent.mkdir(parents=True, exist_ok=True)
            _padded_square(rgb, args.resolution).save(
                full_image_path, format="JPEG", quality=95, optimize=True
            )

        image_rows.append(
            {
                "image_path": _relative(image_path, output_dir),
                "full_image_path": _relative(full_image_path, output_dir) if full_image_path else "",
                "source_video": _relative(record.video_path, dataset_root),
                "video_id": record.video_id,
                "source_video_ids": json.dumps(record.source_ids),
                "frame_number": frame_number,
                "frame_timestamp_seconds": round(timestamp, 6),
                "class": record.media_class,
                "manipulation_type": record.manipulation_type,
                "split": record.split,
                "compression": record.compression,
                "faces_detected": face_count,
                "faces_analyzed": 1 if face_count else 0,
                "preprocessing_mode": preprocessing_mode,
            }
        )

    video_row: dict[str, object] = {
        "video_id": record.video_id,
        "source_video": _relative(record.video_path, dataset_root),
        "source_video_ids": json.dumps(record.source_ids),
        "class": record.media_class,
        "manipulation_type": record.manipulation_type,
        "split": record.split,
        "compression": record.compression,
        "fps": video_info["fps"],
        "total_frames": video_info["total_frames"],
        "width": video_info["width"],
        "height": video_info["height"],
        "sampled_frames": video_info["sampled_frames"],
        "selected_frame_numbers": json.dumps([frame_number for frame_number, _, _ in frames]),
        "selected_frame_timestamps_seconds": json.dumps(
            [round(timestamp, 6) for _, timestamp, _ in frames]
        ),
    }
    counters = {
        "sampled_frames": len(frames),
        "faces_detected_frames": frame_face_count,
        "face_crops_saved": frame_face_count,
        "no_face_frames": no_face_count,
        "multiple_face_frames": multiple_face_count,
        "faces_detected_total": faces_detected_total,
    }
    return image_rows, {"video": video_row, "counts": counters}


def _process_record_safely(
    record: VideoRecord,
    *,
    dataset_root: Path,
    output_dir: Path,
    args: argparse.Namespace,
    worker_state: threading.local,
) -> tuple[VideoRecord, tuple[list[dict[str, object]], dict[str, object]] | None, str | None]:
    try:
        detector = getattr(worker_state, "detector", None)
        if detector is None:
            detector = create_face_detector(args.face_detector, args.face_threshold)
            worker_state.detector = detector
        result = _process_record(
            record,
            dataset_root=dataset_root,
            output_dir=output_dir,
            detector=detector,
            args=args,
        )
        return record, result, None
    except (OSError, ValueError, cv2.error) as exc:
        return record, None, str(exc)


def main() -> None:
    args = parse_args()
    if args.frames_per_video < 1 or args.maximum_frames < 1 or args.resolution < 32 or args.workers < 1:
        raise SystemExit("Frame counts and --workers must be positive; --resolution must be at least 32.")
    if not math.isfinite(args.sampling_fps) or args.sampling_fps <= 0:
        raise SystemExit("--sampling-fps must be positive.")
    if not 0.0 < args.face_threshold <= 1.0:
        raise SystemExit("--face-threshold must be between zero and one.")

    dataset_root = args.dataset_root.resolve() if args.dataset_root else find_ffpp_root(args.data_dir)
    if not (dataset_root / "original_sequences").is_dir() or not (dataset_root / "manipulated_sequences").is_dir():
        raise SystemExit("--dataset-root must contain original_sequences/ and manipulated_sequences/.")

    splits, split_source = load_official_splits(args.split_dir)
    assignments = {video_id: split for split, pairs in splits.items() for pair in pairs for video_id in pair}
    records, inventory = iter_ffpp_videos(dataset_root, assignments, compression=args.compression)
    expected_inventory = {
        "Original": len(assignments),
        **{
            manipulation: sum(2 * len(pairs) for pairs in splits.values())
            for manipulation in MANIPULATIONS
        },
    }
    inventory["expected_included"] = expected_inventory
    incomplete = {
        name: {"expected": expected, "found": inventory["included"].get(name, 0)}
        for name, expected in expected_inventory.items()
        if inventory["included"].get(name, 0) != expected
    }
    if incomplete and not args.allow_incomplete_inventory:
        raise SystemExit(
            "The C23 FF++ download is incomplete for the official split inventory; "
            f"expected/found video counts by dataset: {incomplete}. Finish or resume the v4 download before preparation, "
            "or pass --allow-incomplete-inventory to prepare available videos incrementally."
        )
    records = _cap_records(records, args.max_videos_per_split)
    if not records:
        raise SystemExit(
            f"No {args.compression} FaceForensics++ videos matched the official split files under {dataset_root}."
        )

    output_dir = args.output_dir.resolve()
    image_rows: list[dict[str, object]] = []
    video_rows: list[dict[str, object]] = []
    errors_by_source: dict[str, dict[str, str]] = {}
    totals = Counter()

    if args.resume:
        report_path = output_dir / "preparation_report.json"
        video_manifest_path = output_dir / "video_manifest.csv"
        image_manifest_path = output_dir / "image_manifest.csv"
        if not all(path.is_file() for path in (report_path, video_manifest_path, image_manifest_path)):
            raise SystemExit("--resume requires existing preparation_report.json and both manifests.")
        previous_report = json.loads(report_path.read_text(encoding="utf-8"))
        previous_sampling = previous_report.get("sampling", {})
        requested_sampling = {
            "sampling_fps": args.sampling_fps,
            "frames_per_video": args.frames_per_video,
            "maximum_frames": args.maximum_frames,
            "resolution": args.resolution,
            "face_detection_threshold": args.face_threshold,
            "full_image_view_saved": args.full_image_view,
        }
        if (
            Path(previous_report.get("dataset_root", "")).resolve() != dataset_root.resolve()
            or previous_report.get("compression") != args.compression
            or previous_report.get("official_split_commit") != split_source.get("commit")
            or previous_report.get("max_videos_per_split") != args.max_videos_per_split
            or any(previous_sampling.get(key) != value for key, value in requested_sampling.items())
        ):
            raise SystemExit(
                "Existing preparation settings differ from this request; use a new --output-dir or rerun without --resume."
            )

        available_sources = {_relative(record.video_path, dataset_root) for record in records}
        with video_manifest_path.open(newline="", encoding="utf-8") as stream:
            video_rows = [
                row for row in csv.DictReader(stream)
                if row.get("source_video") in available_sources
            ]
        prepared_sources = {row["source_video"] for row in video_rows}
        with image_manifest_path.open(newline="", encoding="utf-8") as stream:
            image_rows = [
                row for row in csv.DictReader(stream)
                if row.get("source_video") in prepared_sources
            ]
        errors_by_source = {
            row["source_video"]: row
            for row in previous_report.get("video_errors", [])
            if row.get("source_video") in available_sources
        }
        for row in image_rows:
            face_count = int(row.get("faces_detected", 0))
            totals["sampled_frames"] += 1
            totals["faces_detected_frames"] += int(face_count > 0)
            totals["face_crops_saved"] += int(face_count > 0)
            totals["no_face_frames"] += int(face_count == 0)
            totals["multiple_face_frames"] += int(face_count > 1)
            totals["faces_detected_total"] += face_count

    processed_sources = {row["source_video"] for row in video_rows}
    records_to_process = [
        record for record in records
        if _relative(record.video_path, dataset_root) not in processed_sources
    ]

    create_face_detector(args.face_detector, args.face_threshold)  # fail before starting worker threads
    cv2.setNumThreads(1)
    worker_state = threading.local()
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        tasks = [
            pool.submit(
                _process_record_safely,
                record,
                dataset_root=dataset_root,
                output_dir=output_dir,
                args=args,
                worker_state=worker_state,
            )
            for record in records_to_process
        ]
    for index, (record, result, error) in enumerate(
            (task.result() for task in tasks), start=1
        ):
            source_video = _relative(record.video_path, dataset_root)
            if error is None and result is not None:
                rows, result = result
                image_rows.extend(rows)
                video_rows.append(result["video"])
                totals.update(result["counts"])
                errors_by_source.pop(source_video, None)
            else:
                errors_by_source[source_video] = {
                    "source_video": source_video,
                    "error": error or "Unknown processing error",
                }
            if index % 100 == 0 or index == len(records_to_process):
                print(
                    f"Processed {index}/{len(records_to_process)} pending videos; "
                    f"frames={totals['sampled_frames']}; errors={len(errors_by_source)}"
                )

    _write_image_rows(output_dir / "image_manifest.csv", image_rows)
    _write_video_rows(output_dir / "video_manifest.csv", video_rows)
    class_counts = Counter((row["split"], row["class"]) for row in video_rows)
    download_provenance_path = dataset_root / "download_provenance.json"
    download_provenance = (
        json.loads(download_provenance_path.read_text(encoding="utf-8"))
        if download_provenance_path.is_file() else None
    )
    report = {
        "dataset_root": str(dataset_root),
        "dataset_source": "FaceForensics++ only; no original FaceForensics v1 or DeepFakeDetection data included",
        "download_provenance": download_provenance,
        "official_repository": split_source.get("repository"),
        "official_split_commit": split_source.get("commit"),
        "compression": args.compression,
        "manipulation_types": list(MANIPULATIONS),
        "sampling": {
            "sampling_fps": args.sampling_fps,
            "frames_per_video": args.frames_per_video,
            "maximum_frames": args.maximum_frames,
            "resolution": args.resolution,
            "face_detection_threshold": args.face_threshold,
            "processing_workers": args.workers,
            "face_view": "largest detected face with 25 percent context; full-frame fallback when no face is detected",
            "full_image_view_saved": args.full_image_view,
        },
        "max_videos_per_split": args.max_videos_per_split,
        "inventory_complete": not incomplete,
        "official_split_method": (
            "Use the official train.json, val.json, and test.json pairs from ondyari/FaceForensics. "
            "Assign both original IDs in each pair to the same split; include a manipulated target_source video "
            "only when both IDs map to that same split. Exclude cross-split and unassigned pairs before frame extraction."
        ),
        "video_inventory": inventory,
        "videos_by_split_and_class": {
            f"{split}_{media_class}": count
            for (split, media_class), count in sorted(class_counts.items())
        },
        "videos_processed": len(video_rows),
        "frames_processed": len(image_rows),
        "faces_detected_frames": int(totals["faces_detected_frames"]),
        "face_crops_saved": int(totals["face_crops_saved"]),
        "no_face_frames": int(totals["no_face_frames"]),
        "multiple_face_frames": int(totals["multiple_face_frames"]),
        "faces_detected_total": int(totals["faces_detected_total"]),
        "video_errors": list(errors_by_source.values()),
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    (output_dir / "preparation_report.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({key: report[key] for key in (
        "videos_processed", "frames_processed", "face_crops_saved", "faces_detected_frames",
        "no_face_frames", "multiple_face_frames", "videos_by_split_and_class",
    )}, indent=2))
    print(f"Manifests and preparation report saved under {output_dir}")


if __name__ == "__main__":
    main()
