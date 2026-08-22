import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'package:ggen_core/ggen_core.dart';

import '../storage/memory_project_store.dart';
import '../storage/memory_recovery_journal.dart';
import '../storage/payload_journal.dart';

/// App-layer controller that owns the current document project through the
/// platform-neutral `ggen_core` contracts.
///
/// The controller is deliberately widget-free: every mutation flows through
/// the core revision history or a core tool session, so undo/redo, bounds and
/// serialization semantics are exactly the tested core semantics. The shell
/// only observes [project] and triggers these methods.
///
/// Persistence goes through the core [TransactionalProjectStore] and
/// [AutosaveRecoveryJournal] contracts; the default adapters are in-memory
/// until a platform storage decision is accepted.
class StudioController extends ChangeNotifier {
  StudioController({
    String projectName = 'Untitled project',
    int historyLimit = 500,
    TransactionalProjectStore? store,
    AutosaveRecoveryJournal? journal,
    int checkpointEveryTransactions = 16,
  }) : _checkpointEveryTransactions = checkpointEveryTransactions,
       _store = store ?? MemoryProjectStore(),
       _journal =
           journal ??
           MemoryRecoveryJournal(
             AutosavePolicy(
               maxJournalEntries: 200,
               maxJournalBytes: 1 << 20,
               checkpointEveryTransactions: 16,
             ),
           ),
       _history = ProjectHistory.start(
         _newProject(projectName),
         maxEntries: historyLimit,
       );

  static const double defaultArtboardWidth = 1200;
  static const double defaultArtboardHeight = 800;

  /// Provisional checkpoint cadence until measured limits are approved.
  final int _checkpointEveryTransactions;

  final TransactionalProjectStore _store;
  final AutosaveRecoveryJournal _journal;

  ProjectHistory _history;
  String _lastSerialized = '';
  int _lastSerializedBytes = 0;
  int _journalSequence = 0;
  int _transactionsSinceCheckpoint = 0;
  Future<void> _journalTail = Future<void>.value();
  int _shapeCount = 0;
  int _textCount = 0;
  int _groupCount = 0;
  ProjectStoreReceipt? _lastReceipt;

  DocumentProject get project => _history.current;
  int get revision => project.revision;
  int get maxHistoryEntries => _history.maxEntries;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  /// Last canonical serialization, kept for diagnostics and tests.
  String get lastSerialized => _lastSerialized;
  int get lastSerializedBytes => _lastSerializedBytes;

  /// Receipt of the last committed store write, or null before the first
  /// successful [save].
  ProjectStoreReceipt? get lastReceipt => _lastReceipt;

  /// Stable storage key for the current project. Derived from the project id
  /// so save and restore address the same slot.
  ProjectStorageKey get storageKey => ProjectStorageKey(project.id.value);

  /// Total node count across artboards, shown in the shell status bar.
  int get objectCount => project.artboards.fold<int>(
    0,
    (sum, artboard) => sum + artboard.nodes.length,
  );

  // Selection is transient workspace state (never part of history). The
  // ordered list keeps the most recently selected node last; that node is
  // the *primary* selection (inspector target, resize handles).
  final List<GgenId> _orderedSelection = <GgenId>[];

  /// All currently selected node IDs, most recent last (primary last).
  List<GgenId> get selectedNodeIds => List<GgenId>.unmodifiable(_orderedSelection);

  /// Whether anything is selected.
  bool get hasSelection => _orderedSelection.isNotEmpty;

  /// Currently selected node ID (the primary, most recently selected node),
  /// or null when nothing is selected.
  GgenId? get selectedNodeId =>
      _orderedSelection.isEmpty ? null : _orderedSelection.last;

  /// Selects or deselects a node. Does not create a history transaction;
  /// selection is transient workspace state.
  ///
  /// When [toggle] is true the node's membership is flipped (add/remove)
  /// without touching the rest of the selection; a null [nodeId] then does
  /// nothing. When [toggle] is false the selection is replaced by exactly
  /// [nodeId] (null clears everything).
  void selectNode(GgenId? nodeId, {bool toggle = false}) {
    if (toggle) {
      if (nodeId == null) return;
      if (!_orderedSelection.remove(nodeId)) {
        _orderedSelection.add(nodeId);
      }
      notifyListeners();
      return;
    }
    if (nodeId != null && _orderedSelection.length == 1 &&
        _orderedSelection.first == nodeId) {
      return; // Already the sole selection.
    }
    _orderedSelection
      ..clear()
      ..addAll(nodeId == null ? const <GgenId>[] : <GgenId>[nodeId]);
    notifyListeners();
  }

