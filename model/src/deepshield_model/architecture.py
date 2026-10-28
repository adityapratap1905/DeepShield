"""Image encoder definitions shared by training and inference."""

from __future__ import annotations

from torch import nn

ARCHITECTURES = ("resnet18", "efficientnet_b0", "convnext_tiny")


def build_model(*, pretrained: bool, name: str = "resnet18") -> nn.Module:
    """Build a two-class ImageNet model with an explicit fake/real output head.

    The pretrained weights always come from TorchVision's ImageNet weights.
    This function intentionally has no custom-checkpoint loading path.
    """
    try:
        from torchvision import models
    except ImportError as exc:  # pragma: no cover - environment dependent
        raise RuntimeError(
            "Image training requires TorchVision. Install the model training extras "
            "with `python -m pip install -e \".[train]\"`."
        ) from exc

    if name == "resnet18":
        weights = models.ResNet18_Weights.DEFAULT if pretrained else None
        model = models.resnet18(weights=weights)
        model.fc = nn.Linear(model.fc.in_features, 2)
    elif name == "efficientnet_b0":
        weights = models.EfficientNet_B0_Weights.DEFAULT if pretrained else None
        model = models.efficientnet_b0(weights=weights)
        model.classifier[1] = nn.Linear(model.classifier[1].in_features, 2)
    elif name == "convnext_tiny":
        weights = models.ConvNeXt_Tiny_Weights.DEFAULT if pretrained else None
        model = models.convnext_tiny(weights=weights)
        model.classifier[2] = nn.Linear(model.classifier[2].in_features, 2)
    else:
        raise ValueError(f"Unsupported architecture {name!r}. Choose from {ARCHITECTURES}.")
    return model


def classifier_head(model: nn.Module, name: str) -> nn.Module:
    """Return the trainable classification head for a supported model."""
    if name == "resnet18":
        return model.fc
    if name == "efficientnet_b0":
        return model.classifier
    if name == "convnext_tiny":
        return model.classifier
    raise ValueError(f"Unsupported architecture {name!r}.")


def freeze_backbone(model: nn.Module, name: str) -> None:
    """Freeze the backbone and leave only the classifier head trainable."""
    for parameter in model.parameters():
        parameter.requires_grad = False
    for parameter in classifier_head(model, name).parameters():
        parameter.requires_grad = True


def unfreeze_backbone_block(model: nn.Module, name: str, stage2_epoch: int) -> None:
    """Gradually unfreeze the final feature blocks during stage two."""
    if stage2_epoch < 0:
        raise ValueError("stage2_epoch must not be negative.")
    if name == "resnet18":
        ordered_blocks = [model.layer4, model.layer3, model.layer2, model.layer1, model.conv1, model.bn1]
        blocks = ordered_blocks[min(stage2_epoch, len(ordered_blocks) - 1) : min(stage2_epoch, len(ordered_blocks) - 1) + 1]
    elif name == "efficientnet_b0":
        ordered_blocks = list(model.features.children())
        start = max(0, len(ordered_blocks) - 2 * (stage2_epoch + 1))
        blocks = ordered_blocks[start:]
    elif name == "convnext_tiny":
        ordered_blocks = list(model.features.children())
        start = max(0, len(ordered_blocks) - 2 * (stage2_epoch + 1))
        blocks = ordered_blocks[start:]
    else:
        raise ValueError(f"Unsupported architecture {name!r}.")
    for block in blocks:
        for parameter in block.parameters():
            parameter.requires_grad = True


def trainable_parameter_count(model: nn.Module) -> int:
    return sum(parameter.numel() for parameter in model.parameters() if parameter.requires_grad)
