import 'package:flutter_border_beam/flutter_border_beam.dart';

import 'playground_state.dart';

/// Builds the Dart snippet that reproduces [state].
///
/// The effect is always written out — it is the one choice every beam makes
/// — and every other field only when it differs from what the package
/// resolves on its own, so the default configuration prints a three-liner.
/// The result is paste-able as written: `const` sits on every value object,
/// and the one transform that cannot be const ([BeamColors.scaleAlpha]) is
/// emitted as a method call on a const palette.
///
/// The values a pointer, a controller, or a live signal supply print as the
/// variables the surrounding widget would hold, declared in a preamble.
String buildSnippet(PlaygroundState state) {
  final buffer = StringBuffer();
  for (final line in _preamble(state)) {
    buffer.writeln(line);
  }
  if (buffer.isNotEmpty) buffer.writeln();

  var body = _beam(state);
  if (state.syncDemo) {
    final beams = [
      for (var i = 0; i < 3; i++)
        '${_indent(_beam(state, synced: true, phaseOffset: i / 3), '    ')},',
    ].join('\n');
    body = _wrap('BeamSync', [
      if (!state.active) 'active: false,',
      if (state.speed != 1) 'speed: ${_num(state.speed)},',
      if (state.reducedMotion case final BeamReducedMotion mode)
        'reducedMotion: BeamReducedMotion.${mode.name},',
      '// One clock for the group; each beam has its own phase offset.',
    ], 'Column(\n  children: [\n$beams\n  ],\n)');
  }
  if (state.themeDemo) {
    body = _wrap('BorderBeamTheme', [
      'data: const BorderBeamThemeData(',
      '  style: BeamStyle(colors: BeamColors.ocean),',
      '  shape: BeamShape.all(20, superellipse: true),',
      '),',
    ], body);
  }
  return (buffer..write(body)).toString();
}

