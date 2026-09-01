import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';

import '../demo_theme.dart';
import 'playground_state.dart';

// The theme the "Theme demo" toggle installs above the preview.
final BorderBeamThemeData _demoThemeData = BorderBeamThemeData(
  style: const BeamStyle(colors: BeamColors.ocean),
  shape: BeamShape.circular(20, superellipse: true),
);

// The preview surface, and the frame that gives pulse-outside room to bloom.
const double _surfaceHeight = 128;
const double _maxSurfaceWidth = 320;
const double _frameHeight = 240;

class PlaygroundPreviews extends StatelessWidget {
  /// Creates the preview area.
  const PlaygroundPreviews({
    super.key,
    required this.state,
    required this.controllers,
    required this.bothThemes,
  });

  /// The configuration to render.
  final PlaygroundState state;

  /// One controller per preview — a BorderBeamController drives a single
  /// beam at a time, and the wide layout shows two.
  final List<BorderBeamController> controllers;

  /// Whether to render the dark and light backdrops side by side.
  final bool bothThemes;

  @override
  Widget build(BuildContext context) {
    final isDark = DemoTheme.of(context).isDark;
    if (!bothThemes) {
      return _Preview(
        state: state,
        brightness: isDark ? Brightness.dark : Brightness.light,
        controller: controllers.first,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Preview(
            state: state,
            brightness: Brightness.dark,
            controller: controllers[0],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _Preview(
            state: state,
            brightness: Brightness.light,
            controller: controllers[1],
          ),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.state,
    required this.brightness,
    required this.controller,
  });

  final PlaygroundState state;
  final Brightness brightness;
  final BorderBeamController controller;

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    final tokens = dark ? DemoTokens.dark : DemoTokens.light;

    Widget frame(Widget child) => Container(
      height: _frameHeight,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF101010) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: child,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          _maxSurfaceWidth,
          math.max(120.0, constraints.maxWidth - 56),
        );
        final size = Size(width, _surfaceHeight);
        Widget beam = SizedBox(
          width: width,
          height: _surfaceHeight,
          child: BorderBeam(
            variant: state.variant,
            active: state.buildActive(),
            style: state.buildStyle(),
            shape: state.buildShape(),
            timing: state.buildTiming(),
            playback: state.buildPlayback(),
            controller: state.controllerMode ? controller : null,
            child: _MockSurface(state: state, tokens: tokens, size: size),
          ),
        );
        if (state.themeDemo) {
          beam = BorderBeamTheme(data: _demoThemeData, child: beam);
        }
        // BeamTheme.auto reads the ambient brightness, so each preview only
        // needs the right Theme above it — no explicit `theme:` field, which
        // keeps the generated snippet faithful to what is on screen.
        return Theme(
          data: ThemeData(brightness: brightness),
          child: frame(beam),
        );
      },
    );
  }
}

/// The surface the beam hugs. Its own corners must match the beam contour,
/// theme inheritance included — the beam does not read the child's shape.
class _MockSurface extends StatelessWidget {
  const _MockSurface({
    required this.state,
    required this.tokens,
    required this.size,
  });

  final PlaygroundState state;
  final DemoTokens tokens;
  final Size size;

  @override
  Widget build(BuildContext context) {
    // With no shape of its own, the beam inherits the demo theme's squircle
    // 20 — so the surface follows it there too.
    final inherits = state.themeDemo && !state.hasShape;
    final radius = inherits
        ? BorderRadius.circular(20)
        : state.resolvedBorderRadius(size);
    final superellipse = inherits || state.superellipse;
    final side = BorderSide(color: tokens.mockBorder);
    return Container(
      decoration: ShapeDecoration(
        color: tokens.mockBg,
        shape: superellipse
            ? RoundedSuperellipseBorder(borderRadius: radius, side: side)
            : RoundedRectangleBorder(borderRadius: radius, side: side),
      ),
      alignment: Alignment.center,
      child: Text(
        'Build anything...',
        style: TextStyle(
          fontSize: 13,
          color: tokens.mockPlaceholder,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
