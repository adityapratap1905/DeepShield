"""FaceForensics++ discovery, official split loading, and safe frame sampling."""

from __future__ import annotations

import json
import os
import re
import urllib.request
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from hashlib import sha256
from pathlib import Path
from typing import Iterator

import cv2
import numpy as np

OFFICIAL_REPOSITORY = "https://github.com/ondyari/FaceForensics"
OFFICIAL_SPLIT_API = "https://api.github.com/repos/ondyari/FaceForensics/commits/master"
VIDEO_EXTENSIONS = {".mp4", ".avi", ".mov", ".mkv", ".webm"}
MANIPULATIONS = ("Deepfakes", "Face2Face", "FaceSwap", "NeuralTextures")
SPLIT_NAMES = ("train", "val", "test")
EXPECTED_SPLIT_IDS = {"train": 720, "val": 140, "test": 140}
VIDEO_ID_PATTERN = re.compile(r"^(\d{3})(?:_(\d{3}))?$")


@dataclass(frozen=True)
class VideoRecord:
    video_path: Path
    video_id: str
    split: str
    media_class: str
    manipulation_type: str
    source_ids: tuple[str, ...]
    compression: str


def _normalized_id(value: object) -> str:
    text = str(value).strip()
    if text.isdigit():
        return f"{int(text):03d}"
    raise ValueError(f"Invalid FaceForensics++ sequence id: {value!r}")


def _validate_splits(raw_splits: dict[str, list[list[object]]]) -> dict[str, list[tuple[str, str]]]:
    normalized: dict[str, list[tuple[str, str]]] = {}
    assignments: dict[str, str] = {}
    for split in SPLIT_NAMES:
        if split not in raw_splits:
            raise ValueError(f"Official split file {split}.json is missing.")
        pairs: list[tuple[str, str]] = []
        ids: set[str] = set()
        for row in raw_splits[split]:
            if not isinstance(row, list) or len(row) != 2:
                raise ValueError(f"Every {split} split row must contain two video ids.")
            first, second = (_normalized_id(value) for value in row)
            if first == second:
                raise ValueError(f"Official split contains a self-pair: {first}.")
            pairs.append((first, second))
            ids.update((first, second))
        expected = EXPECTED_SPLIT_IDS[split]
        if len(ids) != expected:
            raise ValueError(
                f"Official {split} split has {len(ids)} unique sequence ids; expected {expected}."
            )
        for video_id in ids:
            previous = assignments.setdefault(video_id, split)
            if previous != split:
                raise ValueError(f"Video id {video_id} occurs in both {previous} and {split}.")
        normalized[split] = pairs
    if len(assignments) != sum(EXPECTED_SPLIT_IDS.values()):
        raise ValueError("The official train/validation/test video ids are not disjoint.")
    return normalized