  /// Clears the current node selection.
  void deselectNode() => selectNode(null);

  /// Toggles one node's membership in the multi-selection.
  void toggleNodeSelection(GgenId nodeId) => selectNode(nodeId, toggle: true);

  /// Moves a node by the given artboard-space delta through one undoable
  /// tool session. The node's `x` and `y` extensions are updated; the
  /// resulting position is clamped into the artboard bounds.
  ///
  /// Returns false when no node with [nodeId] exists in the first artboard.
  bool moveNode(GgenId nodeId, double dx, double dy) =>
      moveNodes(<GgenId>[nodeId], dx, dy);

  /// Moves every node in [nodeIds] that exists in the first artboard by the
  /// same artboard-space delta through ONE undoable tool session, so group
  /// move/undo/redo is a single history step. Positions clamp to artboard
  /// bounds; nodes without numeric `x`/`y` extensions are skipped.
  ///
  /// Returns false when no node was moved (missing nodes or zero net delta).
  bool moveNodes(List<GgenId> nodeIds, double dx, double dy) {
    if (nodeIds.isEmpty) return false;
    if (!dx.isFinite || !dy.isFinite) {
      throw ArgumentError('Move delta must be finite.');
    }
    final artboards = project.artboards;
    if (artboards.isEmpty) return false;
    final artboard = artboards.first;
    // Moving a group moves its members too (they stay in the artboard
    // list, so the same delta applies to each child node).
    final wanted = _effectiveNodeSet(nodeIds, artboard.nodes);

    var movedAny = false;
    final nextNodes = <DocumentNode>[];
    for (final node in artboard.nodes) {
      if (!wanted.contains(node.id)) {
        nextNodes.add(node);
        continue;
      }
      final currentX = node.extensions['x'];
      final currentY = node.extensions['y'];
      if (currentX is! num || currentY is! num) {
        nextNodes.add(node);
        continue;
      }
      final newX = (currentX.toDouble() + dx).clamp(0, artboard.width).toDouble();
      final newY =
          (currentY.toDouble() + dy).clamp(0, artboard.height).toDouble();
      if (newX == currentX.toDouble() && newY == currentY.toDouble()) {
        nextNodes.add(node);
        continue;
      }
      movedAny = true;
      nextNodes.add(
        DocumentNode(
          id: node.id,
          kind: node.kind,
          name: node.name,
          visible: node.visible,
          locked: node.locked,
          opacity: node.opacity,
          extensions: <String, Object?>{
            ...node.extensions,
            'x': newX,
            'y': newY,
          },
        ),
      );
    }
    if (!movedAny) return false;

    final nextArtboards = <Artboard>[
      Artboard(
        id: artboard.id,
        name: artboard.name,
        width: artboard.width,
        height: artboard.height,
        nodes: nextNodes,
      ),
      ...artboards.skip(1),
    ];
    final session = beginSession();
    session.updatePreview(project.copyWith(artboards: nextArtboards));
    commitSession(
      session,
      nodeIds.length == 1
          ? 'Move ${nodeIds.first.value}'
          : 'Move ${nodeIds.length} nodes',
    );
    return true;
  }

  // ── Layer operations ──────────────────────────────────────────────────

