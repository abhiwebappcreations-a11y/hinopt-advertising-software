#!/usr/bin/env bash
# ==============================================================================
# HW-TEST-04: Thermal Dissipation & CPU Throttling Monitor
# Target: TPC 151TCT (Fanless Industrial Chassis)
# Purpose: Logs CPU SoC temperature every 10 seconds during 1080p continuous playback
# Success Criteria: SoC temperature <= 75C; zero thermal frequency throttling
# ==============================================================================

LOG_FILE="thermal_log_$(date +%Y%m%d_%H%M%S).csv"
echo "Timestamp,Zone0_Temp_C,Zone1_Temp_C,CPU_Freq_KHz" > "$LOG_FILE"

echo "======================================================================"
echo "  HINOPT Hardware Verification: HW-TEST-04 (Thermal Monitoring)       "
echo "  Logging to: $LOG_FILE (Press Ctrl+C to stop)                         "
echo "======================================================================"

while true; do
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Read thermal zones (temperatures usually in millidegrees C)
    TEMP0=$(adb shell "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null" | tr -d '\r')
    TEMP1=$(adb shell "cat /sys/class/thermal/thermal_zone1/temp 2>/dev/null" | tr -d '\r')
    
    # Read current CPU frequency
    FREQ=$(adb shell "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null" | tr -d '\r')

    # Convert to Celsius
    TEMP0_C=$(awk "BEGIN {printf \"%.1f\", $TEMP0 / 1000}")
    TEMP1_C=$(awk "BEGIN {printf \"%.1f\", $TEMP1 / 1000}")

    echo "$TIMESTAMP, $TEMP0_C C, $TEMP1_C C, Freq: ${FREQ} KHz"
    echo "$TIMESTAMP,$TEMP0_C,$TEMP1_C,$FREQ" >> "$LOG_FILE"

    sleep 10
done
