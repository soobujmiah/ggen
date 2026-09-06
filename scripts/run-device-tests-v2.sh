#!/bin/bash
# GGEN Device Test Runner v2 - Uses debug log file for validation
# After each action, pulls debug_log.jsonl from device to check events

ADB=~/android-sdk/platform-tools/adb
PKG=com.example.ggen
LOG_DIR=/home/sbj/ggen/docs/device-evidence
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_LOG="$LOG_DIR/${TIMESTAMP}-test.log"
EVENT_LOG="$LOG_DIR/${TIMESTAMP}-events.log"

log() {
    echo "$1" | tee -a "$TEST_LOG"
}

pull_debug_log() {
    local dst="/tmp/debug_log_${TIMESTAMP}.jsonl"
    $ADB pull /data/user/0/$PKG/app_flutter/debug_log.jsonl "$dst" 2>/dev/null
    if [ -f "$dst" ] && [ -s "$dst" ]; then
        echo "$dst"
    else
        echo ""
    fi
}

grep_events() {
    local pattern="$1"
    local file="${2:-/tmp/debug_log_*.jsonl}"
    # Find most recent debug log
    local latest=$(ls -t /tmp/debug_log_${TIMESTAMP}*.jsonl 2>/dev/null | head -1)
    if [ -n "$latest" ] && [ -s "$latest" ]; then
        grep -E "\"event\":\"${pattern}\"" "$latest" 2>/dev/null || \
        grep -E "\"event\":\s*\"${pattern}\"" "$latest" 2>/dev/null || true
    fi
}

