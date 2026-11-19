#!/usr/bin/env bash
# ==============================================================================
# HW-TEST-01: Storage Partition Measurement Script
# Target: TPC 151TCT (Android 10 / 16GB eMMC)
# Purpose: Measures empirical usable storage on /data partition
# Success Criteria: >= 6.0 GB available for application cache and Room SQLite
# ==============================================================================

echo "======================================================================"
echo "  HINOPT Hardware Verification: HW-TEST-01 (Storage Partition Audit)  "
echo "======================================================================"

# Check if device is connected via ADB
if ! command -v adb &> /dev/null; then
    echo "[ERROR] 'adb' command not found. Please install Android Platform Tools."
    exit 1
fi

DEVICE_COUNT=$(adb devices | grep -v "List" | grep "device$" | wc -l)
if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "[ERROR] No Android device connected via ADB. Please connect TPC 151TCT."
    exit 1
fi

echo "[INFO] Connected Device: $(adb shell getprop ro.product.model) (Android $(adb shell getprop ro.build.version.release))"
echo "----------------------------------------------------------------------"

# Inspect partition sizes
echo "[INFO] Querying filesystem table for /data partition..."
adb shell df -h /data

# Extract usable bytes
FREE_BLOCKS=$(adb shell stat -f -c "%a" /data | tr -d '\r')
BLOCK_SIZE=$(adb shell stat -f -c "%s" /data | tr -d '\r')
FREE_BYTES=$((FREE_BLOCKS * BLOCK_SIZE))
FREE_MB=$((FREE_BYTES / 1024 / 1024))
FREE_GB=$(awk "BEGIN {printf \"%.2f\", $FREE_MB / 1024}")

echo "----------------------------------------------------------------------"
echo "[RESULT] Exact Free Storage on /data: ${FREE_MB} MB (${FREE_GB} GB)"

if [ "$FREE_MB" -ge 6000 ]; then
    echo "[PASS] Usable storage exceeds required 6.0 GB threshold."
    echo "[ACTION] Media storage cache quota of 5.0 GB is APPROVED."
    exit 0
else
    echo "[WARNING] Usable storage is LESS than 6.0 GB (${FREE_GB} GB)."
    echo "[ACTION] Recommend adjusting dynamic storage watermark or reducing cache."
    exit 2
fi
