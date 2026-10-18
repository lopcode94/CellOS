// Mito's body: the jelly look of gel_body.gdshader, with the FACE PAINTED INTO THE SURFACE.
// The face is evaluated per-fragment from the *undeformed* mesh-space position (`lpos`),
// so it is part of the skin: it can never clip, and it inherits every vertex wobble,
// squash/stretch and rotation of the body for free. Expressions are just uniforms that
// MitoExpressionController (scripts/mito_expression.gd) tweens at runtime.
//
// Face space: the capsule's axis is mesh +Y. The face sits on the camera-facing side
// (angle `face_angle` around the axis). p.x = screen-right (along -Y), p.y = screen-up.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 color : source_color = vec4(1.0, 0.52, 0.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.76, 0.23, 1.0);
uniform float density : hint_range(0.0, 3.0) = 0.7;
uniform float core_glow : hint_range(0.0, 2.0) = 0.4;
uniform float refraction : hint_range(0.0, 0.2) = 0.05;
uniform float dispersion : hint_range(0.0, 0.1) = 0.015;
uniform float gloss : hint_range(0.0, 1.0) = 0.06;
uniform float rim_light : hint_range(0.0, 2.0) = 0.7;
uniform float iridescence : hint_range(0.0, 1.0) = 0.3;
uniform float wobble = 0.035;
uniform float wobble_freq = 3.0;
uniform float wobble_speed = 2.2;
uniform float flash = 0.0;
instance uniform float seed = 0.0;
instance uniform float jiggle = 0.0;

// --- face placement (mesh units) ---
uniform float face_angle = 0.567;
uniform float face_r = 0.82;
uniform float face_y0 = 0.0;
// --- expression controls (tweened by MitoExpressionController) ---
uniform float mouth_open : hint_range(0.0, 1.0) = 0.35;  // 0 = closed line, 1 = screaming
uniform float smile : hint_range(0.0, 1.0) = 0.0;        // 0 = round "o", 1 = big D grin
uniform float teeth : hint_range(0.0, 1.0) = 0.0;        // top tooth row in the grin
uniform float tremble : hint_range(0.0, 1.0) = 0.0;      // shaky lips while scared
uniform float pupil : hint_range(0.2, 1.5) = 1.0;        // pupil size
uniform float jitter : hint_range(0.0, 1.0) = 0.0;       // panicked pupil shake
uniform float brow : hint_range(-1.0, 1.0) = 0.0;        // -1 relaxed, 0 nervous, 1 panic
uniform float squint : hint_range(0.0, 1.0) = 0.0;       // happy "^" squeeze
uniform float blink : hint_range(0.0, 1.0) = 0.0;

varying vec3 lpos;

