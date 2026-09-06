# GGEN Device Validation Report - Final

**Date:** 2026-09-06  
**Device:** Redmi Turbo 4 Pro (product: onyx, model: 25053RT47C)  
**Package:** com.example.ggen v0.1.0  
**Build:** Commit 7cf9031 (debug log persistence + test scripts)

---

## Validation Summary

| Feature | Status | Notes |
|---------|--------|-------|
| App launch & workspace restore | ✓ | `workspace_restore` event logged |
| Rectangle tool | ✓ | Tool selected, shapes created via ADB |
| Ellipse tool | ✓ | Working |
| Text tool | ✓ | Dialog appears, requires keyboard |
| Shape creation | ✓ | 3 shapes created via automation |
| Volume undo/redo | ✓ | `volume_undo`/`volume_redo` logged |
| **Project save** | ✓ | `project_save` with SHA-256 receipt |
| **Restart restore** | ✓ | `project_restore` restores saved project |
| Multi-column UI | ✓ | Columns/Gutter options visible |
| Grid toggle | ⚠️ | Button exists but custom paint layer may not register touches |
| Three-finger redo | ⚠️ | ADB limitation - cannot simulate multi-touch pointers |
| Text input workflow | ⚠️ | Requires keyboard interaction |

---

## Key Findings

### Debug Logging
- **Persistent file logging working**: `app_flutter/debug_log.jsonl` contains all events
- **Events captured**: `storage_init`, `workspace_restore`, `canvas_geometry`, `tool_select`, `node_add`, `node_add_text`, `volume_undo`, `volume_redo`, `project_save`, `project_restore`, `top_action_more`, `top_action_run`
- **Format**: JSON Lines with timestamp, level, event, message, details

### Coordinate Mapping
- **Canvas bounds**: [141,152]-[1280,2631] (1139×2479 px screen)
- **Artboard size**: 419×912 px ( Flutter coordinate space)
- **Tool positions**: x≈70, y=239(Sel)/369(Rect)/500(Ell)/630(Txt)
- **Grid button**: [838,2647]-[947,2756] (bottom toolbar)
- **More actions**: [645,157]-[776,288] (top right)

### Automation Limitations
1. **Multi-touch gestures**: ADB `input touchscreen` commands failed - device may require simultaneous touch pressure
2. **CustomPaint layers**: Grid/rendering may not respond to accessibility taps (rendered via Canvas, not widgets)
3. **Keyboard input**: Text dialog requires IME interaction beyond ADB capabilities

---

## Linked Text-Flow Validation

**Status**: CI verified (237/237 tests), partially device-validated

**What's available on device:**
- Text tool creates text frames (`node_add_text`)
- Multi-column configuration UI present (Columns slider, Gutter field)
- Save/restore preserves text frames with extensions

**Pending manual testing:**
1. Create two text frames manually
2. Open inspector for first frame
3. Check if "Text flow" section appears with link candidates
4. Select second frame as successor
5. Verify blue continuation indicator appears
6. Add text to first frame, verify flow into second

---

## Recommendations

### Immediate Next Steps

1. **Manual three-finger redo test**: User should perform three-finger tap on device to verify `gesture_redo` event fires

2. **Grid toggle manual test**: Tap grid button in bottom toolbar, observe visual change, check log for `grid_toggle` event

3. **Linked text-flow workflow**: Create text frames manually, configure columns, test linking through inspector

### Future Work

Per `phase-2-status.md`:
- SAF/MediaStore import/export for `.ggen` files
- GPU/NPU performance validation
- Production release testing

---

## Artifacts

- Test script: `scripts/run-device-tests-v4.sh`
- Validation script: `scripts/device-validation-final.sh`
- Debug report: `docs/device-evidence/2026-09-06-device-validation.md`
- Progress notes: `docs/device-evidence/2026-09-06-progress-report.md`

---

**Conclusion**: Core functionality validated on device. Automation limited by ADB constraints on multi-touch and CustomPaint rendering. Manual testing recommended for gesture-based features.
