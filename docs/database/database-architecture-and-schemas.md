# Database Architecture & Supabase Isolation Specification

**Document Class:** Technical Engineering Standard  
**Project:** HINOPT Advertising Software  
**Version:** 1.0.0 (Phase 1 Baseline)  
**Authors:** Principal Software Architect (HINOPT)  

---

## 1. Executive Summary & Physical Project Segregation

In accordance with our ratified architectural decisions (ADR-004), HINOPT Advertising Software enforces **physical database isolation** across two separate Supabase cloud projects. Single-database schema splitting was explicitly rejected because a leaked or compromised `service_role` key would breach the sovereign master licensing system.

```mermaid
flowchart TD
    subgraph Project1["Supabase Project 1: hinopt-core (Sovereign Authority)"]
        H_Tenants["hinopt_tenants"]
        H_Plans["hinopt_licence_plans"]
        H_Devices["hinopt_devices"]
        H_Keys["hinopt_device_keys"]
        H_Licences["hinopt_licences"]
        H_Heartbeats["hinopt_heartbeats"]
        H_Audit["hinopt_audit_logs"]
        
        H_Tenants --> H_Devices
        H_Plans --> H_Devices
        H_Devices --> H_Keys
        H_Devices --> H_Licences
        H_Devices --> H_Heartbeats
    end

    subgraph OpaqueBoundary["Cross-Plane Reference Boundary (Zero Shared DB Links)"]
        OpaqueID["hinopt_device_id (UUID v4)"]
    end

    subgraph Project2["Supabase Project 2: admobitics-ads (Advertising Operations)"]
        A_Advertisers["admobitics_advertisers"]
        A_Groups["admobitics_screen_groups"]
        A_Screens["admobitics_screen_configs"]
        A_Campaigns["admobitics_campaigns"]
        A_DayParts["admobitics_day_parts"]
        A_Assets["admobitics_creative_assets"]
        A_CampScreens["admobitics_campaign_screens"]
        A_PoP["admobitics_proof_of_play_summaries"]
        
        A_Advertisers --> A_Campaigns
        A_Groups --> A_Screens
        A_Campaigns --> A_DayParts
        A_Campaigns --> A_Assets
        A_Campaigns --> A_CampScreens
        A_Screens --> A_CampScreens
        A_Screens --> A_PoP
        A_Campaigns --> A_PoP
    end

    H_Devices -.-> OpaqueID
    OpaqueID -.-> A_Screens
```

---

## 2. Security Invariants & Credentials Management

| Dimension | `hinopt-core` (Project 1) | `admobitics-ads` (Project 2) |
| :--- | :--- | :--- |
| **Domain Authority** | HINOPT Platform Owner | Admobitics Operations Tenant |
| **API Keys / Service Role** | Dedicated HINOPT secret keys; stored in HINOPT Cloud KMS | Dedicated Admobitics keys; managed by Admobitics devops |
| **Cross-Database Queries** | **Prohibited.** No foreign data wrappers (FDW) or direct SQL links. | **Prohibited.** |
| **Inter-Service Comms** | Secure HTTPS REST APIs with HMAC / mTLS authentication | Secure HTTPS REST APIs |
| **Entity Reference** | Issues master `hinopt_device_id` UUID | References `hinopt_device_id` as an opaque external key |
| **Signing Key Access** | Manages Ed25519 root/intermediate signing keys | **Zero access** to private signing keys |

---

## 3. `hinopt-core` Entity-Relationship Diagram

```mermaid
erDiagram
    HINOPT_TENANTS ||--o{ HINOPT_DEVICES : owns
    HINOPT_LICENCE_PLANS ||--o{ HINOPT_DEVICES : default_plan
    HINOPT_LICENCE_PLANS ||--o{ HINOPT_LICENCES : defines
    HINOPT_DEVICES ||--|| HINOPT_DEVICE_KEYS : holds
    HINOPT_DEVICES ||--o{ HINOPT_LICENCES : receives
    HINOPT_DEVICES ||--o{ HINOPT_HEARTBEATS : records
    HINOPT_AUDIT_LOGS }o--|| HINOPT_DEVICES : tracks

    HINOPT_TENANTS {
        text tenant_id PK
        text name
        text contact_email
        integer max_screens_quota
        boolean is_active
        timestamptz created_at
    }

    HINOPT_LICENCE_PLANS {
        text plan_id PK
        text name
        integer max_offline_days
        jsonb features
        boolean is_active
    }

    HINOPT_DEVICES {
        uuid hinopt_device_id PK
        text tenant_id FK
        text name
        text activation_code UK
        timestamptz activation_code_expires_at
        text status
        text hardware_model
        text assigned_plan_id FK
        timestamptz created_at
    }

    HINOPT_DEVICE_KEYS {
        uuid hinopt_device_id PK,FK
        text public_key_pem
        text algorithm
        text key_fingerprint_sha256
        timestamptz enrolled_at
    }

    HINOPT_LICENCES {
        uuid licence_id PK
        uuid hinopt_device_id FK
        text tenant_id FK
        text plan_id FK
        text signed_token
        timestamptz valid_from
        timestamptz valid_until
        integer max_offline_days
        boolean is_revoked
    }

    HINOPT_HEARTBEATS {
        bigserial id PK
        uuid hinopt_device_id FK
        timestamptz received_at
        numeric cpu_temp_celsius
        integer memory_used_mb
        bigint storage_free_bytes
        bigint uptime_seconds
        jsonb player_state
    }
```

