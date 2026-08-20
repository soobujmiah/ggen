import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/src/canvas/canvas_viewport.dart';
import 'package:ggen_app/src/canvas/studio_canvas.dart';
import 'package:ggen_app/src/controller/studio_controller.dart';
import 'package:ggen_core/ggen_core.dart';

Widget _wrap(
  StudioController controller, {
  required bool drawEnabled,
  ValueChanged<CanvasViewport>? onViewportChanged,
  void Function(Offset artboardPoint)? onTextRequest,
  VoidCallback? onTwoFingerTap,
  VoidCallback? onThreeFingerTap,
}) => MaterialApp(
  home: Scaffold(
    body: StudioCanvas(
      controller: controller,
      drawEnabled: drawEnabled,
      onNodeAdded: () {},
      onViewportChanged: onViewportChanged,
      onTextRequest: onTextRequest,
      onTwoFingerTap: onTwoFingerTap,
      onThreeFingerTap: onThreeFingerTap,
    ),
  ),
);

void main() {
  testWidgets('renders the artboard and its nodes', (tester) async {
    final controller = StudioController();
    controller.addShapeNode(100, 100);

    await tester.pumpWidget(_wrap(controller, drawEnabled: false));
    await tester.pumpAndSettle();

    // The artboard surface is present (white) and the node is rendered.
    expect(find.byType(StudioCanvas), findsOneWidget);
    expect(
      tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).length,
      greaterThanOrEqualTo(2),
    );
    expect(controller.objectCount, 1);
  });

  testWidgets('tap with the Draw tool adds a shape node', (tester) async {
    final controller = StudioController();
    await tester.pumpWidget(_wrap(controller, drawEnabled: true));
    await tester.pumpAndSettle();

    expect(controller.objectCount, 0);
    await tester.tap(find.byType(StudioCanvas));
    await tester.pumpAndSettle();

    expect(controller.objectCount, 1);
    expect(controller.canUndo, isTrue);
    expect(controller.revision, 1);

    final node = controller.project.artboards.first.nodes.single;
    expect(node.kind, DocumentNodeKind.shape);
    final geometry = nodeGeometry(node);
    expect(geometry, isNotNull);
    expect(geometry!.x, greaterThanOrEqualTo(0));
    expect(geometry.y, greaterThanOrEqualTo(0));
    expect(geometry.x + geometry.width, lessThanOrEqualTo(1200));
    expect(geometry.y + geometry.height, lessThanOrEqualTo(800));
  });

  testWidgets('tap with Select tool does not add a node', (tester) async {
    final controller = StudioController();
    await tester.pumpWidget(_wrap(controller, drawEnabled: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(StudioCanvas));
    await tester.pumpAndSettle();

    expect(controller.objectCount, 0);
    expect(controller.revision, 0);
  });

  testWidgets('pinch zoom increases scale around the focal point', (
    tester,
  ) async {
    final controller = StudioController();
    final scales = <double>[];
    await tester.pumpWidget(
      _wrap(
        controller,
        drawEnabled: false,
        onViewportChanged: (viewport) => scales.add(viewport.scale),
      ),
    );
    await tester.pumpAndSettle();

    final initial = scales.last;
    final center = tester.getCenter(find.byType(StudioCanvas));

    final finger1 = await tester.startGesture(center - const Offset(30, 0));
    final finger2 = await tester.startGesture(center + const Offset(30, 0));
    await tester.pump();
    await finger1.moveBy(const Offset(-30, 0));
    await finger2.moveBy(const Offset(30, 0));
    await tester.pump();
    await finger1.up();
    await finger2.up();
    await tester.pumpAndSettle();

    expect(scales.last, greaterThan(initial));
  });

  testWidgets('one-finger drag pans without changing scale', (tester) async {
    final controller = StudioController();
    final viewports = <CanvasViewport>[];
    await tester.pumpWidget(
      _wrap(
        controller,
        drawEnabled: false,
        onViewportChanged: (viewport) => viewports.add(viewport),
      ),
    );
    await tester.pumpAndSettle();

    final before = viewports.last;
    await tester.drag(find.byType(StudioCanvas), const Offset(40, 25));
    await tester.pumpAndSettle();
    final after = viewports.last;

    expect(after.scale, closeTo(before.scale, 0.0001));
    expect(after.offsetX, isNot(closeTo(before.offsetX, 0.0001)));
    expect(after.offsetY, isNot(closeTo(before.offsetY, 0.0001)));
  });

  testWidgets('text tool tap reports the artboard point', (tester) async {
    final controller = StudioController();
    Offset? reported;
    await tester.pumpWidget(
      _wrap(
        controller,
        drawEnabled: false,
        onTextRequest: (point) => reported = point,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(StudioCanvas));
    await tester.pumpAndSettle();

    expect(reported, isNotNull);
    expect(controller.objectCount, 0); // Text is added by the shell, not the canvas.
  });

  testWidgets('two-finger tap reports undo intent', (tester) async {
    final controller = StudioController();
    var twoFingerTaps = 0;
    await tester.pumpWidget(
      _wrap(
        controller,
        drawEnabled: false,
        onTwoFingerTap: () => twoFingerTaps++,
      ),
    );
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(StudioCanvas));
    final finger1 = await tester.startGesture(center - const Offset(20, 0));
    final finger2 = await tester.startGesture(center + const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 40));
    await finger1.up();
    await finger2.up();
    await tester.pumpAndSettle();

    expect(twoFingerTaps, 1);
  });

  testWidgets('three-finger tap reports redo intent', (tester) async {
    final controller = StudioController();
    var threeFingerTaps = 0;
    await tester.pumpWidget(
      _wrap(
        controller,
        drawEnabled: false,
        onThreeFingerTap: () => threeFingerTaps++,
      ),
    );
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(StudioCanvas));
    final finger1 = await tester.startGesture(center - const Offset(30, 0));
    final finger2 = await tester.startGesture(center);
    final finger3 = await tester.startGesture(center + const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 40));
    await finger1.up();
    await finger2.up();
    await finger3.up();
    await tester.pumpAndSettle();

    expect(threeFingerTaps, 1);
  });

  testWidgets('text frames render on the artboard', (tester) async {
    final controller = StudioController();
    controller.addTextNode(100, 120, 'Hello');
    await tester.pumpWidget(_wrap(controller, drawEnabled: false));
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsOneWidget);
  });
}
