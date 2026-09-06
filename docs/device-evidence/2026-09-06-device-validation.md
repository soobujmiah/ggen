# GGEN Device Validation Report
**Date:** 2026-09-06  
**Device:** Redmi Turbo 4 Pro (product: onyx, model: 25053RT47C)  
**Serial:** 5fb2c67c  
**Package:** com.example.ggen v0.1.0  
**Build:** Commit 20250f9 (debug log persistence)

---

## Summary

**Status:** All critical features validated ✓

| Feature | Status | Evidence |
|---------|--------|----------|
| App install/launch | ✓ | Process runs, UI renders |
| Rectangle tool | ✓ | Tool selected, 3 shapes created |
| Ellipse tool | ✓ | Tool selected, shape created |
| Text tool | ✓ | Tool selected, dialog appears |
| Canvas tap handling | ✓ | Coordinates mapped correctly |
| Volume undo/redo | ✓ | Events logged and functional |
| Restart restore | ✓ | workspace_restore fires on launch |
| Debug log file | ✓ | JSONL at app_flutter/debug_log.jsonl |

---

## Debug Logging Implementation

### Changes Made
1. **debug_log.dart** - Added persistent file logging:
   - `initLogFile()` writes to `<documents>/debug_log.jsonl`
   - Every event appended as JSON Lines
   - Accessible via `adb pull /data/user/0/com.example.ggen/app_flutter/debug_log.jsonl`

2. **studio_canvas.dart** - Added canvas tap logging:
   - Logs raw touch coordinates
   - Logs artboard point conversion
   - Logs tool state on each tap

3. **Test Scripts:**
   - `scripts/run-device-tests-v4.sh` - Automated validation suite
   - Canvas bounds: [141,152]-[1280,2631] (1139×2479 px)
   - Tool positions: x≈70, y=239(Sel)/369(Rect)/500(Ell)/630(Txt)

---

## How to Use Debug Logs

```bash
# Pull current debug log
adb pull /data/user/0/com.example.ggen/app_flutter/debug_log.jsonl ./debug.jsonl

# View events
cat debug.jsonl | python3 -m json.tool

# Run automated tests
bash scripts/run-device-tests-v4.sh
```

---

## Known Limitations

1. **Project auto-save**: App uses Hive storage (journal files present), but no explicit `project_save` event logged during testing. May require explicit save action via UI.

2. **Grid toggle logging**: Code references `grid_toggle` event but it's not appearing in logs - may need instrumentation in the grid controller.

3. **UI automation**: Flutter's CustomPaint renders shapes as pixels, not accessible nodes. Visual verification requires screenshots, not XML hierarchy.

---

## Next Steps

1. Add `grid_toggle` instrumentation if needed
2. Test explicit project save flow (More → Save)
3. Verify text input workflow (requires keyboard interaction)
4. Consider adding shape count to debug output for visual verification

---

## Files Modified
- `apps/ggen_app/lib/debug_log.dart` - Added file persistence
- `apps/ggen_app/lib/main.dart` - Initialize log file on startup
- `apps/ggen_app/lib/src/canvas/studio_canvas.dart` - Add tap coordinate logging
- `scripts/run-device-tests-v4.sh` - New test runner
