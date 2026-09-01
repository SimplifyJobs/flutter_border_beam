import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

const _blobA = BeamBlob(
  color: Color(0xFFFF3264),
  position: Offset(0.33, -0.074),
  size: Size(70, 40),
);
const _blobB = BeamBlob(
  color: Color(0xFF288CFF),
  position: Offset(0.12, -0.05),
  size: Size(60, 35),
);
const _lineBlob = LineBlob(
  color: Color(0xFFFF3264),
  sizeW: 120,
  sizeH: 30,
  offsetX: 0,
  offsetY: 2,
);

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  home: Scaffold(
    body: Center(child: SizedBox(width: 350, height: 140, child: child)),
  ),
);

BeamPainter _beamPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(BorderBeam),
        matching: find.byType(CustomPaint),
      ),
    )
    .expand((paint) => [paint.painter, paint.foregroundPainter])
    .whereType<BeamPainter>()
    .first;

void main() {
  group('BeamBlob equality', () {
    test('compares color, position and size', () {
      expect(
        _blobA,
        const BeamBlob(
          color: Color(0xFFFF3264),
          position: Offset(0.33, -0.074),
          size: Size(70, 40),
        ),
      );
      expect(
        _blobA.hashCode,
        _blobA.withColor(const Color(0xFFFF3264)).hashCode,
      );
      expect(_blobA, isNot(_blobB));
      expect(_blobA, isNot(_blobA.withColor(const Color(0xFF000000))));
      expect(_blobA.toString(), contains('BeamBlob'));
    });

    test('LineBlob compares every geometry field', () {
      expect(
        _lineBlob,
        const LineBlob(
          color: Color(0xFFFF3264),
          sizeW: 120,
          sizeH: 30,
          offsetX: 0,
          offsetY: 2,
        ),
      );
      expect(_lineBlob.hashCode, isNot(0));
      expect(
        _lineBlob,
        isNot(
          const LineBlob(
            color: Color(0xFFFF3264),
            sizeW: 120,
            sizeH: 30,
            offsetX: 1,
            offsetY: 2,
          ),
        ),
      );
      expect(_lineBlob.toString(), contains('LineBlob'));
    });
  });

  group('BeamColors equality', () {
    test('equal custom lists are == with equal hashCodes', () {
      final a = BeamColors.custom(const [Color(0xFFFF00AA), Color(0xFF00FFEE)]);
      final b = BeamColors.custom([
        const Color(0xFFFF00AA),
        const Color(0xFF00FFEE),
      ]);
      expect(identical(a, b), isFalse, reason: 'distinct instances');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('custom order and length are significant', () {
      final a = BeamColors.custom(const [Color(0xFFFF00AA), Color(0xFF00FFEE)]);
      final reordered = BeamColors.custom(const [
        Color(0xFF00FFEE),
        Color(0xFFFF00AA),
      ]);
      final shorter = BeamColors.custom(const [Color(0xFFFF00AA)]);
      expect(a, isNot(reordered));
      expect(a, isNot(shorter));
    });

    test('presets compare by identity of their table and mono flag', () {
      expect(BeamColors.ocean, BeamColors.ocean);
      expect(BeamColors.ocean.hashCode, BeamColors.ocean.hashCode);
      expect(BeamColors.ocean, isNot(BeamColors.sunset));
      expect(BeamColors.mono, isNot(BeamColors.colorful));
      expect(
        BeamColors.colorful,
        isNot(BeamColors.custom(const [Color(0xFFFF00AA)])),
      );
    });

    test('spec compares blob tables element-wise', () {
      const a = BeamColors.spec(border: [_blobA, _blobB]);
      const b = BeamColors.spec(border: [_blobA, _blobB]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const BeamColors.spec(border: [_blobB, _blobA])));
      expect(
        a,
        isNot(const BeamColors.spec(border: [_blobA, _blobB], lineBlobs: [])),
      );
      expect(
        const BeamColors.spec(border: [_blobA], smallBorder: [_blobB]),
        const BeamColors.spec(border: [_blobA], smallBorder: [_blobB]),
      );
      expect(
        const BeamColors.spec(border: [_blobA], smallBorder: [_blobB]),
        isNot(const BeamColors.spec(border: [_blobA])),
      );
      expect(
        const BeamColors.spec(border: [_blobA], lineBlobs: [_lineBlob]),
        const BeamColors.spec(border: [_blobA], lineBlobs: [_lineBlob]),
      );
    });
  });

  group('BeamColors.resolve', () {
    test('memoizes per instance', () {
      final custom = BeamColors.custom(const [Color(0xFFFF00AA)]);
      expect(identical(custom.resolve(), custom.resolve()), isTrue);
      expect(
        identical(BeamColors.ocean.resolve(), BeamColors.ocean.resolve()),
        isTrue,
      );
      const spec = BeamColors.spec(border: [_blobA]);
      expect(identical(spec.resolve(), spec.resolve()), isTrue);
    });

    test('custom distributes colors and preserves preset alpha', () {
      final palette = BeamColors.custom(const [Color(0xFFFF00AA)]).resolve();
      final reference = BeamColors.colorful.resolve();
      for (final (i, blob) in palette.data.smallInner.indexed) {
        expect(blob.color.r, closeTo(1, 1e-6));
        expect(blob.color.g, closeTo(0, 1e-6));
        expect(
          blob.color.a,
          closeTo(reference.data.smallInner[i].color.a, 1e-6),
        );
        expect(blob.position, reference.data.smallInner[i].position);
      }
      expect(palette.data.border.length, reference.data.border.length);
      expect(palette.data.lineBloomDark.length, 5);
      expect(palette.forcesStaticColors, isFalse);
    });

    test('mono preset carries the mono modifiers', () {
      final mono = BeamColors.mono.resolve();
      expect(mono.forcesStaticColors, isTrue);
      expect(mono.opacityMultiplier, 0.5);
      expect(mono.monoTreatment, isTrue);
    });

    test('spec keeps the given tables and derives the rest', () {
      const spec = BeamColors.spec(
        border: [_blobA, _blobB],
        smallBorder: [_blobA],
      );
      final palette = spec.resolve();
      final derived = BeamColors.custom(const [
        Color(0xFFFF3264),
        Color(0xFF288CFF),
      ]).resolve();
      expect(palette.data.border, const [_blobA, _blobB]);
      expect(palette.data.smallBorder, const [_blobA]);
      // smallInner is derived from the given smallBorder at 45% alpha.
      expect(
        palette.data.smallInner.single.color.a,
        closeTo(_blobA.color.a * 0.45, 1e-6),
      );
      // Untouched tables cycle the border colors over the default geometry.
      expect(palette.data.lineInner, derived.data.lineInner);
      expect(palette.data.lineBloomDark, derived.data.lineBloomDark);
      expect(palette.data.spike, derived.data.spike);
    });

    test('spec without a smallBorder derives one', () {
      const spec = BeamColors.spec(border: [_blobA]);
      final palette = spec.resolve();
      final derived = BeamColors.custom(const [Color(0xFFFF3264)]).resolve();
      expect(palette.data.smallBorder, derived.data.smallBorder);
      expect(palette.data.smallInner, derived.data.smallInner);
      expect(palette.data.lineDark, derived.data.lineDark);
    });
  });

  testWidgets('equal custom colors do not re-resolve the config', (
    tester,
  ) async {
    Widget build() => _host(
      BorderBeam.rotate(
        colors: BeamColors.custom([
          const Color(0xFFFF00AA),
          const Color(0xFF00FFEE),
        ]),
        child: const SizedBox.expand(),
      ),
    );

    await tester.pumpWidget(build());
    final first = _beamPainter(tester).config;
    // A fresh widget carrying a fresh — but equal — BeamColors instance.
    await tester.pumpWidget(build());
    expect(identical(_beamPainter(tester).config, first), isTrue);
  });
}
