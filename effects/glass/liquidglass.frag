#version 440
// ─────────────────────────────────────────────────────────────────────────────
// Liquid Glass Fragment Shader (Inspired by Apple NSGlassEffectView / fsalinas26)
//
// Features:
//  * Signed Distance Field (SDF) continuous squircle geometry & subpixel antialiasing
//  * Convex squircle bezel profile -> 3D surface normals
//  * Snell's Law optical refraction with adjustable thickness
//  * Multi-tap Gaussian disk sampling with chromatic dispersion (RGB channel split)
//  * Directional specular highlight & rim illumination (top-left key light)
//  * Meniscus surface tension curvature highlight
//  * Apple content lensing & inner depth shading
//  * Subtle triangular-distribution glass grain
//
// Build: /usr/lib/qt6/bin/qsb --qt6 -o liquidglass.frag.qsb liquidglass.frag
// ─────────────────────────────────────────────────────────────────────────────

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;      // whole shader item in px (glass + pad)
    vec2 glassSize;     // glass surface size in px
    vec2 srcSize;       // backdrop texture size in px
    vec2 srcOffset;     // top-left offset inside backdrop texture in px
    float pad;          // padding around glass (drop shadow area)
    float radius;       // squircle corner radius in px
    float bezel;        // width of refracting rim in px
    float thickness;    // refraction shift distance in px
    float dispersion;   // chromatic dispersion strength
    float blurPx;       // backdrop sampling blur radius in px
    float tintMix;      // translucency / tint mix amount (0..1)
    float saturation;   // backdrop saturation boost
    float dark;         // 1.0 = dark mode, 0.0 = light mode
    float debug;        // 1.0 = debug texture view
    float rim;          // specular rim illumination strength
    float grain;        // fine noise amplitude
    float magnify;      // vertical lens magnification
    float shadowAmt;    // drop shadow strength
    float rimTint;      // 0 = neutral white rim, 1 = tinted rim
    float ringW;        // width in px of sharp edge boundary stroke
    float flatInner;    // 1 = no inner edge shading, 0 = standard depth
};

layout(binding = 1) uniform sampler2D src;

const int   TAPS   = 24;
const float GOLDEN = 2.39996323;

