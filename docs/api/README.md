# API & Protocol Specifications

This directory contains OpenAPI 3.1 YAML specifications, JSON Schemas, and communication protocol definitions.

## APIs
1. **HINOPT Licensing & Device Authority API:**
   - Device enrollment, activation code validation, cryptographic token issuance, device health heartbeats.
2. **Admobitics Campaign & Sync API:**
   - Sync manifest delivery (`/sync-manifest`) with `ETag` and `manifest_version` optimization.
   - Proof-of-play batch reporting (`/playback-reports`).
3. **Media Delivery API:**
   - Cloudflare R2 pre-signed upload URLs and byte-range resumable HTTPS download contracts.
