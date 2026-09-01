import 'package:flutter_border_beam/flutter_border_beam.dart';

import 'playground_state.dart';

/// Where the example is published, used for the share link built off the web.
const String playgroundSiteUrl =
    'https://simplifyjobs.github.io/flutter_border_beam/';

/// Encodes [state] as a compact `key=value&key=value` string.
///
/// Only fields that differ from a fresh [PlaygroundState] are written, so the
/// default configuration encodes to the empty string. Every value is plain
/// ASCII (`[A-Za-z0-9.,-]`), so the result needs no percent-escaping in a
/// URL query or fragment.
String encodePlaygroundState(PlaygroundState state) {
  final d = PlaygroundState();
  final parts = <String>[];
  void put(String key, Object value) => parts.add('$key=$value');
  void number(String key, double value, double fallback) {
    if (value != fallback) put(key, _formatNumber(value));
  }

  void optional(String key, double? value) {
    if (value != null) put(key, _formatNumber(value));
  }

  void flag(String key, bool value) {
    if (value) put(key, 1);
  }

  if (state.variant != d.variant) put('v', _variantIds[state.variant]!);
  if (state.palette != d.palette) put('p', state.palette.id);
  if (state.palette == PalettePreset.custom) {
    put('cc', state.customColors.join(','));
  }

  flag('st', state.stadium);
  flag('pc', state.perCorner);
  number('r', state.radius, d.radius);
  number('rtl', state.radiusTopLeft, d.radiusTopLeft);
  number('rtr', state.radiusTopRight, d.radiusTopRight);
  number('rbr', state.radiusBottomRight, d.radiusBottomRight);
  number('rbl', state.radiusBottomLeft, d.radiusBottomLeft);
  flag('se', state.superellipse);
  number('bw', state.borderWidth, d.borderWidth);

  optional('cy', state.cycleSeconds);
  number('cg', state.cycleGapSeconds, d.cycleGapSeconds);
  number('sp', state.speed, d.speed);
  optional('hp', state.huePeriodSeconds);
  number('bf', state.breatheFactor, d.breatheFactor);
  number('sf', state.spikeFactor, d.spikeFactor);
  number('s2', state.spike2Factor, d.spike2Factor);
  flag('sc', state.staticColors);

  number('str', state.strength, d.strength);
  optional('br', state.brightness);
  optional('sa', state.saturation);
  number('hr', state.hueRange, d.hueRange);
  number('hb', state.hueBase, d.hueBase);
  number('so', state.strokeOpacityFactor, d.strokeOpacityFactor);
  number('io', state.innerOpacityFactor, d.innerOpacityFactor);
  number('bo', state.bloomOpacityFactor, d.bloomOpacityFactor);
  number('gb', state.glowBoost, d.glowBoost);
  optional('cb', state.coreBlur);
  optional('bb', state.bloomBlur);
  optional('gbr', state.glowBrightness);
  optional('gsa', state.glowSaturation);

  if (!state.active) put('a', 0);
  flag('cm', state.controllerMode);
  number('cs', state.controllerSpeed, d.controllerSpeed);
  number('sd', state.startAfterSeconds, d.startAfterSeconds);
  number('du', state.durationSeconds, d.durationSeconds);
  flag('th', state.themeDemo);

  return parts.join('&');
}

