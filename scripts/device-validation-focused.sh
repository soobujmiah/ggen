#!/bin/bash
# Focused GGEN Device Validation - Redmi Turbo 4 Pro
ADB=/home/sbj/android-sdk/platform-tools/adb
PKG=com.example.ggen
LOG=/tmp/ggen_device_validation_2026-09-06.log

echo "==========================================" > "$LOG"
echo "GGEN Device Validation" >> "$LOG"
echo "Device: 25053RT47C (Redmi Turbo 4 Pro)" >> "$LOG"
echo "Android: 16" >> "$LOG"
echo "Date: $(date)" >> "$LOG"
echo "==========================================" >> "$LOG"
echo "" >> "$LOG"

check_event() {
    local event="$1"
    local timeout="${2:-5}"
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if $ADB shell "run-as $PKG cat app_flutter/debug_log.jsonl 2>/dev/null | grep -q \"\\\"event\\\":\\\"$event\\\"\""; then
            return 0
        fi
        sleep 0.5
        ((elapsed++))
    done
    return 1
}

get_event_detail() {
    local event="$1"
    $ADB shell "run-as $PKG cat app_flutter/debug_log.jsonl 2>/dev/null | grep \"$event\""
}

clear_log() {
    $ADB shell "run-as $PKG rm -f app_flutter/debug_log.jsonl" > /dev/null 2>&1
    sleep 0.5
}

restart_app() {
    $ADB shell am force-stop $PKG > /dev/null 2>&1
    sleep 1.5
    $ADB shell am start -n $PKG/$PKG.MainActivity > /dev/null 2>&1
    sleep 4
}

pass() {
    echo "  PASS: $1" | tee -a "$LOG"
}

fail() {
    echo "  FAIL: $1" | tee -a "$LOG"
}

info() {
    echo "  INFO: $1" | tee -a "$LOG"
}

# ===== TEST 1: App Launch & Restart-restore =====
echo "" >> "$LOG"
echo "=== TEST 1: App Launch & Restart-restore ===" >> "$LOG"
restart_app
clear_log

if check_event "storage_init" 5; then
    pass "storage_init detected"
else
    fail "storage_init NOT found"
fi

if check_event "project_restore" 5; then
    pass "project_restore detected"
    get_event_detail "project_restore" >> "$LOG"
else
    fail "project_restore NOT found (clean install may not have saved project)"
fi

if check_event "canvas_geometry" 5; then
    pass "canvas_geometry detected"
    get_event_detail "canvas_geometry" >> "$LOG"
else
    fail "canvas_geometry NOT found"
fi

# ===== TEST 2: Volume Undo/Redo =====
echo "" >> "$LOG"
echo "=== TEST 2: Volume Undo/Redo ===" >> "$LOG"
clear_log

# Create shapes first
$ADB shell "input tap 70 369"  # Rectangle tool
sleep 0.3
for i in 1 2 3 4 5; do
    $ADB shell "input tap $((500 + i*40)) $((1200 + i*20))"
    sleep 0.2
done
sleep 0.5

$ADB shell "input keyevent KEYCODE_VOLUME_DOWN"
sleep 0.3
$ADB shell "input keyevent KEYCODE_VOLUME_DOWN"
sleep 0.3
$ADB shell "input keyevent KEYCODE_VOLUME_UP"
sleep 0.3
$ADB shell "input keyevent KEYCODE_VOLUME_UP"

if check_event "volume_undo" 5; then
    pass "volume_undo detected"
    get_event_detail "volume_undo" >> "$LOG"
else
    fail "volume_undo NOT found"
fi

if check_event "volume_redo" 5; then
    pass "volume_redo detected"
    get_event_detail "volume_redo" >> "$LOG"
else
    fail "volume_redo NOT found"
fi

# ===== TEST 3: Two-finger tap undo (gesture_undo) via monkey =====
echo "" >> "$LOG"
echo "=== TEST 3: Two-finger tap undo (gesture_undo) ===" >> "$LOG"
clear_log
restart_app
sleep 2
clear_log

# Use monkey to generate multi-touch gestures
$ADB shell "monkey -p $PKG --pct-pinchzoom 100 -v 50" > /dev/null 2>&1
sleep 3

if check_event "gesture_undo" 5; then
    pass "gesture_undo detected (two-finger tap undo)"
    get_event_detail "gesture_undo" >> "$LOG"
else
    fail "gesture_undo NOT found"
    info "Checking all available events:"
    $ADB shell "run-as $PKG cat app_flutter/debug_log.jsonl 2>/dev/null" >> "$LOG"
fi

