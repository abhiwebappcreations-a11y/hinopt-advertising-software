# Admobitics Advertising Service

**Stack:** Node.js, TypeScript (Strict Mode), Supabase PostgreSQL (`admobitics-ads`)  
**Domain Authority:** Admobitics Operations Tenant

## Responsibilities
- Campaign lifecycle management (start/end dates, day-parting, status).
- Playlist composition and screen targeting engine.
- Sync manifest generation (`/sync-manifest`) with `ETag` and indexed `manifest_version` check.
- High-throughput proof-of-play report ingestion (`/playback-reports`).
- Playback reconciliation and advertiser billing analytics.
- Zero access to HINOPT master licensing tables or private signing keys.
