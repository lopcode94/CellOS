// Frosted acrylic panel, Frutiger Aero gone postmodern: blurred + tinted backdrop,
// lopsided per-corner radii, a slowly wobbling jelly edge, a glossy candy rim that cycles
// orange -> pink -> purple around the perimeter, faint Memphis confetti, caustic sheen.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 rect_size = vec2(300.0, 200.0);
uniform vec4 radii = vec4(30.0, 12.0, 36.0, 14.0);
uniform float wobble = 2.5;
uniform float seed = 0.0;
uniform vec4 tint : source_color = vec4(0.72, 0.9, 1.0, 0.22);
uniform float blur_lod = 3.0;
uniform float brightness = 1.08;
uniform float sheen = 1.0;
uniform float dark = 0.0;
uniform vec4 rim_a : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform vec4 rim_b : source_color = vec4(1.0, 0.25, 0.75, 1.0);
uniform vec4 rim_c : source_color = vec4(0.55, 0.36, 1.0, 1.0);
uniform float rim_w = 5.0;
uniform float pattern = 0.6;
uniform float inset = 0.0;
uniform vec3 lobe1 = vec3(0.0);
uniform vec3 lobe2 = vec3(0.0);
uniform vec3 bite = vec3(0.0);

float sd_round4(vec2 p, vec2 b, vec4 r) {
	float rr = (p.x > 0.0) ? ((p.y > 0.0) ? r.z : r.y) : ((p.y > 0.0) ? r.w : r.x);
	vec2 q = abs(p) - b + vec2(rr);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rr;
}

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// keep a bump fully inside the rect so it never gets sliced flat
float lobe_r(vec3 l, vec2 rs) {
	vec2 lp = l.xy * rs;
	float e = min(min(lp.x, rs.x - lp.x), min(lp.y, rs.y - lp.y));
	return max(0.0, min(l.z, e - 2.0));
}

vec3 rim_color(float t) {
	t = fract(t);
	if (t < 0.333) return mix(rim_a.rgb, rim_b.rgb, t * 3.0);
	if (t < 0.666) return mix(rim_b.rgb, rim_c.rgb, (t - 0.333) * 3.0);
	return mix(rim_c.rgb, rim_a.rgb, (t - 0.666) * 3.0);
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 c = rect_size * 0.5;
	vec2 p = px - c;
	float m = min(c.x, c.y);
	vec4 r = min(radii, vec4(max(m - wobble - 1.0 - inset, 1.0)));
	float ang = atan(p.y, p.x);
	float d = sd_round4(p, c - vec2(wobble + 1.0 + inset), r);
	// gooey bumps bulging out of the edge, and a scalloped bite taken out of it
	if (lobe1.z > 0.0) d = smin(d, length(px - lobe1.xy * rect_size) - lobe_r(lobe1, rect_size), 18.0);
	if (lobe2.z > 0.0) d = smin(d, length(px - lobe2.xy * rect_size) - lobe_r(lobe2, rect_size), 18.0);
	if (bite.z > 0.0) d = -smin(-d, length(px - bite.xy * rect_size) - bite.z, 12.0);
	d += (sin(ang * 3.0 + TIME * 0.7 + seed) * 0.6 + sin(ang * 5.0 - TIME * 1.1 + seed * 2.3) * 0.4) * wobble;
	float inside = 1.0 - smoothstep(-0.75, 0.75, d);
	vec3 bg = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	vec3 col = mix(bg * brightness, tint.rgb, tint.a);
	col = mix(col, col * 0.3 + vec3(0.0, 0.035, 0.055), dark);
	col += vec3(1.0) * (1.0 - smoothstep(0.0, 0.45, UV.y)) * 0.10 * (1.0 - dark * 0.6);
	// Memphis confetti: polka dots on a skewed grid plus wavy squiggles
	vec2 g = fract((px + vec2(px.y * 0.35, 0.0)) / 28.0) - 0.5;
	float dots = 1.0 - smoothstep(0.06, 0.1, length(g));
	float sq_y = mod(px.y + sin(px.x * 0.07 + seed) * 7.0, 64.0);
	float squig = (1.0 - smoothstep(0.6, 1.6, abs(sq_y - 32.0))) * step(0.55, fract(px.x / 140.0 + seed));
	col += mix(vec3(1.0), rim_color(px.x / 300.0 + seed), 0.5) * (dots * 0.07 + squig * 0.09) * pattern;
	// caustic sheen
	float u = (px.x + px.y * 0.6) / 140.0 - TIME * 0.12;
	float band = pow(max(0.0, sin(u * 3.14159)), 18.0) * 0.09 + pow(max(0.0, sin(u * 1.1624 + 1.3)), 30.0) * 0.07;
	float caust = sin(px.x * 0.045 + sin(px.y * 0.05 + TIME * 0.7) * 1.5 + TIME * 0.4) * sin(px.y * 0.05 + sin(px.x * 0.04 - TIME * 0.5) * 1.5);
	col += vec3(0.85, 0.97, 1.0) * (band + pow(abs(caust), 8.0) * 0.06) * sheen;
	// glossy candy rim
	if (rim_w > 0.0) {
		float rim = smoothstep(-rim_w - 0.8, -rim_w + 0.8, d);
		vec3 rc = rim_color(ang / 6.28318 + TIME * 0.05 + seed * 0.1);
		rc = mix(rc, vec3(1.0), (1.0 - smoothstep(0.0, 0.5, UV.y)) * 0.35);
		float spec = 1.0 - smoothstep(0.0, 1.0, abs(d + rim_w * 0.62));
		rc += vec3(1.0) * spec * 0.55 * (1.0 - smoothstep(0.2, 0.7, UV.y));
		rc *= 0.8 + 0.25 * smoothstep(-rim_w, 0.0, d);
		col = mix(col, rc, rim);
		float inner = 1.0 - smoothstep(0.3, 1.3, abs(d + rim_w + 0.6));
		col = mix(col, vec3(1.0), inner * 0.4);
	} else {
		float border = 1.0 - smoothstep(0.4, 1.4, abs(d + 0.5));
		col = mix(col, vec3(1.0), border * 0.4);
	}
	COLOR = vec4(col, inside);
}
