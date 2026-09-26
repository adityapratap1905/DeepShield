"""DeepShield photo analysis models."""

__all__ = ["CommunityForensicsClassifier", "DeepfakeClassifier", "ModelNotReady"]


def __getattr__(name: str):
    if name == "CommunityForensicsClassifier":
        from .community_forensics import CommunityForensicsClassifier

        return CommunityForensicsClassifier
    if name in {"DeepfakeClassifier", "ModelNotReady"}:
        from .inference import DeepfakeClassifier, ModelNotReady

        return {"DeepfakeClassifier": DeepfakeClassifier, "ModelNotReady": ModelNotReady}[name]
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