def load_official_splits(split_dir: Path) -> tuple[dict[str, list[tuple[str, str]]], dict[str, str]]:
    """Load the official split JSON files, fetching and caching them if absent."""
    split_dir.mkdir(parents=True, exist_ok=True)
    source_path = split_dir / "SOURCE.json"
    split_paths = {name: split_dir / f"{name}.json" for name in SPLIT_NAMES}
    source_exists = source_path.is_file()
    if not all(path.is_file() for path in split_paths.values()):
        request = urllib.request.Request(
            OFFICIAL_SPLIT_API,
            headers={"User-Agent": "DeepShield-FFPP-Pipeline"},
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            commit = json.load(response)["sha"]
        digests: dict[str, str] = {}
        for name, path in split_paths.items():
            url = (
                f"https://raw.githubusercontent.com/ondyari/FaceForensics/{commit}/"
                f"dataset/splits/{name}.json"
            )
            with urllib.request.urlopen(url, timeout=30) as response:
                payload = response.read()
            json.loads(payload)
            path.write_bytes(payload)
            digests[name] = sha256(payload).hexdigest()
        source_path.write_text(
            json.dumps(
                {
                    "repository": OFFICIAL_REPOSITORY,
                    "commit": commit,
                    "retrieved_at_utc": datetime.now(timezone.utc).isoformat(),
                    "sha256": digests,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        source_exists = True

    raw = {name: json.loads(path.read_text(encoding="utf-8")) for name, path in split_paths.items()}
    splits = _validate_splits(raw)
    source = json.loads(source_path.read_text(encoding="utf-8")) if source_exists else {
        "repository": OFFICIAL_REPOSITORY,
        "commit": "unknown-existing-local-splits",
    }
    recorded_hashes = source.get("sha256", {})
    for name, path in split_paths.items():
        payload = path.read_bytes()
        actual = sha256(payload).hexdigest()
        expected = recorded_hashes.get(name)
        # Git may normalize checked-in text to CRLF on Windows. Verify the
        # canonical LF form as well so checkout line endings do not invalidate
        # the pinned source files.
        canonical = sha256(payload.replace(b"\r\n", b"\n").replace(b"\r", b"\n")).hexdigest()
        if expected and actual != expected and canonical != expected:
            raise ValueError(f"Official {name}.json does not match SOURCE.json SHA-256.")
    return splits, source


def _split_assignments(splits: dict[str, list[tuple[str, str]]]) -> dict[str, str]:
    assignments: dict[str, str] = {}
    for split, pairs in splits.items():
        for first, second in pairs:
            assignments[first] = split
            assignments[second] = split
    return assignments


def find_ffpp_root(data_dir: Path) -> Path:
    """Find an FF++ root by structure without assuming its directory name."""
    data_dir = data_dir.resolve()
    if (data_dir / "original_sequences").is_dir() and (data_dir / "manipulated_sequences").is_dir():
        return data_dir
    if not data_dir.is_dir():
        raise FileNotFoundError(f"Dataset search directory does not exist: {data_dir}")
    for current, directories, _ in os.walk(data_dir):
        directories[:] = [
            name for name in directories
            if name.casefold() not in {"processed", "artifacts", ".git", "__pycache__"}
        ]
        path = Path(current)
        child_names = {child.name.casefold() for child in path.iterdir() if child.is_dir()}
        if {"original_sequences", "manipulated_sequences"}.issubset(child_names):
            return path
    raise FileNotFoundError(
        f"No FaceForensics++ root containing original_sequences/ and manipulated_sequences/ was found under {data_dir}."
    )


def iter_ffpp_videos(
    dataset_root: Path,
    assignments: dict[str, str],
    compression: str = "c23",
) -> tuple[list[VideoRecord], dict[str, object]]:
    """Inventory only FaceForensics++ original and requested manipulation videos."""
    dataset_root = dataset_root.resolve()
    records: list[VideoRecord] = []
    inventory: dict[str, object] = {
        "compression": compression,
        "video_files_seen": 0,
        "compression_counts": {},
        "included": {"Original": 0, **{name: 0 for name in MANIPULATIONS}},
        "skipped_cross_split_pairs": 0,
        "skipped_unassigned_ids": 0,
        "skipped_unknown_manipulations": 0,
        "skipped_non_ffpp_originals": 0,
    }
    compression_counts: dict[str, int] = {}

    for current, directories, files in os.walk(dataset_root):
        directories[:] = [
            name for name in directories
            if name.casefold() not in {"processed", "artifacts", ".git", "__pycache__"}
        ]
        folder = Path(current)
        parts = [part.casefold() for part in folder.relative_to(dataset_root).parts]
        for filename in files:
            video_path = folder / filename
            if video_path.suffix.casefold() not in VIDEO_EXTENSIONS:
                continue
            if "original_sequences" not in parts and "manipulated_sequences" not in parts:
                continue
            inventory["video_files_seen"] = int(inventory["video_files_seen"]) + 1
            compression_parts = [part for part in parts if part in {"raw", "c0", "c23", "c40"}]
            if compression_parts:
                version = compression_parts[-1]
                compression_counts[version] = compression_counts.get(version, 0) + 1
            if compression.casefold() not in parts:
                continue

            if "original_sequences" in parts:
                marker = parts.index("original_sequences")
                if "youtube" not in parts[marker + 1 :]:
                    inventory["skipped_non_ffpp_originals"] = int(inventory["skipped_non_ffpp_originals"]) + 1
                    continue
                match = VIDEO_ID_PATTERN.fullmatch(video_path.stem)
                if not match or match.group(2):
                    inventory["skipped_unassigned_ids"] = int(inventory["skipped_unassigned_ids"]) + 1
                    continue
                video_id = _normalized_id(match.group(1))
                split = assignments.get(video_id)
                if split is None:
                    inventory["skipped_unassigned_ids"] = int(inventory["skipped_unassigned_ids"]) + 1
                    continue
                records.append(
                    VideoRecord(video_path, video_id, split, "real", "Original", (video_id,), compression)
                )
                inventory["included"]["Original"] = int(inventory["included"]["Original"]) + 1
                continue

            marker = parts.index("manipulated_sequences")
            method = dataset_root.joinpath(*folder.relative_to(dataset_root).parts[marker + 1 : marker + 2]).name
            canonical_method = next(
                (name for name in MANIPULATIONS if name.casefold() == method.casefold()), None
            )
            if canonical_method is None:
                inventory["skipped_unknown_manipulations"] = int(inventory["skipped_unknown_manipulations"]) + 1
                continue
            match = VIDEO_ID_PATTERN.fullmatch(video_path.stem)
            if not match or not match.group(2):
                inventory["skipped_unassigned_ids"] = int(inventory["skipped_unassigned_ids"]) + 1
                continue
            first, second = _normalized_id(match.group(1)), _normalized_id(match.group(2))
            first_split, second_split = assignments.get(first), assignments.get(second)
            if first_split is None or second_split is None:
                inventory["skipped_unassigned_ids"] = int(inventory["skipped_unassigned_ids"]) + 1
                continue
            if first_split != second_split:
                inventory["skipped_cross_split_pairs"] = int(inventory["skipped_cross_split_pairs"]) + 1
                continue
            records.append(
                VideoRecord(
                    video_path,
                    video_path.stem,
                    first_split,
                    "fake",
                    canonical_method,
                    (first, second),
                    compression,
                )
            )
            inventory["included"][canonical_method] = int(inventory["included"][canonical_method]) + 1

    inventory["compression_counts"] = dict(sorted(compression_counts.items()))
    records.sort(key=lambda item: (item.split, item.media_class, item.manipulation_type, item.video_id))
    ids_by_split = {
        split: {source_id for record in records if record.split == split for source_id in record.source_ids}
        for split in SPLIT_NAMES
    }
    for index, split in enumerate(SPLIT_NAMES):
        for other in SPLIT_NAMES[index + 1 :]:
            overlap = ids_by_split[split] & ids_by_split[other]
            if overlap:
                raise ValueError(f"Source video leakage detected between {split} and {other}: {sorted(overlap)[:5]}.")
    return records, inventory


def sample_frame_indices(
    total_frames: int,
    source_fps: float,
    *,
    sampling_fps: float,
    frames_per_video: int,
    maximum_frames: int,
) -> list[int]:
    """Choose evenly distributed, unique frame indices without reading every frame."""
    if total_frames <= 0:
        return []
    if sampling_fps <= 0 or frames_per_video <= 0 or maximum_frames <= 0:
        raise ValueError("sampling_fps, frames_per_video, and maximum_frames must be positive.")
    duration = max(0.0, (total_frames - 1) / source_fps) if source_fps > 0 else 0.0
    fps_limited_count = max(1, int(np.floor(duration * sampling_fps)) + 1)
    count = min(total_frames, fps_limited_count, frames_per_video, maximum_frames)
    return np.unique(np.rint(np.linspace(0, total_frames - 1, count)).astype(np.int64)).tolist()


def read_sampled_frames(
    video_path: Path,
    *,
    sampling_fps: float,
    frames_per_video: int,
    maximum_frames: int,
) -> tuple[list[tuple[int, float, np.ndarray]], dict[str, float | int]]:
    """Read evenly spread frames with OpenCV, returning RGB arrays and source metadata."""
    capture = cv2.VideoCapture(str(video_path))
    try:
        if not capture.isOpened():
            raise ValueError(f"Video could not be opened: {video_path}")
        source_fps = float(capture.get(cv2.CAP_PROP_FPS) or 0.0)
        total_frames = int(capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH) or 0)
        height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT) or 0)
        indices = sample_frame_indices(
            total_frames,
            source_fps,
            sampling_fps=sampling_fps,
            frames_per_video=frames_per_video,
            maximum_frames=maximum_frames,
        )
        sampled: list[tuple[int, float, np.ndarray]] = []
        for frame_index in indices:
            capture.set(cv2.CAP_PROP_POS_FRAMES, int(frame_index))
            ok, bgr = capture.read()
            if not ok or bgr is None or bgr.size == 0:
                continue
            rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            timestamp = frame_index / source_fps if source_fps > 0 else 0.0
            sampled.append((int(frame_index), float(timestamp), rgb))
        return sampled, {
            "fps": source_fps,
            "total_frames": total_frames,
            "width": width,
            "height": height,
            "sampled_frames": len(sampled),
        }
    finally:
        capture.release()
