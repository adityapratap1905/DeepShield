"""Binary deepfake metrics and validation-only threshold selection."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from sklearn.metrics import (
    accuracy_score,
    average_precision_score,
    confusion_matrix,
    precision_recall_curve,
    precision_score,
    recall_score,
    roc_auc_score,
    roc_curve,
)


def choose_f1_threshold(targets: list[int] | np.ndarray, fake_probabilities: list[float] | np.ndarray) -> float:
    """Choose the threshold with the highest fake-class F1 on supplied validation data."""
    y_true = np.asarray(targets, dtype=np.int64).reshape(-1)
    probabilities = np.asarray(fake_probabilities, dtype=np.float64).reshape(-1)
    if y_true.size == 0 or y_true.size != probabilities.size:
        raise ValueError("Threshold selection needs equally sized, non-empty targets and probabilities.")
    if not np.isfinite(probabilities).all():
        raise ValueError("Fake probabilities must be finite.")

    precision, recall, thresholds = precision_recall_curve(y_true, probabilities, pos_label=1)
    if thresholds.size == 0:
        return 0.5
    f1 = 2 * precision[:-1] * recall[:-1] / np.maximum(precision[:-1] + recall[:-1], 1e-12)
    best = np.flatnonzero(np.isclose(f1, np.nanmax(f1)))
    # Stable tie break: choose the value nearest 0.5, then the higher threshold.
    chosen_index = min(best, key=lambda index: (abs(float(thresholds[index]) - 0.5), -float(thresholds[index])))
    return float(thresholds[chosen_index])


def binary_metrics(
    targets: list[int] | np.ndarray,
    fake_probabilities: list[float] | np.ndarray,
    threshold: float,
) -> dict[str, float | int | list[list[int]] | None]:
    """Compute metrics with class 1 representing FAKE and class 0 representing REAL."""
    y_true = np.asarray(targets, dtype=np.int64).reshape(-1)
    probabilities = np.asarray(fake_probabilities, dtype=np.float64).reshape(-1)
    if y_true.size == 0 or y_true.size != probabilities.size:
        raise ValueError("Metrics need equally sized, non-empty targets and probabilities.")
    if not np.isfinite(probabilities).all():
        raise ValueError("Fake probabilities must be finite.")
    if not 0.0 <= threshold <= 1.0:
        raise ValueError("Threshold must be between zero and one.")

    predictions = (probabilities >= threshold).astype(np.int64)
    matrix = confusion_matrix(y_true, predictions, labels=[0, 1])
    true_real, false_fake = (int(value) for value in matrix[0])
    false_real, true_fake = (int(value) for value in matrix[1])
    positives = true_fake + false_real
    negatives = true_real + false_fake
    metrics: dict[str, float | int | list[list[int]] | None] = {
        "samples": int(y_true.size),
        "accuracy": float(accuracy_score(y_true, predictions)),
        "precision": float(precision_score(y_true, predictions, pos_label=1, zero_division=0)),
        "recall": float(recall_score(y_true, predictions, pos_label=1, zero_division=0)),
        "f1": float(2 * true_fake / max(2 * true_fake + false_fake + false_real, 1)),
        "roc_auc": float(roc_auc_score(y_true, probabilities)) if np.unique(y_true).size == 2 else None,
        "pr_auc": float(average_precision_score(y_true, probabilities)) if positives else None,
        "false_positive_rate": float(false_fake / max(negatives, 1)),
        "false_negative_rate": float(false_real / max(positives, 1)),
        "confusion_matrix_real_fake": matrix.astype(int).tolist(),
    }
    return metrics


def write_curves(
    targets: list[int] | np.ndarray,
    fake_probabilities: list[float] | np.ndarray,
    output_dir: Path,
    label: str,
) -> None:
    """Write ROC and precision-recall plots when both classes are present."""
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    y_true = np.asarray(targets, dtype=np.int64).reshape(-1)
    probabilities = np.asarray(fake_probabilities, dtype=np.float64).reshape(-1)
    output_dir.mkdir(parents=True, exist_ok=True)
    if np.unique(y_true).size != 2:
        return

    fpr, tpr, _ = roc_curve(y_true, probabilities, pos_label=1)
    fig, axis = plt.subplots(figsize=(5, 4))
    axis.plot(fpr, tpr, label=f"ROC-AUC {roc_auc_score(y_true, probabilities):.3f}")
    axis.plot([0, 1], [0, 1], linestyle="--", color="#888888")
    axis.set(xlabel="False positive rate", ylabel="True positive rate", title=f"{label} ROC")
    axis.legend(loc="lower right")
    fig.tight_layout()
    fig.savefig(output_dir / f"{label.lower()}_roc.png", dpi=150)
    plt.close(fig)

    precision, recall, _ = precision_recall_curve(y_true, probabilities, pos_label=1)
    fig, axis = plt.subplots(figsize=(5, 4))
    axis.plot(recall, precision, label=f"PR-AUC {average_precision_score(y_true, probabilities):.3f}")
    axis.set(xlabel="Recall", ylabel="Precision", title=f"{label} precision-recall")
    axis.legend(loc="lower left")
    fig.tight_layout()
    fig.savefig(output_dir / f"{label.lower()}_pr.png", dpi=150)
    plt.close(fig)


def write_confusion_matrix(
    targets: list[int] | np.ndarray,
    fake_probabilities: list[float] | np.ndarray,
    threshold: float,
    destination: Path,
    title: str,
) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    y_true = np.asarray(targets, dtype=np.int64).reshape(-1)
    predictions = (np.asarray(fake_probabilities, dtype=np.float64).reshape(-1) >= threshold).astype(np.int64)
    matrix = confusion_matrix(y_true, predictions, labels=[0, 1])
    destination.parent.mkdir(parents=True, exist_ok=True)
    fig, axis = plt.subplots(figsize=(4.5, 4))
    image = axis.imshow(matrix, cmap="Blues")
    fig.colorbar(image, ax=axis, fraction=0.046, pad=0.04)
    axis.set_xticks([0, 1], labels=["REAL", "FAKE"])
    axis.set_yticks([0, 1], labels=["REAL", "FAKE"])
    axis.set_xlabel("Predicted")
    axis.set_ylabel("Actual")
    axis.set_title(title)
    for row in range(2):
        for column in range(2):
            axis.text(column, row, str(int(matrix[row, column])), ha="center", va="center")
    fig.tight_layout()
    fig.savefig(destination, dpi=150)
    plt.close(fig)
