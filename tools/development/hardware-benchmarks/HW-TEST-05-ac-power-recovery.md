# HW-TEST-05: AC Power Loss & Auto-Reboot Verification Protocol

**Test ID:** HW-TEST-05  
**Target Hardware:** TPC 151TCT (ARMv8 Quad Core / Android 10)  
**Objective:** Confirm that the display automatically boots and launches the HINOPT kiosk player when mains AC power is restored after a sudden power outage, without requiring a physical power button press.

---

## 1. Test Equipment & Prerequisites
1. TPC 151TCT display with power adapter plugged into a switched power strip.
2. HINOPT Player APK installed and set as default Home launcher.
3. Stopwatch / Timer.

---

## 2. Test Procedure

1. **Step 1:** Power on the TPC 151TCT and confirm that the HINOPT display player is actively rendering media.
2. **Step 2:** Without shutting down Android through software, switch off the power strip (simulating a sudden venue power failure).
3. **Step 3:** Wait 60 seconds to allow motherboard capacitors to fully discharge.
4. **Step 4:** Switch the power strip back on (restoring mains AC power). **Do not touch the physical power button on the back of the panel.**
5. **Step 5:** Start stopwatch. Observe screen behavior.

---

## 3. Success Criteria & Verification Matrix

| Checkpoint | Expected Behavior | Actual Observation | Status |
| :--- | :--- | :--- | :---: |
| **Auto-Power On** | Screen backlights turn on and Android boot logo appears automatically within 10 seconds of AC power restore. | [To be recorded] | [PASS / FAIL] |
| **Boot Completion** | Android completes boot to Home screen within 45 seconds. | [To be recorded] | [PASS / FAIL] |
| **Auto-Launch** | HINOPT Player launches into LockTask Kiosk mode automatically within 10 seconds of boot completion. | [To be recorded] | [PASS / FAIL] |
| **Playback Resume**| Offline media playback resumes seamlessly without requiring touch input or network connection. | [To be recorded] | [PASS / FAIL] |

*If the unit fails to power on automatically, verify BIOS / Firmware settings for "Restore on AC Power Loss" (Power On).*
