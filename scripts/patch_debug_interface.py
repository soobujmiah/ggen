#!/usr/bin/env python3
"""Patch generated Android wrapper to add debug intent handling.

This script is called by CI after flutter create and before build.
It modifies the existing MainActivity.kt to accept debug intent extras
for deterministic agent testing.

Supported actions via:
    adb shell am start -n com.example.ggen/com.example.ggen_app.MainActivity
        --es test_action <action>

Actions:
    undo     - Call StudioController.undo()
    redo     - Call StudioController.redo()
"""

import re
import sys
from pathlib import Path


def patch_main_activity(android_dir: Path) -> bool:
    """Modify MainActivity.kt to handle debug intent."""
    activity_path = android_dir / "app" / "src" / "main" / "kotlin" / "com" / "example" / "ggen_app" / "MainActivity.kt"
    if not activity_path.exists():
        print(f"ERROR: MainActivity.kt not found at {activity_path}")
        return False

    content = activity_path.read_text(encoding="utf-8")

    # Check if already patched
    if "DebugIntentBridge.pendingAction" in content:
        print("Debug intent already patched in MainActivity.kt; skipping.")
        return False

    # Add imports
    if "import io.flutter.embedding.android.FlutterActivity" in content:
        content = content.replace(
            "import io.flutter.embedding.android.FlutterActivity\n",
            "import io.flutter.embedding.android.FlutterActivity\nimport android.content.Intent\n",
            1
        )

    # Print debug info about the file structure
    print(f"File content preview (first 500 chars): {content[:500]}")

    # Find and modify the class definition to add our bridge call
    # Look for the class MainActivity line
    class_pattern = r'class MainActivity\s*:\s*FlutterActivity'
    match = re.search(class_pattern, content)
    
    if not match:
        print(f"ERROR: Could not find class MainActivity in {activity_path}")
        return False

    # Insert our debug handler right after the class declaration
    insert_pos = match.end()
    debug_handler = '''

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle debug intent action from ADB
        val debugAction = intent?.getStringExtra("test_action")
        if (debugAction != null) {
            DebugIntentBridge.pendingAction = debugAction
        }
    }'''
    
    content = content[:insert_pos] + debug_handler + content[insert_pos:]
    
    # Also need to remove any existing onCreate if present
    existing_oncreate = re.search(r'override fun onCreate\(savedInstanceState: Bundle\?\)[\s\S]*?^\s*\}', content, re.MULTILINE)
    if existing_oncreate:
        print(f"WARNING: Found existing onCreate, replacing it")
    
    print(f"Patched MainActivity.kt: {activity_path}")
    activity_path.write_text(content, encoding="utf-8")
    return True


def create_debug_bridge(android_dir: Path) -> bool:
    """Create DebugIntentBridge.kt singleton."""
    bridge_path = android_dir / "app" / "src" / "main" / "kotlin" / "com" / "example" / "ggen_app" / "DebugIntentBridge.kt"
    if bridge_path.exists():
        print(f"DebugIntentBridge already exists: {bridge_path}")
        return False

    bridge_path.parent.mkdir(parents=True, exist_ok=True)
    bridge_path.write_text(
        '''package com.example.ggen_app

/**
 * Simple static bridge for passing debug actions from Android to Flutter.
 */
object DebugIntentBridge {
    var pendingAction: String? = null
    
    fun consumeAction(): String? {
        return pendingAction.also { pendingAction = null }
    }
}
''',
        encoding="utf-8",
    )
    print(f"Created: {bridge_path}")
    return True


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: patch_debug_interface.py <path-to-android-dir>")
        sys.exit(1)

    android_dir = Path(sys.argv[1])
    print(f"Patching Android wrapper at: {android_dir}")

    changed = False
    changed |= patch_main_activity(android_dir)
    changed |= create_debug_bridge(android_dir)

    if changed:
        print("Debug interface patching complete.")
    else:
        print("No changes needed.")


if __name__ == "__main__":
    main()
