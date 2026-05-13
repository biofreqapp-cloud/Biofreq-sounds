# BioFreq 4.0.52+2137 - hotfix updater banner

Fecha: 2026-05-13

## Problema

En 4.0.50 y 4.0.51 el banner de actualizacion podia terminar usando una URL vieja/cacheada del actualizador aunque `version.json` tuviera el `apk_url` correcto. El riesgo era que Firestore pisara la URL publicada y el boton terminara apuntando a un destino heredado, incluido Play Store.

## Correccion

- `AppUpdateConfig.resolve()` ahora prioriza `apk_url` de `version.json`.
- Firestore queda solo como fallback heredado cuando `version.json` no trae URL.
- Se rechazan URLs de `market://`, `play.google.com` y `onrender.com` para el APK.
- Se dejo comentario en `lib/modules/version.dart` marcando que `version.json` es la fuente oficial del banner.
- `version.json` publicado incluye `_nota_updater` para evitar mover el updater a Play Store.

## Publicacion

- Version: `4.0.52`
- Build: `2137`
- APK local: `C:\Biofreq_local\CURRENT\APKS\BioFreq_4.0.52_2137_updater_banner_fix_release_20260513.apk`
- APK remoto: `https://firebasestorage.googleapis.com/v0/b/biofreq-app.firebasestorage.app/o/app_updates%2Fandroid%2FBioFreq_4.0.52_2137_updater_banner_fix_release_20260513.apk?alt=media&token=315ce4cc-e446-4e87-a77d-c83ba618df36`
- SHA-256: `e0c68de31452d157a69f5aad54f19b0f91505b5e5f5174cb14b49d9047c37160`
- Commit repo updates/main: `b0b9e873a89bd6df756f09dd2e93ff74dd865a2d`

## Verificacion

- `flutter pub get`: OK.
- `flutter build apk --release`: OK.
- `flutter test`: OK, 3 pruebas del updater pasan.
- `aapt dump badging`: `versionName='4.0.52'`, `versionCode='2137'`.
- Firebase Storage: HTTP 200, `Content-Type: application/vnd.android.package-archive`, `Content-Length: 70995509`.
- `version.json` publico: `4.0.52`, `build_number: 2137`, `apk_sha256` publicado.
- Firestore fallback `configuracion/app.url_actualizador_apk` actualizado al APK 4.0.52.
