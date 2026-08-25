
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/src/workspace/control_layout.dart';

void main() {
  group('classifyWorkspace', () {
    test('portrait phones are compactPortrait', () {
      expect(classifyWorkspace(471, 1020), WorkspaceClass.compactPortrait);
      expect(classifyWorkspace(400, 800), WorkspaceClass.compactPortrait);
      expect(classifyWorkspace(360, 800), WorkspaceClass.compactPortrait);
      expect(classifyWorkspace(200, 300), WorkspaceClass.compactPortrait);
    });

    test('zero-size viewports never crash and stay compact', () {
      expect(classifyWorkspace(0, 0), WorkspaceClass.compactPortrait);
    });

    test('tablets and large portrait screens are wide', () {
      expect(classifyWorkspace(800, 1024), WorkspaceClass.wide);
      expect(classifyWorkspace(1200, 800), WorkspaceClass.wide);
      expect(classifyWorkspace(720, 1600), WorkspaceClass.wide);
      expect(classifyWorkspace(700, 600), WorkspaceClass.wide);
    });

    test('landscape phones are compactLandscape (not wide)', () {
      expect(classifyWorkspace(800, 360), WorkspaceClass.compactLandscape);
      expect(classifyWorkspace(640, 360), WorkspaceClass.compactLandscape);
      expect(classifyWorkspace(900, 412), WorkspaceClass.compactLandscape);
      // Taller than wide on a small screen stays portrait (orientation
      // decides the landscape class, not the raw width).
      expect(classifyWorkspace(599, 699), WorkspaceClass.compactPortrait);
      expect(classifyWorkspace(699, 800), WorkspaceClass.compactPortrait);
    });
  });

  group('estimatedClusterSize', () {
    test('matches the fixed 40px-button renderer math', () {
      expect(estimatedClusterSize(0), const Size(8, 44));
      // 8 (padding) + 40 (button) = 48 wide, 4 + 40 = 44 tall.
      expect(estimatedClusterSize(1), const Size(48, 44));
      // 8 + 2*40 + 2 (one gap) = 90.
      expect(estimatedClusterSize(2), const Size(90, 44));
      // 8 + 6*40 + 5*2 = 258 — the full default history cluster.
      expect(estimatedClusterSize(6), const Size(258, 44));
    });
  });

  group('CanvasControlLayout.resolve', () {
    test('defaults place the immersive exit and document/history/tools', () {
      final layout = CanvasControlLayout.defaults().resolve();
      expect(layout.clusters.length, 3);
      final document = layout.clusterById('document')!;
      expect(document.controls.first, CanvasControl.immersive);
      expect(
        document.controls,
        containsAll(<CanvasControl>[
          CanvasControl.openProject,
          CanvasControl.save,
          CanvasControl.newProject,
          CanvasControl.settings,
        ]),
      );
      expect(
        layout.clusterById('history')!.controls,
        containsAll(<CanvasControl>[
          CanvasControl.zoomIn,
          CanvasControl.zoomOut,
          CanvasControl.zoomFit,
        ]),
      );
      expect(
        layout.clusterById('tools')!.controls,
        contains(CanvasControl.layers),
      );
    });

    test('a control in two clusters keeps only the first cluster', () {
      final layout = CanvasControlLayout([
        FullscreenControlCluster(
          id: 'a',
          controls: const [CanvasControl.undo, CanvasControl.grid],
        ),
        FullscreenControlCluster(
          id: 'b',
          controls: const [CanvasControl.grid, CanvasControl.redo],
        ),
      ]).resolve();
      expect(layout.clusterById('a')!.controls, contains(CanvasControl.grid));
      expect(
        layout.clusterById('b')!.controls,
        isNot(contains(CanvasControl.grid)),
      );
      expect(layout.clusterById('b')!.controls, contains(CanvasControl.redo));
    });

    test('clusters with duplicate ids merge, first position wins', () {
      final layout = CanvasControlLayout([
        FullscreenControlCluster(
          id: 'a',
          position: const Offset(0.2, 0.3),
          controls: const [CanvasControl.undo],
        ),
        FullscreenControlCluster(
          id: 'a',
          position: const Offset(0.9, 0.9),
          controls: const [CanvasControl.redo],
        ),
      ]).resolve();
      expect(layout.clusters.length, 1);
      final merged = layout.clusters.single;
      // resolve() guarantees the immersive exit control in the first cluster.
      expect(merged.controls, [
        CanvasControl.immersive,
        CanvasControl.undo,
        CanvasControl.redo,
      ]);
      expect(merged.position, const Offset(0.2, 0.3));
    });

    test('per-cluster capacity is enforced at 6', () {
      final layout = CanvasControlLayout([
        FullscreenControlCluster(
          id: 'full',
          controls: const [
            CanvasControl.undo,
            CanvasControl.redo,
            CanvasControl.zoomIn,
            CanvasControl.zoomOut,
            CanvasControl.zoomFit,
            CanvasControl.grid,
            CanvasControl.layers,
          ],
        ),
      ]).resolve();
      expect(
        layout.clusterById('full')!.controls.length,
        CanvasControlLayout.maxControlsPerCluster,
      );
      // The overflow control is dropped, not moved somewhere else.
      expect(layout.clusterById('full')!.controls, isNot(contains(CanvasControl.layers)));
    });

    test('empty clusters are dropped', () {
      final layout = CanvasControlLayout([
        const FullscreenControlCluster(id: 'empty', controls: []),
        FullscreenControlCluster(
          id: 'kept',
          controls: const [CanvasControl.save],
        ),
      ]).resolve();
      expect(layout.clusterById('empty'), isNull);
      expect(layout.clusterById('kept'), isNotNull);
    });

    test('immersive exit control is always guaranteed present', () {
      final layout = CanvasControlLayout([
        FullscreenControlCluster(
          id: 'only',
          controls: const [CanvasControl.save],
        ),
      ]).resolve();
      expect(layout.clusterById('only')!.controls, contains(CanvasControl.immersive));

      final empty = CanvasControlLayout(const []).resolve();
      expect(empty.clusters.single.controls, [CanvasControl.immersive]);
    });
  });

  group('CanvasControlLayout persistence', () {
    test('toPrefs/fromPrefs round-trips clusters, positions and order', () {
      final original = CanvasControlLayout([
        const FullscreenControlCluster(
          id: 'document',
          position: Offset(0.8, 0.1),
          controls: [CanvasControl.save, CanvasControl.newProject],
        ),
        const FullscreenControlCluster(
          id: 'history',
          position: Offset(0.9, 0.9),
          controls: [CanvasControl.undo, CanvasControl.zoomIn],
        ),
      ]).resolve();
      final restored = CanvasControlLayout.fromPrefs(original.toPrefs());
      expect(restored.clusters.length, original.clusters.length);
      for (var i = 0; i < original.clusters.length; i++) {
        expect(restored.clusters[i].id, original.clusters[i].id);
        expect(restored.clusters[i].position, original.clusters[i].position);
        expect(restored.clusters[i].controls, original.clusters[i].controls);
      }
    });

    test('fromPrefs fails closed on malformed entries', () {
      final layout = CanvasControlLayout.fromPrefs(<String, dynamic>{
        'clusters': <dynamic>[
          'not a map',
          <String, dynamic>{'id': '', 'controls': <dynamic>['save']},
          <String, dynamic>{
            'id': 'ok',
            'x': 3.0,
            'y': -1.0,
            'controls': <dynamic>['save', 'unknownControl', 42],
          },
        ],
      });
      // Empty id dropped; x/y clamped to 0..1; unknown ids dropped.
      expect(layout.clusters.length, 1);
      final ok = layout.clusters.single;
      expect(ok.id, 'ok');
      expect(ok.position, const Offset(1.0, 0.0));
      expect(ok.controls, [CanvasControl.immersive, CanvasControl.save]);
    });

    test('fromPrefs defaults missing x/y to the center', () {
      final layout = CanvasControlLayout.fromPrefs(<String, dynamic>{
        'clusters': <dynamic>[
          <String, dynamic>{'id': 'plain', 'controls': <dynamic>['save']},
        ],
      });
      expect(layout.clusters.single.position, const Offset(0.5, 0.5));
    });

    test('fromPrefs with no clusters list keeps only the guaranteed exit '
        'control', () {
      // Malformed/empty input yields no user clusters, but resolve() still
      // guarantees the immersive exit control so the user can never be
      // locked inside fullscreen.
      final fromEmpty = CanvasControlLayout.fromPrefs(<String, dynamic>{});
      expect(fromEmpty.clusters.single.controls, [CanvasControl.immersive]);
      final fromJunk =
          CanvasControlLayout.fromPrefs(<String, dynamic>{'clusters': 'nope'});
      expect(fromJunk.clusters.single.controls, [CanvasControl.immersive]);
    });

    test('legacy region map migrates to corner-anchored clusters', () {
      final migrated = CanvasControlLayout.fromLegacyRegions(
        <String, List<String>>{
          'bottomRight': <String>['undo', 'zoomIn'],
          'topRight': <String>['save'],
          'notARegion': <String>['layers'],
        },
      );
      final bottomRight = migrated.clusterById('bottomRight')!;
      expect(bottomRight.position, const Offset(1, 1));
      expect(bottomRight.controls, [
        CanvasControl.immersive,
        CanvasControl.undo,
        CanvasControl.zoomIn,
      ]);
      final topRight = migrated.clusterById('topRight')!;
      expect(topRight.position, const Offset(1, 0));
      expect(topRight.controls, [CanvasControl.save]);
      // Unknown region names and unknown control ids fail closed.
      expect(migrated.clusterById('notARegion'), isNull);
      for (final cluster in migrated.clusters) {
        expect(cluster.controls, isNot(contains(CanvasControl.layers)));
      }
      // The immersive exit control is still guaranteed after migration.
      expect(migrated.clusterOf(CanvasControl.immersive), isNotNull);
    });
  });

  group('CanvasControlLayout free-form placement', () {
    const viewport = Size(400, 800);
    const safe = EdgeInsets.fromLTRB(8, 24, 8, 16);
    const clusterSize = Size(90, 44);

    test('normalized corners map to the safe corners of the viewport', () {
      expect(
        CanvasControlLayout.clusterPixelsForNormalized(
          const Offset(0, 0),
          clusterSize,
          viewport,
          safe,
        ),
        const Offset(8, 24),
      );
      // (1,1) → flush right/bottom while fully inside the safe area.
      expect(
        CanvasControlLayout.clusterPixelsForNormalized(
          const Offset(1, 1),
          clusterSize,
          viewport,
          safe,
        ),
        const Offset(400 - 8 - 90, 800 - 16 - 44),
      );
    });

    test('pixels round-trip through normalization', () {
      const normalized = Offset(0.3, 0.7);
      final pixels = CanvasControlLayout.clusterPixelsForNormalized(
        normalized,
        clusterSize,
        viewport,
        safe,
      );
      final back = CanvasControlLayout.normalizedForClusterPixels(
        pixels,
        clusterSize,
        viewport,
        safe,
      );
      expect((back - normalized).distance, lessThan(0.001));
    });

    test('a cluster larger than the safe viewport pins to the safe origin', () {
      expect(
        CanvasControlLayout.clusterPixelsForNormalized(
          const Offset(1, 1),
          const Size(500, 900),
          viewport,
          safe,
        ),
        const Offset(8, 24),
      );
      expect(
        CanvasControlLayout.normalizedForClusterPixels(
          const Offset(200, 400),
          const Size(500, 900),
          viewport,
          safe,
        ),
        Offset.zero,
      );
    });

    test('moveCluster clamps to the unit square and is a no-op for unknown ids', () {
      final layout = CanvasControlLayout([
        const FullscreenControlCluster(
          id: 'a',
          position: Offset(0.5, 0.5),
          controls: [CanvasControl.save],
        ),
      ]);
      final moved = layout.moveCluster('a', const Offset(2.0, -1.0));
      expect(moved.clusterById('a')!.position, const Offset(1.0, 0.0));
      expect(layout.moveCluster('ghost', const Offset(0.1, 0.1)), layout);
    });

    test('bringClusterToFront reorders without changing positions', () {
      final layout = CanvasControlLayout([
        const FullscreenControlCluster(
          id: 'a',
          position: Offset(0.1, 0.1),
          controls: [CanvasControl.save],
        ),
        const FullscreenControlCluster(
          id: 'b',
          position: Offset(0.9, 0.9),
          controls: [CanvasControl.undo],
        ),
      ]);
      final front = layout.bringClusterToFront('a');
      expect(front.clusters.last.id, 'a');
      expect(front.clusterById('a')!.position, const Offset(0.1, 0.1));
      expect(front.clusterById('b')!.position, const Offset(0.9, 0.9));
    });

    test('assignControl moves a control between clusters', () {
      final layout = CanvasControlLayout([
        const FullscreenControlCluster(
          id: 'a',
          controls: [CanvasControl.save, CanvasControl.grid],
        ),
        const FullscreenControlCluster(id: 'b', controls: [CanvasControl.undo]),
      ]);
      final moved = layout.assignControl(CanvasControl.grid, 'b');
      expect(moved.clusterById('a')!.controls, [
        CanvasControl.immersive,
        CanvasControl.save,
      ]);
      expect(moved.clusterById('b')!.controls, [
        CanvasControl.undo,
        CanvasControl.grid,
      ]);
    });

    test('assignControl to an unknown id creates the cluster', () {
      final layout = CanvasControlLayout(const []);
      final created = layout.assignControl(CanvasControl.layers, 'group1');
      expect(created.clusterById('group1')!.controls, contains(CanvasControl.layers));
      expect(created.clusterById('group1')!.position, const Offset(0.5, 0.35));
    });

    test('removeControl hides a control and drops emptied clusters', () {
      final layout = CanvasControlLayout([
        const FullscreenControlCluster(
          id: 'a',
          controls: [CanvasControl.save, CanvasControl.grid],
        ),
        const FullscreenControlCluster(id: 'b', controls: [CanvasControl.undo]),
      ]);
      final hidden = layout.removeControl(CanvasControl.undo);
      expect(hidden.clusterById('b'), isNull);
      expect(hidden.clusterOf(CanvasControl.undo), isNull);
      // The immersive exit control is re-guaranteed even after hiding.
      expect(hidden.clusterOf(CanvasControl.immersive), isNotNull);
    });

    test('nextClusterId is deterministic and collision-free', () {
      final layout = CanvasControlLayout([
        const FullscreenControlCluster(id: 'group1', controls: [CanvasControl.save]),
        const FullscreenControlCluster(id: 'group3', controls: [CanvasControl.undo]),
        const FullscreenControlCluster(id: 'document', controls: [CanvasControl.grid]),
      ]);
      expect(layout.nextClusterId(), 'group4');
      expect(CanvasControlLayout(const []).nextClusterId(), 'group1');
    });
  });
}
