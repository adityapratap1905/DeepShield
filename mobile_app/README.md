# DeepShield Social mobile app

Flutter client for DeepShield Social. It retains the existing photo analysis and sampled-frame video detection while adding social feeds, profiles, communities, and learning guides.

## Current status

Photo selection uploads JPG and PNG files to the FastAPI service in `../backend/`, and the scan screen can capture a photo with the camera. Video selection supports MP4, MOV, AVI, MKV, and WebM clips up to 200 MB, can record from the camera, and calls the FF++ sampled-frame video endpoint. Video analysis requires the trained FF++ image checkpoint and validation-calibrated video configuration. Model estimates are not proof of authenticity; a `REAL` result is not a claim that the media is safe.

Home and community feeds use the authenticated API for posts, likes, comments and one-level replies, bookmarks, reports, and creator blocking. Community discussions can sort by latest or popular. Posts can include one JPG/PNG image (up to 15 MB) or MP4/MOV/AVI/MKV/WebM video (up to 50 MB); images are fetched with the bearer token and compatible videos play inline. Feed cards share post text and attached media through the device share sheet. Sharing a scan report attaches the original scanned file after the user explicitly selects “Share report and media”; the feed shows model details and limitations. Explore searches API-backed creators and posts, loaded communities, and bundled learning guides. Profiles support name, bio, and private photo updates, list published posts, shared scan reports, and joined communities, and show local-device scan counts beside social stats. Settings includes account discovery and in-app notification preferences, blocked-account management, and password changes. Moderator accounts configured by email can review reports and dismiss or remove content. Email-backed password reset and remote push/email alerts are not available. Social notifications are API-backed.

## Requirements and commands

Install Flutter stable with Dart SDK `>=3.4.0 <4.0.0`, then run commands from this directory:

```sh
flutter pub get
flutter run
```

```sh
flutter analyze
flutter test
```

The `web/` directory here is the Flutter web platform runner, not DeepShield's standalone browser dashboard. That dashboard belongs in the repository's `web_app/` directory. Backend run instructions are in `../backend/README.md` and model training instructions are in `../model/README.md`.

The app defaults to `10.0.2.2:8000` on Android and `127.0.0.1:8000` on web, iOS simulators, and desktop. For a USB-connected Android phone, use `adb reverse tcp:8000 tcp:8000` and pass `--dart-define=DEEPSHIELD_API_BASE_URL=http://127.0.0.1:8000/api/v1`. For a physical iPhone or another host, set the base URL to the computer's LAN address. See the backend README for authentication setup.
