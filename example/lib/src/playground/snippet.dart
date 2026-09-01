import 'package:flutter_border_beam/flutter_border_beam.dart';

import 'playground_state.dart';

/// Builds the Dart snippet that reproduces [state].
///
/// Only fields that differ from what the package resolves on its own are
/// emitted, so the default configuration prints the one-liner. The result is
/// paste-able as written: `const` sits on every value object that can carry
/// it, and the two constructions that cannot be const ([BeamShape.circular],
/// and a [BorderBeamThemeData] holding one) are emitted without it.
String buildSnippet(PlaygroundState state) {
  final buffer = StringBuffer();
  if (state.controllerMode) {
    buffer
      ..writeln('final controller = BorderBeamController();')
      ..writeln('// controller.start() / .pause() / .resume() / .stop()')
      ..writeln('// controller.speed = ${_num(state.controllerSpeed)};')
      ..writeln();
  }

  final beam = _beam(state);
  if (!state.themeDemo) return (buffer..write(beam)).toString();

  buffer
    ..writeln('BorderBeamTheme(')
    ..writeln('  data: BorderBeamThemeData(')
    ..writeln('    style: const BeamStyle(colors: BeamColors.ocean),')
    ..writeln('    shape: BeamShape.circular(20, superellipse: true),')
    ..writeln('  ),')
    ..writeln('  child: ${_indent(beam, '  ').trimLeft()},')
    ..write(')');
  return buffer.toString();
}

// The BorderBeam call itself.
String _beam(PlaygroundState state) {
  final args = <String>[];

  if (state.hasColors) args.add('colors: ${_colors(state)}');
  if (state.buildActive() == false) args.add('active: false');

  final shape = _shape(state);
  if (shape != null) args.add(shape);

  final style = _style(state);
  if (style != null) args.add('style: const BeamStyle(\n$style\n  )');

  final timing = _timing(state);
  if (timing != null) args.add('timing: const BeamTiming(\n$timing\n  )');

  final playback = _playback(state);
  if (playback != null) {
    args.add('playback: const BeamPlayback(\n$playback\n  )');
  }

  if (state.controllerMode) args.add('controller: controller');
  args.add('child: child');

  final name = _constructorNames[state.variant]!;
  return 'BorderBeam.$name(\n  ${args.join(',\n  ')},\n)';
}

String _colors(PlaygroundState state) {
  if (state.palette != PalettePreset.custom) {
    return 'BeamColors.${state.palette.id}';
  }
  final colors = [
    for (final i in state.customColors)
      _color(customSwatches[i].color.toARGB32()),
  ];
  return 'const BeamColors.custom([${colors.join(', ')}])';
}

String _color(int argb) =>
    'Color(0x${argb.toRadixString(16).toUpperCase().padLeft(8, '0')})';

// The `borderRadius:` shorthand when a plain radius is all that changed,
// otherwise a full BeamShape.
String? _shape(PlaygroundState state) {
  if (!state.hasShape) return null;
  final extras = [
    if (state.borderWidth != 1) 'borderWidth: ${_num(state.borderWidth)}',
    if (state.superellipse) 'superellipse: true',
  ];
  if (state.stadium) {
    return 'shape: const BeamShape.stadium(${extras.join(', ')})';
  }
  if (state.perCorner) {
    final radii = [
      'topLeft: Radius.circular(${_num(state.radiusTopLeft)})',
      'topRight: Radius.circular(${_num(state.radiusTopRight)})',
      'bottomRight: Radius.circular(${_num(state.radiusBottomRight)})',
      'bottomLeft: Radius.circular(${_num(state.radiusBottomLeft)})',
    ];
    final fields = [
      'radius: BorderRadius.only(\n      ${radii.join(',\n      ')},\n    )',
      ...extras,
    ];
    return 'shape: const BeamShape(\n    ${fields.join(',\n    ')},\n  )';
  }
  if (extras.isEmpty) return 'borderRadius: ${_num(state.radius)}';
  // BeamShape.circular builds a BorderRadius at runtime, so it is not const.
  return 'shape: BeamShape.circular(${_num(state.radius)}, '
      '${extras.join(', ')})';
}

String? _style(PlaygroundState state) {
  final isPulse = state.variant.isPulse;
  final isOutside = state.variant == BeamVariant.pulseOutside;
  // The four glow overrides only reach the painter on pulse-outside.
  final coreBlur = isOutside ? state.coreBlur : null;
  final bloomBlur = isOutside ? state.bloomBlur : null;
  final glowBrightness = isOutside ? state.glowBrightness : null;
  final glowSaturation = isOutside ? state.glowSaturation : null;
  final fields = [
    if (state.strength != 1) 'strength: ${_num(state.strength)}',
    if (state.brightness case final double v) 'brightness: ${_num(v)}',
    if (state.saturation case final double v) 'saturation: ${_num(v)}',
    if (state.hueRange != 30) 'hueRange: ${_num(state.hueRange)}',
    if (state.hueBase != 0) 'hueBase: ${_num(state.hueBase)}',
    if (state.staticColors) 'staticColors: true',
    if (state.strokeOpacityFactor != 1)
      'strokeOpacityFactor: ${_num(state.strokeOpacityFactor)}',
    if (state.innerOpacityFactor != 1)
      'innerOpacityFactor: ${_num(state.innerOpacityFactor)}',
    if (state.bloomOpacityFactor != 1)
      'bloomOpacityFactor: ${_num(state.bloomOpacityFactor)}',
    if (isPulse && state.glowBoost != 1) 'glowBoost: ${_num(state.glowBoost)}',
    if (coreBlur case final double v) 'coreBlur: ${_num(v)}',
    if (bloomBlur case final double v) 'bloomBlur: ${_num(v)}',
    if (glowBrightness case final double v) 'glowBrightness: ${_num(v)}',
    if (glowSaturation case final double v) 'glowSaturation: ${_num(v)}',
  ];
  return fields.isEmpty ? null : '    ${fields.join(',\n    ')},';
}

String? _timing(PlaygroundState state) {
  final isLine = state.variant == BeamVariant.line;
  final fields = [
    if (state.cycleSeconds case final double v) 'cycle: ${_duration(v)}',
    if (state.cycleGapSeconds != 0)
      'cycleGap: ${_duration(state.cycleGapSeconds)}',
    if (state.speed != 1 && !state.controllerMode)
      'speed: ${_num(state.speed)}',
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
  if (state.controllerMode) return null;
  final fields = [
    if (state.startAfterSeconds != 0)
      'startAfter: ${_duration(state.startAfterSeconds)}',
    if (state.durationSeconds != 0)
      'duration: ${_duration(state.durationSeconds)}',
  ];
  return fields.isEmpty ? null : '    ${fields.join(',\n    ')},';
}

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
