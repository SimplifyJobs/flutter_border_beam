// Throwaway visual harness: renders effects to PNGs for review.
// Not part of the suite — deleted before merge.
//
// ONLY=ref,fx,time,shapes,shim,pal selects groups (default: all); FX=rotate,line
// keeps scenes whose name starts with one of the prefixes. Writes to
// renders/laneA/<group>/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

const out =
    '/private/tmp/claude-501/-Users-rehmatsg-Desktop-Development-border-beam/60ad29b9-aa67-49c3-b5bf-373437975086/scratchpad/renders/laneA';

const _effects = <String, BeamEffect>{
  'rotate': BeamEffect.rotate(),
  'line': BeamEffect.line(),
  'pulse': BeamEffect.pulse(),
  'halo': BeamEffect.halo(),
  'flow': BeamEffect.flow(),
  'spin': BeamEffect.spin(),
  'shimmer': BeamEffect.shimmer(),
  'charge': BeamEffect.charge(),
};

class Scene {
  const Scene(
    this.group,
    this.name,
    this.effect, {
    this.dark = true,
    this.colors = BeamColors.colorful,
    this.shape,
    this.size = const Size(350, 140),
    this.radius = 16,
    this.at = const Duration(milliseconds: 1300),
    this.margin = 64,
    this.style,
    this.progress,
    this.stadium = false,
  });

  final String group;
  final String name;
  final BeamEffect effect;
  final bool dark;
  final BeamColors colors;
  final BeamShape? shape;
  final Size size;
  final double radius;
  final Duration at;
  final double margin;
  final BeamStyle? style;
  final double? progress;
  final bool stadium;
}

