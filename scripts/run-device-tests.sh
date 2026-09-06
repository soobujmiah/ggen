#!/bin/bash
# GGEN ADB Device Test Runner
# Uses UI hierarchy dump + element-centered taps for reliable interaction
# Collects diagnostic events from logcat throughout

ADB=~/android-sdk/platform-tools/adb
PKG=com.example.ggen
LOG_DIR=/home/sbj/ggen/docs/device-evidence
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE_LOG="$LOG_DIR/${TIMESTAMP}-test.log"
EVENT_LOG="$LOG_DIR/${TIMESTAMP}-events.log"
FULL_LOG="$LOG_DIR/${TIMESTAMP}-full.log"

# Capture baseline logcat timestamp before tests
$ADB logcat -c

EVENTS_BEFORE=$($ADB logcat -d | wc -l)
echo "Baseline log lines: $EVENTS_BEFORE" >> "$BASE_LOG"

# ============================================================
# Helper functions
# ============================================================

# Dump UI hierarchy and return the center coordinates for an element by content-desc
get_element_center() {
    local desc="$1"
    $ADB shell uiautomator dump /sdcard/ui_dump.xml 2>/dev/null
    python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('/sdcard/ui_dump.xml')
root = tree.getroot()
for node in root.iter('node'):
    cd = node.get('content-desc', '')
    bounds = node.get('bounds', '')
    if cd and '$desc' in cd:
        import re
        m = re.findall(r'\d+', bounds)
        if len(m) == 4:
            x1, y1, x2, y2 = int(m[0]), int(m[1]), int(m[2]), int(m[3])
            print(f'{(x1+x2)//2},{(y1+y2)//2}')
            exit(0)
print('NOT_FOUND')
" 2>/dev/null
}

# Tap element by content-desc
tap_by_desc() {
    local desc="$1"
    local coords
    coords=$(get_element_center "$desc")
    if [ "$coords" = "NOT_FOUND" ]; then
        echo "TAP_FAIL: $desc not found in UI" | tee -a "$BASE_LOG"
        return 1
    fi
    local x="${coords%,*}"
    local y="${coords#*,}"
    $ADB shell input tap $x $y
    sleep 0.8
    echo "TAPPED: $desc ($x,$y)" | tee -a "$BASE_LOG"
}

# Get canvas center for drawing/text operations
get_canvas_center() {
    $ADB shell uiautomator dump /sdcard/ui_dump.xml 2>/dev/null
    python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('/sdcard/ui_dump.xml')
root = tree.getroot()
for node in root.iter('node'):
    cd = node.get('content-desc', '')
    # Find the large canvas area (not toolbar, not tool rail)
    bounds = node.get('bounds', '')
    import re
    m = re.findall(r'\d+', bounds)
    if len(m) == 4:
        x1, y1, x2, y2 = int(m[0]), int(m[1]), int(m[2]), int(m[3])
        w, h = x2-x1, y2-y1
        # Canvas is typically > 800px wide and > 1000px tall, in upper portion
        if w > 800 and h > 1000 and y2 < 2000:
            print(f'{(x1+x2)//2},{(y1+y2)//2}')
            exit(0)
print('NOT_FOUND')
" 2>/dev/null
}

# Wait and capture new events matching pattern
capture_events() {
    local pattern="$1"
    local label="$2"
    local before=$($ADB logcat -d | grep -cE "$pattern" || true)
    echo "--- $label (before: $before events) ---" | tee -a "$BASE_LOG"
    sleep 1
    local after=$($ADB logcat -d | grep -cE "$pattern" || true)
    echo "After: $after events (+$((after-before)))" | tee -a "$BASE_LOG"
    $ADB logcat -d | grep -E "$pattern" | tee -a "$BASE_LOG"
}

# Force stop and clear
stop_and_clear() {
    $ADB shell am force-stop $PKG
    sleep 1
    $ADB shell pm clear $PKG
    sleep 1
    $ADB logcat -c
    echo "CLEARED" | tee -a "$BASE_LOG"
}

# Check for errors
check_errors() {
    local errors=$($ADB logcat -d | grep -cE "(flutter_error|uncaught_error|Duplicate node ID)" || true)
    if [ "$errors" -gt 0 ]; then
        echo "ERRORS FOUND ($errors):" | tee -a "$BASE_LOG"
        $ADB logcat -d | grep -E "(flutter_error|uncaught_error|Duplicate node ID)" | tee -a "$BASE_LOG"
        return 1
    else
        echo "NO ERRORS" | tee -a "$BASE_LOG"
    fi
}

