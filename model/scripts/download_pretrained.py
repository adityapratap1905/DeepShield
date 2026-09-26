"""Download and checksum the pinned DeepShield image and face models."""

from __future__ import annotations

import hashlib
import shutil
import sys
import urllib.request
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS = (
    (
        "model/artifacts/community_forensics/model.onnx",
        "https://huggingface.co/buildborderless/CommunityForensics-DeepfakeDet-ViT/"
        "resolve/ac6ee457bea904a373065754107451793b56db00/onnx/model.onnx?download=true",
        87_442_080,
        "a42c7d740fbb345ba9a26d469b22f301d73089ce3c6da993877ed2b6965a8ba1",
    ),
    (
        "model/artifacts/face_swap/deepfake_hybrid_final.onnx",
        "https://huggingface.co/nihal4/Deep_Fake_Hybrid_Model/resolve/"
        "2a766f25def3f394fc6c7a4ebe638ee99b7472ff/deepfake_hybrid_final.onnx?download=true",
        1_445_658,
        "1c0fb3da21885911398ec6c7b6f9d3053a90ce25a2bcd1a8602fa9ed94076693",
    ),
    (
        "model/artifacts/face_swap/deepfake_hybrid_final.onnx.data",
        "https://huggingface.co/nihal4/Deep_Fake_Hybrid_Model/resolve/"
        "2a766f25def3f394fc6c7a4ebe638ee99b7472ff/deepfake_hybrid_final.onnx.data?download=true",
        49_185_792,
        "a5a9916ef2bc4c49c927592f7add4d328f5a85ce55fc8408f393e25e7f164267",
    ),
    (
        "model/artifacts/face_swap/yunet.onnx",
        "https://media.githubusercontent.com/media/opencv/opencv_zoo/"
        "47534e27c9851bb1128ccc0102f1145e27f23f98/"
        "models/face_detection_yunet/face_detection_yunet_2023mar.onnx",
        232_589,
        "8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4",
    ),
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def download_verified(destination: Path, url: str, expected_size: int, expected_sha256: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_file() and destination.stat().st_size == expected_size:
        if sha256_file(destination) == expected_sha256:
            print(f"Already ready: {destination.relative_to(REPOSITORY_ROOT)}")
            return

    partial = destination.with_name(destination.name + ".download")
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "DeepShield/0.2 pretrained model setup"},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response, partial.open("wb") as output:
            shutil.copyfileobj(response, output, length=1024 * 1024)

        actual_size = partial.stat().st_size
        actual_sha256 = sha256_file(partial)
        if actual_size != expected_size or actual_sha256 != expected_sha256:
            raise RuntimeError(
                f"Checksum mismatch for {destination.name}: "
                f"size={actual_size}, sha256={actual_sha256}"
            )
        partial.replace(destination)
    except Exception:
        partial.unlink(missing_ok=True)
        raise

    print(f"Downloaded: {destination.relative_to(REPOSITORY_ROOT)}")


def main() -> int:
    try:
        for relative_path, url, size, checksum in ARTIFACTS:
            download_verified(REPOSITORY_ROOT / relative_path, url, size, checksum)
    except Exception as exc:
        print(f"Pretrained model setup failed: {exc}", file=sys.stderr)
        return 1

    print("All pinned image and face-analysis models are ready.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
