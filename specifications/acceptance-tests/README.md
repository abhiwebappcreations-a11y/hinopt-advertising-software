# Acceptance Criteria & Verification Tests

This directory contains formal acceptance criteria, Gherkin feature files, and verification test matrices for HINOPT Advertising Software.

## Structure
- `features/offline-playback.feature`: Validates offline playback transitions and cache survival.
- `features/time-tamper-detection.feature`: Validates rollback quarantine and monotonic clock checks.
- `features/licensing-enforcement.feature`: Validates licence expiry and revocation synchronization.
- `features/campaign-day-parting.feature`: Validates start/end date and time-of-day slot execution.
