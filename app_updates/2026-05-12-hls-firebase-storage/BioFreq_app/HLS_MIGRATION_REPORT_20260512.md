# BioFreq HLS Migration Report - 2026-05-12

## Summary

- Firestore collection: `Sonidos`
- Total documents: `20`
- Documents with audio URL: `19`
- Documents with active HLS: `19`
- Documents without audio URL: `1`
- Migrated in this run: `18`
- Already migrated and verified: `1`
- Errors: `0`

## Verification

- Manifest checks: `19/19` returned HTTP `200`.
- First segment checks: `19/19` returned HTTP `200` or `206`.
- Original `url_sonido` values were preserved as fallback.

## Documents

| Sound ID | Status | Segments | Time |
| --- | --- | ---: | ---: |
| `AeVuSeVXMv8NCJ88KDCg` | migrated | 2 | 4.45s |
| `Beber-ina` | migrated | 3 | 4.48s |
| `bpXdkoDnGtZ7sbsmIltB` | migrated | 283 | 89.03s |
| `CmnqYKyDSvQSWT7wVrRM` | migrated | 6 | 6.58s |
| `cWXnmzcYGSfNMIrx85ja` | migrated | 14 | 9.50s |
| `cYjcKfCaROrjFrioXfoP` | migrated | 17 | 7.71s |
| `eAFLBykbb7qd57XgQnbc` | migrated | 283 | 88.15s |
| `kUzDhgnups0Gh2ZDIU0r` | migrated | 14 | 9.65s |
| `Limitless` | skipped_existing_hls | 27 | verified |
| `LkJGESXYed7vOjR8p0ag` | migrated | 151 | 61.02s |
| `ltJM94TOczrvS3KUV3tO` | migrated | 283 | 90.53s |
| `Metocarb` | migrated | 15 | 10.90s |
| `MoWqi4UtEHa3j4wUV1jA` | migrated | 693 | 215.44s |
| `mxNra8uM615bs73aKoIP` | migrated | 2 | 4.23s |
| `oBiqsYMFypt1e5zB11GO` | migrated | 4 | 5.36s |
| `peiguDCeQIMvjmTt1UzT` | migrated | 5 | 4.65s |
| `qcxuNwAO96JYRmG9JZFm` | migrated | 2 | 4.39s |
| `VEB` | migrated | 5 | 5.47s |
| `WJTgJuUlBszenRfFxuC7` | migrated | 2 | 4.12s |

Document without audio URL:

- `vBwT6KvzyXwZ6m4vN3sq`

## Local Trace Files

- `build/hls_migration_20260512/firestore_sonidos_backup_before.json`
- `build/hls_migration_20260512/firestore_sonidos_backup_after.json`
- `build/hls_migration_20260512/migration_full.log`
- `build/hls_migration_20260512/migration_full_report.json`
- `build/hls_migration_20260512/verification_after.json`

