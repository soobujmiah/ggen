#!/bin/bash
# Multi-touch test for GGEN app on Redmi Turbo 4 Pro
# Uses ADB shell with su-less approach via monkey's pinch-zoom capability

ADB=/home/sbj/android-sdk/platform-tools/adb
PKG=com.example.ggen
LOG=/tmp/ggen_mt_test.log

$ADB shell am force-stop $PKG > /dev/null 2>&1
sleep 1
$ADB shell "run-as $PKG rm -f app_flutter/debug_log.jsonl" > /dev/null 2>&1
sleep 0.5
$ADB shell am start -n $PKG/$PKG.MainActivity > /dev/null 2>&1
echo "App launched. Waiting 3s..."
sleep 3

# Clear log
$ADB shell "run-as $PKG rm -f app_flutter/debug_log.jsonl" > /dev/null 2>&1

echo "=== Test 1: Pinch Zoom OUT (two fingers spreading apart) ==="
# Monkey with 100% pinchzoom, 20 events
$ADB shell "monkey -p $PKG --pct-pinchzoom 100 20" 2>&1 | grep -v "^$" | head -10
sleep 2
$ADB shell "run-as $PKG cat app_flutter/debug_log.jsonl 2>/dev/null | grep -E 'zoom|gesture'"

echo ""
echo "=== Test 2: Check all logged events ==="
$ADB shell "run-as $PKG cat app_flutter/debug_log.jsonl 2>/dev/null"

echo ""
echo "=== Test 3: Volume key + gesture tests ==="
# Create some shapes first
$ADB shell "input tap 70 369"  # Rectangle tool
sleep 0.5
$ADB shell "input tap 640 1300"  # Tap canvas
sleep 0.3
$ADB shell "input tap 700 1400"
sleep 0.3
$ADB shell "input tap 800 1500"
sleep 0.5

# Volume undo
$ADB shell "input keyevent KEYCODE_VOLUME_DOWN"
sleep 0.3
$ADB shell "input keyevent KEYCODE_VOLUME_DOWN"
sleep 0.3
$ADB shell "input keyevent KEYCODE_VOLUME_UP"

echo "Events after volume tests:"
$ADB shell "run-as $PKG cat app_flutter/debug_log.jsonl 2>/dev/null | grep -E 'volume|history'"
