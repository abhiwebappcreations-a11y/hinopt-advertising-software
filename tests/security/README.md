# Security & Tamper Tests

This directory contains automated security verification suites, penetration test scripts, and cryptographic tamper tests.

## Test Scenarios
- **Clock Rollback Injection:** Simulating OS system time set backwards past the Room high-water mark; verifying immediate transition to quarantine safe screen.
- **Licence Signature Forgery:** Injecting forged Ed25519 licences; verifying immediate rejection by Google Tink validator.
- **Tenant Boundary Violation:** Attempting to query `hinopt-core` endpoints with `admobitics-ads` credentials; verifying HTTP 401/403 rejection.
- **USB Ingress Denial:** Attempting to mount external media; verifying DPM restriction enforcement.
