#version 440
// White / black-to-colour tint: near-white and near-black pixels of the icon become `tint`, everything
// else keeps its colours. For tray icons, which are mostly monochrome glyphs (white ones made for dark
// panels, black symbolic ones made for light panels): the glyph follows Theme.text, a coloured logo
// (e.g. Discord's blue) stays as it is.
//
// Drop shadows: a dark pixel that is not (nearly) opaque is a shadow or soft halo, not ink, and would
// otherwise be tinted into a light smudge around the glyph. Those are removed (alpha faded out below ~0.5-0.85).
// That also trims the half-transparent edge of a dark glyph, so users supersample the result
// (see MonoTintIcon.qml): the edge is then cut at sub-pixel precision and smoothed when scaled down.
//
// Anti-aliased edges: the colour is un-premultiplied first, so an edge pixel's colour is the glyph's own
// (white) and only its alpha falls off; where white meets a colour the whiteness share fades smoothly.
//
// Compile after editing:
//   /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o icon_tint.frag.qsb icon_tint.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;          // Theme.text
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 p = texture(source, qt_TexCoord0);
    vec3 c = p.a > 0.0 ? p.rgb / p.a : vec3(0.0);
    float lo = min(c.r, min(c.g, c.b));             // lowest channel: high only for white / light grey
    float hi = max(c.r, max(c.g, c.b));             // highest channel: low only for black / dark grey
    float w = max(smoothstep(0.55, 0.8, lo),        // whiteness
                  1.0 - smoothstep(0.2, 0.45, hi)); // or blackness
    vec3 rgb = mix(c, tint.rgb, w);

    float dark = 1.0 - smoothstep(0.2, 0.45, hi);
    float a = mix(p.a, p.a * smoothstep(0.5, 0.85, p.a), dark);   // dark and see-through: a shadow, dropped

    fragColor = vec4(rgb, 1.0) * a * qt_Opacity;
}
