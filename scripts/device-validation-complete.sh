#!/bin/bash
# GGEN Device Validation - Comprehensive Test Suite
# Tests all flows with proper state management

PKG="com.example.ggen"
ACTIVITY="$PKG/com.example.ggen_app.MainActivity"
ADB="$HOME/android-sdk/platform-tools/adb"
PASS=0
FAIL=0
INFO=0
LOG_BACKUP="/tmp/ggen_debug_log_backup.jsonl"

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

verify_foreground() {
    local expected="$1"
    local fg=$($ADB shell dumpsys activity top 2>&1 | grep -oP 'ACTIVITY \K[^ ]+' | head -1)
    if [[ "$fg" == *"$expected"* ]]; then
        return 0
    else
        log "  WARNING: Expected $expected, got $fg"
        return 1
    fi
}

return_to_termux() {
    log "Returning to Termux..."
    $ADB shell am start -a android.intent.action.MAIN -c android.intent.category.HOME > /dev/null 2>&1
    $ADB shell input keyevent KEYCODE_HOME > /dev/null 2>&1
    sleep 1
    if verify_foreground "termux"; then
        log "  ✓ Termux is foreground"
    else
        log "  ⚠ Foreground verification failed"
    fi
}

clear_log() {
    $ADB shell run-as $PKG rm -f app_flutter/debug_log.jsonl 2>/dev/null
    sleep 0.5
}

get_logs() {
    $ADB shell run-as $PKG cat app_flutter/debug_log.jsonl 2>/dev/null
}

wait_for_event() {
    local event="$1"
    local timeout="${2:-5}"
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if get_logs | grep -q "\"$event\""; then
            return 0
        fi
        sleep 0.5
        ((elapsed++))
    done
    return 1
}

run_test() {
    local name="$1"
    local condition="$2"
    log "Testing: $name"
    if eval "$condition"; then
        log "  ✓ PASS"
        ((PASS++))
    else
        log "  ✗ FAIL"
        ((FAIL++))
    fi
}

start_app() {
    log "Starting app..."
    $ADB shell am force-stop $PKG > /dev/null 2>&1
    sleep 1
    $ADB shell am start -W $ACTIVITY > /dev/null 2>&1
    sleep 4
    clear_log
    wait_for_event "storage_init" 5
}

# ============================================================
# START VALIDATION
# ============================================================
log "=========================================="
log "GGEN Phase 2 Device Validation - Final"
log "Date: $(date)"
log "Device: $($ADB shell getprop ro.product.device 2>/dev/null)"
log "Serial: $($ADB shell getprop ro.serialno 2>/dev/null)"
log "Android: $($ADB shell getprop ro.build.version.release 2>/dev/null)"
log "SDK: $($ADB shell getprop ro.build.version.sdk 2>/dev/null)"
log "=========================================="
log ""

# Verify device connectivity
if ! $ADB devices | grep -q "device"; then
    log "ERROR: No device connected"
    exit 1
fi

# Start fresh
start_app

# Test 1: Storage init
run_test "Storage init logged" '[ "$(get_logs | grep -c "storage_init")" -gt 0 ]'

# Test 2: Workspace restore
run_test "Workspace restore logged" '[ "$(get_logs | grep -c "workspace_restore")" -gt 0 ]'

# Test 3: Canvas geometry
run_test "Canvas geometry logged" '[ "$(get_logs | grep -c "canvas_geometry")" -gt 0 ]'

log ""
log "=== Tool & Shape Tests ==="

# Test 4: Rectangle tool
clear_log
$ADB shell input tap 100 350 > /dev/null 2>&1
sleep 0.5
run_test "Rectangle tool selected" '[ "$(get_logs | grep -c "tool_select")" -gt 0 ]'
RECT_COUNT=$(get_logs | grep "tool_select" | grep -c "Rectangle")
log "  Rectangle selections: $RECT_COUNT"

# Test 5: Create shapes
clear_log
$ADB shell input tap 100 350 > /dev/null 2>&1
sleep 0.3
$ADB shell input tap 600 1300 > /dev/null 2>&1
sleep 0.2
$ADB shell input tap 700 1400 > /dev/null 2>&1
sleep 0.2
$ADB shell input tap 800 1500 > /dev/null 2>&1
sleep 0.5
SHAPE_COUNT=$(get_logs | grep -c "node_add")
run_test "Shape creation (rectangle)" "[ $SHAPE_COUNT -ge 3 ]"
log "  Shapes created: $SHAPE_COUNT"

# Test 6: Ellipse tool
clear_log
$ADB shell input tap 100 500 > /dev/null 2>&1
sleep 0.5
run_test "Ellipse tool selected" '[ "$(get_logs | grep "tool_select" | grep -c "Ellipse")" -gt 0 ]'
$ADB shell input tap 650 1350 > /dev/null 2>&1
sleep 0.3
ELLIPSE_COUNT=$(get_logs | grep -c "node_add")
run_test "Ellipse creation" "[ $ELLIPSE_COUNT -ge 1 ]"
log "  Ellipses created: $ELLIPSE_COUNT"

log ""
log "=== Gesture Tests ==="

