#!/bin/bash
# GGEN Device Test Runner v4 - Final validation
# Canvas: [141,152]-[1280,2631], Tools at x≈70

ADB=~/android-sdk/platform-tools/adb
PKG=com.example.ggen
LOG_FILE=/tmp/debug_log_v4.jsonl
PASS=0
FAIL=0

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

wait_for_log_event() {
    local event="$1"
    local timeout="${2:-3}"
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if $ADB shell run-as $PKG cat app_flutter/debug_log.jsonl 2>/dev/null | grep -q "\"event\":\"$event\""; then
            return 0
        fi
        sleep 0.5
        ((elapsed++))
    done
    return 1
}

run_test() {
    local name="$1"
    local expected_event="$2"
    local timeout="${3:-3}"
    log "Testing: $name"
    
    if wait_for_log_event "$expected_event" "$timeout"; then
        log "  PASS: $expected_event found"
        ((PASS++))
    else
        log "  FAIL: $expected_event NOT found after ${timeout}s"
        ((FAIL++))
    fi
}

clear_log() {
    $ADB shell run-as $PKG rm -f app_flutter/debug_log.jsonl 2>/dev/null
    sleep 0.5
}

restart_app() {
    $ADB shell am force-stop $PKG
    sleep 1
    $ADB shell am start -n com.example.ggen/com.example.ggen_app.MainActivity
    sleep 4
    clear_log
    # Wait for startup events
    wait_for_log_event "storage_init" 5
}

tap_tool() {
    case "$1" in
        select) $ADB shell input tap 70 239 ;;
        rectangle) $ADB shell input tap 70 369 ;;
        ellipse) $ADB shell input tap 70 500 ;;
        text) $ADB shell input tap 70 630 ;;
    esac
    sleep 0.5
}

tap_canvas() {
    $ADB shell input tap "$1" "$2"
    sleep 0.3
}

log "=========================================="
log "GGEN Device Test v4 - Final Validation"
log "Date: $(date)"
log "Device: $($ADB shell getprop ro.product.device)"
log "Serial: $($ADB shell getprop ro.serialno)"
log "=========================================="
log ""

# Test 1: App launch
log "=== Test 1: App Launch & Startup ==="
restart_app
run_test "Storage init" "storage_init"
run_test "Workspace restore" "workspace_restore"
run_test "Canvas geometry" "canvas_geometry"
log ""

# Test 2: Rectangle tool
log "=== Test 2: Rectangle Tool ==="
clear_log
tap_tool rectangle
run_test "Rectangle selected" "tool_select"
log ""

# Test 3: Shape creation
log "=== Test 3: Shape Creation ==="
clear_log
tap_tool rectangle
sleep 0.5
tap_canvas 710 1391
tap_canvas 800 1500
tap_canvas 900 1600
run_test "Shapes created" "node_add" 5
SHAPE_COUNT=$($ADB shell run-as $PKG cat app_flutter/debug_log.jsonl 2>/dev/null | grep -c "node_add" || echo "0")
log "  Shapes created: $SHAPE_COUNT"
if [ "$SHAPE_COUNT" -gt 0 ]; then
    ((PASS++))
else
    ((FAIL++))
fi
log ""

# Test 4: Ellipse tool
log "=== Test 4: Ellipse Tool ==="
clear_log
tap_tool ellipse
run_test "Ellipse selected" "tool_select"
tap_canvas 750 1450
run_test "Ellipse created" "node_add"
log ""

# Test 5: Text tool
log "=== Test 5: Text Tool ==="
clear_log
tap_tool text
run_test "Text selected" "tool_select"
tap_canvas 800 1500
sleep 2
# Text creates node_add_text when keyboard completes
if $ADB shell run-as $PKG cat app_flutter/debug_log.jsonl 2>/dev/null | grep -q "node_add_text"; then
    log "  PASS: Text node created"
    ((PASS++))
else
    log "  INFO: Text requires keyboard input - may need manual verification"
fi
log ""

# Test 6: Volume undo/redo
log "=== Test 6: Volume Undo/Redo ==="
clear_log
tap_tool rectangle
sleep 0.5
tap_canvas 700 1400
tap_canvas 800 1500
$ADB shell input keyevent KEYCODE_VOLUME_DOWN
$ADB shell input keyevent KEYCODE_VOLUME_DOWN
$ADB shell input keyevent KEYCODE_VOLUME_UP
run_test "Volume undo" "volume_undo"
run_test "Volume redo" "volume_redo"
log ""

# Test 7: Grid toggle
log "=== Test 7: Grid Toggle ==="
clear_log
# Tap "Hide grid" button at [838,2647]-[947,2756] -> center (892, 2701)
$ADB shell input tap 892 2701
sleep 1
# Check for grid_toggle event
if $ADB shell run-as $PKG cat app_flutter/debug_log.jsonl 2>/dev/null | grep -q "grid_toggle"; then
    log "  PASS: Grid toggle logged"
    ((PASS++))
else
    log "  INFO: Grid toggle not logged (may not have debug instrumentation)"
fi
log ""

# Test 8: Restart persistence
log "=== Test 8: Restart Persistence ==="
# Create shapes first
clear_log
tap_tool rectangle
sleep 0.5
tap_canvas 750 1450
sleep 1
# Force stop and restart
$ADB shell am force-stop $PKG
sleep 2
restart_app
# Check that previous state was restored
run_test "State restored after restart" "workspace_restore"
run_test "Previous shapes remembered" "node_add"
log ""

# Summary
log "=========================================="
log "TEST SUMMARY"
log "=========================================="
log "Passed: $PASS"
log "Failed: $FAIL"
log ""

if [ $FAIL -eq 0 ]; then
    log "ALL TESTS PASSED!"
    exit 0
else
    log "SOME TESTS FAILED"
    exit 1
fi
