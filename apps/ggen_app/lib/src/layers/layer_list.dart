import 'package:flutter/material.dart';

import 'package:ggen_core/ggen_core.dart';

import '../controller/studio_controller.dart';

/// Layer list panel showing all nodes in the first artboard with visibility
/// toggle, lock toggle, selection sync and drag-to-reorder.
///
/// The widget is presentation-only: all mutations flow through the injected
/// [StudioController], so the layer list never owns document state. Nodes
/// are displayed in reverse order (topmost first) to match the visual
/// z-order on the canvas.
class LayerList extends StatelessWidget {
  const LayerList({
    required this.controller,
    this.onNodeSelected,
    super.key,
  });

  final StudioController controller;

  /// Called when the user taps a layer to select it. The shell uses this to
  /// sync the canvas selection.
  final ValueChanged<GgenId>? onNodeSelected;

  @override
  Widget build(BuildContext context) {
    final nodes = controller.project.artboards.isEmpty
        ? const <DocumentNode>[]
        : controller.project.artboards.first.nodes;

    if (nodes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No layers yet.\nUse the Draw or Text tool to add content.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    // Display in reverse order: topmost node first (last in the list is
    // rendered on top of the canvas).
    final reversed = nodes.reversed.toList(growable: false);

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: reversed.length,
      onReorder: (oldVisualIndex, newVisualIndex) {
        // The visual list is reversed from the artboard list, so convert
        // visual indices back to artboard indices.
        final count = reversed.length;
        if (newVisualIndex > oldVisualIndex) newVisualIndex--;
        final fromArtboard = count - 1 - oldVisualIndex;
        final toArtboard = count - 1 - newVisualIndex;
        controller.reorderNodes(fromArtboard, toArtboard);
      },
      itemBuilder: (context, visualIndex) {
        final node = reversed[visualIndex];
        // The artboard index is (count - 1 - visualIndex).
        final artboardIndex = reversed.length - 1 - visualIndex;
        final isSelected = controller.selectedNodeId == node.id;

        return _LayerTile(
          key: ValueKey(node.id.value),
          node: node,
          index: artboardIndex,
          isSelected: isSelected,
          onTap: () => onNodeSelected?.call(node.id),
          onToggleVisibility: () => controller.toggleNodeVisibility(node.id),
          onToggleLock: () => controller.toggleNodeLock(node.id),
          onDelete: () => controller.deleteNode(node.id),
          dragHandle: ReorderableDragStartListener(
            index: visualIndex,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.drag_handle, size: 20, color: Colors.white38),
            ),
          ),
        );
      },
    );
  }
}

class _LayerTile extends StatelessWidget {
  const _LayerTile({
    required this.node,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onToggleVisibility,
    required this.onToggleLock,
    required this.onDelete,
    required this.dragHandle,
    super.key,
  });

  final DocumentNode node;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onToggleVisibility;
  final VoidCallback onToggleLock;
  final VoidCallback onDelete;
  final Widget dragHandle;

  IconData get _kindIcon {
    switch (node.kind) {
      case DocumentNodeKind.shape:
        return Icons.rectangle_outlined;
      case DocumentNodeKind.textFrame:
        return Icons.text_fields;
      case DocumentNodeKind.image:
        return Icons.image_outlined;
      case DocumentNodeKind.group:
        return Icons.folder_outlined;
      case DocumentNodeKind.vectorPath:
        return Icons.timeline;
      case DocumentNodeKind.rasterLayer:
        return Icons.layers_outlined;
      case DocumentNodeKind.table:
        return Icons.table_chart_outlined;
      case DocumentNodeKind.mask:
        return Icons.crop_outlined;
      case DocumentNodeKind.adjustment:
        return Icons.tune;
      case DocumentNodeKind.componentInstance:
        return Icons.widgets_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              // Drag handle.
              dragHandle,
              // Kind icon.
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  _kindIcon,
                  size: 18,
                  color: node.visible ? Colors.white70 : Colors.white24,
                ),
              ),
              // Node name.
              Expanded(
                child: Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: node.visible ? Colors.white : Colors.white38,
                    fontSize: 13,
                    decoration: node.locked
                        ? TextDecoration.none
                        : null,
                  ),
                ),
              ),
              // Index badge.
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                  ),
                ),
              ),
              // Visibility toggle.
              IconButton(
                tooltip: node.visible ? 'Hide layer' : 'Show layer',
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onToggleVisibility,
                icon: Icon(
                  node.visible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: node.visible ? Colors.white54 : Colors.white24,
                ),
              ),
              // Lock toggle.
              IconButton(
                tooltip: node.locked ? 'Unlock layer' : 'Lock layer',
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onToggleLock,
                icon: Icon(
                  node.locked
                      ? Icons.lock_outline
                      : Icons.lock_open_outlined,
                  color: node.locked ? Colors.amber.shade300 : Colors.white38,
                ),
              ),
              // Delete.
              IconButton(
                tooltip: 'Delete layer',
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// A wrapper that provides the layer list as a titled panel suitable for
/// docking or displaying in a bottom sheet.
class LayerPanel extends StatelessWidget {
  const LayerPanel({
    required this.controller,
    this.onNodeSelected,
    super.key,
  });

  final StudioController controller;
  final ValueChanged<GgenId>? onNodeSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.layers_outlined, size: 18),
              const SizedBox(width: 8),
              Text(
                'Layers',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                '${controller.objectCount}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayerList(
            controller: controller,
            onNodeSelected: onNodeSelected,
          ),
        ),
      ],
    );
  }
}