# Test 7: Two-finger undo via monkey
clear_log
$ADB shell monkey -p $PKG --pct-pinchzoom 100 -v 10 > /dev/null 2>&1
sleep 1
UNDO_COUNT=$(get_logs | grep -c "gesture_undo")
run_test "Two-finger undo gesture" "[ $UNDO_COUNT -gt 0 ]"
log "  Undo gestures triggered: $UNDO_COUNT"

# Test 8: Three-finger redo attempt
log "Testing three-finger redo..."
# Monkey doesn't generate 3-finger, so this will likely fail
THREE_COUNT=$(get_logs | grep -c "gesture_redo")
if [ "$THREE_COUNT" -gt 0 ]; then
    run_test "Three-finger redo gesture" "true"
    log "  Redo gestures triggered: $THREE_COUNT"
else
    log "  INFO: Three-finger redo not triggered (monkey limitation)"
    ((INFO++))
fi

log ""
log "=== Volume Key Tests ==="

# Test 9: Volume undo/redo
clear_log
# First create some shapes to have something to undo
$ADB shell input tap 100 350 > /dev/null 2>&1
sleep 0.2
$ADB shell input tap 600 1300 > /dev/null 2>&1
$ADB shell input tap 700 1400 > /dev/null 2>&1
sleep 0.3

log "Pressing volume down twice..."
$ADB shell input keyevent KEYCODE_VOLUME_DOWN > /dev/null 2>&1
sleep 0.2
$ADB shell input keyevent KEYCODE_VOLUME_DOWN > /dev/null 2>&1
sleep 0.5

VOL_UNDO=$(get_logs | grep -c "volume_undo")
run_test "Volume undo works" "[ $VOL_UNDO -gt 0 ]"
log "  Volume undo events: $VOL_UNDO"

if [ "$VOL_UNDO" -gt 0 ]; then
    log "Pressing volume up..."
    $ADB shell input keyevent KEYCODE_VOLUME_UP > /dev/null 2>&1
    sleep 0.5
    VOL_REDO=$(get_logs | grep -c "volume_redo")
    run_test "Volume redo works" "[ $VOL_REDO -gt 0 ]"
    log "  Volume redo events: $VOL_REDO"
fi

log ""
log "=== UI Control Tests ==="

# Test 10: Grid toggle
clear_log
# Grid button is typically in bottom toolbar area
$ADB shell input tap 850 2700 > /dev/null 2>&1
sleep 0.5
GRID_COUNT=$(get_logs | grep -c "grid_toggle")
if [ "$GRID_COUNT" -eq 0 ]; then
    # Try another coordinate
    $ADB shell input tap 900 2650 > /dev/null 2>&1
    sleep 0.5
    GRID_COUNT=$(get_logs | grep -c "grid_toggle")
fi
run_test "Grid toggle works" "[ $GRID_COUNT -gt 0 ]"
log "  Grid toggle events: $GRID_COUNT"

# Test 11: Zoom controls
clear_log
$ADB shell input tap 1050 250 > /dev/null 2>&1
sleep 0.3
$ADB shell input tap 1100 250 > /dev/null 2>&1
sleep 0.3
ZOOM_OUT=$(get_logs | grep -c "toolbar_zoom_out")
$ADB shell input tap 1050 220 > /dev/null 2>&1
sleep 0.3
ZOOM_IN=$(get_logs | grep -c "toolbar_zoom_in")
run_test "Zoom out control" "[ $ZOOM_OUT -gt 0 ]"
run_test "Zoom in control" "[ $ZOOM_IN -gt 0 ]"
log "  Zoom out clicks: $ZOOM_OUT, Zoom in clicks: $ZOOM_IN"

log ""
log "=== Persistence Tests ==="

# Test 12: Restart persistence
log "Testing restart persistence..."
clear_log
$ADB shell am force-stop $PKG > /dev/null 2>&1
sleep 2
$ADB shell am start -W $ACTIVITY > /dev/null 2>&1
sleep 5
RESTORE_COUNT=$(get_logs | grep -c "workspace_restore")
run_test "Workspace restored after restart" "[ $RESTORE_COUNT -gt 0 ]"
log "  Restore events: $RESTORE_COUNT"

log ""
log "=== Error Check ==="

# Test 13: No Flutter errors
clear_log
$ADB shell monkey -p $PKG --pct-touch 100 -v 5 > /dev/null 2>&1
sleep 1
ERROR_COUNT=$(get_logs | grep -cE '"level":"error"|flutter_error|uncaught_error' || echo 0)
if [ "$ERROR_COUNT" -eq 0 ]; then
    log "✓ Zero errors in log"
    ((PASS++))
else
    log "✗ Found $ERROR_COUNT error(s) in log"
    ((FAIL++))
fi

# ============================================================
# SUMMARY
# ============================================================
log ""
log "=========================================="
log "VALIDATION SUMMARY"
log "=========================================="
log "Passed: $PASS"
log "Failed: $FAIL"
log "Info:   $INFO"
log ""

if [ $FAIL -eq 0 ]; then
    log "ALL TESTS PASSED!"
else
    log "SOME TESTS FAILED - Review above"
fi

log ""
log "Returning to Termux..."
return_to_termux

# Backup logs
get_logs > "$LOG_BACKUP" 2>/dev/null
log "Log backup: $LOG_BACKUP"

exit $FAIL
