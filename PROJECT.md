# Project Charter: HINOPT Ads Display Software

**Project Name:** HINOPT Ads Display Software  
**Software Platform Owner:** HINOPT  
**Commercial Model:** B2B Multi-Tenant Software Platform  
**Document Class:** Master Engineering Charter  
**Version:** 1.1.0 (Clean Production Baseline)  

---

## 1. Product Identity & Business Model Clarification

### 1.1 The Software Owner (HINOPT)
**HINOPT** is the creator and sovereign platform owner of the **HINOPT Ads Display Software**.
- HINOPT owns the software intellectual property (IP), master licensing authority, hardware cryptographic enrollment, and global product governance.
- The HINOPT Super-Admin Portal is used exclusively by HINOPT to register commercial clients, issue/revoke software licences, set screen quotas, and monitor display health.

### 1.2 The Clients (e.g., Admobitics)
**Admobitics** is an independent advertising company and is **a commercial client/customer of HINOPT**.
- Admobitics is **NOT** the software owner, and Admobitics is **NOT** hardcoded into the platform.
- HINOPT licenses the software to Admobitics (and can license it to any other advertising network, retail chain, or media agency).
- Each client receives access to their own **Client Business Portal** where they manage their own advertisers, upload their own ads, create their own day-part schedules, and view proof-of-play reports.

### 1.3 Strict Zero-Demo-Data Policy (Clean Slate Invariant)
To prevent confusion and ensure production readiness:
1. **Zero Pre-Seeded Clients:** Out of the box, the database contains **zero clients/tenants**. The HINOPT Super-Admin sees a clean, empty dashboard. A client appears **only when HINOPT Super-Admin explicitly registers them**.
2. **Zero Pre-Seeded Displays:** Out of the box, there are **zero screens**. A screen appears **only when an actual physical TPC 151TCT display powers on, generates an activation code, and is approved**.
3. **Zero Pre-Seeded Campaigns / Advertisers:** The client portal starts with **zero advertisers, zero campaigns, and zero media assets**.

---

## 2. Phase 1 Boundaries & Constraints

| Domain | Supported in Phase 1 | Explicitly Out of Scope for Phase 1 |
| :--- | :--- | :--- |
| **Edge Hardware** | **Android only:** TPC 151TCT (ARMv8 Quad Core, 2GB RAM, 16GB eMMC, Android 10, 1920x1080 touchscreen). | Linux SoC, Raspberry Pi, Windows, ChromeOS, LG webOS, Samsung Tizen. |
| **Display Runtime** | Native Kotlin, Jetpack Media3 (ExoPlayer), Room SQLite, AndroidKeyStore (ECDSA P-256). | Cross-platform frameworks on player, Electron, pure web players. |
| **Advertising Model**| Direct-booked campaigns (date/time day-parting, screen targeting, image/video). | VAST, VPAID, OpenRTB, programmatic bidding, real-time ad auctions. |
| **Communication** | HTTPS REST APIs with adaptive polling (60–120s) and manifest hashing (`ETag`). | MQTT, WebSockets, gRPC streaming, peer-to-peer media sharing. |
| **Media Ingress** | Authenticated admin portal upload to Cloudflare R2; signed download over HTTPS. | USB media importing, physical drive auto-mounting, direct camera streaming. |
| **Media Retention** | Campaign End Date + exactly 3 additional days. | Indefinite archival, uncurated local drive accumulation. |

---

## 3. Platform Hierarchy

```
+--------------------------------------------------------------------------+
|                       HINOPT (Platform Owner)                            |
|  - Sovereign Master Licensing & Device Cryptographic Authority           |
|  - Manages Commercial Clients / Tenants (e.g. Admobitics, Client B, ...) |
|  - Hardware Device Enrollment (TPC 151TCT displays)                      |
|  - Screen Quotas, Plan Entitlements & Kill-Switch Revocation             |
+--------------------------------------------------------------------------+
                                     |
                  Authenticated HTTPS REST Inter-Plane API
                                     |
+--------------------------------------------------------------------------+
|                  Client Advertising Companies (e.g. Admobitics)          |
|  - Manages Their Own Advertisers & Commercial Contracts                  |
|  - Uploads & Validates 1080p Media (Cloudflare R2)                       |
|  - Builds Day-Parting Matrices & Target Screen Playlists                 |
|  - Generates Proof-of-Play Billing Reconciliation Reports                |
+--------------------------------------------------------------------------+
                                     |
                          Encrypted Local Cache
                                     |
+--------------------------------------------------------------------------+
|                  TPC 151TCT Physical Edge Display Player                 |
|  - 100% Offline Autonomy (Media3 Hardware 1080p Decoding)                |
|  - 4-State Time Security Engine & Rollback Quarantine                    |
|  - Aggregated Proof-of-Play Tallying in Room SQLite                      |
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
