# HW-TEST-07: Real-Time Clock (RTC) Battery Verification Protocol

**Test ID:** HW-TEST-07  
**Target Hardware:** TPC 151TCT (Motherboard RTC Audit)  
**Objective:** Confirm whether the motherboard contains a functional battery-backed Real-Time Clock (RTC coin-cell or supercapacitor) that maintains wall-clock time across complete AC power disconnects.

---

## 1. Test Procedure

1. **Step 1:** Connect the TPC 151TCT to network time (Wi-Fi or Ethernet) to ensure the system clock is set to the current date and time.
2. **Step 2:** Disconnect the network (Turn Wi-Fi OFF and unplug Ethernet).
3. **Step 3:** Record the exact current time from Android:
   ```bash
   adb shell date
   ```
4. **Step 4:** Completely disconnect the main power adapter from the unit.
5. **Step 5:** Keep the unit completely unpowered for **60 minutes**.
6. **Step 6:** Reapply power (keeping network disconnected / offline).
7. **Step 7:** Immediately read the Android clock after boot:
   ```bash
   adb shell date
   ```

---

## 2. Evaluation & Architectural Impact

- **Result A (Hardware RTC Present):** The clock reports the original time plus approximately 60 minutes ($\pm 10\text{ seconds}$).
  - *Impact:* Confirms hardware battery-backed RTC is functional. Offline campaign expiry across reboots is reliable.
- **Result B (No Hardware RTC / Dead Battery):** The clock resets to `1970-01-01` or kernel build date.
  - *Impact:* The HINOPT 4-State Time Machine's persistent `high_water_mark` and 24-hour untrusted grace ceiling become the primary defense against clock drift.
