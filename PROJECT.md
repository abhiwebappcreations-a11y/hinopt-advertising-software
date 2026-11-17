# Project Charter: HINOPT Advertising Software

**Project Name:** HINOPT Advertising Software  
**Platform Owner:** HINOPT  
**Commercial Customer / Tenant:** Admobitics  
**Document Class:** Master Engineering Charter  
**Version:** 1.0.0 (Phase 1 Baseline)  

---

## 1. Mission & Strategic Objectives

The mission of **HINOPT Advertising Software** is to deliver an enterprise-grade, fault-tolerant Digital Signage and Advertising Management Platform that provides:
1. **Sovereign Platform Licensing:** Absolute control over display authorization, plan tiers, device life cycles, and cryptographic licensing by HINOPT.
2. **Autonomous Offline Playback:** Continuous, deterministic advertising playback on edge display units even during prolonged network outages.
3. **Robust Time Security:** Multi-layered defense against clock manipulation, ensuring advertising expiry and licensing boundaries cannot be circumvented offline.
4. **Clean Multi-Tenant Separation:** Physical and logical segregation preventing commercial advertising tenants (Admobitics) from accessing or compromising master licensing authority.
5. **High-Throughput Direct Advertising Operations:** Seamless day-parting, screen targeting, and verified proof-of-play auditing for direct-booked advertising campaigns.

---

## 2. Phase 1 Boundaries & Constraints

To ensure rapid, defect-free execution and prevent architectural drift, Phase 1 enforces the following hard constraints:

| Domain | Supported in Phase 1 | Explicitly Out of Scope for Phase 1 |
| :--- | :--- | :--- |
| **Edge Hardware** | **Android only:** TPC 151TCT (ARMv8 Quad Core, 2GB RAM, 16GB eMMC, Android 10, 1920x1080 touchscreen). | Linux SoC, Raspberry Pi, Windows, ChromeOS, LG webOS, Samsung Tizen. |
| **Display Runtime** | Native Kotlin, Jetpack Media3 (ExoPlayer), Room SQLite, AndroidKeyStore (ECDSA P-256). | Cross-platform frameworks (Flutter/React Native on player), Electron, pure web players. |
| **Advertising Model**| Direct-booked campaigns (date/time day-parting, screen targeting, image/video). | VAST, VPAID, OpenRTB, programmatic bidding, real-time ad auctions. |
| **Communication** | HTTPS REST APIs with adaptive polling (60–120s) and manifest hashing (`ETag`). | MQTT, WebSockets, gRPC streaming, peer-to-peer media sharing. |
| **Media Ingress** | Authenticated admin portal upload to Cloudflare R2; signed download over HTTPS. | USB media importing, physical drive auto-mounting, direct camera streaming. |
| **Media Retention** | Campaign End Date + exactly 3 additional days. | Indefinite archival, uncurated local drive accumulation. |

---

## 3. Platform Ownership & Responsibility Matrix

```
+--------------------------------------------------------------------------+
|                          HINOPT (Platform Owner)                         |
|  - Master Licensing System                                               |
|  - Device Authorization & Enrollment                                     |
|  - Cryptographic Signing Authority (Ed25519)                             |
|  - Device Revocation & Status Tracking                                   |
|  - Platform Permissions & Upgrades                                       |
+--------------------------------------------------------------------------+
                                     |
                  Authenticated HTTPS REST Inter-Plane API
                                     |
+--------------------------------------------------------------------------+
|                     Admobitics (Commercial Tenant)                       |
|  - Advertising Campaign Creation & Approval                              |
|  - Creative Asset Ingestion (Images & Videos)                            |
|  - Day-Parting & Screen Targeting Playlists                              |
|  - Playback Analytics & Advertiser Billing Reports                       |
|  - Admobitics Business User Management                                   |
+--------------------------------------------------------------------------+
```

---

## 4. Hardware Profile: TPC 151TCT Baseline

- **SoC:** ARMv8 Quad Core
- **Memory:** 2GB LPDDR3/4 (App target budget: $\le 192\text{MB}$ Java heap)
- **Internal Storage:** 16GB eMMC (Target app cache quota: $\le 5\text{GB}$, dynamic free watermark: 30%)
- **Operating System:** Android 10 (API Level 29)
- **Display Output:** 1920x1080 native resolution with capacitive touchscreen
- **Deployment Mode:** Android Enterprise Device Owner, Kiosk LockTask mode

---

## 5. Phase Gate Roadmap

```mermaid
flowchart LR
    G0["Gate 0: Foundation Approval"] --> G1["Gate 1: Core Specifications (PRD/OpenAPI)"]
    G1 --> G2["Gate 2: Contract Tests & Mock Harness"]
    G2 --> G3["Gate 3: Implementation Phase"]
```

- **Gate 0 (Current):** Foundation architecture ratification, repository initialization, ADR review.
- **Gate 1:** Formal specifications (`PRD-001`, `PRD-002`, `PRD-003`, OpenAPI YAML, JSON Schemas).
- **Gate 2:** Mock server harnesses, contract tests, and physical hardware verification benchmarks.
- **Gate 3:** Application and backend service implementation.