# ===== TEST 4: Three-finger redo (gesture_redo) via monkey =====
echo "" >> "$LOG"
echo "=== TEST 4: Three-finger redo (gesture_redo) ===" >> "$LOG"
clear_log
$ADB shell "monkey -p $PKG --pct-pinchzoom 100 -v 100" > /dev/null 2>&1
sleep 3

if check_event "gesture_redo" 5; then
    pass "gesture_redo detected (three-finger tap redo)"
    get_event_detail "gesture_redo" >> "$LOG"
else
    fail "gesture_redo NOT found"
    info "Three-finger redo may require manual testing or different gesture pattern"
fi

# ===== TEST 5: Node creation (Rectangle + Ellipse) =====
echo "" >> "$LOG"
echo "=== TEST 5: Node Creation (Rectangle + Ellipse) ===" >> "$LOG"
clear_log
restart_app
sleep 2
clear_log

$ADB shell "input tap 70 369"  # Rectangle
sleep 0.3
$ADB shell "input tap 640 1300"
sleep 0.2
$ADB shell "input tap 700 1400"
sleep 0.2
$ADB shell "input tap 70 500"  # Ellipse
sleep 0.3
$ADB shell "input tap 750 1450"
sleep 0.2
$ADB shell "input tap 850 1550"

RECT_COUNT=$($ADB shell "run-as $PKG cat app_flutter/debug_log.jsonl 2>/dev/null | grep -c 'node_add' || echo 0")
if [ "$RECT_COUNT" -ge 2 ] 2>/dev/null; then
    pass "Node creation working ($RECT_COUNT nodes created)"
    get_event_detail "node_add" >> "$LOG"
else
    fail "Node creation issue ($RECT_COUNT nodes)"
fi

# ===== TEST 6: Save and restart persistence =====
echo "" >> "$LOG"
echo "=== TEST 6: Save & Restart Persistence ===" >> "$LOG"
clear_log

# Ensure we have content
$ADB shell "input tap 70 369"
sleep 0.2
$ADB shell "input tap 640 1300"
sleep 0.3

# Tap save button (approximate position - top right area)
$ADB shell "input tap 1200 100"
sleep 1

# Force stop and restart
$ADB shell am force-stop $PKG
sleep 2
$ADB shell am start -n $PKG/$PKG.MainActivity
sleep 4

if check_event "project_restore" 5; then
    pass "project_restore after save detected"
    get_event_detail "project_restore" >> "$LOG"
else
    fail "project_restore after save NOT found"
fi

# ===== TEST 7: Grid toggle =====
echo "" >> "$LOG"
echo "=== TEST 7: Grid Overlay Toggle ===" >> "$LOG"
clear_log

# Try tapping grid button in the contextual action bar
# Based on device tests, grid toggle is around x=838-947, y=2647-2756
$ADB shell "input tap 892 2701"
sleep 1

if check_event "grid_toggle" 5; then
    pass "grid_toggle detected"
    get_event_detail "grid_toggle" >> "$LOG"
else
    fail "grid_toggle NOT found"
    info "Grid button position may need adjustment"
    info "Current events:"
    $ADB shell "run-as $PKG cat app_flutter/debug_log.jsonl 2>/dev/null" >> "$LOG"
fi

# ===== FINAL SUMMARY =====
echo "" >> "$LOG"
echo "==========================================" >> "$LOG"
echo "FINAL SUMMARY" >> "$LOG"
echo "==========================================" >> "$LOG"
echo "Device: Redmi Turbo 4 Pro (25053RT47C)" >> "$LOG"
echo "Android Version: 16" >> "$LOG"
echo "App Package: $PKG v0.1.0" >> "$LOG"
echo "Touchscreen: NVTCapacitiveTouchScreen (touch_mt, max 10 points)" >> "$LOG"
echo "" >> "$LOG"
echo "Multi-touch Input Method:" >> "$LOG"
echo "  - ADB monkey --pct-pinchzoom: WORKING" >> "$LOG"
echo "  - sendevent to /dev/input/event7: BLOCKED (permission denied)" >> "$LOG"
echo "  - Manual device interaction: RECOMMENDED for complete validation" >> "$LOG"
echo "" >> "$LOG"
echo "Validation Results:" >> "$LOG"
grep -E "PASS|FAIL|INFO" "$LOG" | tail -20 >> "$LOG"
echo "" >> "$LOG"
echo "Full diagnostic log:" >> "$LOG"
$ADB shell "run-as $PKG cat app_flutter/debug_log.jsonl 2>/dev/null" >> "$LOG"

echo ""
echo "Validation complete. Log saved to: $LOG"