// Interleaved gradient noise for jittering tap rotations
float ign(vec2 p)
{
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

// Samples pre-blurred mip levels of the backdrop texture
vec4 backdropLod(vec2 pItem, float lod)
{
    vec2 uv = (pItem + srcOffset) / max(srcSize, vec2(1.0));
    return textureLod(src, clamp(uv, vec2(0.001), vec2(0.999)), lod);
}

// Multi-tap chromatic dispersion sampling
vec4 blurredDisp(vec2 pItem, vec2 disp, float disperse, float rad)
{
    float R   = max(rad, 0.5) * 1.5;
    float gap = R * sqrt(3.14159265 / float(TAPS));
    float lod = clamp(log2(max(gap, 1.0)) + 0.35, 0.0, 6.0);
    float rot = ign(gl_FragCoord.xy) * 6.2831853;
    vec4  acc = vec4(0.0);
    float wsum = 0.0;

    for (int i = 0; i < TAPS; ++i) {
        float fi = float(i) + 0.5;
        float r  = sqrt(fi / float(TAPS));
        float a  = fi * GOLDEN + rot;
        float w  = exp(-2.2 * r * r);
        vec2  o  = vec2(cos(a), sin(a)) * r * R;
        vec4  c;
        c.r = backdropLod(pItem + o + disp * (1.0 + disperse), lod).r;
        c.g = backdropLod(pItem + o + disp,                    lod).g;
        c.b = backdropLod(pItem + o + disp * (1.0 - disperse), lod).b;
        acc  += c * w;
        wsum += w;
    }

    float alpha = backdropLod(pItem, lod).a;
    return vec4(acc.rgb / max(wsum, 1e-4), alpha);
}

// Hash function for subtle glass grain
float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// 2D Rounded Box Signed Distance Field
float roundBox(vec2 q, vec2 hs, float r)
{
    vec2 d = abs(q) - (hs - r);
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

void main()
{
    vec2 p  = qt_TexCoord0 * itemSize;
    vec2 hs = glassSize * 0.5;
    vec2 q  = p - vec2(pad) - hs;
    float r = min(radius, min(hs.x, hs.y));

    float sd  = roundBox(q, hs, r);               // < 0 inside the glass
    float cov = clamp(0.5 - sd, 0.0, 1.0);        // anti-aliased coverage

    // Debug preview of the raw texture
    if (debug > 0.5) {
        vec4 s = texture(src, clamp((p + srcOffset) / max(srcSize, vec2(1.0)), vec2(0.001), vec2(0.999)));
        fragColor = (s.a < 0.01 ? vec4(1.0, 0.0, 1.0, 1.0) : vec4(s.rgb / max(s.a, 1e-3), 1.0)) * cov * qt_Opacity;
        return;
    }

    // ── Soft Drop Shadow (outside the glass) ──
    float sds    = roundBox(q - vec2(0.0, 3.0), hs, r);
    float shadow = 0.32 * shadowAmt * (1.0 - smoothstep(-2.0, 10.0, sds));
    if (sd > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, shadow) * qt_Opacity;
        return;
    }

    // ── Distance to edge + outward edge normal direction ──
    float t = max(-sd, 0.0);
    vec2 d2 = abs(q) - (hs - r);
    vec2 sg = vec2(q.x >= 0.0 ? 1.0 : -1.0, q.y >= 0.0 ? 1.0 : -1.0);
    vec2 m  = max(d2, 0.0);
    vec2 g  = (length(m) > 1e-4) ? normalize(m) * sg
                                 : ((d2.x > d2.y) ? vec2(sg.x, 0.0) : vec2(0.0, sg.y));

    // ── Convex squircle bezel -> 3D surface normal ──
    float bz    = max(bezel, 1.0) * 1.45;
    float u     = clamp(t / bz, 0.0, 1.0);
    float om    = 1.0 - u;
    float om4   = om * om * om * om;
    float slope = (om * om * om) / pow(max(1.0 - om4, 1e-3), 0.75);
    slope = min(slope, 7.0);
    vec3 n = normalize(vec3(g * slope, 1.0));

    // ── Snell's Law Refraction (glass index n = 1.5) ──
    vec3 rd   = refract(vec3(0.0, 0.0, -1.0), n, 1.0 / 1.5);
    vec2 disp = rd.xy / max(-rd.z, 0.2) * thickness * 1.35;

    // Vertical lens magnification
    vec2 ps = vec2(p.x, (p.y - pad - hs.y) * (1.0 - magnify * 1.5) + pad + hs.y);
    float rad = blurPx * mix(0.45, 1.0, smoothstep(0.0, bz, t));

    // Multi-tap sample of the backdrop
    vec4 b4    = blurredDisp(ps, disp, dispersion * 0.6, rad);
    float aBase = clamp(b4.a, 0.0, 1.0);
    vec3 col = b4.rgb / max(aBase, 1e-3);

    // ── Colour grading: saturation, tint mix, milky lift ──
    float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(l), col, saturation);
    vec3 tintC = mix(vec3(0.96, 0.97, 1.0), vec3(0.08, 0.09, 0.12), dark);
    col = mix(col, tintC, tintMix);
    col += mix(0.060, 0.025, dark);

    // ── Apple Depth: soft top sheen, darker lower inner edge ──
    float ty = clamp((q.y + hs.y) / max(glassSize.y, 1.0), 0.0, 1.0);
    col += (1.0 - ty) * mix(0.055, 0.038, dark);
    float innerK = 1.0 - clamp(flatInner, 0.0, 1.0);
    col *= 1.0 - 0.14 * exp(-t / 6.0) * clamp(g.y, 0.0, 1.0) * innerK;
    col *= 1.0 - 0.10 * exp(-t / (bz * 0.45)) * innerK;

    // Rim color (neutral white vs tinted)
    vec3 rimCol = mix(vec3(0.96, 0.98, 1.0), clamp(col * 1.5 + 0.12, 0.0, 1.0), rimTint);

    // ── Directional Specular Rim Lighting (key light from top-left) ──
    vec2  L      = normalize(vec2(-0.55, -0.83));
    float facing = dot(g, L);
    float spec   = pow(max(facing, 0.0), 1.6) + 0.55 * pow(max(-facing, 0.0), 2.2);
    float hair   = exp(-t / 1.1);
    float wide   = exp(-t / 5.0);
    float edgeHi = hair * (0.22 + 0.85 * spec) + wide * 0.12 * (0.35 + spec);
    edgeHi *= rim * mix(0.90, 1.05, dark);
    col += edgeHi * rimCol;

    // ── Meniscus: surface tension highlight inside the rim ──
    float mx  = (t - bz * 0.5) / (bz * 0.2 + 1.0);
    float men = exp(-mx * mx);
    col += men * 0.085 * (0.35 + spec) * rim * rimCol;

    // ── Thin border line right along the edge (illuminated rim) ──
    if (ringW > 0.0) {
        float ring = 1.0 - smoothstep(ringW * 0.5, ringW * 0.5 + 1.0, t);
        col = mix(col, rimCol, ring * (0.60 + 0.40 * clamp(facing * 0.5 + 0.5, 0.0, 1.0)));
    }

    // ── Fine triangular-distribution glass grain ──
    float gn = hash12(gl_FragCoord.xy) + hash12(gl_FragCoord.xy * 1.7 + 17.0) - 1.0;
    col += gn * grain;

    col = clamp(col, 0.0, 1.0);

    float aGlass = cov * aBase;
    float a = aGlass + shadow * (1.0 - aGlass);
    fragColor = vec4(col * aGlass, a) * qt_Opacity;
}
