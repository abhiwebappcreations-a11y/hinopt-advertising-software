# Android Display Player Application

**Target Platform:** TPC 151TCT (ARMv8 Quad Core, 2GB RAM, 16GB eMMC, Android 10)  
**Technology Stack:** Native Kotlin, Android SDK (minSdk 29), Jetpack Media3 (ExoPlayer), Room SQLite, AndroidKeyStore, WorkManager.

## Architecture Highlights
- **Kiosk Execution:** Runs in Android LockTask mode as Device Owner.
- **Continuous Foreground Service:** Backed by `SignagePlaybackService` with a partial wake lock and ongoing notification, executing an adaptive 60–120s HTTPS polling loop without OS throttling.
- **4-State Time Machine:** Monotonic clock calculation via `SystemClock.elapsedRealtime()`, Room high-water mark rollback detection, and safe quarantine screen on tamper or unanchored reboot.
- **Offline Storage:** Plain SQLite Room DB for schedules and logs + `AndroidKeyStore` / `EncryptedSharedPreferences` for device identity and credentials.
- **Zero USB Ingress:** External physical USB storage mounting is blocked via Device Policy Manager.
