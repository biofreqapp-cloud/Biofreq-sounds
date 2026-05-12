from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Iterable
from urllib.parse import quote

import firebase_admin
import requests
from firebase_admin import credentials, firestore
from google.cloud import storage


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SERVICE_ACCOUNT = ROOT.parent / "BioFreq_Engine" / "serviceAccount.json"
DEFAULT_BUCKET = "biofreq-app.firebasestorage.app"
DEFAULT_COLLECTION = "Sonidos"
DEFAULT_PREFIX = "sounds_hls"
SEGMENT_SECONDS = 2


def slug(text: str) -> str:
    cleaned = "".join(ch.lower() if ch.isalnum() else "-" for ch in text.strip())
    while "--" in cleaned:
        cleaned = cleaned.replace("--", "-")
    return cleaned.strip("-") or "sound"


def firebase_url(bucket: str, path: str, token: str) -> str:
    encoded = quote(path, safe="")
    return f"https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encoded}?alt=media&token={token}"


def ensure_file(path: Path, label: str) -> Path:
    if not path.exists():
        raise FileNotFoundError(f"No existe {label}: {path}")
    return path


def init_firebase(service_account: Path) -> None:
    if firebase_admin._apps:
        return
    cred = credentials.Certificate(str(service_account))
    firebase_admin.initialize_app(cred)


def download_to_temp(url: str, target: Path) -> Path:
    with requests.get(url, stream=True, timeout=60) as response:
        response.raise_for_status()
        with target.open("wb") as fh:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    fh.write(chunk)
    return target


def run_ffmpeg(input_path: Path, output_dir: Path, ffmpeg_bin: str, segment_seconds: int) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest = output_dir / "index.local.m3u8"
    segment_pattern = output_dir / "seg_%05d.ts"
    command = [
        ffmpeg_bin,
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(input_path),
        "-vn",
        "-c:a",
        "aac",
        "-b:a",
        "128k",
        "-f",
        "hls",
        "-hls_time",
        str(segment_seconds),
        "-hls_playlist_type",
        "vod",
        "-hls_segment_type",
        "mpegts",
        "-hls_segment_filename",
        str(segment_pattern),
        str(manifest),
    ]
    subprocess.run(command, check=True)
    if not manifest.exists():
        raise RuntimeError("ffmpeg no genero el manifest HLS.")
    return manifest


