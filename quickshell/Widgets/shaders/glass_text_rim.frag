#version 440
// Glass text rim (lock screen clock): the soft, bevelled edge of liquid glass lettering. A band along
// the inside of the glyphs' outline that fades towards the middle of the strokes, lit from the
// top-left and (a bit weaker) from the bottom-right, with a floor so the whole outline stays
// visible, like the digits on iOS's lock screen.
//
// The band comes from how much of a small disc around the pixel is glyph (an average of the alpha
// at two rings of 16 taps): near 1 deep inside a stroke, around a half on the edge. The outline's
// direction comes from the same taps. The disc's radius is the band's width, so a thin stroke
// (the date, ~3 px) would end up all band at the clock's width; the pixels above splitY (in texture
// coordinates, the line between the date and the digits) use the thin radius instead.
// Works in pixels. Rendered supersampled by its user (LockContent.qml), so it's anti-aliased.
//
// Compile after editing:
//   /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o glass_text_rim.frag.qsb glass_text_rim.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texel;         // one pixel of the item, in texture coordinates (1 / width, 1 / height)
    float rimPx;        // band width in pixels (the digits)
    float rimPxThin;    // band width in pixels above splitY (the date)
    float splitY;       // texture y of the line between the date and the digits (0..1)
    float strength;     // opacity of the band where it is brightest, 0..1
    float floorLight;   // how much of the strength the unlit edges keep, 0..1
};

layout(binding = 1) uniform sampler2D source;

// alpha at uv, 0 outside the texture (sampling clamps to the edge pixels otherwise)
float alphaAt(vec2 uv) {
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 0.0;
    return texture(source, uv).a;
}

void main() {
    float a = texture(source, qt_TexCoord0).a;
    if (a <= 0.0) { fragColor = vec4(0.0); return; }

    float r = qt_TexCoord0.y < splitY ? rimPxThin : rimPx;
    r = max(r, 0.5);

    // average alpha over a disc of radius r, and the direction the glyph lies in
    float sum = a;
    vec2 gsum = vec2(0.0);
    for (int k = 0; k < 16; k++) {
        float ang = float(k) * 0.3926991;
        vec2 dir = vec2(cos(ang), sin(ang));
        float inner = alphaAt(qt_TexCoord0 + dir * (0.5 * r) * texel);
        float outer = alphaAt(qt_TexCoord0 + dir * r * texel);
        sum += inner + outer;
        gsum += dir * outer;
    }
    float cover = sum / 33.0;
    if (dot(gsum, gsum) < 1e-4) { fragColor = vec4(0.0); return; }   // deep inside: no band
    vec2 n = normalize(-gsum);                                         // outward

    // band: 1 on the edge, fading to 0 once the disc is mostly glyph
    float band = 1.0 - smoothstep(0.55, 0.98, cover);

    // light from the top-left, a weaker one from the bottom-right
    vec2 L = normalize(vec2(-1.0, -1.0));
    float lit = max(dot(n, L), 0.7 * dot(n, -L));
    float light = mix(floorLight, 1.0, clamp(lit, 0.0, 1.0));

    float k = strength * band * light * a;
    fragColor = vec4(vec3(k), k) * qt_Opacity;                      // premultiplied white
}
