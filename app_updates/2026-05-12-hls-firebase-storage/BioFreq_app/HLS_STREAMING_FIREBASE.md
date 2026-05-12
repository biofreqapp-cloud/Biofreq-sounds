# BioFreq HLS streaming en Firebase Storage

## Objetivo

Los sonidos pueden seguir usando `url_sonido` como MP3 completo, pero ahora la app tambien entiende `hls_manifest_url`.
Cuando ese campo existe, el reproductor usa HLS: descarga un manifest pequeno y luego segmentos de 2 segundos conforme avanza la reproduccion.

Esto mejora la carga inicial y evita guardar el MP3 completo como archivo local de la app. No es DRM: si alguien extrae el manifest podria ver URLs de segmentos. La proteccion fuerte vendria despues con Cloud Functions, URLs firmadas cortas o DRM.

## Campos nuevos en Firestore

Coleccion: `Sonidos`

- `hls_manifest_url`: URL HTTPS del `index.m3u8` en Firebase Storage.
- `hls_storage_path`: ruta Storage del manifest, por ejemplo `sounds_hls/<sonido_id>/index.m3u8`.
- `hls_segment_seconds`: `2`.
- `hls_segment_count`: cantidad de segmentos generados.
- `streaming_mode`: `hls_firebase_storage`.
- `hls_updated_at`: timestamp de migracion.

La app usa `hls_manifest_url` primero. Si no existe, usa `url_sonido`.

## Migrar un sonido local

Desde `C:\Biofreq_local\CURRENT\BioFreq_app`:

Ensayo sin subir nada:

```powershell
python .\tools\hls_migrate_firebase.py `
  --input "C:\ruta\sonido.mp3" `
  --sound-id "ID_DEL_DOC_EN_SONIDOS" `
  --dry-run `
  --keep-workdir
```

Migracion real:

```powershell
python .\tools\hls_migrate_firebase.py `
  --input "C:\ruta\sonido.mp3" `
  --sound-id "ID_DEL_DOC_EN_SONIDOS" `
  --update-firestore
```

## Migrar usando la URL actual de Firestore

```powershell
python .\tools\hls_migrate_firebase.py `
  --from-firestore `
  --sound-id "ID_DEL_DOC_EN_SONIDOS" `
  --update-firestore
```

El script usa:

- Bucket por defecto: `biofreq-app.firebasestorage.app`.
- Service account por defecto: `C:\Biofreq_local\CURRENT\BioFreq_Engine\serviceAccount.json`.
- Ruta Storage por defecto: `sounds_hls/<sound-id>/`.

## Ensayo recomendado

1. Migra un solo sonido corto o de bajo riesgo.
2. Abre la app y confirma que reproduce igual, pero carga mas rapido.
3. Si falla, borra `hls_manifest_url` del documento y la app vuelve automaticamente a `url_sonido`.
4. Cuando el ensayo salga bien, migra el resto por tandas.

## Siguiente paso de seguridad

Para impedir manifests permanentes, la siguiente fase debe servir playlists por Cloud Function:

1. La app pide `/streamManifest?sonidoId=...`.
2. La Function valida Firebase Auth, acceso, receta/pago y App Check.
3. La Function responde un manifest temporal con URLs firmadas de pocos minutos.
4. Los objetos de Storage quedan privados y sin tokens largos.