def content_type(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix == ".m3u8":
        return "application/vnd.apple.mpegurl"
    if suffix == ".ts":
        return "video/mp2t"
    if suffix == ".aac":
        return "audio/aac"
    return "application/octet-stream"


def upload_file(bucket: storage.Bucket, local_path: Path, remote_path: str, token: str) -> str:
    blob = bucket.blob(remote_path)
    blob.metadata = {"firebaseStorageDownloadTokens": token}
    blob.cache_control = "private, max-age=60"
    blob.upload_from_filename(str(local_path), content_type=content_type(local_path))
    return firebase_url(bucket.name, remote_path, token)


def rewrite_manifest(
    local_manifest: Path,
    remote_segment_urls: dict[str, str],
    target_manifest: Path,
) -> None:
    lines = []
    for line in local_manifest.read_text(encoding="utf-8").splitlines():
        key = line.strip()
        lines.append(remote_segment_urls.get(key, line))
    target_manifest.write_text("\n".join(lines) + "\n", encoding="utf-8")


def iter_hls_segments(output_dir: Path) -> Iterable[Path]:
    return sorted(output_dir.glob("seg_*.ts"))


def migrate_one(
    input_path: Path,
    sound_id: str,
    service_account: Path,
    bucket_name: str,
    storage_prefix: str,
    ffmpeg_bin: str,
    update_firestore: bool,
    keep_workdir: bool,
    dry_run: bool,
) -> dict[str, str | int]:
    ensure_file(input_path, "audio de entrada")
    if not dry_run:
        ensure_file(service_account, "service account")
        init_firebase(service_account)

    safe_id = slug(sound_id)
    work_parent = ROOT / "build" / "hls"
    work_parent.mkdir(parents=True, exist_ok=True)
    work_dir = Path(tempfile.mkdtemp(prefix=f"{safe_id}_", dir=work_parent))

    try:
        local_manifest = run_ffmpeg(input_path, work_dir, ffmpeg_bin, SEGMENT_SECONDS)
        segments = list(iter_hls_segments(work_dir))
        if not segments:
            raise RuntimeError("ffmpeg no genero segmentos HLS.")

        if dry_run:
            return {
                "sound_id": sound_id,
                "manifest_local": str(local_manifest),
                "segment_count": len(segments),
                "segment_seconds": SEGMENT_SECONDS,
                "dry_run": "true",
            }

        storage_client = storage.Client.from_service_account_json(str(service_account))
        bucket = storage_client.bucket(bucket_name)
        remote_base = f"{storage_prefix.rstrip('/')}/{safe_id}"

        remote_segment_urls: dict[str, str] = {}
        for segment in segments:
            token = str(uuid.uuid4())
            remote_path = f"{remote_base}/{segment.name}"
            remote_segment_urls[segment.name] = upload_file(bucket, segment, remote_path, token)

        remote_manifest = work_dir / "index.m3u8"
        rewrite_manifest(local_manifest, remote_segment_urls, remote_manifest)
        manifest_token = str(uuid.uuid4())
        manifest_path = f"{remote_base}/index.m3u8"
        manifest_url = upload_file(bucket, remote_manifest, manifest_path, manifest_token)

        result: dict[str, str | int] = {
            "sound_id": sound_id,
            "manifest_url": manifest_url,
            "manifest_path": manifest_path,
            "segment_count": len(segments),
            "segment_seconds": SEGMENT_SECONDS,
        }

        if update_firestore:
            db = firestore.client()
            db.collection(DEFAULT_COLLECTION).document(sound_id).set(
                {
                    "hls_manifest_url": manifest_url,
                    "hls_storage_path": manifest_path,
                    "hls_segment_seconds": SEGMENT_SECONDS,
                    "hls_segment_count": len(segments),
                    "streaming_mode": "hls_firebase_storage",
                    "hls_updated_at": firestore.SERVER_TIMESTAMP,
                },
                merge=True,
            )
            result["firestore"] = f"{DEFAULT_COLLECTION}/{sound_id}"

        return result
    finally:
        if keep_workdir or dry_run:
            print(f"Workdir HLS conservado: {work_dir}")
        else:
            shutil.rmtree(work_dir, ignore_errors=True)


def migrate_from_firestore(
    sound_id: str,
    service_account: Path,
    bucket_name: str,
    storage_prefix: str,
    ffmpeg_bin: str,
    update_firestore: bool,
    keep_workdir: bool,
    dry_run: bool,
) -> dict[str, str | int]:
    ensure_file(service_account, "service account")
    init_firebase(service_account)
    db = firestore.client()
    snap = db.collection(DEFAULT_COLLECTION).document(sound_id).get()
    if not snap.exists:
        raise ValueError(f"No existe {DEFAULT_COLLECTION}/{sound_id}.")
    data = snap.to_dict() or {}
    url = str(data.get("url_sonido") or data.get("url_audio") or "").strip()
    if not url:
        raise ValueError(f"{DEFAULT_COLLECTION}/{sound_id} no tiene url_sonido/url_audio.")

    with tempfile.TemporaryDirectory(prefix=f"{slug(sound_id)}_download_") as tmp:
        input_path = Path(tmp) / f"{slug(sound_id)}.mp3"
        download_to_temp(url, input_path)
        return migrate_one(
            input_path=input_path,
            sound_id=sound_id,
            service_account=service_account,
            bucket_name=bucket_name,
            storage_prefix=storage_prefix,
            ffmpeg_bin=ffmpeg_bin,
            update_firestore=update_firestore,
            keep_workdir=keep_workdir,
            dry_run=dry_run,
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Segmenta sonidos BioFreq a HLS de 2s, sube a Firebase Storage y opcionalmente actualiza Firestore.",
    )
    parser.add_argument("--input", type=Path, help="MP3/WAV local a migrar.")
    parser.add_argument("--from-firestore", action="store_true", help="Descarga el MP3 desde Sonidos/{sound_id}.")
    parser.add_argument("--sound-id", required=True, help="ID del documento en Sonidos.")
    parser.add_argument("--service-account", type=Path, default=DEFAULT_SERVICE_ACCOUNT)
    parser.add_argument("--bucket", default=os.environ.get("FIREBASE_STORAGE_BUCKET", DEFAULT_BUCKET))
    parser.add_argument("--storage-prefix", default=DEFAULT_PREFIX)
    parser.add_argument("--ffmpeg", default=os.environ.get("FFMPEG_BIN", "ffmpeg"))
    parser.add_argument("--update-firestore", action="store_true", help="Escribe hls_manifest_url en Sonidos/{sound_id}.")
    parser.add_argument("--keep-workdir", action="store_true", help="Conserva los archivos HLS temporales para inspeccion.")
    parser.add_argument("--dry-run", action="store_true", help="Solo genera HLS local; no sube a Storage ni actualiza Firestore.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.from_firestore:
            result = migrate_from_firestore(
                sound_id=args.sound_id,
                service_account=args.service_account,
                bucket_name=args.bucket,
                storage_prefix=args.storage_prefix,
                ffmpeg_bin=args.ffmpeg,
                update_firestore=args.update_firestore,
                keep_workdir=args.keep_workdir,
                dry_run=args.dry_run,
            )
        else:
            if not args.input:
                raise ValueError("Usa --input o --from-firestore.")
            result = migrate_one(
                input_path=args.input,
                sound_id=args.sound_id,
                service_account=args.service_account,
                bucket_name=args.bucket,
                storage_prefix=args.storage_prefix,
                ffmpeg_bin=args.ffmpeg,
                update_firestore=args.update_firestore,
                keep_workdir=args.keep_workdir,
                dry_run=args.dry_run,
            )
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    for key, value in result.items():
        print(f"{key}: {value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
