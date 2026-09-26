# Third-party pretrained models and detector

DeepShield downloads `onnx/model.onnx` from [CommunityForensics-DeepfakeDet-ViT](https://huggingface.co/buildborderless/CommunityForensics-DeepfakeDet-ViT), revision `ac6ee457bea904a373065754107451793b56db00`.

- Model: Community Forensics ViT-Small, 384-pixel input, FP32 ONNX
- License: MIT (see the upstream model repository's `LICENSE`)
- Intended task: detect signals of AI-generated images
- Upstream paper: [Community Forensics: Using Thousands of Generators to Train Fake Image Detectors](https://openaccess.thecvf.com/content/CVPR2025/html/Park_Community_Forensics_Using_Thousands_of_Generators_to_Train_Fake_Image_CVPR_2025_paper.html)
- Artifact size: 87,442,080 bytes
- Artifact SHA-256: `a42c7d740fbb345ba9a26d469b22f301d73089ce3c6da993877ed2b6965a8ba1`

This model is not a universal deepfake or image-authenticity detector. In particular, the prediction does not establish whether a photograph is genuine and may not identify face swaps or other edits. See the upstream model card for its intended use and reported limitations.

The pinned ONNX artifact hash matches the corrected export. The upstream [July 2026 changelog](https://huggingface.co/buildborderless/CommunityForensics-DeepfakeDet-ViT/blob/main/CHANGELOG.md) documents corrections to the model weights and image preprocessing; the pinned model revision was updated in August 2026.

## Face manipulation classifier

DeepShield downloads `deepfake_hybrid_final.onnx` and its external weights from [Deep_Fake_Hybrid_Model](https://huggingface.co/nihal4/Deep_Fake_Hybrid_Model), pinned at revision `2a766f25def3f394fc6c7a4ebe638ee99b7472ff`.

- Model: EfficientNet-B1 and RegNetY-800MF hybrid, 260 x 260 RGB face crops, ONNX
- License: MIT, as stated by the upstream model card
- Intended task: classify face crops as real or fake; DeepShield presents the output as a face-manipulation signal
- Training data: [identity-isolated deepfake face dataset](https://huggingface.co/datasets/ThinothW/Deepfake-Identity-Isolated-Dataset-PreP), which includes several face-swap methods and synthetic faces
- ONNX graph size: 1,445,658 bytes; SHA-256: `1c0fb3da21885911398ec6c7b6f9d3053a90ce25a2bcd1a8602fa9ed94076693`
- External weights size: 49,185,792 bytes; SHA-256: `a5a9916ef2bc4c49c927592f7add4d328f5a85ce55fc8408f393e25e7f164267`
- Upstream card reports 95.39% accuracy and 0.9903 ROC-AUC on its listed test split. These are upstream results on that dataset, not a guarantee of DeepShield accuracy on user images.

The classifier includes synthetic faces as well as face swaps and was evaluated on a particular dataset. It may miss unfamiliar manipulation methods, low-quality faces, and crops the face detector does not find. Its score is not a calibrated probability of a swap or authenticity.

## YuNet face detector

DeepShield uses the `face_detection_yunet_2023mar.onnx` model from [OpenCV Zoo YuNet](https://github.com/opencv/opencv_zoo/tree/47534e27c9851bb1128ccc0102f1145e27f23f98/models/face_detection_yunet), pinned at OpenCV Zoo revision `47534e27c9851bb1128ccc0102f1145e27f23f98`.

- License: MIT, as stated by OpenCV Zoo
- Artifact size: 232,589 bytes
- Artifact SHA-256: `8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4`

`model/scripts/download_pretrained.py` downloads the listed files and checks each size and SHA-256 before accepting it. Model artifacts are excluded from Git.