# Collect current events
collect_now() {
    $ADB logcat -d | grep -E "(ggen|flutter_error|uncaught_error|project_|canvas_|layout_|grid_|node_|history_|gesture_|volume_|key_)" | \
        grep -v "WindowManager\|ActivityStarter\|Miui\|ANDR-PWR\|Iorap\|BLAST\|SoSc\|PrefStub\|DynamicDDS\|ShellStarting\|PolicyMaker\|BarFollow\|KeyguardEditor\|SmartPower\|XSpace\|SecurityManager\|Aurogon\|PreStarting\|PerfStub\|BlasSyncEngine\|AppStartScenario\|appsFilter\|Permission\|AppOps\|Zygote\|Adbd\|CarrierSvc\|VRI\|DdmHg\|CameraActivity" >> "$EVENT_LOG"
}

# Export app diagnostics
export_diagnostics() {
    echo "=== EXPORTING DIAGNOSTICS ===" | tee -a "$BASE_LOG"
    tap_by_desc "More actions"
    sleep 1
    # Look for Diagnostics option in the menu
    $ADB shell uiautomator dump /sdcard/ui_dump.xml 2>/dev/null
    local diag_text
    diag_text=$($ADB shell uiautomator dump /sdcard/ui_dump.xml 2>/dev/null && python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('/sdcard/ui_dump.xml')
root = tree.getroot()
for node in root.iter('node'):
    t = node.get('text', '')
    cd = node.get('content-desc', '')
    if 'diagnostic' in t.lower() or 'diagnostic' in cd.lower():
        print(t)
" 2>/dev/null | head -1)
    
    if [ -n "$diag_text" ]; then
        echo "Found diagnostics: $diag_text" | tee -a "$BASE_LOG"
    fi
}

# ============================================================
# MAIN TEST SEQUENCE
# ============================================================
echo "==========================================" | tee "$BASE_LOG"
echo "GGEN Device Test Run - $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$BASE_LOG"
echo "Device: $($ADB shell getprop ro.product.device 2>/dev/null)" | tee -a "$BASE_LOG"
echo "Serial: $($ADB shell getprop ro.serialno 2>/dev/null)" | tee -a "$BASE_LOG"
echo "==========================================" | tee -a "$BASE_LOG"

# Clean start
stop_and_clear

# Launch app
echo ""
echo "=== LAUNCH 1: Fresh install (expect project_restore: No prior project stored) ===" | tee -a "$BASE_LOG"
$ADB shell am start -n $PKG/com.example.ggen_app.MainActivity
sleep 4

# Check initial state
echo "--- Initial event check ---" | tee -a "$BASE_LOG"
$ADB logcat -d | grep -E "project_restore|storage_init" | tee -a "$BASE_LOG"

# Collect canvas geometry
capture_events "canvas_geometry|layout_mode" "Initial geometry"

# ============================================================
# TEST 1: Draw shapes
# ============================================================
echo ""
echo "=== TEST 1: Draw 5 rectangles ===" | tee -a "$BASE_LOG"
tap_by_desc "Rectangle"
sleep 1

canvas_center=$(get_canvas_center)
if [ "$canvas_center" != "NOT_FOUND" ]; then
    for i in 1 2 3 4 5; do
        $ADB shell input tap $((640 + i*20)) $((1400 + i*30))
        sleep 0.5
    done
    echo "Created 5 shapes" | tee -a "$BASE_LOG"
fi
capture_events "node_add" "Shape creation events"

# ============================================================
# TEST 2: Switch to Ellipse and create ellipses
# ============================================================
echo ""
echo "=== TEST 2: Create 3 ellipses ===" | tee -a "$BASE_LOG"
tap_by_desc "Ellipse"
sleep 1
for i in 1 2 3; do
    $ADB shell input tap $((640 + i*30)) $((1500 + i*40))
    sleep 0.5
done
echo "Created 3 ellipses" | tee -a "$BASE_LOG"
capture_events "node_add" "Ellipse creation events"

# ============================================================
# TEST 3: Text tool
# ============================================================
echo ""
echo "=== TEST 3: Create text frame ===" | tee -a "$BASE_LOG"
tap_by_desc "Text"
sleep 1
$ADB shell input tap 640 1600
sleep 2
$ADB shell input text "GGEN-test-বাংলা"
sleep 1
$ADB shell input keyevent 66  # Enter
sleep 1
capture_events "node_add_text" "Text creation events"

# ============================================================
# TEST 4: Select and move
# ============================================================
echo ""
echo "=== TEST 4: Select and move ===" | tee -a "$BASE_LOG"
tap_by_desc "Select"
sleep 1
$ADB shell input tap 660 1420
sleep 1
capture_events "node_select" "Selection events"
$ADB shell input swipe 660 1420 700 1450 300
sleep 1
capture_events "node_move" "Move events"

# ============================================================
# TEST 5: Multi-select
# ============================================================
echo ""
echo "=== TEST 5: Multi-select ===" | tee -a "$BASE_LOG"
tap_by_desc "Multi-select off"
sleep 1
capture_events "multi_select_toggle" "Multi-select toggle"
$ADB shell input tap 680 1440
sleep 0.5
$ADB shell input tap 700 1460
sleep 0.5
capture_events "node_select" "Multi-selection events"

# ============================================================
# TEST 6: Grid toggle
# ============================================================
echo ""
echo "=== TEST 6: Toggle grid ===" | tee -a "$BASE_LOG"
tap_by_desc "Hide grid"
sleep 1
capture_events "grid_toggle" "Grid toggle event"

# ============================================================
# TEST 7: Layers panel
# ============================================================
echo ""
echo "=== TEST 7: Open layers ===" | tee -a "$BASE_LOG"
tap_by_desc "Show layers"
sleep 1
capture_events "layers_toggle" "Layers toggle event"

# ============================================================
# TEST 8: Save project
# ============================================================
echo ""
echo "=== TEST 8: Save project ===" | tee -a "$BASE_LOG"
tap_by_desc "More actions"
sleep 1
capture_events "top_action_more" "More menu opened"
# Save should be visible in the More menu
$ADB shell input tap 710 400
sleep 1
capture_events "project_save" "Save event"

# ============================================================
# TEST 9: Volume undo/redo
# ============================================================
echo ""
echo "=== TEST 9: Volume undo/redo ===" | tee -a "$BASE_LOG"
$ADB shell input keyevent 25  # Volume down = undo
sleep 0.5
$ADB shell input keyevent 25
sleep 0.5
capture_events "volume_undo" "Volume undo events"
$ADB shell input keyevent 24  # Volume up = redo
sleep 0.5
capture_events "volume_redo" "Volume redo events"

# ============================================================
# TEST 10: History bar undo/redo
# ============================================================
echo ""
echo "=== TEST 10: History bar ===" | tee -a "$BASE_LOG"
tap_by_desc "Undo"
sleep 1
capture_events "history_undo" "History undo events"
tap_by_desc "Redo"
sleep 1
capture_events "history_redo" "History redo events"

# ============================================================
# TEST 11: Gesture undo (two-finger tap)
# ============================================================
echo ""
echo "=== TEST 11: Two-finger tap undo ===" | tee -a "$BASE_LOG"
# Simulate two-finger tap using screengestures or multiple touches
$ADB shell input touchscreen tap -1 640 1400
sleep 1
capture_events "gesture_undo" "Gesture undo events"

# ============================================================
# TEST 12: Restart restore
# ============================================================
echo ""
echo "=== TEST 12: Restart restore ===" | tee -a "$BASE_LOG"
$ADB shell am force-stop $PKG
sleep 2
$ADB shell am start -n $PKG/com.example.ggen_app.MainActivity
sleep 4
capture_events "project_restore" "Restart restore events"

# ============================================================
# FINAL ERROR CHECK
# ============================================================
echo ""
echo "=== FINAL ERROR CHECK ===" | tee -a "$BASE_LOG"
check_errors

# ============================================================
# COLLECT ALL EVENTS
# ============================================================
echo ""
echo "=== ALL CAPTURED EVENTS ===" | tee -a "$BASE_LOG"
collect_now
grep -E "(node_add|node_select|node_move|node_add_text|project_save|project_restore|grid_toggle|history_|volume_|gesture_|multi_select|canvas_geometry|layout_mode|flutter_error|uncaught_error|storage_init)" "$BASE_LOG" | sort | uniq -c | tee -a "$EVENT_LOG"

echo ""
echo "=== TEST COMPLETE ===" | tee -a "$BASE_LOG"
echo "Logs saved to:" | tee -a "$BASE_LOG"
echo "  $BASE_LOG" | tee -a "$BASE_LOG"
echo "  $EVENT_LOG" | tee -a "$BASE_LOG"
echo "  $FULL_LOG" | tee -a "$BASE_LOG"
