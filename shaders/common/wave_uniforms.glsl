// The float uniforms of the distortion-wave shaders, shared by wave.frag and
// wave_glow.frag so one packer feeds both. A contract with
// lib/src/distortion_wave/render/wave_frame_data.dart, which writes them in
// this order; test/distortion_wave/render/ parses this file to keep the two
// in step. vec4s and vec4 arrays only, so the float layout is identical on
// every backend.
//
// Everything is in the stage's own logical pixels, origin at its top-left.

#ifndef PRISMATIC_WAVE_UNIFORMS_GLSL
#define PRISMATIC_WAVE_UNIFORMS_GLSL

uniform vec4 uRect;     // the stage in the canvas: left, top, width, height
uniform vec4 uView;     // x px per device px, y dither on/off, z outline perimeter, w unused
uniform vec4 uQuads;    // outline arc length where each quadrant starts: TR, BR, BL, TL
uniform vec4 uFront0;   // origin.x, origin.y, spine, radius
uniform vec4 uFront1;   // squash, time (s), swell, tilt (rad)
uniform vec4 uFront2;   // energy, gravity, glow, rim
uniform vec4 uFront3;   // clearRadius, hairClearRadius, ring (0/1), hold
uniform vec4 uFront4;   // launched (0/1), outgoing shown (0/1), incoming shown (0/1), unused
uniform vec4 uLens;     // amplitude, lens width, aberration, blur
uniform vec4 uBlur;     // blur ahead, blur behind, near blur level, far blur level
uniform vec4 uBand;     // lead, tail, strength, largest corner radius
uniform vec4 uRim;      // width, softness, unevenness, pulse
uniform vec4 uHair;     // width, opacity, white, palette colour count
uniform vec4 uStops[8]; // palette colours in OKLab (L, a, b, unused)
uniform vec4 uFringe[2];// the fringe ahead, the fringe behind, in OKLab
uniform vec4 uLumps[7]; // rim lumps: centre along the perimeter, length, depth, unused
uniform vec4 uRadii;    // corner radii: top-left, top-right, bottom-right, bottom-left

#endif
