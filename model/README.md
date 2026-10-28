# DeepShield image and video models

The new FF++ pipeline trains one image classifier and reuses it on sampled video frames. Video decisions aggregate frame probabilities and use a separately calibrated video threshold. Raw dataset files, extracted frames, checkpoints, and generated reports stay local and are excluded from Git. See [`reports/README.md`](reports/README.md) for report handling.

The pipeline uses only FaceForensics++ C23 `Original`, `Deepfakes`, `Face2Face`, `FaceSwap`, and `NeuralTextures` videos. It does not use the original FaceForensics v1 or the DeepFakeDetection dataset. The existing Community Forensics ONNX model, face-swap ONNX model, and YuNet detector are third-party pretrained inference assets documented in [THIRD_PARTY_MODEL.md](THIRD_PARTY_MODEL.md); they were preserved and are not used to initialize FF++ training.

## Resource and artifact audit

The prior repository contained no custom-trained checkpoint, processed training set, or model experiment logs under `model/artifacts/` or `model/data/`. No custom training artifacts were deleted. The three pretrained ONNX artifacts listed above were preserved. Checkpoints created by this pipeline use ImageNet weights from TorchVision and never load a previous DeepShield checkpoint.

## Install training dependencies

Use the [official PyTorch installer](https://pytorch.org/get-started/locally/) to select a Torch/TorchVision pair that matches the machine and Python version, then install the project extras:

```powershell
cd model
python -m pip install --upgrade pip
python -m pip install -e ".[train]"
```

The training extra includes Torch, TorchVision, scikit-learn, and Matplotlib. The project also needs OpenCV, which is in the base model dependencies. Downloaded ImageNet weights are cached by TorchVision on first training run.

## Download FaceForensics++ C23

Use the v4 downloader URL provided by the dataset authors. Keep the access-specific downloader outside the repository. The script asks for confirmation of the FaceForensics Terms of Use; do not continue until the account holder has agreed to them.

```powershell
$downloader = Join-Path $env:TEMP "faceforensics_download_v4.py"
Invoke-WebRequest -Uri "https://kaldir.vc.in.tum.de/faceforensics_download_v4.py" -OutFile $downloader
$datasetRoot = Join-Path (Get-Location) "data\faceforensics_pp_c23"
$datasets = @("original", "Deepfakes", "Face2Face", "FaceSwap", "NeuralTextures")
foreach ($dataset in $datasets) {
    python $downloader $datasetRoot -d $dataset -c c23 -t videos --server EU2
    if ($LASTEXITCODE -ne 0) { throw "FaceForensics download failed for $dataset" }
}
```

This requests C23 videos only. It avoids `-d all`, which can include additional datasets and manipulation types. The output folder name is only a suggested location; the preparation script finds a dataset by its `original_sequences/` and `manipulated_sequences/` structure.

## Inspect splits and prepare selected frames

```powershell
python scripts/prepare_ffpp.py `
    --data-dir data `
    --compression c23 `
    --sampling-fps 1 `
    --frames-per-video 4 `
    --maximum-frames 4 `
    --workers 4 `
    --resolution 224
```

The script obtains `train.json`, `val.json`, and `test.json` from the official FaceForensics GitHub repository and caches them with a commit and SHA-256 manifest under `data/splits/official/`. It validates the official 720/140/140 source-video assignment and verifies that no source video crosses partitions. A manipulated `target_source` file is used only when both source IDs belong to the same official split. Frames are extracted only after that assignment.

By default, YuNet crops the largest detected face with 25% context into `data/processed/images/{train,val,test}/{real,fake}/`. Frames with no detected face use a clearly marked full-frame fallback. The same selected frames are also saved under `data/processed/full_images/` for a full-frame comparison. `image_manifest.csv`, `video_manifest.csv`, and `preparation_report.json` preserve source paths, split, selected frame numbers and timestamps, class, manipulation type, compression, face counts, and preprocessing mode. Frame sampling is even across each video and capped by the requested FPS and frame limits. Video evaluation records the sampled frame numbers and per-frame fake scores for each one-video sample.

The script reports processed frames, face detections, no-face frames, multiple-face frames, videos by split and class, and decode errors. Four workers each use a separate YuNet detector; lower `--workers` if memory or CPU pressure is high. It does not create synthetic metrics.

Preparation requires the full official C23 video inventory by default. For incremental extraction during a long download, use `--allow-incomplete-inventory` on the first pass and `--resume` on later passes; resume reuses compatible manifests and rejects changed preprocessing, split, or compression settings. Omit the incomplete-inventory flag for the final pass so the full inventory check is enforced.

## Train and select image models

```powershell
python scripts/train.py --view face --architectures resnet18 efficientnet_b0 convnext_tiny
python scripts/train.py --view full --architectures resnet18 efficientnet_b0 convnext_tiny
python scripts/select_image_model.py
```

ConvNeXt-Tiny is skipped automatically when CUDA is unavailable. On CPU, use a smaller frame count or train only ResNet-18 and EfficientNet-B0 if the full run exceeds the available time or memory. Training uses two stages, with backbone blocks progressively unfrozen in stage two, AdamW, differential backbone/head learning rates, a learning-rate scheduler, early stopping, reproducible seeds, mixed precision on CUDA, and balanced video/class sampling. Per-experiment JSON records include dataset and manipulation counts, training settings, augmentation, threshold, metrics, and hardware. The selected checkpoint is chosen from validation metrics only and saved to `artifacts/deepfake_image_best.pt`; candidate checkpoints and per-experiment JSON records are also written under `artifacts/` and `reports/image_experiments/`.

The saved image threshold is selected on validation frames only. Test data is not read during training or model selection.

## Calibrate and evaluate video detection

```powershell
python scripts/evaluate_video.py --split val
python scripts/evaluate_video.py --split test
```

Validation compares mean, median, top-k mean, and the percentage of frames classified as fake. It selects one aggregation method and calibrates thresholds using validation videos only, then writes `artifacts/deepfake_video_config.json`. The test command uses those saved validation thresholds and does not tune them. Video predictions and video-level metrics are kept separate from frame-level image metrics.

The frame-aggregation baseline shares the selected image classifier. A separate temporal model is not trained by this pipeline; the current machine has no CUDA GPU, and no temporal model should be added unless a later resource-supported experiment shows a validation benefit.

## Held-out image evaluation

```powershell
python scripts/evaluate.py `
    --data-dir data/processed/images `
    --checkpoint artifacts/deepfake_image_best.pt
```

This evaluates only the official test frames with the threshold already saved from validation. It writes JSON metrics, a confusion matrix, ROC and precision-recall plots under `reports/image_test/`.

## Local inference

```powershell
python scripts/predict.py --media image --input path\to\photo.jpg
python scripts/predict.py --media video --input path\to\clip.mp4
```

Image and video responses include `REAL`/`FAKE`, fake probability, confidence, and the selected threshold. Confidence is a model score, not a calibrated probability of authenticity. Video responses also include sampled frame count and no-face frame count. Invalid media and videos with too few usable frames return an error instead of a fabricated result.

## Outputs and limitations

- Image checkpoint: `artifacts/deepfake_image_best.pt`
- Video configuration for frame aggregation: `artifacts/deepfake_video_config.json`
- Image comparison: `reports/image_model_comparison.csv`
- Video comparison: `reports/video/video_val_model_comparison.csv` and `reports/video/video_test_model_comparison.csv`
- FF++ preparation statistics: `data/processed/preparation_report.json`

The system is trained and evaluated on FaceForensics++ C23. Its results do not establish performance on unseen manipulation methods, other domains, or every upload quality. Do not describe a `REAL` prediction as proof of authenticity. The video baseline has no learned temporal component.
