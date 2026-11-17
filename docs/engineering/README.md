# Engineering Standards & Runbooks

This directory contains technical engineering guidelines, style guides, linting rules, and CI/CD workflow standards for HINOPT Advertising Software.

## Guidelines
1. **Type Safety:** 100% strict typing in TypeScript and Kotlin.
2. **Panic-Free Edge Player:** All Android media decoding, database, and network operations must implement graceful error recovery.
3. **Linting & Formatting:** ESLint + Prettier (Node.js/TypeScript), ktlint (Kotlin), flutter_lints (Flutter).
4. **Git Workflow:** Conventional commits (`feat:`, `fix:`, `spec:`, `adr:`) and pull request review gates.
