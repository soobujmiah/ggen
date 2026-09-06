# GGEN Device Validation Progress Report

**Date:** 2026-09-06
**Device:** Redmi Turbo 4 Pro (`emulator-5554`, serial `5fb2c67c`)
**Current APK:** Installed 02:30 (pre-debug-log changes)
**New Build:** Committed 13:00, CI passed, APK download blocked by network

---

## What Was Accomplished

### 1. Code Changes for ADB-Readable Debug Logs

**Files modified:**
- `apps/ggen_app/lib/debug_log.dart` - Added persistent file logging
- `apps/ggen_app/lib/main.dart` - Added `debugLog.initLogFile()` call
- `apps/ggen_app/lib/src/canvas/studio_canvas.dart` - Added tap/shape event logging

**Changes:**
- `DebugLogStore` now writes to `<documents>/debug_log.jsonl` (JSON Lines format)
- Log file accessible via `~/android-sdk/platform-tools/adb pull /data/user/0/com.example.ggen/app_flutter/debug_log.jsonl`
- Events logged: `canvas_tap`, `shape_added`, `ellipse_added`, `node_add_text`, `volume_undo`, `volume_redo`, `history_undo`, `history_redo`, `grid_toggle`, `project_restore`, `storage_init`, `flutter_error`, `uncaught_error`

**Git:** Pushed to main (`20250f9`)

### 2. Test Script Created

`scripts/run-device-tests-v2.sh` - Automated test runner that:
- Pulls debug log after each action
- Counts event occurrences
- Reports PASS/FAIL for each feature

---

## Blockers

### APK Download Failure
Network connectivity issues preventing download of new APK from GitHub Actions artifacts. Tried:
- `gh run download` - Connection aborted
- `curl` to nightly.link - Returns 729-byte error page
- Direct GitHub API - Timeout

**Solution needed:** Either:
1. Retry download when network is stable
2. Use alternative distribution method
3. Build locally if Flutter is available

---

## Known Device State (from old APK)

Based on earlier testing with the pre-debug-log build:

| Feature | Status | Evidence |
|---------|--------|----------|
| App install/launch | ✓ | Process runs, UI renders |
| Rectangle tool | ? | Taps received (MIUIInput logs), but no shapes in layer list |
| Ellipse tool | ? | Same as rectangle |
| Text tool | ✓ | Text dialog appears on canvas tap |
| More menu | ✓ | All actions visible |
| Restart restore | ✗ | No shapes in layer list after restart |
| Volume undo/redo | Unverified | Can't confirm without debug logs |
| Grid toggle | Unverified | Button visible but no log feedback |

**Critical finding:** Canvas taps are received by the app (confirmed via MIUIInput logs showing ACTION_DOWN/ACTION_UP events for `com.example.ggen/com.example.ggen_app.MainActivity`), but no shapes appear in the UI hierarchy or layer list. This suggests either:
1. Coordinate mapping issue (screen pixels → artboard space)
2. Tool not properly activated (Rectangle shows `selected=false`)
3. Bug in shape creation logic

---

## Next Steps

1. **Get new APK installed** - Resolve network issue or use alternative build distribution
2. **Run v2 test script** - Will show exact coordinates and tool state for each tap
3. **Investigate coordinate mapping** - Use debug logs to see if `artboard_x/y` values make sense
4. **Verify restart restore** - New debug logs will show if `project_restore` fires

---

## Manual Testing Recommendation

Since automated testing is blocked by the old APK, consider manual testing on device:
1. Open app
2. Tap Rectangle tool (left rail, second button)
3. Tap canvas center
4. Check if shape appears in layer list (right panel, scroll down)
5. Try Save → Close app → Reopen → Verify project restores
