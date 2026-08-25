import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Every action that can be placed on the canvas as a persistent control,
/// in normal or fullscreen (immersive) mode.
///
/// Single source of truth for control identity, order, labels and icons so
/// pinning, cluster placement and iconography cannot drift between surfaces.
enum CanvasControl {
  undo('Undo', Icons.undo),
  redo('Redo', Icons.redo),
  zoomIn('Zoom in', Icons.add),
  zoomOut('Zoom out', Icons.remove),
  zoomFit('Fit to screen', Icons.fit_screen_outlined),
  grid('Grid', Icons.grid_4x4),
  layers('Layers', Icons.layers_outlined),
  multiSelect('Multi-select', Icons.done_all_outlined),
  columns('Columns', Icons.view_column_outlined),
  newProject('New project', Icons.note_add_outlined),
  openProject('Open project', Icons.folder_open_outlined),
  save('Save project', Icons.save_outlined),
  diagnostics('Diagnostics export', Icons.bug_report_outlined),
  settings('Settings', Icons.tune),
  immersive('Immersive canvas', Icons.fullscreen),
  dockInspector('Dock inspector', Icons.vertical_split_outlined);

  const CanvasControl(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Rendering constants shared with [CanvasControlCluster] in
/// `workspace_bars.dart`, so the pure layout math below and the real
/// rendered cluster can never disagree about how much space a cluster of N
/// controls occupies. Buttons are fixed 40×40, gaps 2px, padding 4px
/// horizontal / 2px vertical (see `ToolButton`).
const double kControlButtonExtent = 40;
const double kControlButtonGap = 2;
const double kClusterHorizontalInset = 8; // 4 + 4
const double kClusterVerticalInset = 4; // 2 + 2

/// Exact rendered size of a fullscreen control cluster holding
/// [controlCount] controls. Pure math, unit tested; the renderer uses the
/// same constants so hit-testing and clamping stay exact.
Size estimatedClusterSize(int controlCount) {
  final n = math.max(0, controlCount);
  final width = kClusterHorizontalInset +
      n * kControlButtonExtent +
      (n == 0 ? 0 : (n - 1) * kControlButtonGap);
  const height = kClusterVerticalInset + kControlButtonExtent;
  return Size(width, height);
}

/// One free-floating fullscreen control cluster.
///
/// [position] is the cluster's top-left anchor in NORMALIZED space:
/// x = 0 → flush left, 1 → as far right as the cluster still fits fully
/// on screen; y = 0 → flush top, 1 → as far down as it still fits. Storing
/// normalized coordinates makes persisted placements robust across device
/// sizes and orientations (a cluster anchored at (1, 1) stays in the
/// bottom-right corner on any screen).
class FullscreenControlCluster {
  const FullscreenControlCluster({
    required this.id,
    required this.controls,
    this.position = const Offset(0.5, 0.5),
  });

  /// Stable cluster identity. Unique within a resolved layout.
  final String id;

  /// Controls rendered together, in order.
  final List<CanvasControl> controls;

  /// Normalized top-left anchor, x/y each clamped to 0..1.
  final Offset position;
}

/// Device/workstation class used to select the workspace layout.
///
/// Replaces the old single `width < 700` breakpoint so landscape phones are
/// no longer misclassified as "wide desktop":
///
/// - [wide]: width >= 700 AND height >= 600 — tablets, large portrait
///   phones, desktop. Left tool rail + dockable inspector + status bar.
/// - [compactLandscape]: not wide and width > height — landscape phones.
///   One compact landscape bar, maximum usable canvas.
/// - [compactPortrait]: otherwise — portrait phones. Canonical mobile shell
///   (left rail + contextual action bar).
enum WorkspaceClass { compactPortrait, compactLandscape, wide }

/// Deterministic device-class selection (pure, unit tested).
WorkspaceClass classifyWorkspace(double width, double height) {
  if (width >= 700 && height >= 600) return WorkspaceClass.wide;
  if (width > height) return WorkspaceClass.compactLandscape;
  return WorkspaceClass.compactPortrait;
}

/// User-defined fullscreen control placement: an ordered list of free-form
/// clusters.
///
/// Cluster list order is the render (z-) order; the LAST cluster paints on
/// top and receives gestures first when clusters overlap. Overlapping
/// clusters are always all rendered — placement is free-form and overlap is
/// allowed; a cluster is never hidden or moved merely because another
/// cluster occupies the same spot.
///
/// Normalized by [resolve] so every surface renders the same deterministic
/// layout: duplicate cluster ids merged, controls deduped (first cluster
/// wins), per-cluster capacity enforced, empty clusters dropped, and the
/// [CanvasControl.immersive] exit control always guaranteed present.
class CanvasControlLayout {
  CanvasControlLayout(List<FullscreenControlCluster> clusters)
      : _clusters = List<FullscreenControlCluster>.unmodifiable(clusters);

  final List<FullscreenControlCluster> _clusters;

  List<FullscreenControlCluster> get clusters => _clusters;

  /// Hard deterministic per-cluster capacity. Beyond this the customization
  /// sheet rejects placements; clusters scroll horizontally if they hold
  /// many controls, but keeping them small keeps them usable.
  static const int maxControlsPerCluster = 6;

  /// Sensible first-run layout, orientation-aware.
  ///
  /// PORTRAIT: project actions top-right, history + zoom bottom-right,
  /// context tools bottom-left (anchored at normalized corner positions so
  /// the layout lands in the corners on any screen).
  ///
  /// LANDSCAPE: vertical space is scarce, so the defaults place ONE primary
  /// tool/navigation cluster on the LEFT side and ONE action cluster on the
  /// RIGHT side (both vertically centered in the available space) — the
  /// center of the screen remains maximum canvas.
  factory CanvasControlLayout.defaults({bool landscape = false}) =>
      CanvasControlLayout(
        landscape ? _landscapeDefaults : _portraitDefaults,
      ).resolve();

  static const List<FullscreenControlCluster> _portraitDefaults = [
    FullscreenControlCluster(
      id: 'document',
      position: Offset(1, 0),
      controls: [
        CanvasControl.openProject,
        CanvasControl.save,
        CanvasControl.newProject,
        CanvasControl.settings,
      ],
    ),
    FullscreenControlCluster(
      id: 'history',
      position: Offset(1, 1),
      controls: [
        CanvasControl.undo,
        CanvasControl.redo,
        CanvasControl.zoomOut,
        CanvasControl.zoomFit,
        CanvasControl.zoomIn,
        CanvasControl.grid,
      ],
    ),
    FullscreenControlCluster(
      id: 'tools',
      position: Offset(0, 1),
      controls: [
        CanvasControl.layers,
        CanvasControl.multiSelect,
        CanvasControl.columns,
      ],
    ),
  ];

  static const List<FullscreenControlCluster> _landscapeDefaults = [
    FullscreenControlCluster(
      id: 'tools',
      position: Offset(0, 0.5),
      controls: [
        CanvasControl.undo,
        CanvasControl.redo,
        CanvasControl.zoomOut,
        CanvasControl.zoomFit,
        CanvasControl.zoomIn,
        CanvasControl.layers,
      ],
    ),
    FullscreenControlCluster(
      id: 'actions',
      position: Offset(1, 0.5),
      controls: [
        CanvasControl.immersive,
        CanvasControl.openProject,
        CanvasControl.save,
        CanvasControl.newProject,
        CanvasControl.multiSelect,
        CanvasControl.settings,
      ],
    ),
  ];

  /// Loads a stored layout from the current persistence format:
  /// `{"clusters": [{"id", "x", "y", "controls": [...]}, ...]}`.
  /// Fails closed on unknown ids/controls/malformed entries (those entries
  /// are dropped) and normalizes through [resolve].
  factory CanvasControlLayout.fromPrefs(Map<String, dynamic> raw) {
    final byName = <String, CanvasControl>{
      for (final control in CanvasControl.values) control.name: control,
    };
    final clusters = <FullscreenControlCluster>[];
    final rawList = raw['clusters'];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is! Map<String, dynamic>) continue;
        final id = item['id'];
        if (id is! String || id.trim().isEmpty) continue;
        final x = item['x'] is num ? (item['x'] as num).toDouble() : 0.5;
        final y = item['y'] is num ? (item['y'] as num).toDouble() : 0.5;
        final controls = item['controls'];
        final resolved = <CanvasControl>[];
        if (controls is List) {
          for (final name in controls) {
            if (name is String && byName[name] != null) {
              resolved.add(byName[name]!);
            }
          }
        }
        clusters.add(
          FullscreenControlCluster(
            id: id.trim(),
            position: clampNormalized(Offset(x, y)),
            controls: resolved,
          ),
        );
      }
    }
    return CanvasControlLayout(clusters).resolve();
  }

  /// Migrates the retired region-based format (`region name → control
  /// ids`, pre-free-form) into clusters anchored at the matching corners.
  /// Unknown region names and control ids fail closed (dropped).
  factory CanvasControlLayout.fromLegacyRegions(
    Map<String, List<String>> raw,
  ) {
    const anchors = <String, Offset>{
      'topLeft': Offset(0, 0),
      'topCenter': Offset(0.5, 0),
      'topRight': Offset(1, 0),
      'bottomLeft': Offset(0, 1),
      'bottomCenter': Offset(0.5, 1),
      'bottomRight': Offset(1, 1),
    };
    final byName = <String, CanvasControl>{
      for (final control in CanvasControl.values) control.name: control,
    };
    final clusters = <FullscreenControlCluster>[];
    for (final entry in raw.entries) {
      final anchor = anchors[entry.key];
      if (anchor == null) continue;
      clusters.add(
        FullscreenControlCluster(
          id: entry.key,
          position: anchor,
          controls: [
            for (final name in entry.value)
              if (byName[name] != null) byName[name]!,
          ],
        ),
      );
    }
    return CanvasControlLayout(clusters).resolve();
  }

  /// Stable persistence encoding (current format).
  Map<String, dynamic> toPrefs() => <String, dynamic>{
    'clusters': [
      for (final cluster in _clusters)
        <String, dynamic>{
          'id': cluster.id,
          'x': cluster.position.dx,
          'y': cluster.position.dy,
          'controls': [for (final control in cluster.controls) control.name],
        },
    ],
  };

  /// Deterministic normalization:
  /// 1. clusters with the same id merge (first position wins);
  /// 2. a control keeps only its first cluster (later duplicates dropped);
  /// 3. each cluster is capped at [maxControlsPerCluster];
  /// 4. empty clusters are dropped;
  /// 5. [CanvasControl.immersive] is guaranteed present (first slot of the
  ///    first cluster, dropping the last user control only when that
  ///    cluster is full) so the user can never be locked inside fullscreen.
  CanvasControlLayout resolve() {
    final byId = <String, FullscreenControlCluster>{};
    final order = <String>[];
    for (final cluster in _clusters) {
      final existing = byId[cluster.id];
      if (existing == null) {
        byId[cluster.id] = FullscreenControlCluster(
          id: cluster.id,
          position: clampNormalized(cluster.position),
          controls: [...cluster.controls],
        );
        order.add(cluster.id);
      } else {
        byId[cluster.id] = FullscreenControlCluster(
          id: existing.id,
          position: existing.position,
          controls: [...existing.controls, ...cluster.controls],
        );
      }
    }
    final placed = <CanvasControl>{};
    final result = <FullscreenControlCluster>[];
    for (final id in order) {
      final cluster = byId[id]!;
      final controls = <CanvasControl>[];
      for (final control in cluster.controls) {
        if (!placed.add(control)) continue;
        controls.add(control);
      }
      if (controls.length > maxControlsPerCluster) {
        controls.removeRange(maxControlsPerCluster, controls.length);
      }
      if (controls.isEmpty) continue;
      result.add(
        FullscreenControlCluster(
          id: cluster.id,
          position: cluster.position,
          controls: List<CanvasControl>.unmodifiable(controls),
        ),
      );
    }
    if (!placed.contains(CanvasControl.immersive)) {
      if (result.isEmpty) {
        result.add(
          const FullscreenControlCluster(
            id: 'actions',
            position: Offset(1, 0),
            controls: [CanvasControl.immersive],
          ),
        );
      } else {
        final first = result.first;
        result[0] = FullscreenControlCluster(
          id: first.id,
          position: first.position,
          controls: <CanvasControl>[
            CanvasControl.immersive,
            ...first.controls,
          ].take(maxControlsPerCluster).toList(growable: false),
        );
      }
    }
    return CanvasControlLayout(result);
  }

  /// The cluster containing [control], or null when the control is hidden
  /// (or unknown).
  String? clusterOf(CanvasControl control) {
    for (final cluster in _clusters) {
      if (cluster.controls.contains(control)) return cluster.id;
    }
    return null;
  }

  /// First cluster with [id], or null.
  FullscreenControlCluster? clusterById(String id) {
    for (final cluster in _clusters) {
      if (cluster.id == id) return cluster;
    }
    return null;
  }

  /// Copy with [id]'s cluster moved to the given normalized [position].
  /// No-op when the id is unknown. Position is clamped to 0..1 — the
  /// on-screen clamping against insets happens at render time.
  CanvasControlLayout moveCluster(String id, Offset position) {
    if (clusterById(id) == null) return this;
    return CanvasControlLayout([
      for (final cluster in _clusters)
        cluster.id == id
            ? FullscreenControlCluster(
                id: cluster.id,
                controls: cluster.controls,
                position: clampNormalized(position),
              )
            : cluster,
    ]);
  }

  /// Copy with [id]'s cluster moved to the END of the list (topmost in
  /// render order). The last-touched cluster therefore receives gestures
  /// first when clusters overlap. No-op when the id is unknown.
  CanvasControlLayout bringClusterToFront(String id) {
    if (clusterById(id) == null) return this;
    final reordered = <FullscreenControlCluster>[
      for (final cluster in _clusters)
        if (cluster.id != id) cluster,
    ];
    reordered.add(clusterById(id)!);
    return CanvasControlLayout(reordered);
  }

  /// Copy with [control] removed from every cluster and appended to the
  /// cluster named [clusterId]. A cluster id that does not exist yet is
  /// created at a sensible center-ish default position. The resulting
  /// layout is normalized (empty clusters drop out; capacity enforced).
  CanvasControlLayout assignControl(CanvasControl control, String clusterId) {
    final cluster = clusterById(clusterId);
    if (cluster == null) {
      return CanvasControlLayout([
        ..._clusters.map(_withoutControl(control)),
        FullscreenControlCluster(
          id: clusterId,
          position: const Offset(0.5, 0.35),
          controls: [control],
        ),
      ]).resolve();
    }
    return CanvasControlLayout([
      for (final existing in _clusters)
        if (existing.id == clusterId)
          FullscreenControlCluster(
            id: existing.id,
            position: existing.position,
            controls: [...existing.controls, control],
          )
        else
          _withoutControl(control)(existing),
    ]).resolve();
  }

  /// Copy with [control] removed from every cluster (Hidden). The
  /// immersive exit control is still re-guaranteed by [resolve].
  CanvasControlLayout removeControl(CanvasControl control) =>
      CanvasControlLayout(
        _clusters.map(_withoutControl(control)).toList(growable: false),
      ).resolve();

  /// Next available generated cluster id (`group1`, `group2`, …) for the
  /// customizer's "New group" flow. Deterministic and collision-free
  /// against ids that follow the pattern.
  String nextClusterId() {
    final pattern = RegExp(r'^group(\d+)$');
    var max = 0;
    for (final cluster in _clusters) {
      final match = pattern.firstMatch(cluster.id);
      if (match == null) continue;
      final value = int.tryParse(match.group(1)!);
      if (value != null && value > max) max = value;
    }
    return 'group${max + 1}';
  }

  static FullscreenControlCluster Function(FullscreenControlCluster)
  _withoutControl(CanvasControl control) => (cluster) =>
      FullscreenControlCluster(
        id: cluster.id,
        position: cluster.position,
        controls: [
          for (final existing in cluster.controls)
            if (existing != control) existing,
        ],
      );

  /// Clamps a normalized position into the 0..1 unit square.
  static Offset clampNormalized(Offset position) => Offset(
    position.dx.clamp(0.0, 1.0),
    position.dy.clamp(0.0, 1.0),
  );

  /// Maps a normalized cluster position to concrete pixels: the cluster's
  /// top-left inside [viewport], kept fully visible within [safe] (cutout /
  /// gesture insets). A cluster larger than the safe area is pinned to the
  /// safe origin and scrolls internally instead of overflowing.
  static Offset clusterPixelsForNormalized(
    Offset normalized,
    Size clusterSize,
    Size viewport,
    EdgeInsets safe,
  ) {
    final availableW = math.max(
      0.0,
      viewport.width - safe.horizontal - clusterSize.width,
    );
    final availableH = math.max(
      0.0,
      viewport.height - safe.vertical - clusterSize.height,
    );
    return Offset(
      safe.left + normalized.dx * availableW,
      safe.top + normalized.dy * availableH,
    );
  }

  /// Inverse of [clusterPixelsForNormalized]. Guards the degenerate case
  /// where the cluster is at least as large as the safe viewport (returns
  /// 0,0 → pinned to the safe origin).
  static Offset normalizedForClusterPixels(
    Offset pixels,
    Size clusterSize,
    Size viewport,
    EdgeInsets safe,
  ) {
    final availableW = math.max(
      0.0,
      viewport.width - safe.horizontal - clusterSize.width,
    );
    final availableH = math.max(
      0.0,
      viewport.height - safe.vertical - clusterSize.height,
    );
    return Offset(
      availableW <= 0
          ? 0.0
          : ((pixels.dx - safe.left) / availableW).clamp(0.0, 1.0),
      availableH <= 0
          ? 0.0
          : ((pixels.dy - safe.top) / availableH).clamp(0.0, 1.0),
    );
  }
}
