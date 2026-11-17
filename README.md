# HINOPT Advertising Software

Enterprise-grade, specification-driven Digital Signage and Advertising Management Platform engineered for high-reliability offline-first edge playback, sovereign cryptographic licensing, and scalable ad operations.

---

## 1. System Overview & Architecture

**HINOPT Advertising Software** is architected around a strict operational and security separation between the **Platform Owner (HINOPT)** and the **Advertising Operations Customer/Tenant (Admobitics)**.

```mermaid
flowchart TD
    subgraph HINOPT_Sovereign["HINOPT Sovereign Domain (Platform Owner)"]
        H_Auth["HINOPT Licensing & Device Authority"]
        H_DB[("HINOPT Core DB (Supabase Project 1)")]
        H_Admin["HINOPT Super-Admin Portal (Flutter)"]
        H_Admin --> H_Auth
        H_Auth --> H_DB
    end

    subgraph Admobitics_Tenant["Admobitics Operations Domain (Customer/Tenant)"]
        A_Backend["Admobitics Campaign & Schedule Service"]
        A_DB[("Admobitics DB (Supabase Project 2)")]
        A_R2["Cloudflare R2 (Media Storage - 3-Day Retention)"]
        A_Admin["Admobitics Business Operations Portal (Flutter)"]
        A_Admin --> A_Backend
        A_Backend --> A_DB
        A_Backend --> A_R2
    end

    subgraph EdgePlayer["TPC 151TCT Display Unit (Edge Plane)"]
        Keystore["AndroidKeyStore (ECDSA P-256 Identity)"]
        LicenceEngine["HINOPT Licence & 4-State Clock Engine"]
        Media3Engine["Jetpack Media3 ExoPlayer Engine"]
        RoomDB[("Local Room SQLite DB (Schedules & Logs)")]
        LocalCache[("Local Media Cache Storage")]
        
        Keystore --> LicenceEngine
        LicenceEngine -->|Authorized Licence Token| Media3Engine
        RoomDB --> Media3Engine
        LocalCache --> Media3Engine
    end

    A_Backend -->|HTTPS REST: Device Quota & Authorization| H_Auth
    LicenceEngine <-->|HTTPS REST: Device Registration & Heartbeats| H_Auth
    Media3Engine <-->|HTTPS REST: Sync Manifest & Playback Reports| A_Backend
    Media3Engine -->|HTTPS GET: Signed Byte-Range Downloads| A_R2
```

---

## 2. Core Subsystems

| Component | Target Runtime / Stack | Responsibility |
| :--- | :--- | :--- |
| **Android Display Player** (`apps/android-player/`) | Kotlin, Jetpack Media3, Android SDK 29, Room, WorkManager, Android Keystore | Hardware-accelerated 1080p video playback, offline 4-state time machine, clock rollback protection, local schedule evaluation. |
| **HINOPT Admin Portal** (`apps/hinopt-admin/`) | Flutter (Web/Desktop) | Master licensing, screen authorization, plan limits, device revocation, platform telemetry. |
| **Admobitics Business Portal** (`apps/business-admin/`) | Flutter (Web/Desktop) | Advertising campaigns, day-parting, screen targeting, creative upload, proof-of-play analytics. |
| **Licensing Service** (`backend/licensing-service/`) | Node.js, TypeScript, Supabase PostgreSQL (`hinopt-core`) | Sovereign device registry, Ed25519 licence signing, device heartbeat ingestion. |
| **Advertising Service** (`backend/advertising-service/`) | Node.js, TypeScript, Supabase PostgreSQL (`admobitics-ads`) | Campaign scheduling, playlist generation, sync-manifest generation, proof-of-play ingestion. |
| **Media Service** (`backend/media-service/`) | Node.js, TypeScript, Cloudflare R2 | Pre-signed upload coordination, video validation, automated deletion (End Date + 3 Days). |

---

## 3. Repository Directory Structure

