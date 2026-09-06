#!/usr/bin/env python3
"""Patch generated MainActivity.kt to add debug intent handling.

This script is called by CI after flutter create and before build.
It modifies the existing MainActivity.kt to accept debug intent extras
for deterministic agent testing.

Supported actions via:
    adb shell am start -n com.example.ggen/com.example.ggen_app.MainActivity
        --es test_action <action>

Actions:
    undo     - Call StudioController.undo()
    redo     - Call StudioController.redo()

The app reads the intent extra on startup and processes it.
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
    if "debugIntentAction" in content:
        print("Debug intent already patched in MainActivity.kt; skipping.")
        return False

    # Add imports
    if "import io.flutter.embedding.android.FlutterActivity\n" in content:
        content = content.replace(
            "import io.flutter.embedding.android.FlutterActivity\n",
            "import io.flutter.embedding.android.FlutterActivity\nimport android.content.Intent\n",
            1
        )

    # Find and replace the onCreate method
    oncreate_pattern = r'override fun onCreate\(savedInstanceState: Bundle\?\) \{[\s\S]*?super\.onCreate\(savedInstanceState\)[\s\S]*?\}'
    
    new_oncreate = '''override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle debug intent action from ADB
        val debugAction = intent?.getStringExtra("test_action")
        if (debugAction != null) {
            DebugIntentBridge.setPendingAction(debugAction)
        }
    }'''

    # Replace the onCreate method
    match = re.search(oncreate_pattern, content)
    if match:
        content = content[:match.start()] + new_oncreate + content[match.end():]
        print(f"Patched MainActivity.kt: {activity_path}")
        activity_path.write_text(content, encoding="utf-8")
        return True
    
    print(f"ERROR: Could not find onCreate in {activity_path}")
    return False


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
    @Volatile
    var pendingAction: String? = null
    
    fun setPendingAction(action: String) {
        pendingAction = action
    }
    
    fun consumeAction(): String? {
        return pendingAction.also { pendingAction = null }
    }
}
''',
        encoding="utf-8",
    )
    print(f"Created: {bridge_path}")
    return True


def remove_old_debug_files(android_dir: Path) -> bool:
    """Remove old DebugActivity.kt if it exists from previous runs."""
    activity_path = android_dir / "app" / "src" / "main" / "kotlin" / "com" / "example" / "ggen_app" / "DebugActivity.kt"
    manifest = android_dir / "app" / "src" / "main" / "AndroidManifest.xml"
    
    changed = False
    
    # Remove old DebugActivity.kt if it exists
    if activity_path.exists():
        activity_path.unlink()
        print(f"Removed old DebugActivity.kt: {activity_path}")
        changed = True
    
    # Remove DebugActivity entry from manifest if it exists
    if manifest.exists():
        text = manifest.read_text(encoding="utf-8")
        if "DebugActivity" in text:
            # Remove the entire activity block
            pattern = r'\s*<activity\s+android:name="\.DebugActivity"[^>]*/?>'
            new_text = re.sub(pattern, '', text)
            # Also remove any trailing whitespace/empty lines
            new_text = re.sub(r'\n\s*\n\s*\n', '\n\n', new_text)
            if new_text != text:
                manifest.write_text(new_text, encoding="utf-8")
                print(f"Removed DebugActivity from manifest: {manifest}")
                changed = True
    
    return changed


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: patch_debug_interface.py <path-to-android-dir>")
        sys.exit(1)

    android_dir = Path(sys.argv[1])
    print(f"Patching Android wrapper at: {android_dir}")

    changed = False
    changed |= remove_old_debug_files(android_dir)
    changed |= patch_main_activity(android_dir)
    changed |= create_debug_bridge(android_dir)

    if changed:
        print("Debug interface patching complete.")
    else:
        print("No changes needed.")


if __name__ == "__main__":
    main()
