#!/usr/bin/env python3
"""Patch generated Android wrapper to add debug intent handling.

This script is called by CI after flutter create and before build.
It modifies MainActivity.kt to store the debug action in SharedPreferences,
which Flutter can then read on startup via shared_preferences package.

Supported actions via:
    adb shell am start -n com.example.ggen/com.example.ggen_app.MainActivity
        --es test_action <action> [--es target <value>]

Actions:
    undo     - Call StudioController.undo()
    redo     - Call StudioController.redo()
    grid     - Toggle grid (NOT YET IMPLEMENTED - needs UI state)
    zoom_in  - Zoom in (NOT YET IMPLEMENTED - needs canvas reference)
    zoom_out - Zoom out (NOT YET IMPLEMENTED - needs canvas reference)
    fit      - Fit to screen (NOT YET IMPLEMENTED - needs canvas reference)
"""

import re
import sys
from pathlib import Path


def patch_main_activity(android_dir: Path) -> bool:
    """Modify MainActivity.kt to handle debug intent via SharedPreferences."""
    activity_path = android_dir / "app" / "src" / "main" / "kotlin" / "com" / "example" / "ggen_app" / "MainActivity.kt"
    if not activity_path.exists():
        print(f"ERROR: MainActivity.kt not found at {activity_path}")
        return False

    content = activity_path.read_text(encoding="utf-8")

    # Check if already patched
    if "test_action" in content:
        print("Debug intent already patched in MainActivity.kt; skipping.")
        return False

    # Add imports for SharedPreferences
    if "import io.flutter.embedding.android.FlutterActivity" in content:
        content = content.replace(
            "import io.flutter.embedding.android.FlutterActivity\n",
            """import io.flutter.embedding.android.FlutterActivity
import android.content.SharedPreferences
""",
            1
        )

    # Find onCreate and modify it to store the action
    # Match the existing onCreate method
    oncreate_pattern = r'(override fun onCreate\(savedInstanceState: Bundle\?\) \{)([\s\S]*?)(\n\})'
    match = re.search(oncreate_pattern, content)
    
    if match:
        old_oncreate = match.group(0)
        new_oncreate = '''override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle debug intent action from ADB
        val debugAction = intent?.getStringExtra("test_action")
        if (debugAction != null) {
            // Store in SharedPreferences for Flutter to read on startup
            val prefs: SharedPreferences = getSharedPreferences("ggen_debug_prefs", MODE_PRIVATE)
            prefs.edit().putString("debug_pending_action", debugAction).apply()
        }
    }'''
        content = content.replace(old_oncreate, new_oncreate)
        print(f"Patched MainActivity.kt: {activity_path}")
        activity_path.write_text(content, encoding="utf-8")
        return True
    
    print(f"ERROR: Could not find onCreate in {activity_path}")
    return False


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: patch_debug_interface.py <path-to-android-dir>")
        sys.exit(1)

    android_dir = Path(sys.argv[1])
    print(f"Patching Android wrapper at: {android_dir}")

    changed = patch_main_activity(android_dir)

    if changed:
        print("Debug interface patching complete.")
    else:
        print("No changes needed.")


if __name__ == "__main__":
    main()
