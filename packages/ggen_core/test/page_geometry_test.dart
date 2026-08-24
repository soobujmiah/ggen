import 'package:ggen_core/ggen_core.dart';
import 'package:test/test.dart';

void main() {
  group('PageMargins', () {
    test('default and zero are one column of no inset', () {
      const m = PageMargins();
      expect(m.isZero, isTrue);
      expect(m, PageMargins.zero);
      expect(m.horizontalSpan, 0);
      expect(m.verticalSpan, 0);
    });

    test('asymmetric margins kept exactly', () {
      final m = PageMargins.create(top: 1, right: 2, bottom: 3, left: 4);
      expect(m.top, 1);
      expect(m.right, 2);
      expect(m.bottom, 3);
      expect(m.left, 4);
      expect(m.isUniform, isFalse);
      expect(m.horizontalSpan, 6);
      expect(m.verticalSpan, 4);
    });

    test('all/symmetric constructors', () {
      expect(
        PageMargins.all(10),
        PageMargins.create(top: 10, right: 10, bottom: 10, left: 10),
      );
      final s = PageMargins.symmetric(horizontal: 5, vertical: 8);
      expect(s.left, 5);
      expect(s.right, 5);
      expect(s.top, 8);
      expect(s.bottom, 8);
      expect(s.isUniform, isFalse);
    });

    test('negative and non-finite margins rejected', () {
      expect(() => PageMargins.create(top: -1), throwsArgumentError);
      expect(() => PageMargins.create(left: -0.5), throwsArgumentError);
      expect(() => PageMargins.create(right: double.nan), throwsArgumentError);
      expect(
        () => PageMargins.create(bottom: double.infinity),
        throwsArgumentError,
      );
    });

    test('copyWith is validated (fail closed)', () {
      final m = PageMargins.zero;
      final n = m.copyWith(left: 12);
      expect(n.left, 12);
      expect(m.isZero, isTrue); // immutable
      expect(() => m.copyWith(top: -1), throwsArgumentError);
    });

    test('JSON roundtrip', () {
      final m = PageMargins.create(top: 72, right: 36, bottom: 72, left: 36);
      final decoded = PageMargins.decodeJson(m.toJson());
      expect(decoded, m);
    });

    test('JSON defaults to zero for null/empty, tolerates partial keys', () {
      expect(PageMargins.decodeJson(null), PageMargins.zero);
      expect(PageMargins.decodeJson(<String, Object?>{}), PageMargins.zero);
      final partial = PageMargins.decodeJson({'left': 9});
      expect(partial.left, 9);
      expect(partial.top, 0);
    });

    test('JSON fails closed on malformed values', () {
      expect(() => PageMargins.decodeJson('nope'), throwsFormatException);
      expect(
        () => PageMargins.decodeJson({'top': '72'}),
        throwsFormatException,
      );
      expect(() => PageMargins.decodeJson({'top': -1}), throwsArgumentError);
      expect(
        () => PageMargins.decodeJson({'right': double.infinity}),
        throwsFormatException,
      );
    });
  });

  group('PageBleed', () {
    test('none is zero and legacy default', () {
      expect(PageBleed.none.isNone, isTrue);
      expect(PageBleed.decodeJson(null), PageBleed.none);
    });

    test('positive finite bleed accepted', () {
      expect(PageBleed.create(12).size, 12);
      expect(PageBleed.create(0.0).isNone, isTrue);
    });

    test('negative and non-finite bleed rejected', () {
      expect(() => PageBleed.create(-1), throwsArgumentError);
      expect(() => PageBleed.create(double.nan), throwsArgumentError);
      expect(() => PageBleed.create(double.infinity), throwsArgumentError);
    });

    test('JSON roundtrip and malformed rejection', () {
      expect(
        PageBleed.decodeJson(PageBleed.create(12).toJson()),
        PageBleed(12),
      );
      expect(() => PageBleed.decodeJson(-3), throwsFormatException);
      expect(() => PageBleed.decodeJson('12'), throwsFormatException);
    });
  });

  group('PageGeometry', () {
    test('normal page: bounds derived deterministically', () {
      const page = PageGeometry(width: 612, height: 792);
      expect(page.pageRect, FrameRect.fromLTWH(0, 0, 612, 792));
      expect(page.contentBounds, FrameRect.fromLTWH(0, 0, 612, 792));
      expect(
        page.bleedBounds,
        const BleedBounds(left: 0, top: 0, width: 612, height: 792),
      );
      expect(page.bleedFitsPage, isTrue);
      expect(page.hasBleed, isFalse);
    });

    test('asymmetric margins: content bounds exact', () {
      final page = PageGeometry.create(
        width: 100,
        height: 200,
        margins: PageMargins.create(top: 10, right: 20, bottom: 30, left: 40),
      );
      final c = page.contentBounds;
      expect(c.left, 40);
      expect(c.top, 10);
      expect(c.width, 100 - 40 - 20);
      expect(c.height, 200 - 10 - 30);
      // Content is contained in the page.
      expect(page.pageRect.containsRect(c), isTrue);
    });

    test('zero margins equal the page rect', () {
      final page = PageGeometry.create(width: 50, height: 60);
      expect(page.contentBounds, page.pageRect);
    });

    test('bleed: bounds expand from the content edge', () {
      // Margin 10, bleed 5: the bleed region stays INSIDE the page
      // (content starts at 10, bleed reaches to 5).
      final page = PageGeometry.create(
        width: 100,
        height: 100,
        margins: PageMargins.all(10),
        bleed: PageBleed(5),
      );
      final c = page.contentBounds; // (10,10,80,80)
      final b = page.bleedBounds;
      expect(b, const BleedBounds(left: 5, top: 5, width: 90, height: 90));
      expect(page.hasBleed, isTrue);
      expect(page.bleedFitsPage, isTrue);
      expect(b.containsFrame(c), isTrue);
    });

    test('bleed larger than the margin extends past the page edge', () {
      // Margin 5, bleed 10: the bleed region crosses the page edge by
      // design (artwork is trimmed to the page at export time). BleedBounds
      // uses negative offsets for this; FrameRect (non-negative artboard
      // space) must not be used for it.
      final page = PageGeometry.create(
        width: 100,
        height: 100,
        margins: PageMargins.all(5),
        bleed: PageBleed(10),
      );
      final c = page.contentBounds; // (5,5,90,90)
      final b = page.bleedBounds;
      expect(b, const BleedBounds(left: -5, top: -5, width: 110, height: 110));
      expect(page.bleedFitsPage, isFalse);
      expect(b.containsFrame(c), isTrue);
      // The full-bleed region covers the entire page (and more).
      expect(b.containsFrame(page.pageRect), isTrue);
    });

    test(
      'large bleed remains deterministic (no upper bound beyond the page)',
      () {
        final page = PageGeometry.create(
          width: 100,
          height: 100,
          margins: PageMargins.all(20),
          bleed: PageBleed(50),
        );
        // Content (20,20,60,60) expanded by 50 on all sides.
        expect(
          page.bleedBounds,
          const BleedBounds(left: -30, top: -30, width: 160, height: 160),
        );
        expect(page.bleedFitsPage, isFalse);
      },
    );

    test('bleed 0 leaves bleedBounds equal to contentBounds', () {
      final page = PageGeometry.create(
        width: 100,
        height: 100,
        margins: PageMargins.all(10),
      );
      final b = page.bleedBounds;
      final c = page.contentBounds;
      expect(b.left, c.left);
      expect(b.top, c.top);
      expect(b.width, c.width);
      expect(b.height, c.height);
    });

    test('invalid dimensions rejected (fail closed)', () {
      expect(
        () => PageGeometry.create(width: 0, height: 10),
        throwsArgumentError,
      );
      expect(
        () => PageGeometry.create(width: -5, height: 10),
        throwsArgumentError,
      );
      expect(
        () => PageGeometry.create(width: double.nan, height: 10),
        throwsArgumentError,
      );
      expect(
        () => PageGeometry.create(width: 10, height: double.infinity),
        throwsArgumentError,
      );
      expect(
        () => PageGeometry.create(
          width: PageGeometry.maxDimension + 1,
          height: 10,
        ),
        throwsArgumentError,
      );
    });

    test('margins consuming the page rejected', () {
      // Horizontal consumption: left + right == width.
      expect(
        () => PageGeometry.create(
          width: 100,
          height: 100,
          margins: PageMargins.create(left: 60, right: 40),
        ),
        throwsArgumentError,
      );
      // Vertical consumption: top + bottom > height.
      expect(
        () => PageGeometry.create(
          width: 100,
          height: 100,
          margins: PageMargins.create(top: 50, bottom: 51),
        ),
        throwsArgumentError,
      );
    });

    test('bleed validation happens at the PageBleed level (finite, >= 0)', () {
      // Negative / non-finite bleed is rejected before the page is built.
      expect(
        () => PageGeometry.create(
          width: 100,
          height: 100,
          bleed: PageBleed.create(-1),
        ),
        throwsArgumentError,
      );
      expect(
        () => PageGeometry.create(
          width: 100,
          height: 100,
          bleed: PageBleed.create(double.nan),
        ),
        throwsArgumentError,
      );
      // There is no upper bound on bleed size: it may cross the page edge
      // (full-bleed pages); see the BleedBounds semantics.
      expect(
        PageGeometry.create(
          width: 100,
          height: 100,
          margins: PageMargins.all(10),
          bleed: PageBleed.create(9999),
        ).bleedFitsPage,
        isFalse,
      );
    });

    test('copyWith is validated', () {
      final page = PageGeometry.create(width: 100, height: 100);
      final bigger = page.copyWith(width: 120);
      expect(bigger.width, 120);
      expect(page.width, 100);
      expect(
        () => page.copyWith(margins: PageMargins.create(left: 101)),
        throwsArgumentError,
      );
    });

    test('JSON roundtrip preserves margins and bleed', () {
      final page = PageGeometry.create(
        width: 612,
        height: 792,
        margins: PageMargins.create(top: 72, right: 72, bottom: 72, left: 72),
        bleed: PageBleed(12),
      );
      final decoded = PageGeometry.decodeJson(page.toJson());
      expect(decoded, page);
      expect(decoded!.margins, page.margins);
      expect(decoded.bleed, page.bleed);
    });

    test('JSON tolerates int numbers and missing optional blocks', () {
      final decoded = PageGeometry.decodeJson(<String, Object?>{
        'width': 100,
        'height': 100,
      });
      expect(decoded, PageGeometry.create(width: 100, height: 100));
      final withBleed = PageGeometry.decodeJson(<String, Object?>{
        'width': 100,
        'height': 100,
        'bleed': 8,
      });
      expect(withBleed!.bleed, PageBleed(8));
    });

    test('legacy/missing page data decodes to null (no page)', () {
      expect(PageGeometry.decodeJson(null), isNull);
    });

    test('present but incomplete page data fails closed', () {
      expect(
        () => PageGeometry.decodeJson(<String, Object?>{}),
        throwsFormatException,
      );
      expect(
        () => PageGeometry.decodeJson(<String, Object?>{'height': 100}),
        throwsFormatException,
      );
      expect(() => PageGeometry.decodeJson('page'), throwsFormatException);
      expect(
        () => PageGeometry.decodeJson(<String, Object?>{
          'width': 100,
          'height': 100,
          'bleed': -1,
        }),
        throwsFormatException,
      );
      expect(
        () => PageGeometry.decodeJson(<String, Object?>{
          'width': 100,
          'height': 100,
          'margins': {'left': 101},
        }),
        throwsArgumentError,
      );
    });
  });
}
