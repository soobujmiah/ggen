import 'package:flutter/material.dart';

import 'package:ggen_core/ggen_core.dart';

import '../controller/studio_controller.dart';

/// Layer list panel showing the first artboard's nodes in reverse z-order
/// with visibility toggle, lock toggle, selection sync and drag-to-reorder.
///
/// Leader nodes (groups) display their members indented directly below the
/// group row; the group row's chevron collapses/expands the members. All
/// mutations flow through the injected [StudioController]; the panel owns
/// no document state (only the trivially transient collapse set).
class LayerList extends StatefulWidget {
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
  State<LayerList> createState() => _LayerListState();
}

class _LayerListState extends State<LayerList> {
  /// Group ids whose members are currently collapsed (UI state only).
  final Set<String> _collapsed = <String>{};

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final nodes = widget.controller.project.artboards.isEmpty
            ? const <DocumentNode>[]
            : widget.controller.project.artboards.first.nodes;

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
        // rendered on top of the canvas). Group members are spliced directly
        // under their group row (also reversed) unless the group is
        // collapsed. The parallel index lists drive reordering and the
        // index badge.
        final reversed = nodes.reversed.toList(growable: false);
        final rows = <DocumentNode>[];
        final rowArtboardIndex = <int>[];
        final rowIsGroupMember = <bool>[];
        for (var topVisual = 0; topVisual < reversed.length; topVisual++) {
          final node = reversed[topVisual];
          rows.add(node);
          rowArtboardIndex.add(nodes.length - 1 - topVisual);
          rowIsGroupMember.add(false);
          final members = isGroupNode(node) ? groupChildIds(node) : null;
          if (members == null || _collapsed.contains(node.id.value)) continue;
          final memberSet = members.toSet();
          final memberNodes = <DocumentNode>[
            for (final n in nodes)
              if (memberSet.contains(n.id)) n,
          ];
          for (final member in memberNodes.reversed) {
            rows.add(member);
            rowArtboardIndex.add(nodes.indexWhere((n) => n.id == member.id));
            rowIsGroupMember.add(true);
          }
        }

        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: rows.length,
          onReorder: (oldVisualIndex, newVisualIndex) {
            // Group member rows carry no drag handle; only top-level rows
            // can reach the reorder callback.
            if (rowIsGroupMember[oldVisualIndex]) return;
            if (newVisualIndex > oldVisualIndex) newVisualIndex--;
            final fromArtboard = rowArtboardIndex[oldVisualIndex];
            final toArtboard = rowArtboardIndex[newVisualIndex];
            widget.controller.reorderNodes(fromArtboard, toArtboard);
          },
          itemBuilder: (context, visualIndex) {
            final node = rows[visualIndex];
            final isMember = rowIsGroupMember[visualIndex];
            final artboardIndex = rowArtboardIndex[visualIndex];
            final isSelected = widget.controller.selectedNodeIds.contains(
              node.id,
            );
            final isGroup = isGroupNode(node);
            final collapsed =
                isGroup && _collapsed.contains(node.id.value);
            return _LayerTile(
              key: ValueKey(node.id.value),
              node: node,
              index: artboardIndex,
              isSelected: isSelected,
              isGroupMember: isMember,
              memberCount: isGroup ? (groupChildIds(node)?.length ?? 0) : null,
              dragHandle: isMember
                  ? const SizedBox(width: 24)
                  : ReorderableDragStartListener(
                      index: visualIndex,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.drag_handle,
                          size: 20,
                          color: Colors.white38,
                        ),
                      ),
                    ),
              expandButton: isGroup
                  ? IconButton(
                      tooltip: collapsed ? 'Expand group' : 'Collapse group',
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          if (collapsed) {
                            _collapsed.remove(node.id.value);
                          } else {
                            _collapsed.add(node.id.value);
                          }
                        });
                      },
                      icon: Icon(
                        collapsed ? Icons.chevron_right : Icons.expand_more,
                        size: 18,
                        color: Colors.white54,
                      ),
                    )
                  : null,
              onTap: () => widget.onNodeSelected?.call(node.id),
              onToggleVisibility: () =>
                  widget.controller.toggleNodeVisibility(node.id),
              onToggleLock: () => widget.controller.toggleNodeLock(node.id),
              onDelete: () => widget.controller.deleteNode(node.id),
            );
          },
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
    required this.isGroupMember,
    required this.onTap,
    required this.onToggleVisibility,
    required this.onToggleLock,
    required this.onDelete,
    required this.dragHandle,
    this.expandButton,
    this.memberCount,
    super.key,
  });

  final DocumentNode node;
  final int index;
  final bool isSelected;

  /// Whether this row is a group member (rendered indented, no drag
  /// handle, no expand control).
  final bool isGroupMember;
  final VoidCallback onTap;
  final VoidCallback onToggleVisibility;
  final VoidCallback onToggleLock;
  final VoidCallback onDelete;
  final Widget dragHandle;

  /// Expand/collapse control for group rows; null for plain rows.
  final Widget? expandButton;

  /// Member count badge for group rows; null for plain rows.
  final int? memberCount;

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
        child: Padding(
          padding: EdgeInsets.only(left: isGroupMember ? 24 : 0),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                // Drag handle (or spacer for member rows).
                dragHandle,
                // Expand/collapse for groups.
                if (expandButton != null) expandButton!,
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
                      decoration: node.locked ? TextDecoration.none : null,
                    ),
                  ),
                ),
                // Member count badge for groups (group collapsed still
                // shows how many layers it contains).
                if (memberCount != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '$memberCount',
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
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
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
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
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
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
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
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
      ),
    );
  }
}

/// A wrapper that provides the layer list as a titled panel suitable for
/// docking or displaying in a bottom sheet. The header carries Group
/// selection / Ungroup actions that act on the current selection.
class LayerPanel extends StatelessWidget {
  const LayerPanel({
    required this.controller,
    this.onNodeSelected,
    this.onGroup,
    this.onUngroup,
    super.key,
  });

  final StudioController controller;
  final ValueChanged<GgenId>? onNodeSelected;

  /// Called after a successful Group selection action with the number of
  /// grouped nodes; the shell logs the diagnostics event.
  final ValueChanged<int>? onGroup;

  /// Called after a successful Ungroup action with the dissolved group id;
  /// the shell logs the diagnostics event.
  final ValueChanged<GgenId>? onUngroup;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selectedIds = controller.selectedNodeIds;
        final primary = controller.selectedNodeId;
        final artboard = controller.project.artboards.isEmpty
            ? null
            : controller.project.artboards.first;
        DocumentNode? primaryNode;
        if (primary != null && artboard != null) {
          final primaryIndex = artboard.nodes.indexWhere(
            (n) => n.id == primary,
          );
          if (primaryIndex >= 0) primaryNode = artboard.nodes[primaryIndex];
        }
        final primaryIsGroup =
            primaryNode != null && isGroupNode(primaryNode);
        final canGroup = selectedIds.length >= 2;
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
                  IconButton(
                    tooltip: 'Group selection',
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: canGroup
                        ? () {
                            final ok = controller.createGroup(selectedIds);
                            if (ok) onGroup?.call(selectedIds.length);
                          }
                        : null,
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                  IconButton(
                    tooltip: 'Ungroup',
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: primaryIsGroup
                        ? () {
                            final ok = controller.ungroup(primary!);
                            if (ok) onUngroup?.call(primary!);
                          }
                        : null,
                    icon: const Icon(Icons.folder_off_outlined),
                  ),
                  Text(
                    '${controller.objectCount}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
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
      },
    );
  }
}
