#!/usr/bin/env python3
"""GGEN Device Test Runner - Fixed version."""
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
import re
from pathlib import Path

PKG = "com.example.ggen"
ADB = "/home/sbj/android-sdk/platform-tools/adb"
LOG_DIR = Path("/home/sbj/ggen/docs/device-evidence")
LOG_DIR.mkdir(parents=True, exist_ok=True)

timestamp = time.strftime("%Y%m%d_%H%M%S")
test_log = LOG_DIR / f"{timestamp}-test.log"
event_log = LOG_DIR / f"{timestamp}-events.log"
full_log = LOG_DIR / f"{timestamp}-full.log"

def run(cmd, shell=True):
    result = subprocess.run(cmd, shell=shell, capture_output=True, text=True)
    return result.stdout.strip(), result.stderr.strip(), result.returncode

def log(msg):
    print(msg)
    with open(test_log, "a") as f:
        f.write(msg + "\n")

def tap(x, y):
    success, err, rc = run(f"{ADB} shell input tap {x} {y}")
    if rc != 0:
        log(f"  TAP FAIL ({x},{y}): {err}")
        return False
    time.sleep(0.6)
    return True

def swipe(x1, y1, x2, y2, duration=300):
    run(f"{ADB} shell input swipe {x1} {y1} {x2} {y2} {duration}")
    time.sleep(0.5)

def key(event_code):
    run(f"{ADB} shell input keyevent {event_code}")
    time.sleep(0.5)

def dump_ui():
    run(f"{ADB} shell uiautomator dump /sdcard/ui_dump.xml")
    time.sleep(0.3)
    run(f"{ADB} pull /sdcard/ui_dump.xml /tmp/ui_dump_{timestamp}.xml")
    tree = ET.parse(f"/tmp/ui_dump_{timestamp}.xml")
    return tree

def get_bounds(node):
    bounds = node.get("bounds", "[0,0][0,0]")
    m = re.findall(r"\d+", bounds)
    if len(m) >= 4:
        return int(m[0]), int(m[1]), int(m[2]), int(m[3])
    return 0, 0, 0, 0

def center_of(node):
    x1, y1, x2, y2 = get_bounds(node)
    return (x1 + x2) // 2, (y1 + y2) // 2

def find_by_desc(desc_fragment):
    tree = dump_ui()
    for node in tree.iter("node"):
        cd = node.get("content-desc", "")
        if desc_fragment and desc_fragment in cd:
            return node, center_of(node), get_bounds(node)
    return None, None, None

def collect_events(pattern, label):
    before_lines = run(f"{ADB} logcat -d | grep -cE '{pattern}'", shell=True)[0]
    try:
        before = int(before_lines)
    except:
        before = 0
    log(f"--- {label} (before: {before}) ---")
    time.sleep(0.8)
    after_lines = run(f"{ADB} logcat -d | grep -cE '{pattern}'", shell=True)[0]
    try:
        after = int(after_lines)
    except:
        after = 0
    log(f"After: {after} (+{after-before})")
    # Save matching lines
    out, _, _ = run(f"{ADB} logcat -d | grep -E '{pattern}'")
    if out:
        with open(event_log, "a") as f:
            f.write(f"\n=== {label} ===\n{out}\n")
    return after - before

def clear_and_launch():
    run(f"{ADB} shell am force-stop {PKG}")
    time.sleep(0.5)
    out, _, _ = run(f"{ADB} shell pm clear {PKG}")
    log(f"Clear: {out}")
    run(f"{ADB} logcat -c")
    time.sleep(0.5)
    run(f"{ADB} shell am start -n {PKG}/com.example.ggen_app.MainActivity")
    time.sleep(4)

# ============================================================
# TEST SEQUENCE
# ============================================================
log("=" * 60)
log(f"GGEN Device Test - {time.strftime('%Y-%m-%d %H:%M:%S')}")
log(f"Device: {run(f'{ADB} shell getprop ro.product.device')[0]}")
log(f"Serial: {run(f'{ADB} shell getprop ro.serialno')[0]}")
log("=" * 60)

clear_and_launch()

# Check initial state
log("\n=== INITIAL STATE CHECK ===")
out, _, _ = run(f"{ADB} logcat -d | grep 'project_restore'")
log(f"Initial project_restore: {out or 'NOT FOUND'}")

