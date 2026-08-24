import 'package:flutter/material.dart';

/// Canonical primary creation tools of the studio shell.
///
/// Single source of truth for tool identity, order and iconography: the
/// compact vertical tool rail and the wide [NavigationRail] both render
/// from [StudioTool.values], so a tool index can never diverge between
/// surfaces. The Redmi Turbo 4 Pro device RangeError
/// ("Invalid value: Not in inclusive range 0..2: 3") came from a
/// 4-destination bottom NavigationBar forwarding its raw destination index
/// (3 = the contextual Columns entry) into a 3-entry tool-name list; tools
/// are now typed, and contextual actions live on the contextual action bar
/// instead of being disguised as tool destinations.
///
/// The `draw` enum value is the **Rectangle** primitive for Vector Studio
/// Milestone 1. It is kept as `draw` (rather than renamed to `rectangle`)
/// to preserve API stability with existing tests, tool-selection code and
/// serialized workspace preferences. Its label and icon are the rectangle
/// primitive identity; the wire constant name is an implementation detail.
enum StudioTool {
  select('Select', Icons.near_me_outlined, Icons.near_me),
  draw('Rectangle', Icons.rectangle_outlined, Icons.rectangle),
  ellipse('Ellipse', Icons.circle_outlined, Icons.circle),
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
