#!/usr/bin/env bash
# ==============================================================================
# HW-TEST-06: Device Owner & LockTask Kiosk Provisioning Script
# Target: TPC 151TCT (Android 10)
# Purpose: Validates ability to set HINOPT as Device Owner and suppress system bars
# Success Criteria: Device Owner granted; LockTask mode locks out navigation
# ==============================================================================

PACKAGE_NAME="com.hinopt.player"
RECEIVER_NAME="com.hinopt.player.receiver.AdminReceiver"

echo "======================================================================"
echo "  HINOPT Hardware Verification: HW-TEST-06 (Kiosk Mode Provisioning)  "
echo "======================================================================"

if ! command -v adb &> /dev/null; then
    echo "[ERROR] 'adb' command not found."
    exit 1
fi

echo "[INFO] Testing Device Owner provisioning via ADB..."
OUTPUT=$(adb shell dpm set-device-owner "$PACKAGE_NAME/$RECEIVER_NAME" 2>&1)

echo "$OUTPUT"

if echo "$OUTPUT" | grep -qi "Success"; then
    echo "----------------------------------------------------------------------"
    echo "[PASS] Device Owner successfully provisioned!"
    echo "[INFO] Enabling LockTask kiosk mode test..."
    adb shell am start -n "$PACKAGE_NAME/.ui.MainActivity"
    echo "[ACTION] Verify that Home, Back, Recent Apps, and Status Bar are locked."
    exit 0
elif echo "$OUTPUT" | grep -qi "already set"; then
    echo "[NOTICE] Device Owner is already configured for this package."
    exit 0
else
    echo "[WARNING] Device Owner provisioning failed. Please ensure no existing Google accounts exist in Android Settings -> Accounts."
    exit 1
fi
