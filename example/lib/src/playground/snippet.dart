import 'package:flutter_border_beam/flutter_border_beam.dart';

import 'playground_state.dart';

/// Builds the Dart snippet that reproduces [state].
///
/// Only fields that differ from what the package resolves on its own are
/// emitted, so the default configuration prints the one-liner. The result is
/// paste-able as written: `const` sits on every value object that can carry
/// it, and the two constructions that cannot be const (a runtime-built
/// [BeamShape.circular], and a [BorderBeamThemeData] holding one) are
/// emitted without it.
///
/// Two things a snippet cannot carry are named rather than pretended: a
/// [BeamPathContour] takes a builder function, so it prints as a commented
/// placeholder, and the values a pointer or a live signal supply print as
/// the variables the surrounding widget would hold.
String buildSnippet(PlaygroundState state) {
  final buffer = StringBuffer();
  for (final line in _preamble(state)) {
    buffer.writeln(line);
  }
  if (buffer.isNotEmpty) buffer.writeln();

  var body = _beam(state);
  if (state.syncDemo) {
    body = _wrap('BeamSync', [
      '// One clock for the group; each beam sets its own '
          'timing.phaseOffset.',
    ], body);
  }
  if (state.themeDemo) {
    body = _wrap('BorderBeamTheme', [
      'data: BorderBeamThemeData(',
      '  style: const BeamStyle(colors: BeamColors.ocean),',
      '  shape: BeamShape.circular(20, superellipse: true),',
      '),',
    ], body);
  }
  return (buffer..write(body)).toString();
}

// The declarations the beam's arguments refer to.
List<String> _preamble(PlaygroundState state) => [
  if (state.controllerMode) ...[
    'final controller = BorderBeamController();',
    '// controller.start() / .pause() / .resume() / .stop()',
    '// controller.pulse() / .flash()',
    '// controller.speed = ${_num(state.controllerSpeed)};',
  ],
  if (state.strengthSignal)
    'final level = ValueNotifier<double>(1); // drive from your own signal',
  if (state.followsPointer)
    '// pointer: the normalized pointer position (0–1 on each axis), from a '
        'MouseRegion or a Listener.',
];

// Wraps [child] in [name], with [header] lines above the `child:` argument.
String _wrap(String name, List<String> header, String child) {
  final buffer = StringBuffer('$name(\n');
  for (final line in header) {
    buffer.writeln('  $line');
  }
  return (buffer
        ..writeln('  child: ${_indent(child, '  ').trimLeft()},')
        ..write(')'))
      .toString();
}

// The BorderBeam call itself.
String _beam(PlaygroundState state) {
  final args = <String>[];

  if (state.hasColors) args.add('colors: ${_colors(state)}');
  if (state.buildActive() == false) args.add('active: false');

  final shape = _shape(state);
  if (shape != null) args.add(shape);

  final style = _style(state);
  if (style != null) {
    args.add(
      state.usesStockPulseOutside
          ? 'style: $style'
          : 'style: const BeamStyle(\n$style\n  )',
    );
  }

  final timing = _timing(state);
  if (timing != null) args.add('timing: const BeamTiming(\n$timing\n  )');

  final playback = _playback(state);
  if (playback != null) {
    args.add('playback: const BeamPlayback(\n$playback\n  )');
  }

  if (state.buildProgress() case final double progress) {
    args.add('progress: ${_num(progress)}');
  }
  if (state.followsPointer) args.add('follow: pointer');
  if (state.strengthSignal) args.add('strengthListenable: level');

  if (state.controllerMode) args.add('controller: controller');
  args.add('child: child');

  final name = _constructorNames[state.variant]!;
  return 'BorderBeam.$name(\n  ${args.join(',\n  ')},\n)';
}

String _colors(PlaygroundState state) {
  final base = switch (state.palette) {
    PalettePreset.custom => _customColors(state),
    PalettePreset.seed => _seedColors(state),
    PalettePreset.lerp =>
      'const BeamColors.lerp(${_preset(state.lerpFrom)}, '
          '${_preset(state.lerpTo)}, ${_num(state.lerpT)})',
    _ => _preset(state.palette),
  };
  return state.alphaScale == 1
      ? base
      : '$base.scaleAlpha(${_num(state.alphaScale)})';
}

String _preset(PalettePreset preset) =>
    'BeamColors.'
    '${preset.colors == null ? PalettePreset.colorful.id : preset.id}';

String _customColors(PlaygroundState state) {
  final colors = [
    for (final i in state.customColors)
      _color(customSwatches[i].color.toARGB32()),
  ];
  final base = state.customBase == PalettePreset.colorful
      ? ''
      : ', base: ${_preset(state.customBase)}';
  return 'const BeamColors.custom([${colors.join(', ')}]$base)';
}

