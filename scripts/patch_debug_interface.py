#!/usr/bin/env python3
"""Patch generated MainActivity.kt to add debug intent handling.

This script is called by CI after flutter create and before build.
It adds an exported debug activity that accepts intent extras for
deterministic agent testing.

Supported actions via:
    adb shell am start -n com.example.ggen/com.example.ggen_app.DebugActivity
        --es test_action <action> [--es target <value>]

Actions:
    undo     - Call StudioController.undo()
    redo     - Call StudioController.redo()

Note: DebugActivity simply forwards the intent to MainActivity which
handles the debug action when it resumes to foreground.
"""

import re
import sys
from pathlib import Path

MANIFEST_DEBUG_ENTRY = """        <activity
            android:name=".DebugActivity"
            android:exported="true"
            android:label="GGEN Debug">
        </activity>
"""


def patch_manifest(android_dir: Path) -> bool:
    """Add DebugActivity to AndroidManifest.xml."""
    manifest = android_dir / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest.exists():
        print(f"ERROR: Manifest not found: {manifest}")
        return False

    text = manifest.read_text(encoding="utf-8")

    # Check if already patched
    if "DebugActivity" in text:
        print("DebugActivity already in manifest; skipping.")
        return False

    # Insert DebugActivity entry before </application>
    close_pattern = r"</application>"
    match = re.search(close_pattern, text)
    if not match:
        print("ERROR: </application> tag not found in manifest")
        return False

    insert_pos = match.start()
    new_text = text[:insert_pos] + MANIFEST_DEBUG_ENTRY + text[insert_pos:]

    manifest.write_text(new_text, encoding="utf-8")
    print(f"Patched manifest: {manifest}")
    return True


def create_debug_activity(android_dir: Path) -> bool:
    """Create DebugActivity.kt if it doesn't exist."""
    activity_path = android_dir / "app" / "src" / "main" / "kotlin" / "com" / "example" / "ggen_app" / "DebugActivity.kt"
    if activity_path.exists():
        print(f"DebugActivity already exists: {activity_path}")
        return False

    activity_path.parent.mkdir(parents=True, exist_ok=True)
    activity_path.write_text(
        '''package com.example.ggen_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * Debug activity for agent-driven device testing.
 *
 * Exports a deterministic control surface accessible via:
 *   adb shell am start -n com.example.ggen/com.example.ggen_app.DebugActivity
 *       --es test_action <action>
 *
 * Supported actions:
 *   undo     - Call StudioController.undo()
 *   redo     - Call StudioController.redo()
 *
 * This activity simply forwards the debug intent to MainActivity
 * which processes the action via SharedPreferences (since debug
 * actions need to work even when the app is in background).
 */
class DebugActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Get the action from the incoming intent
        val action = intent?.getStringExtra("test_action")
        
        // Forward to MainActivity via a broadcast-style approach
        // We'll store it in a global static holder that MainActivity can read
        if (action != null) {
            DebugIntentHandler.setPendingAction(action)
        }
        
        // Launch MainActivity and bring it to front
        val mainIntent = Intent(this, MainActivity::class.java)
        mainIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        startActivity(mainIntent)
        finish()
    }
}

/**
 * Simple static holder for passing debug actions between activities.
 * Since each FlutterActivity has its own engine, we need a bridge.
 */
object DebugIntentHandler {
    @Volatile
    var pendingAction: String? = null
    
    fun clearAction() {
        pendingAction = null
    }
}
''',
        encoding="utf-8",
    )
    print(f"Created: {activity_path}")
    return True


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: patch_debug_interface.py <path-to-android-dir>")
        sys.exit(1)

    android_dir = Path(sys.argv[1])
    print(f"Patching Android wrapper at: {android_dir}")

    changed = False
    changed |= patch_manifest(android_dir)
    changed |= create_debug_activity(android_dir)

    if changed:
        print("Debug interface patching complete.")
    else:
        print("No changes needed.")


if __name__ == "__main__":
    main()