  /// Toggles the visibility of [nodeId] in the first artboard through one
  /// undoable tool session. Returns false when the node is not found.
  ///
  /// When [nodeId] is a group, the group and every member node flip
  /// together in the SAME undoable step (one revision).
  bool toggleNodeVisibility(GgenId nodeId) {
    final artboards = project.artboards;
    if (artboards.isEmpty) return false;
    final artboard = artboards.first;
    final nodeIndex = artboard.nodes.indexWhere((n) => n.id == nodeId);
    if (nodeIndex < 0) return false;
    final node = artboard.nodes[nodeIndex];
    if (!isGroupNode(node)) {
      return _replaceNode(
        nodeId,
        (n) => DocumentNode(
          id: n.id,
          kind: n.kind,
          name: n.name,
          visible: !n.visible,
          locked: n.locked,
          opacity: n.opacity,
          extensions: n.extensions,
        ),
        'Toggle visibility of ',
      );
    }
    final effective = _effectiveNodeSet(<GgenId>[nodeId], artboard.nodes);
    final nextVisible = !node.visible;
    final nextNodes = <DocumentNode>[
      for (final n in artboard.nodes)
        effective.contains(n.id)
            ? DocumentNode(
                id: n.id,
                kind: n.kind,
                name: n.name,
                visible: nextVisible,
                locked: n.locked,
                opacity: n.opacity,
                extensions: n.extensions,
              )
            : n,
    ];
    return _commitNodeList(
      artboard,
      nextNodes,
      'Toggle visibility of ${node.name}',
    );
  }

  /// Toggles the lock state of [nodeId] in the first artboard through one
  /// undoable tool session. Returns false when the node is not found.
  ///
  /// When [nodeId] is a group, the group and every member node flip
  /// together in the SAME undoable step (one revision).
  bool toggleNodeLock(GgenId nodeId) {
    final artboards = project.artboards;
    if (artboards.isEmpty) return false;
    final artboard = artboards.first;
    final nodeIndex = artboard.nodes.indexWhere((n) => n.id == nodeId);
    if (nodeIndex < 0) return false;
    final node = artboard.nodes[nodeIndex];
    if (!isGroupNode(node)) {
      return _replaceNode(
        nodeId,
        (n) => DocumentNode(
          id: n.id,
          kind: n.kind,
          name: n.name,
          visible: n.visible,
          locked: !n.locked,
          opacity: n.opacity,
          extensions: n.extensions,
        ),
        'Toggle lock of ',
      );
    }
    final effective = _effectiveNodeSet(<GgenId>[nodeId], artboard.nodes);
    final nextLocked = !node.locked;
    final nextNodes = <DocumentNode>[
      for (final n in artboard.nodes)
        effective.contains(n.id)
            ? DocumentNode(
                id: n.id,
                kind: n.kind,
                name: n.name,
                visible: n.visible,
                locked: nextLocked,
                opacity: n.opacity,
                extensions: n.extensions,
              )
            : n,
    ];
    return _commitNodeList(
      artboard,
      nextNodes,
      'Toggle lock of ${node.name}',
    );
  }

  /// Reorders nodes in the first artboard: moves the node at [fromIndex] to
  /// [toIndex] through one undoable tool session. Indices are in artboard
  /// node order (first = bottom of z-stack). Returns false when the indices
  /// are out of range or identical.
  bool reorderNodes(int fromIndex, int toIndex) {
    final artboards = project.artboards;
    if (artboards.isEmpty) return false;
    final artboard = artboards.first;
    final count = artboard.nodes.length;
    if (fromIndex < 0 || fromIndex >= count) return false;
    if (toIndex < 0 || toIndex >= count) return false;
    if (fromIndex == toIndex) return false;

    final nodes = List<DocumentNode>.from(artboard.nodes);
    final moved = nodes.removeAt(fromIndex);
    nodes.insert(toIndex, moved);

    final nextArtboards = <Artboard>[
      Artboard(
        id: artboard.id,
        name: artboard.name,
        width: artboard.width,
        height: artboard.height,
        nodes: nodes,
      ),
      ...artboards.skip(1),
    ];
    final session = beginSession();
    session.updatePreview(project.copyWith(artboards: nextArtboards));
    commitSession(session, 'Reorder ${moved.name}');
    return true;
  }

