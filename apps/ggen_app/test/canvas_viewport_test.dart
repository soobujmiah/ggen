import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/src/canvas/canvas_viewport.dart';

void main() {
  group('fit', () {
    test('fits a wide artboard into a narrow viewport', () {
      final viewport = CanvasViewport.fit(
        artboardWidth: 1200,
        artboardHeight: 800,
        viewportWidth: 400,
        viewportHeight: 800,
      );
      // Width is the limiting dimension: (400-32)/1200.
      expect(viewport.scale, closeTo(368 / 1200, 0.0001));
      // Artboard is vertically centered.
      final artboardScreenHeight = 800 * viewport.scale;
      expect(
        viewport.offsetY,
        closeTo((800 - artboardScreenHeight) / 2, 0.0001),
      );
    });

    test('fits a tall artboard into a short viewport', () {
      final viewport = CanvasViewport.fit(
        artboardWidth: 800,
        artboardHeight: 1200,
        viewportWidth: 800,
        viewportHeight: 400,
      );
      expect(viewport.scale, closeTo((400 - 32) / 1200, 0.0001));
    });

    test('clamps the fit scale to the supported range', () {
      final huge = CanvasViewport.fit(
        artboardWidth: 10,
        artboardHeight: 10,
        viewportWidth: 10000,
        viewportHeight: 10000,
      );
      expect(huge.scale, CanvasViewport.maxScale);
    });
  });

  group('coordinate mapping', () {
    test('toArtboard inverts toScreen', () {
      const viewport = CanvasViewport(scale: 2, offsetX: 10, offsetY: -20);
      const artboard = Offset(300, 150);
      final screen = viewport.toScreen(artboard);
      expect(screen.dx, 610);
      expect(screen.dy, 280);
      final roundTrip = viewport.toArtboard(screen);
      expect(roundTrip.dx, closeTo(300, 0.0001));
      expect(roundTrip.dy, closeTo(150, 0.0001));
    });
  });

  group('zoom', () {
    test('zoomAt keeps the artboard point under the focal stationary', () {
      final viewport = CanvasViewport.fit(
        artboardWidth: 1200,
        artboardHeight: 800,
        viewportWidth: 400,
        viewportHeight: 400,
      );
      const focal = Offset(200, 200);
      final artboardBefore = viewport.toArtboard(focal);
      final zoomed = viewport.zoomAt(
        focalX: focal.dx,
        focalY: focal.dy,
        targetScale: viewport.scale * 2,
      );
      expect(zoomed.scale, closeTo(viewport.scale * 2, 0.0001));
      final artboardAfter = zoomed.toArtboard(focal);
      expect(artboardAfter.dx, closeTo(artboardBefore.dx, 0.0001));
      expect(artboardAfter.dy, closeTo(artboardBefore.dy, 0.0001));
    });

    test('zoom clamps to min and max scale', () {
      const viewport = CanvasViewport(scale: 1, offsetX: 0, offsetY: 0);
      expect(
        viewport.zoomAt(focalX: 0, focalY: 0, targetScale: 100).scale,
        CanvasViewport.maxScale,
      );
      expect(
        viewport.zoomAt(focalX: 0, focalY: 0, targetScale: 0.0001).scale,
        CanvasViewport.minScale,
      );
    });
  });

  group('pan', () {
    test('panBy shifts the offset without changing scale', () {
      const viewport = CanvasViewport(scale: 1.5, offsetX: 10, offsetY: 20);
      final panned = viewport.panBy(30, -40);
      expect(panned.scale, 1.5);
      expect(panned.offsetX, 40);
      expect(panned.offsetY, -20);
    });
  });
}
