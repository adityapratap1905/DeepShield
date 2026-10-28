"""Train and compare ImageNet-initialized image detectors on prepared FF++ frames."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

MODEL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODEL_ROOT / "src"))

from deepshield_model.architecture import ARCHITECTURES


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-dir", type=Path, default=MODEL_ROOT / "data" / "processed" / "images",
        help="Prepared face-crop data root. Use processed/full_images to train on full frames.",
    )
    parser.add_argument("--view", choices=("face", "full"), default="face")
    parser.add_argument(
        "--architectures", nargs="+", choices=ARCHITECTURES,
        default=["resnet18", "efficientnet_b0", "convnext_tiny"],
    )
    parser.add_argument("--output-dir", type=Path, default=MODEL_ROOT / "artifacts")
    parser.add_argument("--report-dir", type=Path, default=MODEL_ROOT / "reports")
    parser.add_argument("--image-size", type=int, default=224)
    parser.add_argument("--stage1-epochs", type=int, default=2)
    parser.add_argument("--stage2-epochs", type=int, default=8)
    parser.add_argument("--batch-size", type=int, default=4)
    parser.add_argument("--workers", type=int, default=0)
    parser.add_argument("--learning-rate", type=float, default=3e-4)
    parser.add_argument("--weight-decay", type=float, default=1e-2)
    parser.add_argument("--patience", type=int, default=4)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument(
        "--allow-cpu-convnext", action="store_true",
        help="Allow the slow ConvNeXt-Tiny experiment on CPU; it is skipped by default without CUDA.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.stage1_epochs < 0 or args.stage2_epochs < 1:
        raise SystemExit("--stage1-epochs must be non-negative and --stage2-epochs must be positive.")
    if args.batch_size < 1 or args.workers < 0 or args.image_size < 64:
        raise SystemExit("Use a positive batch size, non-negative workers, and image size of at least 64.")
    if args.patience < 1 or args.learning_rate <= 0 or args.weight_decay < 0:
        raise SystemExit("Invalid optimizer or early-stopping settings.")

    import torch
    from deepshield_model.training import finalize_best_model, train_one_model, write_comparison_csv

    selected_architectures = list(dict.fromkeys(args.architectures))
    if not torch.cuda.is_available() and not args.allow_cpu_convnext:
        skipped = [name for name in selected_architectures if name == "convnext_tiny"]
        selected_architectures = [name for name in selected_architectures if name != "convnext_tiny"]
        if skipped:
            print("Skipping ConvNeXt-Tiny because CUDA is unavailable; pass --allow-cpu-convnext to override.")
    if not selected_architectures:
        raise SystemExit("No model architecture is eligible for this machine.")

    results = []
    for architecture in selected_architectures:
        candidate_path = args.output_dir / f"deepfake_image_{args.view}_{architecture}_candidate.pt"
        report_path = args.report_dir / "image_experiments" / f"{args.view}_{architecture}.json"
        result = train_one_model(
            architecture=architecture,
            data_dir=args.data_dir,
            output_path=candidate_path,
            report_path=report_path,
            view=args.view,
            image_size=args.image_size,
            stage1_epochs=args.stage1_epochs,
            stage2_epochs=args.stage2_epochs,
            batch_size=args.batch_size,
            workers=args.workers,
            learning_rate=args.learning_rate,
            weight_decay=args.weight_decay,
            patience=args.patience,
            seed=args.seed,
        )
        results.append(result)

    args.report_dir.mkdir(parents=True, exist_ok=True)
    comparison_path = args.report_dir / "image_model_comparison.csv"
    write_comparison_csv(results, comparison_path)
    (args.report_dir / "image_model_comparison.json").write_text(
        json.dumps(results, indent=2) + "\n", encoding="utf-8"
    )
    selected = finalize_best_model(results, args.output_dir / "deepfake_image_best.pt")
    print(json.dumps({"selected": selected, "comparison_csv": str(comparison_path)}, indent=2))


if __name__ == "__main__":
    main()
