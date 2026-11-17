# Security & Cryptography Specifications

This directory contains the security architecture, threat models, cryptographic standards, and vulnerability mitigation protocols.

## Key Security Controls
1. **STRIDE Threat Model:** Exhaustive threat analysis covering spoofing, tampering, repudiation, information disclosure, denial of service, and elevation of privilege.
2. **Device Identity:** AndroidKeyStore-backed asymmetric ECDSA P-256 key generation on first boot. Private keys are non-exportable.
3. **Master Licensing:** Ed25519 cryptographic signatures generated exclusively by HINOPT backend authority and verified on-device via Google Tink.
4. **Offline Time Security:** 4-state time machine, monotonic clock tracking (`SystemClock.elapsedRealtime()`), persistent high-water mark logging, and safe quarantine screens upon rollback detection.
5. **USB Media Lockdown:** USB external media access disabled via Android Device Policy Manager (`DISALLOW_MOUNT_PHYSICAL_MEDIA`).