# Get canvas area
tree = dump_ui()
canvas_center = None
for node in tree.iter("node"):
    cd = node.get("content-desc", "")
    if not cd:
        x1, y1, x2, y2 = get_bounds(node)
        w, h = x2 - x1, y2 - y1
        if w > 800 and h > 800 and y2 < 2200:
            canvas_center = (x1 + w//2, y1 + h//2)
            log(f"Canvas found at center: {canvas_center}, bounds: [{x1},{y1}][{x2},{y2}]")
            break
if not canvas_center:
    canvas_center = (640, 1400)
    log(f"Canvas fallback: {canvas_center}")

# ============================================================
# TEST 1: Draw 5 rectangles
# ============================================================
log("\n=== TEST 1: Draw 5 rectangles ===")
node, coords, bounds = find_by_desc("Rectangle")
if node and coords:
    log(f"Tapped Rectangle at {coords}")
    tap(*coords)
else:
    log("ERROR: Rectangle button not found!")
time.sleep(1)

for i in range(5):
    tap(canvas_center[0] + i*30, canvas_center[1] + i*20)
collect_events("node_add", "Shape creation events")

# ============================================================
# TEST 2: Create ellipses
# ============================================================
log("\n=== TEST 2: Create 3 ellipses ===")
node, coords, bounds = find_by_desc("Ellipse")
if node and coords:
    log(f"Tapped Ellipse at {coords}")
    tap(*coords)
else:
    log("ERROR: Ellipse button not found!")
time.sleep(1)

for i in range(3):
    tap(canvas_center[0] + 20 + i*25, canvas_center[1] + 150 + i*30)
collect_events("node_add", "Ellipse creation events")

# ============================================================
# TEST 3: Text frame
# ============================================================
log("\n=== TEST 3: Create text frame ===")
node, coords, bounds = find_by_desc("Text")
if node and coords:
    log(f"Tapped Text at {coords}")
    tap(*coords)
else:
    log("ERROR: Text button not found!")
time.sleep(1)
tap(canvas_center[0], canvas_center[1] + 250)
time.sleep(2)
# Try to type text
out, err, rc = run(f"{ADB} shell input text 'GGEN-test'")
log(f"Text input result: rc={rc}, err={err[:100]}")
time.sleep(0.5)
key(66)  # Enter
collect_events("node_add_text", "Text creation events")

# ============================================================
# TEST 4: Select and move
# ============================================================
log("\n=== TEST 4: Select and move ===")
node, coords, bounds = find_by_desc("Select")
if node and coords:
    log(f"Tapped Select at {coords}")
    tap(*coords)
time.sleep(1)
tap(canvas_center[0], canvas_center[1])
time.sleep(1)
collect_events("node_select", "Selection events")
swipe(canvas_center[0], canvas_center[1], canvas_center[0]+50, canvas_center[1]+50)
collect_events("node_move", "Move events")

# ============================================================
# TEST 5: Multi-select
# ============================================================
log("\n=== TEST 5: Multi-select toggle ===")
results = []
tree = dump_ui()
for node in tree.iter("node"):
    cd = node.get("content-desc", "")
    if "Multi-select" in cd:
        results.append((node, center_of(node)))
if results:
    node, coords = results[0]
    log(f"Tapped Multi-select at {coords}")
    tap(*coords)
    collect_events("multi_select_toggle", "Multi-select toggle")

# ============================================================
# TEST 6: Grid toggle
# ============================================================
log("\n=== TEST 6: Grid toggle ===")
results = []
tree = dump_ui()
for node in tree.iter("node"):
    cd = node.get("content-desc", "")
    if "grid" in cd.lower():
        results.append((node, center_of(node)))
if results:
    node, coords = results[0]
    log(f"Tapped grid control at {coords}")
    tap(*coords)
    collect_events("grid_toggle", "Grid toggle event")

# ============================================================
# TEST 7: Layers panel
# ============================================================
log("\n=== TEST 7: Layers panel ===")
results = []
tree = dump_ui()
for node in tree.iter("node"):
    cd = node.get("content-desc", "")
    if "layer" in cd.lower():
        results.append((node, center_of(node)))
if results:
    node, coords = results[0]
    log(f"Tapped layers at {coords}")
    tap(*coords)
    collect_events("layers_toggle", "Layers toggle event")

# ============================================================
# TEST 8: Save project
# ============================================================
log("\n=== TEST 8: Save project ===")
results = []
tree = dump_ui()
for node in tree.iter("node"):
    cd = node.get("content-desc", "")
    if "More actions" in cd:
        results.append((node, center_of(node)))
if results:
    node, coords = results[0]
    log(f"Tapped More actions at {coords}")
    tap(*coords)
    collect_events("top_action_more", "More menu opened")
    time.sleep(1)
    # Try save
    tap(710, 400)
    time.sleep(1)
    collect_events("project_save", "Save event")

# ============================================================
# TEST 9: Volume undo/redo
# ============================================================
log("\n=== TEST 9: Volume keys ===")
key(25)  # Volume down = undo
time.sleep(0.3)
key(25)
collect_events("volume_undo", "Volume undo events")
key(24)  # Volume up = redo
collect_events("volume_redo", "Volume redo events")

# ============================================================
# TEST 10: History buttons
# ============================================================
log("\n=== TEST 10: History buttons ===")
results = []
tree = dump_ui()
for node in tree.iter("node"):
    cd = node.get("content-desc", "")
    if cd == "Undo":
        results.append(("Undo", center_of(node)))
    elif cd == "Redo":
        results.append(("Redo", center_of(node)))

for name, coords in results:
    log(f"Tapped {name} at {coords}")
    tap(*coords)
    collect_events(f"history_{'undo' if name=='Undo' else 'redo'}", f"{name} event")

# ============================================================
# TEST 11: Two-finger tap (gesture undo)
# ============================================================
log("\n=== TEST 11: Gesture undo ===")
# This requires actual multi-touch, skip for now
log("Skipping two-finger gesture (requires hardware multi-touch support)")

# ============================================================
# TEST 12: Restart restore
# ============================================================
log("\n=== TEST 12: Restart restore ===")
run(f"{ADB} shell am force-stop {PKG}")
time.sleep(2)
run(f"{ADB} shell am start -n {PKG}/com.example.ggen_app.MainActivity")
time.sleep(4)
collect_events("project_restore|storage_init", "Restart restore events")

# ============================================================
# FINAL ERROR CHECK
# ============================================================
log("\n=== ERROR CHECK ===")
err_out, _, _ = run(f"{ADB} logcat -d | grep -E '(flutter_error|uncaught_error|Duplicate node ID)'")
if err_out:
    log(f"ERRORS FOUND:\n{err_out}")
else:
    log("NO ERRORS")

# ============================================================
# EXPORT DIAGNOSTICS FROM APP
# ============================================================
log("\n=== EXPORTING APP DIAGNOSTICS ===")
# Tap More menu
results = []
tree = dump_ui()
for node in tree.iter("node"):
    cd = node.get("content-desc", "")
    if "More actions" in cd:
        results.append(center_of(node))
if results:
    tap(*results[0])
    time.sleep(1)
    # Look for Diagnostics
    tree = dump_ui()
    diag_coords = None
    for node in tree.iter("node"):
        t = node.get("text", "").lower()
        cd = node.get("content-desc", "").lower()
        if "diagnostic" in t or "diagnostic" in cd:
            diag_coords = center_of(node)
            break
    if diag_coords:
        log(f"Found diagnostics at {diag_coords}")
        tap(*diag_coords)
        time.sleep(2)
        # Copy clipboard
        out, _, _ = run(f"{ADB} shell cmd clipboard get 2>/dev/null || echo ''")
        if out and "Error" not in out:
            log(f"Diagnostics clipboard: {out[:500]}")
    else:
        log("Diagnostics option not found in More menu")

# ============================================================
# SUMMARY
# ============================================================
log("\n=== TEST COMPLETE ===")
log(f"Logs saved to:")
log(f"  {test_log}")
log(f"  {event_log}")
log(f"  {full_log}")

# Count total events
summary = run(f"{ADB} logcat -d | grep -E 'node_add|node_select|node_move|node_add_text|project_save|project_restore|grid_toggle|history_|volume_|multi_select|canvas_geometry' | wc -l", shell=True)[0]
try:
    log(f"Total diagnostic events captured: {int(summary)}")
except:
    log(f"Total diagnostic events: unknown")
