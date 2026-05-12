# BioFreq app update: Firebase Storage HLS streaming

This update bundle contains the BioFreq app files changed locally on 2026-05-12 to support fast segmented audio loading.

## What changed

- `BioFreq_app/lib/main.dart`
  - Adds `just_audio` and `audio_session` imports.
- `BioFreq_app/lib/modules/sounds.dart`
  - Uses `just_audio` for the sound detail player.
  - Prefers `hls_manifest_url` / `url_hls` / `stream_url`.
  - Falls back to `url_sonido` if HLS fails.
  - Reuses the prepared stream for replay instead of reopening the URL each time.
- `BioFreq_app/pubspec.yaml` and `BioFreq_app/pubspec.lock`
  - Adds `just_audio` and `audio_session`.
  - Removes `audioplayers`.
  - Bumps the compiled app to `4.0.50+2135`.
- `BioFreq_app/android/settings.gradle.kts`, `BioFreq_app/android/app/build.gradle.kts`,
  and `BioFreq_app/android/app/google-services.json`
  - Restores the Android Gradle files required for Flutter builds.
- `BioFreq_app/assets/logo.png`
  - Restores the asset declared in `pubspec.yaml`.
- `BioFreq_app/tools/hls_migrate_firebase.py`
  - Segments MP3/WAV into 2-second HLS with ffmpeg.
  - Uploads manifest and segments to Firebase Storage.
  - Optionally updates `Sonidos/{sound_id}` with `hls_manifest_url`.
- `BioFreq_app/HLS_STREAMING_FIREBASE.md`
  - Operational migration notes.

## Production smoke test already performed

`Sonidos/Limitless` was migrated as a single test document:

- `hls_storage_path`: `sounds_hls/limitless/index.m3u8`
- `hls_segment_seconds`: `2`
- `hls_segment_count`: `27`

The original `url_sonido` remains in Firestore as fallback.

## Validation

- `python -m py_compile tools/hls_migrate_firebase.py`
- `python tools/hls_migrate_firebase.py --input C:\Biofreq_local\CURRENT\_tmp_Biofreq_sounds\adara.mp3 --sound-id codex-dry-run-adara --dry-run`
- `dart analyze lib/main.dart lib/modules/sounds.dart`
- `flutter build apk --debug`
- `aapt dump badging C:\Biofreq_local\CURRENT\APKS\BioFreq_4.0.50_2135_HLS_streaming_debug_20260512.apk`

Compiled APK:

- `versionName`: `4.0.50`
- `versionCode`: `2135`
- Firebase Storage URL is published through `version.json` on `main`.
