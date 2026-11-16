#version 440
// iOS-style tinted icon: every icon becomes a dark, translucent accent tile with a bright accent
// glyph on it, whatever its original colours.
//
// The tile's colours are sampled just inside the icon's edge (any colour seen at 3+ points, so
// gradient and two-tone tiles work); pixels that differ from all of them are the glyph. Icons
// without a full tile (e.g. a folder shape) are treated as all glyph.
//
// Detail mode (glyphDetail = 1, per app: Theme.iconOptions "detail"): for icons whose glyph has parts of
// different colours that would otherwise all become the same flat bright (a calculator: dark body, a
// grey screen, orange buttons). The glyph's brightness then follows its own colours: darker original
// colours stay bright, parts lighter than the body dim down a lot (a screen), saturated colours (orange
// keys) sit mid-way.
//
// Compile after editing:
//   /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o tinted_icon.frag.qsb tinted_icon.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;          // Theme.accent
    float tileOpacity;  // how solid the dark tile is (the glass shows through the rest)
    float gloss;        // strength of the sheen across the top
    float glyphScale;   // < 1 shrinks the glyph towards the centre (for glyphs that run off the tile)
    float glyphDetail;  // 1: the glyph's brightness follows its colours (see above), 0: flat
    float detailRef;    // detail mode: x (0..1) where the glyph's main body is plain, to compare against
};

layout(binding = 1) uniform sampler2D source;

vec4 unpremul(vec4 c) { return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0); }

void main() {
    // --- the tile's colours: samples just inside the edge. A colour counts as tile if it shows
    //     up at 3+ of the sample points, so two-tone and gradient tiles are fully covered, while a
    //     glyph that merely touches the edge (one or two points) still counts as glyph.
    const int N = 10;
    // ~13% in from the edges: still on the tile for icons with transparent padding around it
    // (common, ~6-10%), and inside the rounded corners
    vec2 pts[N] = vec2[N](vec2(0.25, 0.14), vec2(0.50, 0.13), vec2(0.75, 0.14),
                          vec2(0.25, 0.86), vec2(0.50, 0.87), vec2(0.75, 0.86),
                          vec2(0.13, 0.35), vec2(0.13, 0.65), vec2(0.87, 0.35), vec2(0.87, 0.65));
    vec4 s[N];
    int opaque = 0;
    for (int i = 0; i < N; i++) {
        s[i] = unpremul(texture(source, pts[i]));
        if (s[i].a > 0.9) opaque++;
    }
    // no full tile (e.g. a folder shape): the whole shape is glyph
    bool hasTile = opaque >= 8;

    // which samples are real tile colours: close to at least two others
    bool ok[N];
    for (int i = 0; i < N; i++) {
        ok[i] = false;
        if (s[i].a <= 0.9) continue;
        int support = 0;
        for (int j = 0; j < N; j++)
            if (j != i && s[j].a > 0.9 && distance(s[i].rgb, s[j].rgb) < 0.18) support++;
        ok[i] = support >= 2;
    }

    // --- this pixel. The tile keeps the icon's own shape (c); the glyph is read from a point
    //     scaled out from the centre (g), so glyphScale < 1 draws it smaller, inside the tile.
    vec4 c = unpremul(texture(source, qt_TexCoord0));
    float glyph = 1.0;
    float level = 1.0;      // brightness of the glyph (detail mode)
    if (hasTile) {
        vec2 guv = 0.5 + (qt_TexCoord0 - 0.5) / glyphScale;
        bool inside = all(greaterThanEqual(guv, vec2(0.0))) && all(lessThanEqual(guv, vec2(1.0)));
        vec4 g = inside ? unpremul(texture(source, guv)) : vec4(0.0);
        // glyph amount = how far it is from the nearest tile colour
        float dmin = 1e9;
        for (int i = 0; i < N; i++)
            if (ok[i]) dmin = min(dmin, distance(g.rgb, s[i].rgb));
        // only where the scaled icon is opaque: its soft outer edge would otherwise show as a
        // faint outline when shrunk
        glyph = dmin < 1e8 ? smoothstep(0.14, 0.32, dmin) * smoothstep(0.85, 1.0, g.a) : 0.0;

        if (glyphDetail > 0.0) {
            float lum = dot(g.rgb, vec3(0.299, 0.587, 0.114));
            float sat = max(g.rgb.r, max(g.rgb.g, g.rgb.b)) - min(g.rgb.r, min(g.rgb.g, g.rgb.b));
            // dark colours stay bright (the body), lighter greys dim a lot (a screen); saturated colours
            // (orange keys) sit in between
            // A body that fades from dark to light (a calculator's) would pass for a screen further
            // down, so a part counts as lighter only against the body at the same height (sampled at
            // x = detailRef): the screen is lighter than the body beside it, the body is not.
            // The brightest of three samples (here and a little above): a thin dark outline along the body's
            // edge (curving up round a corner) would otherwise make a whole row look lighter than the body.
            float refLum = lum;
            float refMax = -1.0;
            for (int k = 0; k < 3; k++) {
                vec4 r = unpremul(texture(source, vec2(detailRef, guv.y - 0.015 * float(k))));
                if (r.a > 0.9) refMax = max(refMax, dot(r.rgb, vec3(0.299, 0.587, 0.114)));
            }
            if (refMax >= 0.0) refLum = refMax;
            float byLum = 0.88 - 0.66 * smoothstep(0.05, 0.12, lum - refLum);

            // Pixels along the glyph's outer edge are a blend of the glyph and the (lighter) tile, so
            // they'd pass for "lighter than the body" and turn into a dark outline. Only a part that's
            // surrounded by glyph (the screen) dims: next to the tile (or outside the icon) it doesn't.
            float edge = 0.0;
            for (int k = 0; k < 4; k++) {
                vec2 d = k == 0 ? vec2(0.012, 0.0) : (k == 1 ? vec2(-0.012, 0.0) : (k == 2 ? vec2(0.0, 0.012) : vec2(0.0, -0.012)));
                vec4 nb = unpremul(texture(source, guv + d));
                float nd = 1e9;
                for (int i = 0; i < N; i++)
                    if (ok[i]) nd = min(nd, distance(nb.rgb, s[i].rgb));
                if (nb.a < 0.5 || nd < 0.2) edge = 1.0;
            }
            byLum = mix(byLum, 0.88, edge);
            float detailLevel = mix(byLum, 0.50, smoothstep(0.35, 0.70, sat));
            level = mix(1.0, detailLevel, glyphDetail);
        }
    }

    // --- colours: vertical gradients, lighter at the top
    float y = qt_TexCoord0.y;
    vec3 tileCol  = mix(tint.rgb * 0.32, tint.rgb * 0.14, y);
    // (detail mode: the glyph fades much less towards the bottom, so a big body isn't dark down there)
    vec3 glyphBottom = mix(tint.rgb, mix(tint.rgb, vec3(1.0), 0.30), glyphDetail);
    vec3 glyphCol = mix(mix(tint.rgb, vec3(1.0), 0.40), glyphBottom, y);

    // soft sheen over the top part
    float sheen = gloss * (1.0 - smoothstep(0.0, 0.55, y));
    tileCol  += vec3(sheen);
    glyphCol += vec3(sheen * 0.5);

    // premultiplied output: translucent tile + solid glyph, cut to the icon's shape
    float gl = glyph * level;
    float a = mix(tileOpacity, 1.0, gl);
    vec3 rgb = tileCol * tileOpacity * (1.0 - gl) + glyphCol * gl;
    fragColor = vec4(rgb, a) * c.a * qt_Opacity;
}