/// Decodes an [encodePlaygroundState] string back into a state.
///
/// Unknown keys, malformed pairs, and out-of-range values are ignored: the
/// corresponding field keeps its default, so a truncated or hand-edited link
/// still opens a usable playground.
PlaygroundState decodePlaygroundState(String encoded) {
  final state = PlaygroundState();
  final values = <String, String>{};
  for (final pair in encoded.split('&')) {
    if (pair.isEmpty) continue;
    final split = pair.indexOf('=');
    if (split <= 0) continue;
    values[pair.substring(0, split)] = pair.substring(split + 1);
  }

  double? read(String key, double min, double max) {
    final raw = values[key];
    if (raw == null) return null;
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed.isNaN || parsed < min || parsed > max) {
      return null;
    }
    return parsed;
  }

  bool? readFlag(String key) => switch (values[key]) {
    '1' => true,
    '0' => false,
    _ => null,
  };

  for (final entry in _variantIds.entries) {
    if (entry.value == values['v']) state.variant = entry.key;
  }
  for (final preset in PalettePreset.values) {
    if (preset.id == values['p']) state.palette = preset;
  }
  final colors = values['cc'];
  if (colors != null) {
    final parsed = [
      for (final part in colors.split(','))
        if (int.tryParse(part) case final int i)
          if (i >= 0 && i < customSwatches.length) i,
    ];
    if (parsed.length >= minCustomColors) {
      state.customColors = parsed.take(maxCustomColors).toList();
    }
  }

  state.stadium = readFlag('st') ?? state.stadium;
  state.perCorner = readFlag('pc') ?? state.perCorner;
  state.radius = read('r', 0, 48) ?? state.radius;
  state.radiusTopLeft = read('rtl', 0, 48) ?? state.radiusTopLeft;
  state.radiusTopRight = read('rtr', 0, 48) ?? state.radiusTopRight;
  state.radiusBottomRight = read('rbr', 0, 48) ?? state.radiusBottomRight;
  state.radiusBottomLeft = read('rbl', 0, 48) ?? state.radiusBottomLeft;
  state.superellipse = readFlag('se') ?? state.superellipse;
  state.borderWidth = read('bw', 0.5, 4) ?? state.borderWidth;

  state.cycleSeconds = read('cy', 0.5, 8);
  state.cycleGapSeconds = read('cg', 0, 4) ?? state.cycleGapSeconds;
  state.speed = read('sp', 0.25, 4) ?? state.speed;
  state.huePeriodSeconds = read('hp', 2, 30);
  state.breatheFactor = read('bf', 0.5, 3) ?? state.breatheFactor;
  state.spikeFactor = read('sf', 0.5, 3) ?? state.spikeFactor;
  state.spike2Factor = read('s2', 0.5, 3) ?? state.spike2Factor;
  state.staticColors = readFlag('sc') ?? state.staticColors;

  state.strength = read('str', 0, 1) ?? state.strength;
  state.brightness = read('br', 0.5, 3);
  state.saturation = read('sa', 0.5, 3);
  state.hueRange = read('hr', 0, 60) ?? state.hueRange;
  state.hueBase = read('hb', -180, 180) ?? state.hueBase;
  state.strokeOpacityFactor = read('so', 0, 2) ?? state.strokeOpacityFactor;
  state.innerOpacityFactor = read('io', 0, 2) ?? state.innerOpacityFactor;
  state.bloomOpacityFactor = read('bo', 0, 2) ?? state.bloomOpacityFactor;
  state.glowBoost = read('gb', 0, 3) ?? state.glowBoost;
  state.coreBlur = read('cb', 0, 60);
  state.bloomBlur = read('bb', 0, 120);
  state.glowBrightness = read('gbr', 0.5, 3);
  state.glowSaturation = read('gsa', 0.5, 3);

  state.active = readFlag('a') ?? state.active;
  state.controllerMode = readFlag('cm') ?? state.controllerMode;
  state.controllerSpeed = read('cs', 0.25, 4) ?? state.controllerSpeed;
  state.startAfterSeconds = read('sd', 0, 3) ?? state.startAfterSeconds;
  state.durationSeconds = read('du', 0, 15) ?? state.durationSeconds;
  state.themeDemo = readFlag('th') ?? state.themeDemo;

  return state;
}

/// Pulls a playground state string out of [uri].
///
/// Three shapes reproduce a configuration, and all three are accepted: the
/// query (`?v=line`), a bare fragment (`#v=line` — the form the share button
/// hands out off the web), and a fragment carrying a route and query
/// (`#/?v=line` — the form Flutter web's hash routing writes back). Returns
/// null when the URL carries no state.
String? playgroundStateStringFrom(Uri uri) {
  String? fromFragment(String fragment) {
    if (fragment.isEmpty) return null;
    final query = fragment.indexOf('?');
    if (query >= 0) return fragment.substring(query + 1);
    // A fragment that is only a route path carries no state.
    return fragment.startsWith('/') ? null : fragment;
  }

  final fragment = fromFragment(uri.fragment);
  if (fragment != null && fragment.isNotEmpty) return fragment;
  return uri.query.isEmpty ? null : uri.query;
}

/// The link that reproduces [encoded] on the published example site.
String playgroundShareUrl(String encoded) =>
    encoded.isEmpty ? playgroundSiteUrl : '$playgroundSiteUrl#$encoded';

const Map<BeamVariant, String> _variantIds = {
  BeamVariant.rotate: 'rotate',
  BeamVariant.small: 'small',
  BeamVariant.line: 'line',
  BeamVariant.pulseInside: 'pulse-inside',
  BeamVariant.pulseOutside: 'pulse-outside',
};

/// Formats a double as compactly as the two-decimal control resolution
/// allows: `1.5` stays `1.5`, `2.0` becomes `2`.
String _formatNumber(double value) {
  final fixed = value.toStringAsFixed(2);
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}
