// Liquid orb gauge: lens-refracted backdrop, sloshing sine-wave fluid, carbonation
// bubbles, optional vortex, fresnel rim, crescent highlight and an alarm pulse.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float fill : hint_range(0.0, 1.0) = 0.5;
uniform vec4 liquid : source_color = vec4(0.3, 1.0, 0.45, 1.0);
uniform vec4 glass_tint : source_color = vec4(0.75, 0.92, 1.0, 0.18);
uniform float slosh = 0.0;
uniform float swirl = 0.0;
uniform float bubbles = 1.0;
uniform float alarm = 0.0;
uniform vec4 rim_col : source_color = vec4(1.0, 0.55, 0.15, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float aa = 1.0 - smoothstep(0.965, 1.0, r);
	vec3 bg = textureLod(screen_tex, SCREEN_UV - p * 0.03 * (1.0 - r), 2.0).rgb;
	vec3 col = mix(bg * 0.8, glass_tint.rgb, glass_tint.a);
	float has = step(0.001, fill);
	float wave = sin(UV.x * 8.0 + TIME * 3.1) * 0.03 * (1.0 + slosh) + sin(UV.x * 17.0 - TIME * 2.2) * 0.012;
	float level = 1.0 - fill + wave * step(fill, 0.99);
	float liq = smoothstep(level - 0.012, level + 0.012, UV.y) * has;
	float depth = clamp((UV.y - level) / max(fill, 0.05), 0.0, 1.0);
	vec3 lc = mix(liquid.rgb * 1.15 + 0.08, liquid.rgb * 0.55, depth);
	float ang = atan(p.y, p.x) + TIME * swirl * 2.5 - r * 4.0;
	lc += vec3(1.0) * pow(max(0.0, sin(ang * 3.0)), 12.0) * 0.2 * step(0.01, swirl) * (1.0 - r);
	float b = 0.0;
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float bx = fract(sin(fi * 37.1) * 917.3) * 1.3 - 0.65 + sin(TIME * 2.0 + fi * 1.7) * 0.05;
		float by = 1.0 - fract(TIME * (0.18 + fract(fi * 0.613) * 0.22) + fi * 0.19) * 2.0;
		float br = 0.045 + fract(fi * 0.71) * 0.04;
		float dd = length(p - vec2(bx, by));
		b += (1.0 - smoothstep(br - 0.012, br, dd)) * (0.3 + 0.7 * smoothstep(br - 0.035, br - 0.01, dd));
	}
	lc += vec3(1.0) * min(b, 1.0) * 0.55 * bubbles;
	col = mix(col, lc, liq * 0.92);
	float surf = (1.0 - smoothstep(0.0, 0.02, abs(UV.y - level))) * has * step(fill, 0.999);
	col += vec3(1.0) * surf * 0.5;
	float fres = smoothstep(0.55, 1.0, r);
	col = mix(col, vec3(0.88, 0.97, 1.0), fres * 0.35);
	col += liquid.rgb * smoothstep(0.35, 1.0, p.y) * fres * 0.45;
	float e = length((p - vec2(0.0, -0.5)) / vec2(0.7, 0.42));
	float cres = (1.0 - smoothstep(0.92, 1.0, e)) * clamp(1.0 - (p.y + 0.92) / 0.75, 0.0, 1.0);
	col = mix(col, vec3(1.0), cres * 0.55);
	float glint = 1.0 - smoothstep(0.0, 0.07, length(p - vec2(0.42, 0.52)));
	col += vec3(1.0) * glint * 0.5;
	col = mix(col, vec3(1.0, 0.25, 0.3), alarm * (0.5 + 0.5 * sin(TIME * 10.0)) * fres * 0.7);
	float ring = smoothstep(0.88, 0.9, r);
	vec3 rc = mix(rim_col.rgb, vec3(1.0), (1.0 - smoothstep(-0.9, 0.2, p.y)) * 0.45);
	rc += vec3(1.0) * (1.0 - smoothstep(0.0, 0.025, abs(r - 0.93))) * 0.5 * step(p.y, 0.0);
	col = mix(col, rc * (0.75 + 0.35 * smoothstep(0.9, 0.97, r)), ring);
	float edge = 1.0 - smoothstep(0.0, 0.02, abs(r - 0.885));
	col = mix(col, vec3(1.0), edge * 0.5);
	COLOR = vec4(col, aa);
}