String _seedColors(PlaygroundState state) {
  final harmony = state.seedHarmony == BeamSeedHarmony.analogous
      ? ''
      : ', harmony: BeamSeedHarmony.${state.seedHarmony.name}';
  final seed = _color(customSwatches[state.seedColor].color.toARGB32());
  return 'const BeamColors.fromSeed($seed$harmony)';
}

String _color(int argb) =>
    'Color(0x${argb.toRadixString(16).toUpperCase().padLeft(8, '0')})';

// The `borderRadius:` shorthand when a plain radius is all that changed,
// otherwise a full BeamShape. `BeamShape.all` stores the radius as a number
// instead of building a BorderRadius, which is what keeps it const.
String? _shape(PlaygroundState state) {
  if (!state.hasShape) return null;
  final isLine = state.variant == BeamVariant.line;
  final extras = <String>[
    if (state.borderWidth != 1) 'borderWidth: ${_num(state.borderWidth)}',
    if (state.superellipse) 'superellipse: true',
    if (isLine && state.edge != BeamEdge.bottom)
      'edge: BeamEdge.${state.edge.name}',
    if (state.ringOffset != 0) 'ringOffset: ${_num(state.ringOffset)}',
  ];
  final contour = state.contour ? _contourPlaceholder : null;

  if (state.perCorner && !state.stadium) {
    final radii = [
      'topLeft: Radius.circular(${_num(state.radiusTopLeft)})',
      'topRight: Radius.circular(${_num(state.radiusTopRight)})',
      'bottomRight: Radius.circular(${_num(state.radiusBottomRight)})',
      'bottomLeft: Radius.circular(${_num(state.radiusBottomLeft)})',
    ];
    return _shapeBlock('const BeamShape', [
      'radius: BorderRadius.only(\n      ${radii.join(',\n      ')},\n    ),',
      for (final field in extras) '$field,',
      ?contour,
    ]);
  }

  final head = state.stadium
      ? 'const BeamShape.stadium'
      : 'const BeamShape.all';
  final positional = state.stadium ? <String>[] : [_num(state.radius)];
  if (contour != null) {
    return _shapeBlock(head, [
      for (final field in [...positional, ...extras]) '$field,',
      contour,
    ]);
  }
  if (!state.stadium && extras.isEmpty) {
    return 'borderRadius: ${_num(state.radius)}';
  }
  return 'shape: $head(${[...positional, ...extras].join(', ')})';
}

// A BeamPathContour takes a builder, which a generated snippet cannot write
// for you — the placeholder names the field and the key it compares on.
const String _contourPlaceholder =
    "// contour: BeamPathContour(builder: yourPath, key: 'star'),";

String _shapeBlock(String head, List<String> lines) =>
    'shape: $head(\n    ${lines.join('\n    ')}\n  )';

String? _style(PlaygroundState state) {
  final isPulse = state.variant.isPulse;
  final isOutside = state.variant == BeamVariant.pulseOutside;
  // The four glow overrides only reach the painter on pulse-outside.
  final coreBlur = isOutside ? state.coreBlur : null;
  final bloomBlur = isOutside ? state.bloomBlur : null;
  final glowBrightness = isOutside ? state.glowBrightness : null;
  final glowSaturation = isOutside ? state.glowSaturation : null;
  final segments = state.variant == BeamVariant.line ? null : state.segments;
  final fields = [
    if (state.strength != 1) 'strength: ${_num(state.strength)}',
    if (state.brightness case final double v) 'brightness: ${_num(v)}',
    if (state.saturation case final double v) 'saturation: ${_num(v)}',
    if (state.hueRange != 30) 'hueRange: ${_num(state.hueRange)}',
    if (state.hueMode case final BeamHueMode v)
      'hueMode: BeamHueMode.${v.name}',
    if (state.hueBase != 0) 'hueBase: ${_num(state.hueBase)}',
    if (state.staticColors) 'staticColors: true',
    if (state.strokeOpacityFactor != 1)
      'strokeOpacityFactor: ${_num(state.strokeOpacityFactor)}',
    if (state.innerOpacityFactor != 1)
      'innerOpacityFactor: ${_num(state.innerOpacityFactor)}',
    if (state.bloomOpacityFactor != 1)
      'bloomOpacityFactor: ${_num(state.bloomOpacityFactor)}',
    if (state.isRing && state.tailLength != 1)
      'tailLength: ${_num(state.tailLength)}',
    if (state.glowSpread != 1) 'glowSpread: ${_num(state.glowSpread)}',
    if (state.isRing && state.comet) 'comet: true',
    if (state.isTraveling && state.sparkle != 0)
      'sparkle: ${_num(state.sparkle)}',
    if (segments case final int v) 'segments: $v',
    if (state.variant == BeamVariant.pulseInside && state.innerSizeScale != 1)
      'innerSizeScale: ${_num(state.innerSizeScale)}',
    if (state.renderScale != 1) 'renderScale: ${_num(state.renderScale)}',
    if (isPulse && state.glowBoost != 1) 'glowBoost: ${_num(state.glowBoost)}',
    if (coreBlur case final double v) 'coreBlur: ${_num(v)}',
    if (bloomBlur case final double v) 'bloomBlur: ${_num(v)}',
    if (glowBrightness case final double v) 'glowBrightness: ${_num(v)}',
    if (glowSaturation case final double v) 'glowSaturation: ${_num(v)}',
  ];
  if (state.usesStockPulseOutside) {
    // The stock look is a whole style; merge layers the fields set here
    // over it, which is what the preview does too.
    return fields.isEmpty
        ? _stockStyle
        : '$_stockStyle.merge(\n    const BeamStyle(\n      '
              '${fields.join(',\n      ')},\n    ),\n  )';
  }
  return fields.isEmpty ? null : '    ${fields.join(',\n    ')},';
}