vec3 thin_film(float t) {
	return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

vec3 jelly_wobble(vec3 v, vec3 n, float t) {
	float w = sin(v.y * wobble_freq + t * wobble_speed + seed) * 0.5
			+ sin(v.x * wobble_freq * 1.3 - t * wobble_speed * 1.4 + seed * 2.1) * 0.3
			+ sin(v.z * wobble_freq * 0.9 + t * wobble_speed * 0.7 + seed * 0.7) * 0.2;
	float j = sin(t * 10.0 + v.y * 4.0 + seed) * jiggle;
	return v + n * (w * wobble + j * 0.06);
}

float sd_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// layer `c` over `base` where signed distance d < 0 (soft 0.012-unit edge)
vec4 over(vec4 base, vec3 c, float d) {
	float a = 1.0 - smoothstep(-0.006, 0.006, d);
	return vec4(mix(base.rgb, c, a), max(base.a, a));
}

// Paints the face. Returns rgb = emission-space color, a = coverage.
vec4 paint_face(vec3 lp, float t) {
	vec4 f = vec4(0.0);
	float ang = atan(lp.z, lp.x);
	float da = ang - face_angle;
	da = da - 6.28318 * floor((da + 3.14159) / 6.28318);
	if (abs(da) > 1.3) {
		return f;
	}
	vec2 p = vec2(-(lp.y - face_y0), -da * face_r);
	vec3 ink = vec3(0.07, 0.02, 0.07);
	vec3 ring = vec3(0.24, 0.07, 0.42);
	vec3 sclera = vec3(1.25, 1.02, 0.18);
	vec3 white = vec3(1.4);
	vec2 jit = vec2(sin(t * 47.0), cos(t * 39.0)) * 0.012 * jitter;
	// --- eyes: mismatched, purple-ringed, glowing yellow ---
	for (int i = 0; i < 2; i++) {
		float side = i == 0 ? -1.0 : 1.0;
		vec2 c = i == 0 ? vec2(-0.25, 0.02) : vec2(0.25, 0.06);
		float r = i == 0 ? 0.15 : 0.19;
		float open = clamp((1.0 - squint * 0.75) * (1.0 - blink), 0.06, 1.0);
		vec2 q = (p - c) / vec2(1.0, open);
		float d = length(q) - r;
		f = over(f, ring, d - 0.05);
		f = over(f, sclera, d);
		// happy squint shows as a curved "^" lid line over the closed eye
		float lid = abs(length((p - c - vec2(0.0, -r * 0.55)) / vec2(1.0, 0.8)) - r * 1.05) - 0.022;
		f = over(f, ink, lid + (1.0 - step(0.5, squint)) * 9.0 + step(p.y, c.y - r * 0.1) * 9.0);
		vec2 pc = c + vec2(side * 0.012, -0.012) + jit;
		f = over(f, ink, (length((p - pc) / vec2(1.0, open)) - r * 0.3 * pupil) + (1.0 - step(0.0, -d)) * 9.0);
		f = over(f, white, length(p - (c + vec2(-0.32, 0.36) * r)) - 0.035 * open);
		// three lashes flicking up and out from the top of each ring
		for (int k = 0; k < 3; k++) {
			float a = side < 0.0 ? 1.9 + 0.38 * float(k) : 1.24 - 0.38 * float(k);
			vec2 dir = vec2(cos(a), sin(a));
			vec2 root = c + dir * (r + 0.04) * vec2(1.0, open);
			f = over(f, ink, sd_seg(p, root, root + dir * 0.09 + vec2(0.0, 0.015)) - 0.013);
		}
		// brows: inner ends lift when nervous/scared, relax (and arch) when happy
		vec2 inner = c + vec2(-side * 0.11, r + 0.13 + 0.07 * brow);
		vec2 outer = c + vec2(side * 0.15, r + 0.12 - 0.035 * brow + 0.03 * max(-brow, 0.0));
		f = over(f, ink, sd_seg(p, inner, outer) - 0.022);
	}
	// --- mouth: round "o" <-> big D grin <-> trembling scream ---
	vec2 m = vec2(0.02, -0.36);
	float w = 0.13 + 0.13 * smile + 0.03 * mouth_open;
	float h = 0.035 + 0.19 * mouth_open;
	h *= 1.0 + sin(t * 55.0) * 0.1 * tremble;
	vec2 q = p - m;
	q.x += sin(t * 47.0 + q.y * 30.0) * 0.012 * tremble;
	float e = (length(q / vec2(w, h)) - 1.0) * min(w, h);
	float top = mix(h, h * (-0.15 + 1.0 * (q.x / w) * (q.x / w)), smile);
	float mouth = max(e, q.y - top);
	f = over(f, ink, mouth - 0.022);
	f = over(f, vec3(0.32, 0.03, 0.1), mouth);
	f = over(f, vec3(1.3, 0.42, 0.55), max(mouth, q.y + h * 0.35));
	float tooth_row = max(mouth, -(q.y - (top - h * 0.38)));
	float gaps = abs(fract(q.x * 13.0) - 0.5) * 2.0 - 0.86;
	f = over(f, white, max(tooth_row, gaps * 0.02) + (1.0 - teeth) * 9.0);
	// the signature buck tooth when not grinning
	vec2 bt = q - vec2(-0.035, top - 0.03);
	f = over(f, white, max(max(abs(bt.x) - 0.024, abs(bt.y) - 0.035), mouth) + teeth * 9.0 + step(mouth_open, 0.15) * 9.0);
	return f;
}

void vertex() {
	lpos = VERTEX;
	VERTEX = jelly_wobble(VERTEX, NORMAL, TIME);
}

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 2.5);
	float thickness = mix(0.25, 1.0, ndv);
	vec2 dir = vec2(NORMAL.x, -NORMAL.y) * refraction * (0.4 + fres);
	vec3 bg;
	bg.r = textureLod(screen_tex, SCREEN_UV - dir, 0.3).r;
	bg.g = textureLod(screen_tex, SCREEN_UV - dir * (1.0 + dispersion * 5.0), 0.3).g;
	bg.b = textureLod(screen_tex, SCREEN_UV - dir * (1.0 + dispersion * 10.0), 0.3).b;
	vec3 absorb = pow(max(color.rgb, vec3(0.001)), vec3(density * thickness * 2.0));
	vec3 body = mix(bg * absorb, color.rgb, 0.42 + 0.25 * ndv);
	body += core_color.rgb * pow(ndv, 3.0) * core_glow;
	body += thin_film(fres * 1.2 + lpos.y * 0.3 + TIME * 0.05 + seed * 0.1) * fres * iridescence;
	body += mix(color.rgb, vec3(1.0), 0.6) * fres * rim_light * 0.5;
	body *= 0.78;
	vec4 face = paint_face(lpos, TIME);
	body = mix(body, face.rgb * 0.6, face.a);
	body = mix(body, vec3(1.0), flash);
	ALBEDO = mix(color.rgb * 0.08, vec3(0.02), face.a);
	EMISSION = body;
	ROUGHNESS = mix(gloss, 0.12, face.a);
	SPECULAR = 0.75;
	ALPHA = 1.0;
}
