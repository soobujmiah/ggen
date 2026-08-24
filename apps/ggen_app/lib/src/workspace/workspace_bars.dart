import 'package:flutter/material.dart';

import '../canvas/canvas_zoom_controller.dart';
import '../controller/studio_controller.dart';
import 'control_layout.dart';
import 'studio_tool.dart';

/// Reusable studio tool/action button with a consistent visual contract:
/// fixed 40x40 box, 20px icon, obvious selected state (primary container
/// fill). Every toolbar surface of the mobile shell renders through this
/// one component so icon sizing, hit targets and active states cannot
/// drift apart again.
class ToolButton extends StatelessWidget {
  const ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;

  /// Null renders the disabled state (visible but not tappable).
  final VoidCallback? onPressed;

  /// Selected/active state: filled primary container, obvious at a glance.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      isSelected: selected,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(40, 40),
        maximumSize: const Size(40, 40),
        backgroundColor: selected ? scheme.primaryContainer : null,
        foregroundColor: selected ? scheme.onPrimaryContainer : null,
      ),
    );
  }
}

/// Compact vertical tool rail — the single stable home of the primary
/// creation tools on phone-class (<700px) viewports.
///
/// The rail is deliberately NOT dockable, collapsible or reorderable: the
/// canonical mobile layout keeps primary tools in one predictable place
/// (Vector-Ink-style left rail) and the canvas visually dominant. Tools
/// come from [StudioTool.values] — the same metadata the wide
/// [NavigationRail] uses — so a tool index can never point outside the
/// tool list.
class MobileToolRail extends StatelessWidget {
  const MobileToolRail({
    required this.activeTool,
    required this.onSelected,
    super.key,
  });

  static const Key railKey = ValueKey('mobile_tool_rail');

