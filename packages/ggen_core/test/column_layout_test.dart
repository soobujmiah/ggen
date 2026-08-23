import 'package:ggen_core/ggen_core.dart';
import 'package:test/test.dart';

void main() {
  group('ColumnLayout model', () {
    test('default is one column, zero gutter, ltr, unbalanced', () {
      const layout = ColumnLayout();
      expect(layout.columnCount, 1);
      expect(layout.gutter, 0);
      expect(layout.direction, ColumnDirection.leftToRight);
      expect(layout.balanced, false);
      expect(layout.isSingleColumn, isTrue);
      expect(layout, ColumnLayout.single);
    });

    test('2/3/4 columns accepted', () {
      expect(ColumnLayout.create(columnCount: 2).columnCount, 2);
      expect(ColumnLayout.create(columnCount: 3).columnCount, 3);
      expect(ColumnLayout.create(columnCount: 4).columnCount, 4);
    });

    test('zero and positive gutter accepted', () {
      expect(ColumnLayout.create(gutter: 0).gutter, 0);
      expect(ColumnLayout.create(gutter: 12.5).gutter, 12.5);
    });

    test('negative gutter rejected', () {
      expect(() => ColumnLayout.create(gutter: -1), throwsArgumentError);
    });

    test('zero/negative column count rejected', () {
      expect(() => ColumnLayout.create(columnCount: 0), throwsArgumentError);
      expect(() => ColumnLayout.create(columnCount: -3), throwsArgumentError);
    });

    test('column count above max rejected', () {
      expect(
        () => ColumnLayout.create(columnCount: ColumnLayout.maxColumnCount + 1),
        throwsArgumentError,
      );
    });

    test('non-finite gutter rejected', () {
      expect(
        () => ColumnLayout.create(gutter: double.nan),
        throwsArgumentError,
      );
      expect(
        () => ColumnLayout.create(gutter: double.infinity),
        throwsArgumentError,
      );
    });

    test('excessive gutter is valid at model level, rejected at geometry', () {
      // The model stores gutter; the geometry engine rejects impossible fits.
      final layout = ColumnLayout.create(columnCount: 2, gutter: 100000);
      expect(layout.gutter, 100000);
      final content = FrameRect.fromLTWH(0, 0, 100, 100);
      expect(
        () => ColumnGeometry.layout(layout: layout, content: content),
        throwsArgumentError,
      );
    });

    test('right-to-left direction rejected this milestone', () {
      expect(
        () => ColumnLayout.create(direction: ColumnDirection.rightToLeft),
        throwsArgumentError,
      );
    });

    test('balanced=true rejected (not implemented)', () {
      expect(() => ColumnLayout.create(balanced: true), throwsArgumentError);
    });

    test('copyWith produces validated new layout', () {
      final a = ColumnLayout.create(columnCount: 1, gutter: 0);
      final b = a.copyWith(columnCount: 3, gutter: 8);
      expect(b.columnCount, 3);
      expect(b.gutter, 8);
      expect(a.columnCount, 1); // immutable
    });

    test('JSON roundtrip', () {
      final layout = ColumnLayout.create(columnCount: 3, gutter: 10);
      final json = layout.toJson();
      final decoded = ColumnLayout.decodeJson(json);
      expect(decoded, layout);
      expect(decoded.columnCount, 3);
      expect(decoded.gutter, 10);
    });

    test('JSON defaults to single for null/empty', () {
      expect(ColumnLayout.decodeJson(null), ColumnLayout.single);
      expect(ColumnLayout.decodeJson(<String, Object?>{}), ColumnLayout.single);
    });

    test('JSON fails closed on malformed values', () {
      expect(
        () => ColumnLayout.decodeJson({'columnCount': 'two'}),
        throwsFormatException,
      );
      expect(
        () => ColumnLayout.decodeJson({'gutter': -1}),
        throwsArgumentError,
      );
      expect(
        () => ColumnLayout.decodeJson({'direction': 'rtl'}),
        throwsFormatException,
      );
      expect(
        () => ColumnLayout.decodeJson({'balanced': true}),
        throwsArgumentError,
      );
      expect(() => ColumnLayout.decodeJson('nope'), throwsFormatException);
    });

    test('JSON tolerates numeric 2.0 for columnCount', () {
      final decoded = ColumnLayout.decodeJson({'columnCount': 2.0});
      expect(decoded.columnCount, 2);
    });
  });

  group('ColumnGeometry', () {
    FrameRect content(double w, double h) => FrameRect.fromLTWH(0, 0, w, h);

    test('single column fills the content rect', () {
      final g = ColumnGeometry.layout(
        layout: ColumnLayout.single,
        content: content(300, 400),
      );
      expect(g.columnCount, 1);
      expect(g[0].bounds, content(300, 400));
      expect(g.totalContentBounds, content(300, 400));
    });

    test('2 columns: exact widths and gutter separation', () {
      final g = ColumnGeometry.layout(
        layout: ColumnLayout.create(columnCount: 2, gutter: 20),
        content: content(220, 100),
      );
      // availableWidth = 220 - 20 = 200; columnWidth = 100
      expect(g[0].bounds.width, 100);
      expect(g[1].bounds.width, 100);
      expect(g[0].bounds.left, 0);
      expect(g[1].bounds.left, 120); // 100 + 20 gutter
      expect(g[1].bounds.right, 220);
    });

    test('3 columns: exact widths', () {
      final g = ColumnGeometry.layout(
        layout: ColumnLayout.create(columnCount: 3, gutter: 10),
        content: content(320, 50),
      );
      // available = 320 - 20 = 300; width = 100
      for (var i = 0; i < 3; i++) {
        expect(g[i].bounds.width, 100);
        expect(g[i].bounds.left, i * 110);
        expect(g[i].bounds.height, 50);
      }
      expect(g[2].bounds.right, 320);
    });

    test('4 columns no gutter', () {
      final g = ColumnGeometry.layout(
        layout: ColumnLayout.create(columnCount: 4, gutter: 0),
        content: content(400, 10),
      );
      for (var i = 0; i < 4; i++) {
        expect(g[i].bounds.width, 100);
      }
    });

    test('columns never overlap', () {
      final g = ColumnGeometry.layout(
        layout: ColumnLayout.create(columnCount: 5, gutter: 8),
        content: content(532, 200),
      );
      for (var i = 0; i < g.columnCount; i++) {
        for (var j = i + 1; j < g.columnCount; j++) {
          expect(
            g[i].bounds.overlaps(g[j].bounds),
            isFalse,
            reason: 'columns $i and $j overlap',
          );
        }
      }
    });

    test('columns are contained in the content bounds', () {
      final c = content(500, 300);
      final g = ColumnGeometry.layout(
        layout: ColumnLayout.create(columnCount: 4, gutter: 12),
        content: c,
      );
      for (final col in g.columnBounds) {
        expect(c.containsRect(col.bounds), isTrue);
      }
    });

    test('rejects availableWidth <= 0', () {
      expect(
        () => ColumnGeometry.layout(
          layout: ColumnLayout.create(columnCount: 2, gutter: 100),
          content: content(100, 50),
        ),
        throwsArgumentError,
      );
    });

    test('rejects empty content', () {
      expect(
        () => ColumnGeometry.layout(
          layout: ColumnLayout.single,
          content: FrameRect.fromLTWH(0, 0, 0, 100),
        ),
        throwsArgumentError,
      );
    });

    test('columnAtPoint returns correct column, -1 in gutter/outside', () {
      final g = ColumnGeometry.layout(
        layout: ColumnLayout.create(columnCount: 3, gutter: 10),
        content: content(320, 100),
      );
      expect(g.columnAtPoint(50, 50), 0); // inside col 0
      expect(g.columnAtPoint(105, 50), -1); // in gutter (100..110)
      expect(g.columnAtPoint(150, 50), 1); // col 1 (110..210)
      expect(g.columnAtPoint(300, 50), 2); // col 2 (220..320)
      expect(g.columnAtPoint(999, 50), -1); // outside
    });

    test('containsPoint distinguishes content from gutter', () {
      final g = ColumnGeometry.layout(
        layout: ColumnLayout.create(columnCount: 2, gutter: 20),
        content: content(220, 100),
      );
      expect(g.containsPoint(110, 50), isTrue); // gutter, inside content
      expect(g.columnAtPoint(110, 50), -1);
      expect(g.containsPoint(-5, 50), isFalse);
    });

    test('frame contentRect applies padding', () {
      final geom = FrameGeometry(
        x: 10,
        y: 20,
        frameWidth: 200,
        frameHeight: 100,
        innerPadding: 10,
      );
      final c = geom.contentRect;
      expect(c.left, 20);
      expect(c.top, 30);
      expect(c.width, 180);
      expect(c.height, 80);
    });

    test('frame padding that consumes content fails closed', () {
      const geom = FrameGeometry(
        x: 0,
        y: 0,
        frameWidth: 10,
        frameHeight: 10,
        innerPadding: 10,
      );
      expect(() => geom.contentRect, throwsStateError);
    });
  });
}
