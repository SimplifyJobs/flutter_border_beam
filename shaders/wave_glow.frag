// DistortionWave — the colour alone, for the end of the wave.
//
// Once the front has crossed the stage and no longer bends anything, the
// revealed side is drawn as itself and only the colour the wave left on the
// edges — the rim and the hairline, and whatever of the band is left — is
// drawn over it, by this shader: the colour part of wave.frag with no
// images. Premultiplied, over the content. One draw.

#version 460 core

#include <flutter/runtime_effect.glsl>
#include "common/wave_uniforms.glsl"

out vec4 fragColor;

#include "common/outline.glsl"
#include "common/wave_field.glsl"
#include "common/wave_colour.glsl"

void main() {
  vec2 pos = FlutterFragCoord().xy;
  vec2 p = pos - uRect.xy;

  // Away from the edges, with the band gone, there is nothing to draw: the
  // field need not be worked out at all.
  // The band gone, the octagon inside the outline already rules most of the
  // view out before the outline is worked out.
  if (uFront2.z <= 0.0 && !waveColourReaches(p, 0.0)) {
    fragColor = vec4(0.0);
    return;
  }
  vec4 o = waveOutline(p);
  float inset = max(-o.x, 0.0);
  bool nearEdge = waveNearEdge(inset);
  if (uFront2.z <= 0.0 && !nearEdge) {
    fragColor = vec4(0.0);
    return;
  }
  float thickness = 1.0;
  float edge = 0.0;
  if (nearEdge) {
    edge = waveEdgeAt(p);
    thickness = waveRimThicknessAt(edge * uView.z);
  }
  if (waveRimFaded(inset, thickness)) {
    fragColor = vec4(0.0);
    return;
  }
  vec2 q;
  float g;
  vec3 w = waveField(p, q, g);
  fragColor = waveDithered(waveGlowCore(p, o, edge, thickness, w.x, q, g), pos);
}
