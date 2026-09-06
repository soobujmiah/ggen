#!/usr/bin/env python3
"""Patch generated MainActivity.kt to add debug intent handling.

This script is called by CI after flutter create and before build.
It adds an exported debug activity that accepts intent extras for
deterministic agent testing.
"""

import re
import sys
from pathlib import Path

DEBUG_ACTIVITY_KOTLIN = '''
package com.example.ggen_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * Debug activity for agent-driven device testing.
 * Exports a deterministic control surface accessible via:
 *   adb shell am start -n com.example.ggen/com.example.ggen_app.DebugActivity
 *       --es test_action <action> [--es target <value>]
 *
 * Supported actions:
 *   undo     - Call StudioController.undo()
 *   redo     - Call StudioController.redo()
 *   grid     - Toggle grid overlay
 *   zoom_in  - Zoom in 25%
 *   zoom_out - Zoom out 20%
 *   fit      - Fit to screen
 *
 * Note: This activity launches the main app with the action applied.
 * The actual operation happens in the main activity's initState.
 */
class DebugActivity : FlutterActivity() {
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // Forward result to Flutter engine
        flutterEngine?.plugins?.get(FlutterPluginRegistry::class.java)?.activityResultCallback?.invoke(
            requestCode, resultCode, data
        )
    }

    override fun onResume() {
        super.onResume()
        // Handle debug action from intent
        val action = intent?.getStringExtra("test_action")
        if (action != null) {
            // Store for main activity to pick up
            intent.putExtra("debug_action_handled", action)
        }
    }
}
'''

MANIFEST_DEBUG_ENTRY = '''
        <activity
            android:name=".DebugActivity"
            android:exported="true"
            android:label="@string/app_name">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        <activity
            android:name=".MainActivity"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:launchMode="singleTask"
            android:theme="@style/LaunchTheme"
            android:windowSoftInputMode="adjustResize">
            <!-- Specifies an Android theme to apply to this Activity as soon as
                 the Android process has started. This theme is visible to the user
                 while the Flutter UI initializes. After that, this theme continues
                 to determine the Window background behind the Flutter UI. -->
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme"
                />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.DEFAULT"/>
            </intent-filter>
        </activity>
'''


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

    # Insert DebugActivity before MainActivity
    # Find the MainActivity declaration
    ma_pattern = r'<activity\s+android:name="\.MainActivity"'
    match = re.search(ma_pattern, text)
    if not match:
        print("ERROR: MainActivity not found in manifest")
        return False

    # Insert DebugActivity entry before MainActivity
    insert_pos = match.start()
    new_text = text[:insert_pos] + DEBUG_ACTIVITY_KOTLIN.rstrip() + "\n" + text[insert_pos:]

    # Actually, we need to add it to the manifest, not the kotlin file
    # Let's fix this
    debug_entry = '''        <activity
            android:name=".DebugActivity"
            android:exported="true"
            android:label="@string/app_name">
        </activity>
'''
    new_text = text[:insert_pos] + debug_entry + text[insert_pos:]

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
    activity_path.write_text(DEBUG_ACTIVITY_KOTLIN.lstrip(), encoding="utf-8")
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
