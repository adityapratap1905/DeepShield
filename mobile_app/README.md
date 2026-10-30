# DeepShield mobile app

Flutter client for the DeepShield project. It supports photo analysis and sampled-frame video deepfake estimates.

## Current status

Photo selection uploads JPG and PNG files to the FastAPI service in `../backend/`. Video selection supports MP4, MOV, AVI, MKV, and WebM clips up to 200 MB and calls the FF++ sampled-frame video endpoint. Video analysis requires the trained FF++ image checkpoint and validation-calibrated video configuration. Model estimates are not proof of authenticity; a `REAL` result is not a claim that the media is safe.

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

The `web/` directory here is the Flutter web platform runner, not DeepShield's standalone browser dashboard. That dashboard belongs in the repository's `web_app/` directory. Backend run instructions are in `../backend/README.md` and model training instructions are in `../model/README.md`.

On the Android emulator, the app defaults to the backend at `10.0.2.2:8000`. For another device or simulator, set `DEEPSHIELD_API_BASE_URL` with `--dart-define`; see the backend README for examples.
