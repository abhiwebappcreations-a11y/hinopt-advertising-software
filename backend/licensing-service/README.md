# HINOPT Licensing Service

**Stack:** Node.js, TypeScript (Strict Mode), Supabase PostgreSQL (`hinopt-core`)  
**Domain Authority:** HINOPT Platform Owner

## Responsibilities
- Device enrollment and activation code verification.
- Device public key registry (ECDSA P-256).
- Ed25519 cryptographic licence signing via secure cloud key management (KMS).
- Display heartbeat ingestion and device status tracking.
- Inter-plane device quota API for tenant systems (Admobitics).
- Strict isolation: holds credentials solely to `hinopt-core` Supabase project.
