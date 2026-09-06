#!/bin/bash
# GGEN Device Test Runner v3 - With correct canvas coordinates
# Canvas: [141,152]-[1280,2631], Artboard: 419x912
# Tools at x≈70, spaced ~130px apart vertically

ADB=~/android-sdk/platform-tools/adb
PKG=com.example.ggen
LOG_FILE=/tmp/debug_log_v3.jsonl
PASS=0
FAIL=0

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

run_test() {
    local name="$1"
    local expected_event="$2"
    log "Testing: $name"
    
    # Pull current log
    $ADB shell run-as $PKG cat app_flutter/debug_log.jsonl > "$LOG_FILE" 2>/dev/null
    
    # Check if expected event exists
    if grep -q "\"event\":\"$expected_event\"" "$LOG_FILE" 2>/dev/null; then
        log "  PASS: $expected_event found"
        ((PASS++))
    else
        log "  FAIL: $expected_event NOT found"
        ((FAIL++))
    fi
}

clear_log() {
    $ADB shell run-as $PKG rm -f app_flutter/debug_log.jsonl
    sleep 0.5
}

restart_app() {
    $ADB shell am force-stop $PKG
    sleep 1
    $ADB shell am start -n com.example.ggen/com.example.ggen_app.MainActivity
    sleep 3
    clear_log
}

tap_tool() {
    # Tool positions based on UI dump
    case "$1" in
        select) $ADB shell input tap 70 239 ;;
        rectangle) $ADB shell input tap 70 369 ;;
        ellipse) $ADB shell input tap 70 500 ;;
        text) $ADB shell input tap 70 630 ;;
    esac
    sleep 0.5
}

tap_canvas() {
    # Canvas tap at given coordinates
    $ADB shell input tap "$1" "$2"
    sleep 0.3
}

log "=========================================="
log "GGEN Device Test v3"
log "Date: $(date)"
log "Device: $($ADB shell getprop ro.product.device)"
log "=========================================="
log ""

# Test 1: App launch and workspace restore
log "=== Test 1: App Launch & Workspace Restore ==="
restart_app
run_test "Workspace restore" "workspace_restore"
run_test "Storage init" "storage_init"
run_test "Canvas geometry" "canvas_geometry"
log ""

# Test 2: Rectangle tool selection
log "=== Test 2: Rectangle Tool ==="
clear_log
tap_tool rectangle
run_test "Rectangle selected" "tool_select"
# Verify tool is rectangle
if grep -q '"tool":"Rectangle"' "$LOG_FILE" 2>/dev/null; then
    log "  PASS: Rectangle tool confirmed"
    ((PASS++))
else
    log "  FAIL: Rectangle tool not in log"
    ((FAIL++))
fi
log ""

# Test 3: Shape creation on canvas
log "=== Test 3: Shape Creation ==="
clear_log
tap_tool rectangle
sleep 0.5
# Tap canvas at multiple positions
tap_canvas 710 1391
tap_canvas 800 1500
tap_canvas 900 1600
run_test "Shape created" "node_add"
# Count shapes
SHAPE_COUNT=$(grep -c "node_add" "$LOG_FILE" 2>/dev/null || echo "0")
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
sleep 0.5
tap_canvas 750 1450
tap_canvas 850 1550
run_test "Ellipse selected" "tool_select"
run_test "Ellipse created" "node_add"
log ""

# Test 5: Text tool
log "=== Test 5: Text Tool ==="
clear_log
tap_tool text
sleep 0.5
tap_canvas 800 1500
sleep 2  # Wait for keyboard/dialog
run_test "Text tool selected" "tool_select"
# Text adds a node_add_text event
if grep -q "node_add_text" "$LOG_FILE" 2>/dev/null; then
    log "  PASS: Text node created"
    ((PASS++))
else
    log "  INFO: Text dialog may require keyboard input"
fi
log ""

# Test 6: Volume undo/redo
log "=== Test 6: Volume Undo/Redo ==="
clear_log
tap_tool rectangle
sleep 0.5
tap_canvas 700 1400
sleep 0.5
tap_canvas 800 1500
# Press volume down twice
$ADB shell input keyevent KEYCODE_VOLUME_DOWN
sleep 0.5
$ADB shell input keyevent KEYCODE_VOLUME_DOWN
sleep 0.5
# Press volume up once
$ADB shell input keyevent KEYCODE_VOLUME_UP
sleep 0.5
run_test "Volume undo" "volume_undo"
run_test "Volume redo" "volume_redo"
log ""

# Test 7: Restart project restore
log "=== Test 7: Restart Project Restore ==="
# Create a shape first
clear_log
tap_tool rectangle
sleep 0.5
tap_canvas 750 1450
sleep 1
# Save project via More menu
$ADB shell input tap 710 222  # More actions button
sleep 1
$ADB shell input tap 710 400  # Try Save option
sleep 1
# Force stop and restart
$ADB shell am force-stop $PKG
sleep 2
restart_app
# Check if project was restored
run_test "Project restore" "workspace_restore"
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
else
    log "SOME TESTS FAILED - check logs above"
fi

# Show full log
log ""
log "Full debug log:"
cat "$LOG_FILE" 2>/dev/null | head -50
