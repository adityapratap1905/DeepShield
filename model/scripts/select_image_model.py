"""Select the final image checkpoint from completed validation-only experiments."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

MODEL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODEL_ROOT / "src"))

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-dir", type=Path, default=MODEL_ROOT / "reports" / "image_experiments")
    parser.add_argument("--output-dir", type=Path, default=MODEL_ROOT / "artifacts")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    from deepshield_model.training import finalize_best_model, write_comparison_csv
    results = []
    for path in sorted(args.report_dir.glob("*.json")):
        result = json.loads(path.read_text(encoding="utf-8"))
        checkpoint = Path(result["checkpoint"])
        if checkpoint.is_file() and result.get("best_validation_metrics"):
            results.append(result)
    if not results:
        raise SystemExit(f"No completed image experiments with validation metrics found in {args.report_dir}.")
    comparison_path = MODEL_ROOT / "reports" / "image_model_comparison.csv"
    write_comparison_csv(results, comparison_path)
    selected = finalize_best_model(results, args.output_dir / "deepfake_image_best.pt")
    selection = {
        **selected,
        "selection_data": "official validation image frames only",
        "validation_metrics": next(
            item["best_validation_metrics"]
            for item in results
            if item["architecture"] == selected["selected_architecture"]
            and Path(item["checkpoint"]).resolve() == Path(selected["source"]).resolve()
        ),
        "comparison_csv": str(comparison_path),
    }
    (args.output_dir / "deepfake_image_selection.json").write_text(
        json.dumps(selection, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(selection, indent=2))


if __name__ == "__main__":
    main()
