#!/bin/bash
# GGEN Device Validation Script
# Captures diagnostics before, during, and after each test phase
# Usage: ./device-test.sh <action> [args]

ADB=~/android-sdk/platform-tools/adb
PKG=com.example.ggen
LOG_DIR=/home/sbj/ggen/docs/device-evidence
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$LOG_DIR/${TIMESTAMP}-logcat.log"

case "$1" in
  clear)
    $ADB shell pm clear $PKG 2>&1
    ;;
  install)
    APK=$2
    if [ -z "$APK" ]; then
      echo "Usage: ./device-test.sh install <path-to-apk>"
      exit 1
    fi
    $ADB install -r "$APK"
    ;;
  launch)
    $ADB shell am start -n $PKG/.MainActivity
    sleep 2
    ;;
  stop)
    $ADB shell am force-stop $PKG
    ;;
  start-log)
    $ADB logcat -c
    $ADB logcat > "$LOG" &
    echo "Logging to $LOG (PID: $!)"
    ;;
  stop-log)
    pkill -f "adb logcat"
    echo "Log saved to $LOG"
    cat "$LOG" | grep -E "(node_add|history_|gesture_|project_save|project_restore|grid_toggle|inspector_text|configure_text_columns|text_flow_|top_action_reorder|flutter_error|uncaught_error|Duplicate)" | tee "$LOG.events"
    ;;
  check-events)
    EVENT=$2
    if [ -z "$EVENT" ]; then
      echo "Usage: ./device-test.sh check-events <event-name>"
      exit 1
    fi
    $ADB logcat -d | grep -i "$EVENT" | tail -20
    ;;
  all-events)
    $ADB logcat -d | grep -E "(node_add|history_|gesture_|project_save|project_restore|grid_toggle|inspector_text|configure_text_columns|text_flow_|top_action_reorder|flutter_error|uncaught_error|Duplicate|cluster_|compact_|landscape_)" | tee "$LOG_DIR/${TIMESTAMP}-events.log"
    ;;
  package-info)
    $ADB shell pm list packages | grep ggen
    $ADB shell pm path $PKG
    ;;
  *)
    echo "GGEN Device Test Script"
    echo "Actions: clear, install <apk>, launch, stop, start-log, stop-log, check-events <name>, all-events, package-info"
    exit 1
    ;;
esac