```
.
├── README.md                       # Master project overview & architecture
├── PROJECT.md                      # Official project charter, scope, and governance
├── CONTRIBUTING.md                 # Engineering guidelines, conventional commits, SDD rules
├── CHANGELOG.md                    # Formal semantic version release log
├── LICENSE                         # Proprietary license terms
│
├── docs/                           # Living technical documentation
│   ├── product/                    # Product requirements, personas, workflows
│   ├── architecture/               # System architecture, C4 diagrams, Revision 3.0 baseline
│   ├── engineering/                # Coding standards, linters, CI/CD specifications
│   ├── security/                   # STRIDE threat model, key management, offline time security
│   ├── database/                   # Supabase schemas, ERDs, RLS policies, migrations
│   ├── api/                        # OpenAPI contracts and communication protocols
│   └── deployment/                 # Deployment architecture, environment configs
│
├── specifications/                 # Formal engineering specifications (SDD)
│   ├── requirements/               # PRD-001 through PRD-003
│   ├── features/                   # Detailed functional feature specifications
│   ├── decisions/                  # Architecture Decision Records (ADR-001 through ADR-009)
│   └── acceptance-tests/           # Gherkin/Cucumber acceptance criteria
│
├── apps/                           # Application frontends
│   ├── android-player/             # Kotlin/Media3 Android kiosk display player
│   ├── business-admin/             # Flutter operations portal for Admobitics
│   └── hinopt-admin/               # Flutter super-admin portal for HINOPT
│
├── backend/                        # Backend microservices (Node.js + TypeScript)
│   ├── licensing-service/          # HINOPT sovereign licensing & device authority
│   ├── advertising-service/        # Admobitics campaign scheduling & playback analytics
│   └── media-service/              # Cloudflare R2 ingestion, pre-signed URLs, cleanup
│
├── infrastructure/                 # Infrastructure as Code & Database Migrations
│   ├── supabase/                   # Supabase migrations for hinopt-core and admobitics-ads
│   ├── storage/                    # Cloudflare R2 lifecycle rules and IAM policies
│   └── deployment/                 # Docker, orchestration, and environment templates
│
├── tests/                          # Automated test suites
│   ├── unit/                       # Unit test harnesses
│   ├── integration/                # End-to-end API and contract test suites
│   └── security/                   # Cryptographic verification and tamper tests
│
└── tools/                          # Developer tooling and test scripts
    └── development/                # Hardware benchmarking scripts (TPC 151TCT) & mock servers
```

---

## 4. Engineering Principles & SDD Protocol

This repository operates strictly under **Specification-Driven Development (SDD)**:
1. **Spec First:** No application code may be written until the corresponding specification (`specifications/`) and Architecture Decision Record (`specifications/decisions/`) have been committed, reviewed, and approved.
2. **Strict Type Safety:** Zero untyped code (`any`) across TypeScript and Kotlin.
3. **Panic-Free Edge Runtime:** Edge player code must be crash-resilient; unhandled exceptions must never terminate playback loops.
4. **Offline Resilience:** All campaign schedules and verified media must play autonomously without network connectivity.

---

## 5. Getting Started & Documentation Links

- [Project Charter & Scope](file:///d:/Advertising%20&%20Digital%20Signage%20Management%20Platform/PROJECT.md)
- [Architecture Revision 3.0 Foundation](file:///d:/Advertising%20&%20Digital%20Signage%20Management%20Platform/docs/architecture/README.md)
- [Architecture Decision Records (ADRs)](file:///d:/Advertising%20&%20Digital%20Signage%20Management%20Platform/specifications/decisions/README.md)
- [Hardware Verification Protocol (TPC 151TCT)](file:///d:/Advertising%20&%20Digital%20Signage%20Management%20Platform/tools/development/README.md)
- [Contributing Guidelines](file:///d:/Advertising%20&%20Digital%20Signage%20Management%20Platform/CONTRIBUTING.md)

---
*Confidential & Proprietary — HINOPT Technologies. All Rights Reserved.*
