# Development & Hardware Benchmarking Tools

This directory contains development utilities, mock backend servers, and the physical hardware benchmarking suite for the TPC 151TCT industrial panel.

## Hardware Verification Suite (TPC 151TCT)

Before initiating code implementation, the following physical tests must be executed:

1. **`HW-TEST-01-storage-audit.sh`:** Measure actual usable flash on `/data` after clean vendor OS boot. Target: $\ge 6.0\text{ GB}$.
2. **`HW-TEST-02-codec-audit.kt`:** Enumerate `MediaCodecList` for hardware H.264/H.265 decoders (`c2.*` or `OMX.*`).
3. **`HW-TEST-03-72h-stress.kt`:** 72-hour continuous 1080p video loop; verify memory stability $\le 192\text{MB}$ Java heap.
4. **`HW-TEST-04-thermal-monitor.sh`:** Measure SoC temperature under continuous 1080p decoding in 40°C ambient conditions.
5. **`HW-TEST-05-ac-power-recovery.md`:** Validate auto-boot on AC power restore without power button press.
6. **`HW-TEST-06-device-owner-setup.sh`:** Validate `dpm set-device-owner` and LockTask kiosk mode.
7. **`HW-TEST-07-rtc-battery-audit.md`:** Verify RTC hardware battery time retention across power loss.

## Development Mock Utilities
- `mock-licensing-server/`: Lightweight mock server implementing `openapi-hinopt-licensing.yaml`.
- `mock-advertising-server/`: Lightweight mock server implementing `openapi-admobitics-campaigns.yaml`.
