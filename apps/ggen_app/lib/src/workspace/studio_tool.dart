import 'package:flutter/material.dart';

/// Canonical primary creation tools of the studio shell.
///
/// Single source of truth for tool identity, order and iconography: the
/// compact vertical tool rail and the wide [NavigationRail] both render
/// from [StudioTool.values], so a tool index can never diverge between
/// surfaces again. The Redmi Turbo 4 Pro device RangeError
/// ("Invalid value: Not in inclusive range 0..2: 3") came from a
/// 4-destination bottom NavigationBar forwarding its raw destination index
/// (3 = the contextual Columns entry) into a 3-entry tool-name list; tools
/// are now typed, and contextual actions live on the contextual action bar
/// instead of being disguised as tool destinations.
enum StudioTool {
  select('Select', Icons.near_me_outlined, Icons.near_me),
  draw('Draw', Icons.brush_outlined, Icons.brush),
  text('Text', Icons.text_fields, Icons.text_fields);

  const StudioTool(this.label, this.icon, this.selectedIcon);

  /// User-facing tool name (tooltip on the compact rail, label on the wide
  /// rail).
  final String label;

  /// Resting icon.
  final IconData icon;

  /// Icon when the tool is active.
  final IconData selectedIcon;
}
