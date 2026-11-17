# Database Architecture & Supabase Isolation

This directory documents the database schemas, entity-relationship diagrams (ERDs), migration protocols, and Row-Level Security (RLS) policies.

## Dual Project Segregation

HINOPT Advertising Software enforces strict physical and credential isolation across two Supabase projects:

1. **`hinopt-core` (HINOPT Sovereign Database):**
   - Tables: `devices`, `device_public_keys`, `licence_plans`, `issued_licences`, `device_heartbeats`, `audit_logs`.
   - Access: HINOPT backend services only.
2. **`admobitics-ads` (Admobitics Advertising Database):**
   - Tables: `advertisers`, `campaigns`, `day_parts`, `playlists`, `playlist_slots`, `creatives`, `screen_assignments`, `playback_reports`.
   - References screens via opaque `hinopt_device_id` UUIDs.
   - Access: Admobitics backend services only.
