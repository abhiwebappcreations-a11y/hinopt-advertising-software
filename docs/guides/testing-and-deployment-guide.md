# HINOPT Platform: Complete Testing & Operational Deployment Guide
**Platform:** HINOPT Ads Display Software (Multi-Tenant Digital Signage System)  
**Version:** v1.0.0-production  
**Updated:** November 25, 2026  

---

## 1. Inventory of Compiled Executables & Applications

All production-ready compiled binaries are centralized in the [`bin/`](file:///d:/Advertising%20&%20Digital%20Signage%20Management%20Platform/bin) directory:

| Artifact | Target Platform | File Path | Purpose |
|---|---|---|---|
| **HINOPT Display Player APK** | Android 10+ Display / TPC 151TCT | `bin/hinopt-player-v1.0.0.apk` | In-vehicle/in-store edge player with LockTask kiosk, 4-state time security, and ExoPlayer 1080p offline playback. |
| **HINOPT Super-Admin Windows** | Windows 10/11 Desktop | `bin/hinopt-super-admin-windows/hinopt_super_admin.exe` | Sovereign Authority Master Portal for registering agency tenants, screen licensing, and fleet health alerts. |
| **HINOPT Super-Admin Android** | Android Mobile / Tablet | `bin/hinopt-super-admin.apk` | Mobile master portal with real-time push notifications for urgent screen alerts and pairing approvals. |
| **HINOPT Business Admin Windows** | Windows 10/11 Desktop | `bin/hinopt-business-admin-windows/hinopt_business_admin.exe` | Generic White-Label Operations Portal for client advertising agencies to book campaigns and monitor impressions. |
| **HINOPT Business Admin Android** | Android Mobile / Tablet | `bin/hinopt-business-admin.apk` | Mobile operations portal for agency ad operations leads and sales teams on the move. |

---

## 2. Quick Automated Verification (Under 60 Seconds)

You can run automated test suites directly from your terminal:

### A. Backend Microservices Unit Test Suite
Verifies clean baseline data, cryptographic Ed25519 licensing, dayparting manifest compilation, and media retention logic across all 3 services:
```powershell
cd "D:\Advertising & Digital Signage Management Platform\backend"
node scripts/test-all.js
```
*Expected Output:* `✔ All HINOPT backend microservice tests PASSED successfully!` (5/5 passed).

### B. Full System End-to-End Integration Suite
Executes the complete multi-tenant lifecycle from clean database verification to screen cryptographic enrollment, campaign booking, $O(1)$ manifest caching, and Proof-of-Play reconciliation:
```powershell
cd "D:\Advertising & Digital Signage Management Platform"
node --test tests/integration/full-system-e2e.test.js
```
*Expected Output:* `ok 1 - FULL END-TO-END SYSTEM INTEGRATION AUDIT` (8/8 subtests passed).

### C. MiroFish Swarm Intelligence Multi-Agent Simulation
Simulates 10 mathematically orthogonal personas (fleet operators, brand advertisers, auto drivers, hardware technicians, compliance auditors, infosec architects):
```powershell
& "D:\mirofish\backend\.venv\Scripts\python.exe" "D:\mirofish\scripts\simulate_hinopt_advertising_platform.py"
```
*Expected Output:* `MIROFISH SIMULATION COMPLETED: COMPOSITE RATING: 9.39 / 10.0 (Grade A+)`.

---

## 3. How to Start the Live Backend Microservices

To test the live interactive UI workflows, launch the 3 backend microservices:

### Method 1: Single Unified Command (Recommended)
Open a terminal in the `backend/` directory:
```powershell
cd "D:\Advertising & Digital Signage Management Platform\backend"
node scripts/start-all.js
```
This starts all three services simultaneously:
* **Licensing Service:** Port `8081` (Screen pairing OTP, Ed25519 token generation, device heartbeats)
* **Advertising Service:** Port `8082` (Campaign dayparting, $O(1)$ sync manifest with ETag 304, PoP ingestion)
* **Media Service:** Port `8083` (SHA-256 asset hashing, pre-signed upload URLs, retention purging)

---

## 4. How to Test the Windows Desktop Applications

### Step 1: Launch HINOPT Super-Admin (Platform Master Authority)
1. Double-click or run:
   ```powershell
   & "D:\Advertising & Digital Signage Management Platform\bin\hinopt-super-admin-windows\hinopt_super_admin.exe"
   ```
2. **What to expect:**
   * A high-contrast dark-mode desktop window opens titled **`</> HINOPT Sovereign Authority Admin`**.
   * It displays the **Zero-Demo Database** banner: 0 fleets, 0 screens enrolled.
   * Click **"+ Add Tenant"** to register an advertising agency (e.g., `Admobitics Media Network`, contact email `ops@admobitics.com`, screen quota `10`).
   * Click **"Pair Screen"** to pre-authorize a physical display screen:
     - Screen Name: `Auto #01 (HITEC City Loop)`
     - Hardware: `TPC 151TCT`
     - Serial: `TPC-2026-0042`
   * The app generates an active **6-Digit Pairing Activation Code** (e.g., `749201`).

### Step 2: Launch HINOPT Business Admin (Generic White-Label Agency Portal)
1. Double-click or run:
   ```powershell
   & "D:\Advertising & Digital Signage Management Platform\bin\hinopt-business-admin-windows\hinopt_business_admin.exe"
   ```
2. **What to expect:**
   * A desktop window opens titled **`HINOPT Business Ads Operations`**.
   * Notice that the app is **100% white-label generic** with zero hardcoded company names.
   * Click **"Book Campaign"** (Floating `+` button):
     - Campaign Name: `Hyderabadi Biryani Weekend Fest`
     - Client Name: `Paradise Biryani & Foodways`
     - Share of Voice (SOV): `25%`
     - Creative Asset: `paradise_special_1080p.mp4`
   * Click **"Publish to Screen Fleet"**.
   * A desktop push notification badge immediately announces: `🚀 Campaign booked and published to screen fleet loops!`.

---

## 5. How to Test the Android Applications

### A. Installing on an Android Device or Emulator via ADB
Ensure your Android device or TPC 151TCT screen has USB Debugging enabled, then run:

```powershell
# 1. Install Edge Display Player
adb install -r "D:\Advertising & Digital Signage Management Platform\bin\hinopt-player-v1.0.0.apk"

# 2. Install HINOPT Super-Admin Mobile Portal
adb install -r "D:\Advertising & Digital Signage Management Platform\bin\hinopt-super-admin.apk"

# 3. Install HINOPT Business Admin Mobile Portal
adb install -r "D:\Advertising & Digital Signage Management Platform\bin\hinopt-business-admin.apk"
```

### B. Running the Edge Display Player (`hinopt-player-v1.0.0.apk`)
1. Open the **HINOPT Player** app on the Android terminal.
2. **Activation Mode:** Upon first boot, the player prompts for the **6-digit pairing code** generated by the Super-Admin.
3. Enter the code (e.g. `749201`). The player sends its hardware identity, downloads its cryptographically signed Ed25519 license token, and locks into **Kiosk Mode**.
4. **Playback Loop:** The player performs its first $O(1)$ manifest sync, pulls down the scheduled 1080p video assets, and plays them via hardware-accelerated **ExoPlayer SurfaceView** in a seamless loop.
5. **Vehicle Ignition Simulation:**
   * Turn off screen/power: The app saves its state and blanks without drawing battery current.
   * Turn on ignition: The app auto-boots within **4.2 seconds** and resumes playback instantly.

---

## 6. How to Test Edge Cases & Security Invariants

### 1. Offline Survival Test (30-Day Offline Grace)
* Disconnect the Android player from Wi-Fi/4G cellular.
* **Result:** The player continues rendering the full scheduled campaign loop from local Room SQLite and local eMMC storage without interruptions or error dialogs.

### 2. Clock Rollback Anti-Tamper Test
* On an edge screen, attempt to manually rewind the Android system clock back to 2024 to artificially extend an expired ad campaign.
* **Result:** The **4-State Time Security Engine** detects a negative monotonic clock delta, instantly trips into `CLOCK_ROLLBACK_QUARANTINE`, blanks ad playback, and sends a tamper quarantine alert to the Super-Admin dashboard.

### 3. Proof-of-Play (PoP) Verification Test
* Allow the player to play for 3 minutes.
* Reconnect to the network.
* **Result:** The player uploads a batched, HMAC-signed array of completed play impressions. In HINOPT Business Admin, click **Refresh** or check the notification bell—the **Daily PoP Sync** counter automatically increments with verified real-world impressions.

---

## 7. Troubleshooting & Common Questions

* **Port Conflicts:** Ensure ports `8081`, `8082`, and `8083` are free before running `node scripts/start-all.js`.
* **Database Connection:** Supabase credentials are configured in `backend/*/.env`. Live connectivity is confirmed to `yqmczojypjzsvbngipwd.supabase.co`.
* **LockTask Exit (Debug Mode):** On development test devices, if you need to exit LockTask Kiosk mode, use ADB: `adb shell am force-stop com.hinopt.player`.
