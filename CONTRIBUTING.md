# Contributing to HINOPT Advertising Software

This document defines the professional engineering guidelines, quality standards, and contribution workflow for **HINOPT Advertising Software**.

---

## 1. Specification-Driven Development (SDD) Protocol

We follow strict **Specification-Driven Development**. Code is an artifact of approved specifications.

1. **No Spec, No Code:** No pull request introducing application features or schema changes will be merged without an approved specification in `specifications/` and an accompanying Architecture Decision Record in `specifications/decisions/`.
2. **Contract-First Development:** Interface changes (REST endpoints, JSON payloads, manifest schemas) must be committed to `docs/api/` as OpenAPI 3.1 YAML or JSON Schemas before client/server implementation.
3. **Traceability:** Every commit and PR must reference a specific requirement ID (e.g., `PRD-001-REQ-04`).

---

## 2. Commit Message Conventions

We enforce [Conventional Commits (v1.0.0)](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>

[optional body]

[optional footer(s)]
```

### Allowed Types
- `spec`: Changes to specifications, PRDs, or schemas.
- `adr`: New or updated Architecture Decision Records.
- `feat`: A new feature or capability.
- `fix`: A bug fix.
- `docs`: Documentation-only updates.
- `refactor`: Code changes that neither fix a bug nor add a feature.
- `test`: Adding or correcting tests.
- `chore`: Build process, auxiliary tools, or dependency updates.

### Allowed Scopes
- `player`: Android display player (`apps/android-player`).
- `admin-hinopt`: HINOPT admin portal (`apps/hinopt-admin`).
- `admin-admobitics`: Admobitics business portal (`apps/business-admin`).
- `licensing`: HINOPT licensing backend (`backend/licensing-service`).
- `advertising`: Admobitics advertising backend (`backend/advertising-service`).
- `media`: Media ingestion and storage service (`backend/media-service`).
- `db`: Supabase migrations and schema definitions (`infrastructure/supabase`).
- `hardware`: TPC 151TCT test scripts and hardware profiles (`tools/development`).

---

## 3. Engineering Quality Gates

### 3.1 Strict Type Safety
- **TypeScript:** Strict mode enabled (`"strict": true`, `"noImplicitAny": true`). Zero usage of `any`.
- **Kotlin:** Strict null safety. Explicit typing on public APIs. No forced unwraps (`!!`).

### 3.2 Panic-Free Edge Player Rules
- The Android display player must be resilient against runtime panics.
- All media decoding operations, network calls, and SQLite transactions must be wrapped in structured error-handling scopes.
- Unhandled exceptions must be trapped by a global default uncaught exception handler and logged to encrypted local storage before a clean recovery restart.

### 3.3 Security & Secret Management
- **Zero Secrets in Repository:** Never commit API keys, private keys, passwords, or `.env` files.
- **Keystore Isolation:** Private keys on Android must be generated and stored inside `AndroidKeyStore`.
- **Credential Segregation:** HINOPT credentials must never be accessed or imported into Admobitics modules.

---

## 4. Branching Strategy

- `main`: Production-ready, fully tested codebase. Direct pushes are disabled; changes require approved PRs.
- `develop`: Integration branch for the active phase gate.
- `feature/<scope>-<description>`: Topic branches branched from `develop`.
- `spec/<scope>-<description>`: Specification and ADR drafting branches.

---
*HINOPT Software Engineering Standards — Revision 1.0*
