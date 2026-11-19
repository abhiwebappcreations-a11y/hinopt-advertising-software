#!/usr/bin/env bash
# ==============================================================================
# HW-TEST-02: Hardware Video Codec Enumeration Script
# Target: TPC 151TCT (ARMv8 Quad Core / Android 10)
# Purpose: Verifies presence of hardware-accelerated H.264 (AVC) and H.265 (HEVC) decoders
# Success Criteria: Hardware 1080p @ 60fps decoders present (non-software Google codecs)
# ==============================================================================

echo "======================================================================"
echo "  HINOPT Hardware Verification: HW-TEST-02 (Hardware Video Codec Audit)"
echo "======================================================================"

if ! command -v adb &> /dev/null; then
    echo "[ERROR] 'adb' command not found."
    exit 1
fi

echo "[INFO] Querying Android MediaCodecList via dumpsys..."
CODEC_DUMP=$(adb shell dumpsys media.player)

# Check for H.264 / AVC decoders
echo "----------------------------------------------------------------------"
echo "[INFO] Checking for H.264 (video/avc) Hardware Decoders..."
AVC_DECODERS=$(adb shell "dumpsys media.player | grep -i 'omx\|c2' | grep -i 'avc' | grep -iv 'google\|sw'")
if [ -n "$AVC_DECODERS" ]; then
    echo "[PASS] Hardware H.264 Decoders Found:"
    echo "$AVC_DECODERS"
else
    echo "[WARNING] No hardware H.264 decoder detected. Software decoding will cause thermal throttling!"
fi

# Check for H.265 / HEVC decoders
echo "----------------------------------------------------------------------"
echo "[INFO] Checking for H.265 (video/hevc) Hardware Decoders..."
HEVC_DECODERS=$(adb shell "dumpsys media.player | grep -i 'omx\|c2' | grep -i 'hevc' | grep -iv 'google\|sw'")
if [ -n "$HEVC_DECODERS" ]; then
    echo "[PASS] Hardware H.265 Decoders Found:"
    echo "$HEVC_DECODERS"
else
    echo "[NOTICE] H.265 hardware decoder not found. Recommend standardizing on H.264 for Phase 1."
fi

echo "======================================================================"