const String _stockStyle = 'BeamStyle.pulseOutsideStock';

String? _timing(PlaygroundState state) {
  final isLine = state.variant == BeamVariant.line;
  final travels = state.isTraveling;
  final fields = [
    if (state.cycleSeconds case final double v) 'cycle: ${_duration(v)}',
    if (state.cycleGapSeconds != 0)
      'cycleGap: ${_duration(state.cycleGapSeconds)}',
    if (state.speed != 1 && !state.controllerMode)
      'speed: ${_num(state.speed)}',
    if (travels && state.direction != BeamDirection.forward)
      'direction: BeamDirection.${state.direction.name}',
    if (travels && state.phaseOffset != 0)
      'phaseOffset: ${_num(state.phaseOffset)}',
    if (travels && state.beamCount != 1) 'beamCount: ${state.beamCount}',
    if (state.huePeriodSeconds case final double v)
      'huePeriod: ${_duration(v)}',
    if (isLine && state.breatheFactor != 1.3)
      'breatheFactor: ${_num(state.breatheFactor)}',
    if (isLine && state.spikeFactor != 1.33)
      'spikeFactor: ${_num(state.spikeFactor)}',
    if (isLine && state.spike2Factor != 1.7)
      'spike2Factor: ${_num(state.spike2Factor)}',
  ];
  return fields.isEmpty ? null : '    ${fields.join(',\n    ')},';
}

String? _playback(PlaygroundState state) {
  // A controller owns scheduling exclusively; repeat and reduced motion stay
  // the beam's own either way.
  final scheduled = !state.controllerMode;
  final fields = [
    if (scheduled && state.startAfterSeconds != 0)
      'startAfter: ${_duration(state.startAfterSeconds)}',
    if (scheduled && state.durationSeconds != 0)
      'duration: ${_duration(state.durationSeconds)}',
    if (state.repeatCycles case final int cycles) 'repeat: ${_repeat(cycles)}',
    if (state.reducedMotion case final BeamReducedMotion v)
      'reducedMotion: BeamReducedMotion.${v.name}',
    if (state.pauseWhenOffscreen) 'pauseWhenOffscreen: true',
    if (state.cssFadeCurve) 'fadeCurve: BeamPlayback.cssEase',
  ];
  return fields.isEmpty ? null : '    ${fields.join(',\n    ')},';
}

String _repeat(int cycles) =>
    cycles == 1 ? 'BeamRepeat.once()' : 'BeamRepeat.count($cycles)';

String _duration(double seconds) {
  final ms = (seconds * 1000).round();
  return ms % 1000 == 0
      ? 'Duration(seconds: ${ms ~/ 1000})'
      : 'Duration(milliseconds: $ms)';
}

/// Formats a double the way a hand-written argument would read: `2` rather
/// than `2.0`, `1.33` kept at the control's resolution.
String _num(double value) {
  final fixed = value.toStringAsFixed(2);
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _indent(String source, String prefix) =>
    source.split('\n').map((line) => '$prefix$line').join('\n');

const Map<BeamVariant, String> _constructorNames = {
  BeamVariant.rotate: 'rotate',
  BeamVariant.small: 'small',
  BeamVariant.line: 'line',
  BeamVariant.pulseInside: 'pulseInside',
  BeamVariant.pulseOutside: 'pulseOutside',
};