  /// Resizes and repositions a shape node through one undoable tool session.
  /// The new bounds replace the node's `x`, `y`, `w`, `h` extensions.
  /// Returns false when the node is not found or has no shape geometry.
  bool resizeNode(
    GgenId nodeId, {
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    if (!x.isFinite || !y.isFinite || !width.isFinite || !height.isFinite) {
      throw ArgumentError('Resize geometry must be finite.');
    }
    if (width < 1 || height < 1) {
      throw ArgumentError('Resize dimensions must be positive.');
    }
    final artboards = project.artboards;
    if (artboards.isEmpty) return false;
    final artboard = artboards.first;
    final nodeIndex = artboard.nodes.indexWhere((n) => n.id == nodeId);
    if (nodeIndex < 0) return false;
    final node = artboard.nodes[nodeIndex];

    // Only shape nodes with x/y/w/h geometry can be resized.
    if (node.extensions['w'] is! num || node.extensions['h'] is! num) {
      return false;
    }

    final resizedNode = DocumentNode(
      id: node.id,
      kind: node.kind,
      name: node.name,
      visible: node.visible,
      locked: node.locked,
      opacity: node.opacity,
      extensions: <String, Object?>{
        ...node.extensions,
        'x': x,
        'y': y,
        'w': width,
        'h': height,
      },
    );
    final nextNodes = <DocumentNode>[
      ...artboard.nodes.sublist(0, nodeIndex),
      resizedNode,
      ...artboard.nodes.sublist(nodeIndex + 1),
    ];
    final nextArtboards = <Artboard>[
      Artboard(
        id: artboard.id,
        name: artboard.name,
        width: artboard.width,
        height: artboard.height,
        nodes: nextNodes,
      ),
      ...artboards.skip(1),
    ];
    final session = beginSession();
    session.updatePreview(project.copyWith(artboards: nextArtboards));
    commitSession(session, 'Resize ${node.name}');
    return true;
  }

  /// Deletes [nodeId] from the first artboard through one undoable tool
  /// session. Clears the node from the selection when it was selected.
  /// Returns false when the node is not found.
  bool deleteNode(GgenId nodeId) => deleteNodes(<GgenId>[nodeId]);

  /// Deletes every node in [nodeIds] that exists in the first artboard
  /// through ONE undoable tool session (group delete is a single history
  /// step). Any deleted node is removed from the multi-selection; the
  /// remaining selection keeps its order and primary node.
  /// Returns false when no node was deleted.
  bool deleteNodes(List<GgenId> nodeIds) {
    if (nodeIds.isEmpty) return false;
    final artboards = project.artboards;
    if (artboards.isEmpty) return false;
    final artboard = artboards.first;
    // Deleting a group deletes its members too; deleting a member directly
    // removes it from its group's membership (a group that loses every
    // member dissolves).
    final wanted = _effectiveNodeSet(nodeIds, artboard.nodes);

    var changed = false;
    final nextNodes = <DocumentNode>[];
    for (final node in artboard.nodes) {
      if (wanted.contains(node.id)) {
        changed = true;
        continue;
      }
      if (isGroupNode(node)) {
        final updated = _groupWithPrunedMembers(node, wanted);
        if (updated == null) {
          changed = true; // Every member was deleted: the group dissolves.
          continue;
        }
        if (!identical(updated, node)) changed = true;
        nextNodes.add(updated);
      } else {
        nextNodes.add(node);
      }
    }
    if (!changed) return false;

    final nextArtboards = <Artboard>[
      Artboard(
        id: artboard.id,
        name: artboard.name,
        width: artboard.width,
        height: artboard.height,
        nodes: nextNodes,
      ),
      ...artboards.skip(1),
    ];
    final session = beginSession();
    session.updatePreview(project.copyWith(artboards: nextArtboards));
    commitSession(
      session,
      nodeIds.length == 1
          ? 'Delete ${nodeIds.first.value}'
          : 'Delete ${nodeIds.length} nodes',
    );
    final selectionBefore = _orderedSelection.length;
    _orderedSelection.removeWhere(wanted.contains);
    if (_orderedSelection.length != selectionBefore) {
      notifyListeners();
    }
    return true;
  }

  // ── Layer groups ──────────────────────────────────────────────────────

  /// Creates a group containing [nodeIds] as members through ONE undoable
  /// tool session. Members stay first-class nodes (geometry, z-order and
  /// canvas rendering are untouched); the group node is appended at the top
  /// of the artboard and carries the member ids in its `children`
  /// extension. Grouping is single-level: members cannot be groups or
  /// members of an existing group, and every id must exist in the first
  /// artboard.
  ///
  /// Returns false when the inputs are not groupable; on success the
  /// selection becomes exactly the new group.
  bool createGroup(List<GgenId> nodeIds, {String? name}) {
    if (nodeIds.length < 2) return false;
    final artboards = project.artboards;
    if (artboards.isEmpty) return false;
    final artboard = artboards.first;
    final nodes = artboard.nodes;
    final wanted = nodeIds.toSet();
    if (wanted.length != nodeIds.length) return false; // Duplicate ids.
    for (final id in wanted) {
      if (nodes.every((n) => n.id != id)) return false; // Unknown node.
    }
    for (final node in nodes) {
      if (wanted.contains(node.id)) {
        if (isGroupNode(node)) return false; // No nested groups.
      } else {
        final members = groupChildIds(node);
        if (members != null && members.any(wanted.contains)) {
          return false; // Already a member of another group.
        }
      }
    }

    _groupCount++;
    final trimmedName = name?.trim();
    final groupName = (trimmedName == null || trimmedName.isEmpty)
        ? 'Group $_groupCount'
        : trimmedName;
    final childValues = <String>[
      for (final node in nodes)
        if (wanted.contains(node.id)) node.id.value,
    ];
    final group = DocumentNode(
      id: GgenId('group-$_groupCount'),
      kind: DocumentNodeKind.group,
      name: groupName,
      extensions: <String, Object?>{'children': childValues},
    );
    final nextNodes = <DocumentNode>[...nodes, group];
    _commitNodeList(artboard, nextNodes, 'Group ${nodeIds.length} nodes');
    _orderedSelection
      ..clear()
      ..add(group.id);
    notifyListeners();
    return true;
  }

  /// Removes the group node [groupId]; its members stay in the artboard at
  /// their current positions and z-order. One undoable step; the selection
  /// becomes the members (ordered as in the group).
  ///
  /// Returns false when [groupId] is missing or is not a group.
  bool ungroup(GgenId groupId) {
    final artboards = project.artboards;
    if (artboards.isEmpty) return false;
    final artboard = artboards.first;
    final index = artboard.nodes.indexWhere((n) => n.id == groupId);
    if (index < 0) return false;
    final group = artboard.nodes[index];
    final members = groupChildIds(group);
    if (members == null) return false;

    final nextNodes = <DocumentNode>[...artboard.nodes]..removeAt(index);
    final remaining = <GgenId>[
      for (final id in members)
        if (nextNodes.any((n) => n.id == id)) id,
    ];
    _commitNodeList(artboard, nextNodes, 'Ungroup ${group.name}');
    _orderedSelection
      ..clear()
      ..addAll(remaining);
    notifyListeners();
    return true;
  }

  /// Expands [ids] with the members of every group in the set, so
  /// operations address the group and its members together.
  Set<GgenId> _effectiveNodeSet(List<GgenId> ids, List<DocumentNode> nodes) {
    final result = <GgenId>{...ids};
    for (final node in nodes) {
      if (result.contains(node.id)) {
        final members = groupChildIds(node);
        if (members != null) result.addAll(members);
      }
    }
    return result;
  }

  /// Returns [group] unchanged when no member is in [removed]; an updated
  /// copy with those members pruned when some are; or null when every
  /// member was removed (the group dissolves and is dropped).
  DocumentNode? _groupWithPrunedMembers(
    DocumentNode group,
    Set<GgenId> removed,
  ) {
    final members = groupChildIds(group);
    if (members == null) return group;
    final remaining = <String>[
      for (final id in members)
        if (!removed.contains(id)) id.value,
    ];
    if (remaining.length == members.length) return group;
    if (remaining.isEmpty) return null;
    return DocumentNode(
      id: group.id,
      kind: group.kind,
      name: group.name,
      visible: group.visible,
      locked: group.locked,
      opacity: group.opacity,
      extensions: <String, Object?>{
        ...group.extensions,
        'children': remaining,
      },
    );
  }

  /// Commits [nextNodes] as the first artboard's node list through one
  /// undoable tool session. Returns true when committed (the callers have
  /// already validated that the change is meaningful).
  bool _commitNodeList(
    Artboard artboard,
    List<DocumentNode> nextNodes,
    String description,
  ) {
    final nextArtboards = <Artboard>[
      Artboard(
        id: artboard.id,
        name: artboard.name,
        width: artboard.width,
        height: artboard.height,
        nodes: nextNodes,
      ),
      ...project.artboards.skip(1),
    ];
    final session = beginSession();
    session.updatePreview(project.copyWith(artboards: nextArtboards));
    commitSession(session, description);
    return true;
  }

  /// Replaces a single node in the first artboard through one undoable tool
  /// session. The [transform] receives the current node and returns the
  /// replacement. Returns false when the node is not found.
  bool _replaceNode(
    GgenId nodeId,
    DocumentNode Function(DocumentNode) transform,
    String descriptionPrefix,
  ) {
    final artboards = project.artboards;
    if (artboards.isEmpty) return false;
    final artboard = artboards.first;
    final nodeIndex = artboard.nodes.indexWhere((n) => n.id == nodeId);
    if (nodeIndex < 0) return false;
    final node = artboard.nodes[nodeIndex];

    final replaced = transform(node);
    final nextNodes = <DocumentNode>[
      ...artboard.nodes.sublist(0, nodeIndex),
      replaced,
      ...artboard.nodes.sublist(nodeIndex + 1),
    ];
    final nextArtboards = <Artboard>[
      Artboard(
        id: artboard.id,
        name: artboard.name,
        width: artboard.width,
        height: artboard.height,
        nodes: nextNodes,
      ),
      ...artboards.skip(1),
    ];
    final session = beginSession();
    session.updatePreview(project.copyWith(artboards: nextArtboards));
    commitSession(session, '$descriptionPrefix${node.name}');
    return true;
  }

  /// Replaces the whole project (New Project). Not undoable by design: the
  /// previous project leaves the workspace entirely.
  void newProject(String name) {
    _history = ProjectHistory.start(
      _newProject(name),
      maxEntries: maxHistoryEntries,
    );
    _shapeCount = 0;
    _textCount = 0;
    _groupCount = 0;
    _orderedSelection.clear();
    _clearSerialized();
    _lastReceipt = null;
    notifyListeners();
  }

  /// Opens a reversible tool session against the current project snapshot.
  ProjectToolSession beginSession() => ProjectToolSession(project);

  /// Palette for the Draw tool's initial shapes (ARGB).
  static const List<int> shapePalette = <int>[
    0xFF4E6BFF,
    0xFFFF6B6B,
    0xFFFFD93D,
    0xFF6BCB77,
    0xFFB983FF,
    0xFFFF9F68,
    0xFF4ECDC4,
    0xFFE056FD,
  ];

  /// Draw-tool action: adds one shape node to the first artboard through a
  /// reversible tool session, so it is exactly one undoable transaction.
  ///
  /// The tap point is clamped into the artboard; node geometry lives in the
  /// node's extensions (`x`, `y`, `w`, `h`, `color`) until a later schema
  /// introduces typed studio payloads.
  void addShapeNode(double artboardX, double artboardY, {double size = 64}) {
    if (!artboardX.isFinite ||
        !artboardY.isFinite ||
        !size.isFinite ||
        size <= 0) {
      throw ArgumentError('Shape geometry must be finite and positive.');
    }
    final artboards = project.artboards;
    if (artboards.isEmpty) return;
    final artboard = artboards.first;
    final effectiveSize = size.clamp(1, artboard.width).toDouble();
    final clampedX = artboardX
        .clamp(0, artboard.width - effectiveSize)
        .toDouble();
    final clampedY = artboardY
        .clamp(0, artboard.height - effectiveSize)
        .toDouble();

    _shapeCount++;
    final node = DocumentNode(
      id: GgenId('node-$_shapeCount'),
      kind: DocumentNodeKind.shape,
      name: 'Shape $_shapeCount',
      extensions: <String, Object?>{
        'x': clampedX,
        'y': clampedY,
        'w': effectiveSize,
        'h': effectiveSize,
        'color': shapePalette[_shapeCount % shapePalette.length],
      },
    );
    final nextArtboards = <Artboard>[
      Artboard(
        id: artboard.id,
        name: artboard.name,
        width: artboard.width,
        height: artboard.height,
        nodes: <DocumentNode>[...artboard.nodes, node],
      ),
      ...artboards.skip(1),
    ];
    final session = beginSession();
    session.updatePreview(project.copyWith(artboards: nextArtboards));
    commitSession(session, 'Add shape $_shapeCount');
  }

  /// Text-tool action: adds one text frame to the first artboard through a
  /// reversible tool session. Geometry and text live in the node's
  /// extensions (`x`, `y`, `size`, `text`, `color`) until a later schema
  /// introduces typed studio payloads.
  void addTextNode(
    double artboardX,
    double artboardY,
    String text, {
    double size = 24,
  }) {
    if (!artboardX.isFinite ||
        !artboardY.isFinite ||
        !size.isFinite ||
        size <= 0) {
      throw ArgumentError('Text geometry must be finite and positive.');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 256) {
      throw ArgumentError('Text must contain 1..256 characters.');
    }
    final artboards = project.artboards;
    if (artboards.isEmpty) return;
    final artboard = artboards.first;
    final clampedX = artboardX.clamp(0, artboard.width).toDouble();
    final clampedY = artboardY.clamp(0, artboard.height).toDouble();

    _textCount++;
    final node = DocumentNode(
      id: GgenId('text-$_textCount'),
      kind: DocumentNodeKind.textFrame,
      name: 'Text $_textCount',
      extensions: <String, Object?>{
        'x': clampedX,
        'y': clampedY,
        'size': size,
        'text': trimmed,
        'color': 0xFF222222,
      },
    );
    final nextArtboards = <Artboard>[
      Artboard(
        id: artboard.id,
        name: artboard.name,
        width: artboard.width,
        height: artboard.height,
        nodes: <DocumentNode>[...artboard.nodes, node],
      ),
      ...artboards.skip(1),
    ];
    final session = beginSession();
    session.updatePreview(project.copyWith(artboards: nextArtboards));
    commitSession(session, 'Add text $_textCount');
  }

  /// Commits a session preview as exactly one undoable transaction and
  /// appends a bounded recovery-journal transaction record.
  void commitSession(ProjectToolSession session, String description) {
    final transaction = session.commit(description);
    _history = _history.commit(transaction);
    _journalRecord(transaction.before.revision, transaction.after.revision);
    _clearSerialized();
    notifyListeners();
  }

  /// Cancels a session and restores the exact input project.
  void cancelSession(ProjectToolSession session) {
    session.cancel();
    notifyListeners();
  }

  /// Undoes one transaction and records a journal state marker so replay can
  /// reconstruct the resulting revision without a forward delta.
  void undo() {
    _history = _history.undo();
    _journalRecord(revision, revision);
    _clearSerialized();
    notifyListeners();
  }

  /// Redoes one transaction and records a forward journal delta.
  void redo() {
    final revisionBefore = revision;
    _history = _history.redo();
    _journalRecord(revisionBefore, revision);
    _clearSerialized();
    notifyListeners();
  }

  /// Persists the current project through a transactional store write.
  ///
  /// Stages the canonical envelope, commits it atomically and returns the
  /// content-addressed receipt. A checkpoint record is appended to the
  /// recovery journal at the provisional cadence. Throws [StateError] when
  /// the store rejects a stale or non-advancing write.
  Future<ProjectStoreReceipt> save() async {
    final key = storageKey;
    final stored = await _store.read(key);
    final transaction = await _store.begin(
      key,
      expectedRevision: stored?.project.revision ?? -1,
    );
    final encoded = _encodeProject(project);
    await transaction.stage(
      ProjectEnvelope(
        project: project,
        schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
      ),
    );
    final receipt = await transaction.commit();
    _lastReceipt = receipt;
    if (_transactionsSinceCheckpoint >= _checkpointEveryTransactions) {
      await _journalCheckpoint(encoded);
    }
    notifyListeners();
    return receipt;
  }

  /// Restores the project previously committed under [key].
  ///
  /// Returns false when the store has no committed project for the key; the
  /// current workspace is left untouched in that case.
  Future<bool> restore(ProjectStorageKey key) async {
    final envelope = await _store.read(key);
    if (envelope == null) return false;
    _history = ProjectHistory.start(
      envelope.project,
      maxEntries: maxHistoryEntries,
    );
    _clearSerialized();
    notifyListeners();
    return true;
  }

  /// Serializes the current envelope with the canonical bounded codec.
  ///
  /// Persistence to platform storage is a later milestone (the core storage
  /// contracts already exist); this keeps the canonical bytes available for
  /// diagnostics and tests.
  String serialize() {
    final encoded = _encodeProject(project);
    _lastSerialized = encoded;
    _lastSerializedBytes = utf8.encode(encoded).length;
    return encoded;
  }

  String _encodeProject(DocumentProject project) {
    final codec = ProjectCodec(limits: ProjectCodecLimits.conservative());
    return codec.encode(
      ProjectEnvelope(
        project: project,
        schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
      ),
    );
  }

  /// Appends a recovery-journal transaction record for a history transition.
  ///
  /// Forward transitions (commit, redo) record a delta with base < target.
  /// Non-forward transitions (undo) record a state marker with base == target
  /// so replay can reconstruct the resulting revision directly.
  void _journalRecord(int baseRevision, int targetRevision) {
    final encoded = _encodeProject(project);
    final record = RecoveryJournalRecord(
      id: GgenId('txn-$_journalSequence'),
      projectId: project.id,
      kind: RecoveryRecordKind.transaction,
      sequence: _journalSequence,
      baseRevision: baseRevision,
      targetRevision: targetRevision,
      payloadSha256: _sha256Hex(encoded),
      payloadBytes: utf8.encode(encoded).length,
    );
    _journalSequence++;
    // Append then store the payload in order, so file-backed journals never
    // see a payload before the record's journal exists. The append starts
    // synchronously (in-memory journals update their records immediately);
    // the chain exists only so flushJournal can await full quiescence.
    final journalFuture = _appendAndStorePayload(record, encoded);
    _journalTail = _journalTail.then((_) => journalFuture);
    _transactionsSinceCheckpoint++;
  }

  Future<void> _journalCheckpoint(String encoded) async {
    final record = RecoveryJournalRecord(
      id: GgenId('cp-$_journalSequence'),
      projectId: project.id,
      kind: RecoveryRecordKind.checkpoint,
      sequence: _journalSequence,
      baseRevision: project.revision,
      targetRevision: project.revision,
      payloadSha256: _sha256Hex(encoded),
      payloadBytes: utf8.encode(encoded).length,
    );
    _journalSequence++;
    await _appendAndStorePayload(record, encoded);
    _transactionsSinceCheckpoint = 0;
  }

  Future<void> _appendAndStorePayload(
    RecoveryJournalRecord record,
    String encoded,
  ) async {
    await _journal.append(record);
    if (_journal case PayloadJournal journal) {
      journal.storePayload(record.projectId, record.id, encoded);
    }
  }

  /// Waits for all chained journal appends and payload stores to complete.
  /// Tests and save paths use this to observe a quiescent journal.
  Future<void> flushJournal() async {
    await _journalTail;
  }

  static String _sha256Hex(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static DocumentProject _newProject(String name) => DocumentProject(
    id: GgenId('project-${DateTime.now().microsecondsSinceEpoch}'),
    name: name,
    artboards: <Artboard>[
      Artboard(
        id: GgenId('artboard-1'),
        name: 'Artboard 1',
        width: defaultArtboardWidth,
        height: defaultArtboardHeight,
      ),
    ],
  );

  void _clearSerialized() {
    _lastSerialized = '';
    _lastSerializedBytes = 0;
  }
}

/// Whether [node] is a group node (an organizational container whose
/// members stay first-class nodes in the artboard).
bool isGroupNode(DocumentNode node) => node.kind == DocumentNodeKind.group;

/// Returns the member ids of a group node in artboard (z-)order, or null
/// when [node] is not a group or its `children` payload is malformed.
/// Presentation code must treat null as "not a valid group" (fail closed);
/// core construction validates the payload, so null here only appears for
/// data that predates the group milestone or external sources.
List<GgenId>? groupChildIds(DocumentNode node) {
  if (!isGroupNode(node)) return null;
  final raw = node.extensions['children'];
  if (raw is! List || raw.isEmpty) return null;
  final ids = <GgenId>[];
  for (final entry in raw) {
    if (entry is! String) return null;
    try {
      ids.add(GgenId(entry));
    } on ArgumentError {
      return null;
    }
  }
  if (ids.toSet().length != ids.length) return null;
  return ids;
}
