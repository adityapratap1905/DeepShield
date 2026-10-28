# Local model data

Do not commit raw FaceForensics++ videos, extracted frames, uploaded media, or other training data. Dataset and processed-output directories are ignored by Git. Keep the official train/validation/test split metadata under `splits/official/`; the preparation script records its source commit and file hashes.

Use the FaceForensics++ v4 downloader with `--server EU2` and C23 videos only. Keep the original FaceForensics v1 and DeepFakeDetection datasets out of the main training set. See [model setup](../README.md) for download, preparation, training, and evaluation commands.
