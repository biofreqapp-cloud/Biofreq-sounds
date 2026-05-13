# BioFreq Hotfix 4.0.51 - 2026-05-12

## Motivo

La version `4.0.50+2135` fue compilada desde una fuente local incompleta. Aunque el streaming HLS funcionaba, esa fuente no contenia la version completa de:

- sistema de compra/cobro de tokens,
- opciones completas del panel Admin,
- filtros avanzados de sonidos.

## Correccion

Se restauro la fuente completa `4.0.49+2134` desde:

`C:\Biofreq_local\BioFreq_4_0_28_WORKSPACE_20260408_2353\04_PROYECTO_EDITABLE\BioFreq_app`

Y luego se reaplico el soporte HLS sobre el reproductor de detalle de sonido:

- prioridad: `hls_manifest_url`, `url_hls`, `stream_url`;
- fallback: `url_sonido`;
- motor de audio: `just_audio` + `audio_session`;
- version publicada: `4.0.51+2136`.

## Validacion

- `dart analyze lib/main.dart lib/modules/core.dart lib/modules/admin.dart lib/modules/sounds.dart`
  - sin errores de compilacion; solo warnings/lints preexistentes.
- `flutter build apk --release`
  - correcto.
- `aapt dump badging`
  - `versionName='4.0.51'`
  - `versionCode='2136'`

## APK publicado

`C:\Biofreq_local\CURRENT\APKS\BioFreq_4.0.51_2136_restore_core_admin_filters_hls_release_20260512.apk`

