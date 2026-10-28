"""Run local image or video inference with the selected FF++ model."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path

MODEL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODEL_ROOT / "src"))

from deepshield_model.multimedia_inference import DeepfakeImageClassifier, DeepfakeVideoAnalyzer

SUPPORTED_VIDEO_SUFFIXES = {".mp4", ".mov", ".avi", ".mkv", ".webm"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--media", choices=("image", "video"), required=True)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument(
        "--checkpoint", type=Path, default=MODEL_ROOT / "artifacts" / "deepfake_image_best.pt"
    )
    parser.add_argument(
        "--face-detector", type=Path, default=MODEL_ROOT / "artifacts" / "face_swap" / "yunet.onnx"
    )
    parser.add_argument(
        "--video-config", type=Path, default=MODEL_ROOT / "artifacts" / "deepfake_video_config.json"
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if not args.input.is_file():
        raise SystemExit(f"Input file not found: {args.input}")
    classifier = DeepfakeImageClassifier(args.checkpoint, args.face_detector)
    if args.media == "image":
        prediction = classifier.predict_image_bytes(args.input.read_bytes())
        result = asdict(prediction)
        result["model_version"] = classifier.model_version
        result["confidence_is_calibrated"] = False
    else:
        if args.input.suffix.casefold() not in SUPPORTED_VIDEO_SUFFIXES:
            raise SystemExit(f"Unsupported video format: {args.input.suffix or '(no extension)'}")
        analyzer = DeepfakeVideoAnalyzer(classifier, args.video_config)
        prediction = analyzer.predict_video(args.input)
        result = asdict(prediction)
        result["model_version"] = classifier.model_version
        result["confidence_is_calibrated"] = False
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