---

## 4. `admobitics-ads` Entity-Relationship Diagram

```mermaid
erDiagram
    ADMOBITICS_ADVERTISERS ||--o{ ADMOBITICS_CAMPAIGNS : books
    ADMOBITICS_SCREEN_GROUPS ||--o{ ADMOBITICS_SCREEN_CONFIGS : clusters
    ADMOBITICS_CAMPAIGNS ||--o{ ADMOBITICS_DAY_PARTS : schedules
    ADMOBITICS_CAMPAIGNS ||--o{ ADMOBITICS_CREATIVE_ASSETS : contains
    ADMOBITICS_CAMPAIGNS ||--o{ ADMOBITICS_CAMPAIGN_SCREENS : assigned_to
    ADMOBITICS_SCREEN_CONFIGS ||--o{ ADMOBITICS_CAMPAIGN_SCREENS : plays
    ADMOBITICS_SCREEN_CONFIGS ||--o{ ADMOBITICS_PROOF_OF_PLAY_SUMMARIES : reports
    ADMOBITICS_CAMPAIGNS ||--o{ ADMOBITICS_PROOF_OF_PLAY_SUMMARIES : audited_by

    ADMOBITICS_SCREEN_CONFIGS {
        uuid hinopt_device_id PK
        uuid group_id FK
        text display_name
        text fallback_mode
        text audio_policy
        jsonb audio_schedule
        text rotation_policy
        text layout_mode
        text pop_upload_trigger
        bigint manifest_version
    }

    ADMOBITICS_CAMPAIGNS {
        uuid campaign_id PK
        uuid advertiser_id FK
        text name
        date flight_start_date
        date flight_end_date
        integer weight
        text status
    }

    ADMOBITICS_DAY_PARTS {
        uuid day_part_id PK
        uuid campaign_id FK
        text[] days_of_week
        time start_time
        time end_time
    }

    ADMOBITICS_CREATIVE_ASSETS {
        uuid asset_id PK
        uuid campaign_id FK
        text media_type
        text r2_object_key UK
        text cdn_url
        integer duration_seconds
        bigint file_size_bytes
        text sha256
        timestamptz r2_purge_at
        boolean is_purged
    }

    ADMOBITICS_PROOF_OF_PLAY_SUMMARIES {
        uuid summary_id PK
        uuid hinopt_device_id FK
        uuid campaign_id FK
        uuid asset_id FK
        date reporting_date
        integer impressions_count
        integer total_seconds_played
        integer interrupted_count
        timestamptz first_play_timestamp
        timestamptz last_play_timestamp
    }
```

---

## 5. Performance Optimizations & Manifest Versioning

### 5.1 O(1) Manifest Change Detection
Instead of executing expensive relational `JOIN` queries across campaigns, day-parts, and creative assets on every 60-second display poll, the system maintains an incrementing `manifest_version` column on `admobitics_screen_configs`:
1. Whenever a campaign is assigned, updated, or removed, a PostgreSQL database trigger (`trg_campaign_screens_manifest_update`) automatically increments `manifest_version`.
2. When the display calls `GET /v1/displays/{id}/sync-manifest` with `If-None-Match: "v{manifest_version}"`:
   ```sql
   SELECT manifest_version FROM admobitics_screen_configs WHERE hinopt_device_id = $1;
   ```
3. If the version matches the client's `ETag`, the server immediately responds with **`304 Not Modified`** in sub-5ms with zero data transfer.

---

## 6. Retention & Automated Cleanup Workers

1. **R2 Asset Retention:** A daily background job queries `admobitics_creative_assets`:
   ```sql
   SELECT r2_object_key FROM admobitics_creative_assets
   WHERE r2_purge_at <= NOW() AND is_purged = FALSE;
   ```
   The backend deletes the objects from Cloudflare R2 and marks `is_purged = TRUE`.
2. **Heartbeat Data Pruning:** Telemetry records in `hinopt_heartbeats` older than 90 days are automatically pruned or archived to cold storage to keep database size predictable.