count_events() {
    local pattern="$1"
    local latest=$(ls -t /tmp/debug_log_${TIMESTAMP}*.jsonl 2>/dev/null | head -1)
    if [ -n "$latest" ] && [ -s "$latest" ]; then
        grep -cE "\"event\":\s*\"${pattern}\"" "$latest" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# ============================================================
log "=========================================="
log "GGEN Device Test v2 - $(date '+%Y-%m-%d %H:%M:%S')"
log "Device: $($ADB shell getprop ro.product.device 2>/dev/null)"
log "Serial: $($ADB shell getprop ro.serialno 2>/dev/null)"
log "=========================================="

# Clear and launch
$ADB shell am force-stop $PKG 2>/dev/null
$ADB shell pm clear $PKG 2>/dev/null
$ADB logcat -c
$ADB shell am start -n $PKG/com.example.ggen_app.MainActivity
sleep 4

# Pull initial debug log
DEBUG_LOG=$(pull_debug_log)
if [ -z "$DEBUG_LOG" ]; then
    log "WARNING: No debug log file found after launch"
else
    log "Debug log initialized: $DEBUG_LOG"
    cat "$DEBUG_LOG" | tee -a "$TEST_LOG"
fi

# Check restart restore
if [ -f "$DEBUG_LOG" ]; then
    RESTORE=$(grep -o '"event":"project_restore"[^}]*' "$DEBUG_LOG" 2>/dev/null || \
              grep -o '"event": "project_restore"[^}]*' "$DEBUG_LOG" 2>/dev/null)
    if [ -n "$RESTORE" ]; then
        log "✓ project_restore event found: $RESTORE"
    else
        log "✗ project_restore event NOT found (expected: No prior project stored)"
    fi
fi

# Tap Rectangle tool
log "\n=== TEST 1: Draw rectangles ==="
$ADB shell input tap 70 369
sleep 1

# Tap canvas 5 times
for i in 1 2 3 4 5; do
    $ADB shell input tap $((640 + i*20)) $((1200 + i*30))
    sleep 0.5
done

# Pull and check debug log
sleep 1
DEBUG_LOG=$(pull_debug_log)
if [ -n "$DEBUG_LOG" ]; then
    CANVAS_TAPS=$(grep -c 'canvas_tap' "$DEBUG_LOG" 2>/dev/null || echo "0")
    SHAPE_ADDED=$(grep -c 'shape_added' "$DEBUG_LOG" 2>/dev/null || echo "0")
    log "Canvas taps received: $CANVAS_TAPS"
    log "Shapes created: $SHAPE_ADDED"
    
    if [ "$SHAPE_ADDED" -gt 0 ]; then
        log "✓ Shapes successfully created"
        grep 'shape_added' "$DEBUG_LOG" | tail -1 | tee -a "$TEST_LOG"
    else
        log "✗ No shapes created despite taps"
        log "Last few log entries:"
        tail -5 "$DEBUG_LOG" | tee -a "$TEST_LOG"
    fi
fi

# ============================================================
log "\n=== TEST 2: Ellipse tool ==="
$ADB shell input tap 70 500
sleep 1
for i in 1 2 3; do
    $ADB shell input tap $((660 + i*20)) $((1300 + i*30))
    sleep 0.5
done
DEBUG_LOG=$(pull_debug_log)
if [ -n "$DEBUG_LOG" ]; then
    ELLIPSE_COUNT=$(grep -c 'ellipse' "$DEBUG_LOG" 2>/dev/null || echo "0")
    log "Ellipse-related events: $ELLIPSE_COUNT"
fi

# ============================================================
log "\n=== TEST 3: Text tool ==="
$ADB shell input tap 70 630
sleep 1
$ADB shell input tap 640 1400
sleep 2
$ADB shell input text "test"
sleep 0.5
$ADB shell input keyevent 66
sleep 1
DEBUG_LOG=$(pull_debug_log)
if [ -n "$DEBUG_LOG" ]; then
    TEXT_COUNT=$(grep -c 'node_add_text' "$DEBUG_LOG" 2>/dev/null || echo "0")
    log "Text nodes created: $TEXT_COUNT"
fi

# ============================================================
log "\n=== TEST 4: Undo/Redo ==="
$ADB shell input keyevent 25  # Volume down = undo
$ADB shell input keyevent 25
sleep 0.5
$ADB shell input keyevent 24  # Volume up = redo
sleep 0.5
DEBUG_LOG=$(pull_debug_log)
if [ -n "$DEBUG_LOG" ]; then
    UNDO_COUNT=$(grep -c 'volume_undo\|history_undo' "$DEBUG_LOG" 2>/dev/null || echo "0")
    REDO_COUNT=$(grep -c 'volume_redo\|history_redo' "$DEBUG_LOG" 2>/dev/null || echo "0")
    log "Undo events: $UNDO_COUNT"
    log "Redo events: $REDO_COUNT"
fi

# ============================================================
log "\n=== TEST 5: Grid toggle ==="
$ADB shell input tap 823 2701  # Hide grid button
sleep 1
DEBUG_LOG=$(pull_debug_log)
if [ -n "$DEBUG_LOG" ]; then
    GRID_COUNT=$(grep -c 'grid_toggle' "$DEBUG_LOG" 2>/dev/null || echo "0")
    log "Grid toggle events: $GRID_COUNT"
    if [ "$GRID_COUNT" -gt 0 ]; then
        log "✓ Grid toggle working"
    fi
fi

# ============================================================
log "\n=== TEST 6: Restart restore ==="
$ADB shell am force-stop $PKG
sleep 2
$ADB shell am start -n $PKG/com.example.ggen_app.MainActivity
sleep 4
DEBUG_LOG=$(pull_debug_log)
if [ -n "$DEBUG_LOG" ]; then
    RESTORE=$(grep -o '"event":"project_restore"[^}]*' "$DEBUG_LOG" 2>/dev/null || \
              grep -o '"event": "project_restore"[^}]*' "$DEBUG_LOG" 2>/dev/null)
    if [ -n "$RESTORE" ]; then
        log "✓ project_restore found: $RESTORE"
    else
        log "✗ project_restore NOT found - RESTORE FAILED"
    fi
fi

# ============================================================
log "\n=== FINAL SUMMARY ==="
log "Total debug log entries:"
cat /tmp/debug_log_${TIMESTAMP}*.jsonl 2>/dev/null | wc -l | tee -a "$TEST_LOG"
log "\nEvent counts:"
for evt in canvas_tap shape_added node_add ellipse node_add_text volume_undo volume_redo history_undo history_redo grid_toggle project_restore storage_init; do
    count=$(grep -c "\"event\": \"$evt\"" /tmp/debug_log_${TIMESTAMP}*.jsonl 2>/dev/null || echo "0")
    log "  $evt: $count"
done
log "\nFull debug log saved to: $DEBUG_LOG"
log "Test complete."
