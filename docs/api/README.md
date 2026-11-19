# API & Protocol Specifications

This directory contains the formal contract-first **OpenAPI 3.1 Specifications** governing all client-server, inter-domain, and display communications within **HINOPT Advertising Software**.

---

## 1. OpenAPI Specification Register

| API Specification | Target Service | Base URL | Scope & Security |
| :--- | :--- | :--- | :--- |
| **[openapi-hinopt-licensing-v1.yaml](file:///d:/Advertising%20&%20Digital%20Signage%20Management%20Platform/docs/api/openapi-hinopt-licensing-v1.yaml)** | HINOPT Sovereign Authority | `https://authority.hinopt.com/v1` | Master device pre-authorization, cryptographic ECDSA P-256 enrollment, Ed25519 token issuance, health heartbeats, screen revocation, and replacement. |
| **[openapi-admobitics-campaigns-v1.yaml](file:///d:/Advertising%20&%20Digital%20Signage%20Management%20Platform/docs/api/openapi-admobitics-campaigns-v1.yaml)** | Admobitics Advertising Service | `https://api.admobitics.hinopt.com/v1` | Direct-booked campaigns, day-parting grids, screen configurations, $O(1)$ sync manifests (`304 Not Modified`), and proof-of-play report ingestion. |
| **[openapi-media-service-v1.yaml](file:///d:/Advertising%20&%20Digital%20Signage%20Management%20Platform/docs/api/openapi-media-service-v1.yaml)** | Media Ingestion Service | `https://media.admobitics.hinopt.com/v1` | Pre-signed Cloudflare R2 S3 PUT uploads, 1080p video spec validation, SHA-256 integrity registration, and automated 3-day retention purges. |

---

## 2. Global Error Response Standard (Option A)

All APIs enforce the user-ratified **Simple Structured Error Standard**:

```json
{
  "error": {
    "code": "ACTIVATION_CODE_EXPIRED",
    "message": "The 6-digit activation code has expired. Please refresh the screen.",
    "timestamp": "2026-11-19T12:00:00Z"
  }
}
```

---

## 3. Cryptographic Authentication Models

1. **Administrative Portals (Flutter):** Standard JWT Bearer tokens passed via HTTP `Authorization: Bearer <jwt>`.
2. **Edge Displays (TPC 151TCT):** Hardware-backed HTTP request signatures generated via `AndroidKeyStore` passed in headers:
   - `X-Device-Id`: Opaque `hinopt_device_id` UUID.
   - `X-Device-Timestamp`: Current UTC epoch timestamp (rejected if clock skew > 300s).
   - `X-Device-Signature`: Base64-encoded ECDSA P-256 signature computed over `METHOD\nPATH\nTIMESTAMP\nSHA256(BODY)`.
