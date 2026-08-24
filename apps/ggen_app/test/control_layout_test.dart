import 'dart:ui';

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
      // Borderline: taller than wide on a small screen stays portrait.
      expect(classifyWorkspace(699, 599), WorkspaceClass.compactPortrait);
    });
  });

  group('CanvasControlLayout.resolve', () {
    test('defaults place the immersive exit and a movable zoom cluster', () {
      final layout = CanvasControlLayout.defaults().resolve();
      final topRight = layout.regions[ControlRegion.topRight]!;
      expect(topRight.first, CanvasControl.immersive);
      expect(
        layout.regions[ControlRegion.bottomRight],
        containsAll(<CanvasControl>[
          CanvasControl.zoomIn,
          CanvasControl.zoomOut,
          CanvasControl.zoomFit,
        ]),
      );
      expect(
        layout.regions[ControlRegion.bottomLeft],
        contains(CanvasControl.layers),
      );
    });

    test('a control in two regions keeps only the first region', () {
      final layout = CanvasControlLayout({
        ControlRegion.bottomLeft: const [
          CanvasControl.undo,
          CanvasControl.grid,
        ],
        ControlRegion.bottomRight: const [
          CanvasControl.grid,
          CanvasControl.zoomIn,
        ],
      }).resolve();
      expect(
        layout.regions[ControlRegion.bottomLeft],
        contains(CanvasControl.grid),
      );
      expect(
        layout.regions[ControlRegion.bottomRight],
        isNot(contains(CanvasControl.grid)),
      );
    });

    test('per-region capacity is enforced deterministically', () {
      final layout = CanvasControlLayout({
        ControlRegion.bottomRight: const [
          CanvasControl.undo,
          CanvasControl.redo,
          CanvasControl.zoomIn,
          CanvasControl.zoomOut,
          CanvasControl.zoomFit,
          CanvasControl.grid,
          CanvasControl.layers, // 7th — dropped
        ],
      }).resolve();
      expect(
        layout.regions[ControlRegion.bottomRight]!.length,
        CanvasControlLayout.maxControlsPerRegion,
      );
      expect(
        layout.regions[ControlRegion.bottomRight],
        isNot(contains(CanvasControl.layers)),
      );
    });

    test('the immersive exit control is always enforced', () {
      // Even an empty layout must provide a way out of fullscreen.
      final empty = CanvasControlLayout(const {}).resolve();
      expect(
        empty.regions[ControlRegion.topRight],
        <CanvasControl>[CanvasControl.immersive],
      );

      // A full topRight still keeps immersive by dropping the last user
      // control (deterministic, never locked in).
      final full = CanvasControlLayout({
        ControlRegion.topRight: const [
          CanvasControl.save,
          CanvasControl.newProject,
          CanvasControl.settings,
          CanvasControl.diagnostics,
          CanvasControl.dockInspector,
          CanvasControl.layers,
        ],
      }).resolve();
      final topRight = full.regions[ControlRegion.topRight]!;
      expect(topRight.first, CanvasControl.immersive);
      expect(topRight.length, CanvasControlLayout.maxControlsPerRegion);
    });

    test('fromPrefs fails closed on unknown regions and controls', () {
      final layout = CanvasControlLayout.fromPrefs({
        'not_a_region': <String>['undo'],
        'bottomRight': <String>['undo', 'not_a_control', 'zoomIn'],
      });
      expect(layout.regions.containsKey(ControlRegion.topLeft), isFalse);
      expect(
        layout.regions[ControlRegion.bottomRight],
        <CanvasControl>[CanvasControl.undo, CanvasControl.zoomIn],
      );
    });

    test('toPrefs/fromPrefs round-trips the resolved layout', () {
      final original = CanvasControlLayout.defaults().resolve();
      final restored = CanvasControlLayout.fromPrefs(original.toPrefs());
      expect(restored.regions.keys, original.regions.keys);
      for (final region in original.regions.keys) {
        expect(
          restored.regions[region],
          original.regions[region],
          reason: 'region $region must round-trip exactly',
        );
      }
    });
  });

  group('CanvasControlLayout.nearestRegion', () {
    const viewport = Size(100, 100);

    test('corners snap to the matching corner regions', () {
      expect(
        CanvasControlLayout.nearestRegion(const Offset(10, 10), viewport),
        ControlRegion.topLeft,
      );
      expect(
        CanvasControlLayout.nearestRegion(const Offset(90, 10), viewport),
        ControlRegion.topRight,
      );
      expect(
        CanvasControlLayout.nearestRegion(const Offset(10, 90), viewport),
        ControlRegion.bottomLeft,
      );
      expect(
        CanvasControlLayout.nearestRegion(const Offset(90, 90), viewport),
        ControlRegion.bottomRight,
      );
    });

    test('middle column snaps to the center regions', () {
      expect(
        CanvasControlLayout.nearestRegion(const Offset(50, 10), viewport),
        ControlRegion.topCenter,
      );
      expect(
        CanvasControlLayout.nearestRegion(const Offset(50, 90), viewport),
        ControlRegion.bottomCenter,
      );
    });

    test('degenerate viewport falls back deterministically', () {
      expect(
        CanvasControlLayout.nearestRegion(
          const Offset(10, 10),
          const Size(0, 0),
        ),
        ControlRegion.bottomRight,
      );
    });
  });
}
