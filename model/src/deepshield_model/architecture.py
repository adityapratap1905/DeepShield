"""Neural network architecture shared by training and inference."""

from torch import nn
from torchvision.models import ResNet18_Weights, resnet18


def build_model(*, pretrained: bool) -> nn.Module:
    """Create a two-class ResNet-18; pretrained weights are used for training only."""
    weights = ResNet18_Weights.DEFAULT if pretrained else None
    model = resnet18(weights=weights)
    model.fc = nn.Linear(model.fc.in_features, 2)
    return model
