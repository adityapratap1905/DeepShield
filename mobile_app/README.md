# DeepShield mobile app

Flutter client for the DeepShield project. The first mobile milestone is photo deepfake detection; video support is planned afterward.

## Current status

Photo selection uploads JPG and PNG files to the FastAPI service in `../backend/`. The API calls the classifier package in `../model/`. A dataset and trained checkpoint are not included, so the API reports model-unavailable and returns HTTP 503 until you train and configure a checkpoint. The app does not show fabricated scores.

## Requirements and commands

Install Flutter stable with Dart SDK `>=3.3.0 <4.0.0`, then run commands from this directory:

```sh
flutter pub get
flutter run
```

```sh
flutter analyze
flutter test
```

The `web/` directory here is the Flutter web platform runner, not DeepShield's future standalone browser dashboard. That dashboard belongs in the repository's `web_app/` directory. Backend run instructions are in `../backend/README.md` and model training instructions are in `../model/README.md`.

On the Android emulator, the app defaults to the backend at `10.0.2.2:8000`. For another device or simulator, set `DEEPSHIELD_API_BASE_URL` with `--dart-define`; see the backend README for examples. The endpoint will return model-unavailable until you train a checkpoint.
