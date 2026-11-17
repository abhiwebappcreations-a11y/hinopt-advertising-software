# Architecture Documentation

This directory contains the system architecture documentation for **HINOPT Advertising Software**.

## Contents

- [foundation-revision-3.0.md](file:///d:/Advertising%20&%20Digital%20Signage%20Management%20Platform/docs/architecture/foundation-revision-3.0.md) — The ratified foundational architecture document (Revision 3.0), including:
  - Dual-domain platform ownership (HINOPT Sovereign Domain vs Admobitics Operations Tenant).
  - TPC 151TCT hardware profile and constraints.
  - 4-state offline time machine and rollback quarantine policy.
  - Android Kiosk Foreground Architecture.
  - Dual Supabase project isolation (`hinopt-core` vs `admobitics-ads`).
  - Cloudflare R2 storage architecture with 3-day retention policy.
- Future C4 diagrams (Context, Container, Component, Code) will be maintained in this directory.