  final StudioTool activeTool;
  final ValueChanged<StudioTool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: railKey,
      width: 52,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          const SizedBox(height: 8),
          for (final tool in StudioTool.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ToolButton(
                icon: tool == activeTool ? tool.selectedIcon : tool.icon,
                tooltip: tool.label,
                selected: tool == activeTool,
                onPressed: () => onSelected(tool),
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Bottom contextual action bar of the compact (phone) workspace.
///
/// One surface, one row, grouped by separators:
///   history (undo/redo) | zoom (out/in/fit) | view (grid/layers) |
///   context (multi-select with the Select tool; Columns for a selected
///   text frame).
/// Context-dependent controls appear only in the states where they mean
/// something — the old compact shell exposed "Columns" as a permanently
/// visible 4th navigation destination whose disabled state still delivered
/// index 3 into a 3-tool list (the on-device RangeError). Here contextual
/// actions are plain buttons that simply do not exist outside their state.
///
/// The row is centered and becomes horizontally scrollable only if the
/// viewport is narrower than its content, so it can never overflow its
/// constraints at any width (471px-class devices fit the maximal button
/// set without scrolling).
class ContextualActionBar extends StatelessWidget {
  const ContextualActionBar({
    required this.controller,
    required this.zoomController,
    required this.activeTool,
    required this.gridVisible,
    required this.multiSelect,
    required this.columnsEnabled,
    required this.onToggleGrid,
    required this.onToggleMultiSelect,
    required this.onShowLayers,
    required this.onConfigureColumns,
    this.onDiagnostic,
    super.key,
  });

  static const Key barKey = ValueKey('contextual_action_bar');

  final StudioController controller;
  final CanvasZoomController zoomController;
  final StudioTool activeTool;
  final bool gridVisible;
  final bool multiSelect;

  /// True when exactly the selected node is a text frame; shows the
  /// Columns action (column/gutter/text-flow sheet).
  final bool columnsEnabled;

  final VoidCallback onToggleGrid;
  final VoidCallback onToggleMultiSelect;
  final VoidCallback onShowLayers;
  final VoidCallback onConfigureColumns;

  /// Diagnostic hook: called with a short event id after each direct bar
  /// action (undo/redo/zoom), so the shell can record device evidence
  /// without this widget depending on the shell's logger.
  final void Function(String event)? onDiagnostic;

  Widget _separator() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Container(width: 1, height: 24, color: Colors.white24),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final buttons = <Widget>[
          ToolButton(
            icon: Icons.undo,
            tooltip: 'Undo',
            onPressed: controller.canUndo
                ? () {
                    controller.undo();
                    onDiagnostic?.call('history_undo');
                  }
                : null,
          ),
          ToolButton(
            icon: Icons.redo,
            tooltip: 'Redo',
            onPressed: controller.canRedo
                ? () {
                    controller.redo();
                    onDiagnostic?.call('history_redo');
                  }
                : null,
          ),
          _separator(),
          ToolButton(
            icon: Icons.remove,
            tooltip: 'Zoom out',
            onPressed: () {
              zoomController.zoomOut();
              onDiagnostic?.call('toolbar_zoom_out');
            },
          ),
          ToolButton(
            icon: Icons.add,
            tooltip: 'Zoom in',
            onPressed: () {
              zoomController.zoomIn();
              onDiagnostic?.call('toolbar_zoom_in');
            },
          ),
          ToolButton(
            icon: Icons.fit_screen_outlined,
            tooltip: 'Fit to screen',
            onPressed: () {
              zoomController.fitToScreen();
              onDiagnostic?.call('toolbar_zoom_fit');
            },
          ),
          _separator(),
          ToolButton(
            icon: Icons.grid_4x4,
            tooltip: gridVisible ? 'Hide grid' : 'Show grid',
            selected: gridVisible,
            onPressed: onToggleGrid,
          ),
          ToolButton(
            icon: Icons.layers_outlined,
            tooltip: 'Show layers',
            onPressed: onShowLayers,
          ),
          // Contextual group: present only in the states where the action
          // is meaningful (active tool / selection type).
          if (activeTool == StudioTool.select || columnsEnabled) _separator(),
          if (activeTool == StudioTool.select)
            ToolButton(
              icon: multiSelect ? Icons.done_all : Icons.done_all_outlined,
              tooltip: multiSelect ? 'Multi-select on' : 'Multi-select off',
              selected: multiSelect,
              onPressed: onToggleMultiSelect,
            ),
          if (columnsEnabled)
            ToolButton(
              icon: Icons.view_column_outlined,
              tooltip: 'Columns',
              onPressed: onConfigureColumns,
            ),
        ];
        return Material(
          key: barKey,
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 52,
              // Centered when the content fits (the 471px-class target
              // fits the maximal set); scrollable below that so the row
              // can never exceed its constraints.
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < buttons.length; i++) ...[
                        if (i > 0 && buttons[i] is ToolButton)
                          const SizedBox(width: 2),
                        buttons[i],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A [CanvasControl] resolved to a concrete shell action.
///
/// The shell builds these (mapping each control to its enabled state and
/// callback); the cluster renders them without knowing about controllers,
/// keeping the renderer dumb and testable.
class ResolvedControlAction {
  const ResolvedControlAction(this.control, {this.onPressed, this.selected = false});

  final CanvasControl control;

  /// Null renders the disabled state (visible but not tappable).
  final VoidCallback? onPressed;

  /// Selected/active state (e.g. grid visible).
  final bool selected;
}

/// Compact floating cluster of fullscreen controls rendered over the canvas
/// in immersive mode, one per occupied [ControlRegion].
///
/// Contract: the cluster is width-bounded ([maxWidth]) and horizontally
/// scrollable, so however many controls a region holds it can never overflow
/// its constraints or be clipped (device finding: the old fixed zoom overlay
/// could not grow). Buttons keep the shared 40×40 [ToolButton] contract.
class CanvasControlCluster extends StatelessWidget {
  const CanvasControlCluster({
    required this.actions,
    this.maxWidth = 360,
    super.key,
  });

  final List<ResolvedControlAction> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(22),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  ToolButton(
                    icon: actions[i].control.icon,
                    tooltip: actions[i].control.label,
                    selected: actions[i].selected,
                    onPressed: actions[i].onPressed,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact landscape bottom bar — the ONE bottom surface of the
/// [WorkspaceClass.compactLandscape] layout.
///
/// Landscape phones previously fell into the "wide" branch (left rail +
/// bottom status bar + fixed zoom overlay), wasting the short vertical
/// space. This single 48px bar carries everything: tools (from
/// [StudioTool.values], the same metadata as every other surface),
/// history, zoom, view, and the contextual multi-select/columns entries.
/// Horizontally scrollable and centered, so it can never overflow at any
/// landscape width.
class LandscapeBar extends StatelessWidget {
  const LandscapeBar({
    required this.controller,
    required this.zoomController,
    required this.activeTool,
    required this.onSelectedTool,
    required this.gridVisible,
    required this.onToggleGrid,
    required this.onToggleMultiSelect,
    required this.onShowLayers,
    required this.multiSelect,
    required this.columnsEnabled,
    required this.onConfigureColumns,
    this.onDiagnostic,
    super.key,
  });

  static const Key barKey = ValueKey('landscape_bar');

  final StudioController controller;
  final CanvasZoomController zoomController;
  final StudioTool activeTool;
  final ValueChanged<StudioTool> onSelectedTool;
  final bool gridVisible;
  final VoidCallback onToggleGrid;
  final VoidCallback onToggleMultiSelect;
  final VoidCallback onShowLayers;
  final bool multiSelect;
  final bool columnsEnabled;
  final VoidCallback onConfigureColumns;
  final void Function(String event)? onDiagnostic;

  Widget _separator() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Container(width: 1, height: 24, color: Colors.white24),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final buttons = <Widget>[
          for (final tool in StudioTool.values)
            ToolButton(
              icon: tool == activeTool ? tool.selectedIcon : tool.icon,
              tooltip: tool.label,
              selected: tool == activeTool,
              onPressed: () => onSelectedTool(tool),
            ),
          _separator(),
          ToolButton(
            icon: Icons.undo,
            tooltip: 'Undo',
            onPressed: controller.canUndo
                ? () {
                    controller.undo();
                    onDiagnostic?.call('landscape_history_undo');
                  }
                : null,
          ),
          ToolButton(
            icon: Icons.redo,
            tooltip: 'Redo',
            onPressed: controller.canRedo
                ? () {
                    controller.redo();
                    onDiagnostic?.call('landscape_history_redo');
                  }
                : null,
          ),
          _separator(),
          ToolButton(
            icon: Icons.remove,
            tooltip: 'Zoom out',
            onPressed: () {
              zoomController.zoomOut();
              onDiagnostic?.call('landscape_zoom_out');
            },
          ),
          ToolButton(
            icon: Icons.add,
            tooltip: 'Zoom in',
            onPressed: () {
              zoomController.zoomIn();
              onDiagnostic?.call('landscape_zoom_in');
            },
          ),
          ToolButton(
            icon: Icons.fit_screen_outlined,
            tooltip: 'Fit to screen',
            onPressed: () {
              zoomController.fitToScreen();
              onDiagnostic?.call('landscape_zoom_fit');
            },
          ),
          _separator(),
          ToolButton(
            icon: Icons.grid_4x4,
            tooltip: gridVisible ? 'Hide grid' : 'Show grid',
            selected: gridVisible,
            onPressed: onToggleGrid,
          ),
          ToolButton(
            icon: Icons.layers_outlined,
            tooltip: 'Show layers',
            onPressed: onShowLayers,
          ),
          if (activeTool == StudioTool.select || columnsEnabled) _separator(),
          if (activeTool == StudioTool.select)
            ToolButton(
              icon: multiSelect ? Icons.done_all : Icons.done_all_outlined,
              tooltip: multiSelect ? 'Multi-select on' : 'Multi-select off',
              selected: multiSelect,
              onPressed: onToggleMultiSelect,
            ),
          if (columnsEnabled)
            ToolButton(
              icon: Icons.view_column_outlined,
              tooltip: 'Columns',
              onPressed: onConfigureColumns,
            ),
        ];
        return Material(
          key: barKey,
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 48,
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < buttons.length; i++) ...[
                        if (i > 0 && buttons[i] is ToolButton)
                          const SizedBox(width: 2),
                        buttons[i],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
