# Media Service

**Stack:** Node.js, TypeScript (Strict Mode), Cloudflare R2 S3-Compatible API  
**Domain Authority:** Admobitics Operations Tenant

## Responsibilities
- Pre-signed upload URL generation for authorized Admobitics admin users.
- Media asset ingestion validation (1080p resolution, H.264 profile, file size limits).
- SHA-256 checksum generation and integrity verification.
- Automated cleanup worker: deletes media files from Cloudflare R2 when all associated campaigns reach **End Date + 3 Days**.