Widget build(Scene s) {
  final dark = s.dark;
  final brightness = dark ? Brightness.dark : Brightness.light;
  final radius = s.stadium
      ? BorderRadius.circular(s.size.shortestSide / 2)
      : BorderRadius.circular(s.radius);
  final squircle = s.shape?.superellipse ?? false;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      backgroundColor: dark ? const Color(0xFF070707) : const Color(0xFFFDFDFD),
      body: Center(
        child: RepaintBoundary(
          key: const ValueKey('shot'),
          child: ColoredBox(
            color: dark ? const Color(0xFF070707) : const Color(0xFFFDFDFD),
            child: Padding(
              padding: EdgeInsets.all(s.margin),
              child: BorderBeam(
                effect: s.effect,
                colors: s.colors,
                shape:
                    s.shape ??
                    (s.stadium
                        ? const BeamShape.stadium()
                        : BeamShape(radius: radius)),
                style: s.style,
                progress: s.progress,
                playback: BeamPlayback(debugFrozenAt: s.at),
                child: SizedBox.fromSize(
                  size: s.size,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: dark ? const Color(0xFF1D1D1D) : Colors.white,
                      shape: squircle
                          ? RoundedSuperellipseBorder(
                              borderRadius: radius,
                              side: BorderSide(
                                color: dark
                                    ? const Color(0x14FFFFFF)
                                    : const Color(0x14000000),
                              ),
                            )
                          : RoundedRectangleBorder(
                              borderRadius: radius,
                              side: BorderSide(
                                color: dark
                                    ? const Color(0x14FFFFFF)
                                    : const Color(0x14000000),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> shoot(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('shot')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

String _t(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(1);

List<Scene> scenes() {
  final list = <Scene>[];
  // Reference comparisons against the old goldens.
  for (final dark in [true, false]) {
    final th = dark ? 'dark' : 'light';
    for (final e in ['rotate', 'line', 'pulse', 'halo']) {
      for (final p in {
        'colorful': BeamColors.colorful,
        'mono': BeamColors.mono,
        'ocean': BeamColors.ocean,
        'sunset': BeamColors.sunset,
      }.entries) {
        list.add(
          Scene(
            'ref',
            '${e}_${th}_${p.key}',
            _effects[e]!,
            dark: dark,
            colors: p.value,
          ),
        );
      }
    }
    list
      ..add(
        Scene(
          'ref',
          'rotate_${th}_colorful_late',
          _effects['rotate']!,
          dark: dark,
          at: const Duration(milliseconds: 2300),
        ),
      )
      ..add(
        Scene(
          'ref',
          'line_${th}_colorful_late',
          _effects['line']!,
          dark: dark,
          at: const Duration(milliseconds: 2000),
        ),
      )
      ..add(
        Scene(
          'ref',
          'small_${th}_colorful',
          _effects['rotate']!,
          dark: dark,
          size: const Size(120, 36),
          radius: 18,
          margin: 40,
        ),
      )
      ..add(
        Scene(
          'ref',
          'small_${th}_mono',
          _effects['rotate']!,
          dark: dark,
          size: const Size(120, 36),
          radius: 18,
          margin: 40,
          colors: BeamColors.mono,
        ),
      );
  }
  // Every effect, both themes.
  for (final e in _effects.entries) {
    for (final dark in [true, false]) {
      list.add(
        Scene('fx', '${e.key}_${dark ? 'dark' : 'light'}', e.value, dark: dark),
      );
    }
  }
  // Motion samples.
  for (final e in _effects.entries) {
    for (final ms in [300, 800, 1300, 2000, 2700]) {
      final at = Duration(milliseconds: ms);
      list.add(Scene('time', '${e.key}_t${_t(at)}', e.value, at: at));
    }
  }
  // Shapes and sizes.
  for (final e in _effects.entries) {
    for (final dark in [true, false]) {
      final th = dark ? 'dark' : 'light';
      list
        ..add(
          Scene(
            'shapes',
            '${e.key}_${th}_chip',
            e.value,
            dark: dark,
            size: const Size(120, 36),
            radius: 18,
            margin: 40,
          ),
        )
        ..add(
          Scene(
            'shapes',
            '${e.key}_${th}_stadium',
            e.value,
            dark: dark,
            size: const Size(220, 56),
            stadium: true,
            margin: 48,
          ),
        );
    }
    list
      ..add(
        Scene(
          'shapes',
          '${e.key}_large',
          e.value,
          size: const Size(390, 700),
          radius: 28,
          margin: 64,
        ),
      )
      ..add(
        Scene(
          'shapes',
          '${e.key}_squircle',
          e.value,
          shape: const BeamShape(
            radius: BorderRadius.all(Radius.circular(24)),
            superellipse: true,
          ),
          radius: 24,
        ),
      )
      ..add(
        Scene(
          'shapes',
          '${e.key}_bottomhalf',
          e.value,
          shape: const BeamShape(segment: BeamSegment.bottomHalf),
        ),
      )
      ..add(
        Scene(
          'shapes',
          '${e.key}_dashes8',
          e.value,
          shape: const BeamShape(dashes: 8),
        ),
      )
      ..add(
        Scene(
          'shapes',
          '${e.key}_ring8',
          e.value,
          shape: const BeamShape(ringOffset: 8),
        ),
      );
  }
  list
    ..add(const Scene('shapes', 'rotate_count3', BeamEffect.rotate(count: 3)))
    ..add(
      const Scene(
        'shapes',
        'rotate_count3_light',
        BeamEffect.rotate(count: 3),
        dark: false,
      ),
    )
    ..add(const Scene('shapes', 'rotate_comet', BeamEffect.rotate(comet: true)))
    ..add(
      const Scene(
        'shapes',
        'rotate_comet_light',
        BeamEffect.rotate(comet: true),
        dark: false,
      ),
    )
    ..add(
      const Scene('shapes', 'charge_p35', BeamEffect.charge(), progress: 0.35),
    )
    ..add(
      const Scene(
        'shapes',
        'charge_p80_light',
        BeamEffect.charge(),
        progress: 0.8,
        dark: false,
      ),
    );
  // Shimmer through its sweep.
  for (final dark in [true, false]) {
    for (final ms in [200, 450, 700, 950, 1200]) {
      final at = Duration(milliseconds: ms);
      list
        ..add(
          Scene(
            'shim',
            'shimmer_${dark ? 'dark' : 'light'}_t${_t(at)}',
            _effects['shimmer']!,
            dark: dark,
            at: at,
          ),
        )
        ..add(
          Scene(
            'shim',
            'shimmerchip_${dark ? 'dark' : 'light'}_t${_t(at)}',
            _effects['shimmer']!,
            dark: dark,
            at: at,
            size: const Size(120, 36),
            radius: 18,
            margin: 40,
          ),
        );
    }
  }
  // Palettes.
  for (final e in _effects.entries) {
    for (final p in {
      'mono': BeamColors.mono,
      'ocean': BeamColors.ocean,
      'sunset': BeamColors.sunset,
      'gold': BeamColors.gold,
      'neon': BeamColors.neon,
    }.entries) {
      for (final dark in [true, false]) {
        list.add(
          Scene(
            'pal',
            '${e.key}_${p.key}_${dark ? 'dark' : 'light'}',
            e.value,
            dark: dark,
            colors: p.value,
          ),
        );
      }
    }
  }
  return list;
}

void main() {
  setUpAll(() async {
    await BorderBeam.precache();
  });

  final only = Platform.environment['ONLY']?.split(',');
  final fx = Platform.environment['FX']?.split(',');
  for (final s in scenes()) {
    if (only != null && !only.contains(s.group)) continue;
    if (fx != null && !fx.any((f) => s.name.startsWith(f))) continue;
    testWidgets('${s.group}/${s.name}', (tester) async {
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.binding.setSurfaceSize(const Size(900, 1000));
      await tester.pumpWidget(build(s));
      await tester.pump();
      await shoot(tester, '$out/${s.group}/${s.name}.png');
    });
  }
}