// The declarations the beam's arguments refer to.
List<String> _preamble(PlaygroundState state) => [
  if (state.controllerMode && !state.syncDemo) ...[
    'final controller = BorderBeamController();',
    '// controller.start() / .pause() / .resume() / .stop()',
    '// controller.pulse() / .flash()',
    '// controller.speed = ${_num(state.controllerSpeed)};',
  ],
  if (state.strengthSignal)
    'final level = ValueNotifier<double>(1); // drive from your own signal',
  if (state.followsPointer && !state.syncDemo)
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
String _beam(
  PlaygroundState state, {
  bool synced = false,
  double? phaseOffset,
}) {
  final args = <String>['effect: ${_effect(state)}'];

  if (state.hasColors) args.add('colors: ${_colors(state)}');
  if (!synced && state.buildActive() == false) args.add('active: false');

  final shape = _shape(state);
  if (shape != null) args.add(shape);

  final style = _block(_style(state));
  if (style != null) args.add('style: const BeamStyle(\n$style\n  )');

  final timing = _block(
    _timing(state, synced: synced, phaseOffset: phaseOffset),
  );
  if (timing != null) args.add('timing: const BeamTiming(\n$timing\n  )');

  final playback = _block(_playback(state, synced: synced));
  if (playback != null) {
    args.add('playback: const BeamPlayback(\n$playback\n  )');
  }

  if (state.buildProgress() case final double progress) {
    args.add('progress: ${_num(progress)}');
  }
  if (state.followsPointer && !synced) args.add('follow: pointer');
  if (state.strengthSignal) args.add('strengthListenable: level');

  if (state.controllerMode && !synced) args.add('controller: controller');
  args.add('child: child');

  return 'BorderBeam(\n  ${args.join(',\n  ')},\n)';
}

// `const BeamEffect.<name>(…)`, with only the parameters that differ from
// the effect's own defaults.
String _effect(PlaygroundState state) {
  final params = switch (state.buildEffect()) {
    RotateEffect(:final length, :final count, :final comet) => [
      if (length != const RotateEffect().length) 'length: ${_num(length)}',
      if (count != const RotateEffect().count) 'count: $count',
      if (comet) 'comet: true',
    ],
    LineEffect(:final edge) => [
      if (edge != const LineEffect().edge) 'edge: BeamEdge.${edge.name}',
    ],
    ShimmerEffect(:final angle) => [
      if (angle != const ShimmerEffect().angle) 'angle: ${_num(angle)}',
    ],
    _ => const <String>[],
  };
  return 'const BeamEffect.${state.effect.id}(${params.join(', ')})';
}

String _colors(PlaygroundState state) {
  final base = switch (state.paletteMode) {
    PaletteMode.preset => _preset(state.preset),
    PaletteMode.custom => _customColors(state),
    PaletteMode.seed => _seedColors(state),
    PaletteMode.lerp =>
      'const BeamColors.lerp(${_preset(state.lerpFrom)}, '
          '${_preset(state.lerpTo)}, ${_num(state.lerpT)})',
  };
  return state.alphaScale == 1
      ? base
      : '$base.scaleAlpha(${_num(state.alphaScale)})';
}

String _preset(String name) =>
    'BeamColors.${BeamColors.presets.containsKey(name) ? name : 'colorful'}';

String _customColors(PlaygroundState state) {
  final colors = [
    for (final i in state.customColors)
      _color(customSwatches[i].color.toARGB32()),
  ];
  return 'const BeamColors([${colors.join(', ')}])';
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
  if (state.radiusOnly) return 'borderRadius: ${_num(state.radius)}';

  final extras = <String>[
    if (state.borderWidth != 1) 'borderWidth: ${_num(state.borderWidth)}',
    if (state.superellipse) 'superellipse: true',
    if (state.ringOffset != 0) 'ringOffset: ${_num(state.ringOffset)}',
    if (state.segmentPreset != SegmentPreset.off) 'segment: ${_segment(state)}',
    if (state.dashes case final int count) 'dashes: $count',
  ];

  if (state.perCorner && !state.stadium) {
    final radii = [
      'topLeft: Radius.circular(${_num(state.radiusTopLeft)})',
      'topRight: Radius.circular(${_num(state.radiusTopRight)})',
      'bottomRight: Radius.circular(${_num(state.radiusBottomRight)})',
      'bottomLeft: Radius.circular(${_num(state.radiusBottomLeft)})',
    ];
    final lines = [
      'radius: BorderRadius.only(\n      ${radii.join(',\n      ')},\n    ),',
      for (final field in extras) '$field,',
    ];
    return 'shape: const BeamShape(\n    ${lines.join('\n    ')}\n  )';
  }

  final args = state.stadium ? extras : [_num(state.radius), ...extras];
  final head = state.stadium ? 'BeamShape.stadium' : 'BeamShape.all';
  return 'shape: const $head(${args.join(', ')})';
}

String _segment(PlaygroundState state) => switch (state.segmentPreset) {
  SegmentPreset.off => throw StateError('Off has no BeamSegment'),
  SegmentPreset.custom =>
    'BeamSegment(start: '
        '${_edgeAnchor(state.segmentStartEdge, state.segmentStartT)}, '
        'end: ${_edgeAnchor(state.segmentEndEdge, state.segmentEndT)}, '
        'feather: ${_num(state.segmentFeather)})',
  final SegmentPreset preset => 'BeamSegment.${preset.id}',
};

String _edgeAnchor(BeamEdge edge, double t) => t == 0.5
    ? 'BeamAnchor.edge(BeamEdge.${edge.name})'
    : 'BeamAnchor.edge(BeamEdge.${edge.name}, ${_num(t)})';

List<String> _style(PlaygroundState state) => [
  if (state.beamTheme case final BeamTheme theme)
    'theme: BeamTheme.${theme.name}',
  if (state.strength != 1) 'strength: ${_num(state.strength)}',
  if (state.glow != 1) 'glow: ${_num(state.glow)}',
  if (state.hueShiftApplies && state.hueShift != 30)
    'hueShift: ${_num(state.hueShift)}',
  if (state.hueMode case final BeamHueMode mode)
    'hueMode: BeamHueMode.${mode.name}',
  if (state.hueBase != 0) 'hueBase: ${_num(state.hueBase)}',
];

List<String> _timing(
  PlaygroundState state, {
  bool synced = false,
  double? phaseOffset,
}) {
  final phase = phaseOffset ?? state.phaseOffset;
  return [
    if (state.cycleSeconds case final double v) 'cycle: ${_duration(v)}',
    if (state.travels && state.cycleGapSeconds != null)
      'cycleGap: ${_duration(state.cycleGapSeconds!)}',
    if (state.speed != 1 && !state.controllerMode && !synced)
      'speed: ${_num(state.speed)}',
    if (state.directionApplies && state.direction != BeamDirection.forward)
      'direction: BeamDirection.${state.direction.name}',
    if (phase != 0) 'phaseOffset: ${_num(phase)}',
    if (state.hueDrifts && state.huePeriodSeconds != null)
      'huePeriod: ${_duration(state.huePeriodSeconds!)}',
  ];
}

List<String> _playback(PlaygroundState state, {bool synced = false}) {
  if (synced) return const [];
  // A controller owns scheduling exclusively; repeat and reduced motion stay
  // the beam's own either way.
  final scheduled = !state.controllerMode;
  return [
    if (scheduled && state.startAfterSeconds != 0)
      'startAfter: ${_duration(state.startAfterSeconds)}',
    if (scheduled && state.durationSeconds != 0)
      'duration: ${_duration(state.durationSeconds)}',
    if (state.repeatCycles case final int cycles) 'repeat: ${_repeat(cycles)}',
    if (state.reducedMotion case final BeamReducedMotion v)
      'reducedMotion: BeamReducedMotion.${v.name}',
    if (state.pauseWhenOffscreen case final bool value)
      'pauseWhenOffscreen: $value',
    if (state.cssFadeCurve) 'fadeCurve: BeamPlayback.cssEase',
  ];
}

// The body of a multi-line value-object argument, or null when it is empty.
String? _block(List<String> fields) =>
    fields.isEmpty ? null : '    ${fields.join(',\n    ')},';

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
