# Changelog

All notable changes to **HINOPT Advertising Software** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] - 2026-11-17

### Added
- Initialized production-grade repository structure for HINOPT Advertising Software.
- Established master architecture foundation (Revision 3.0).
- Defined dual-domain operational boundaries: HINOPT (Platform Owner) vs Admobitics (Advertising Operations Tenant).
- Formulated 4-state offline time machine and rollback quarantine policy for edge display units.
- Defined Android Kiosk Foreground Architecture with `Activity` LockTask mode and continuous `ForegroundService`.
- Replaced single-project schema splitting with two physically isolated Supabase instances (`hinopt-core` vs `admobitics-ads`).
- Specified cryptographic device identity using `AndroidKeyStore` ECDSA P-256 and Google Tink Ed25519 verification.
- Defined Cloudflare R2 media storage architecture with automated **Campaign End Date + 3 Days** retention policy.
- Formulated 7-step physical hardware benchmarking protocol for the TPC 151TCT industrial panel.
- Established formal repository directory tree: `docs/`, `specifications/`, `apps/`, `backend/`, `infrastructure/`, `tests/`, and `tools/`.
