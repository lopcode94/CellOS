// Squishy translucent jelly body (organelles, viruses, critters, snacks).
//   * screen-space refraction + RGB dispersion of everything opaque behind it
//   * Beer-Lambert absorption: thick middle = rich saturated color, thin edges = clear
//   * trapped core glow (fake subsurface), glossy specular, colored Fresnel rim light
//   * faint thin-film iridescence on the rim, and an organic vertex wobble + jiggle
// Faces are opaque "ink" meshes embedded just under the surface, so the gel refracts
// them: expressions read as part of the jelly, not stuck-on googly eyes.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 color : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float density : hint_range(0.0, 3.0) = 1.2;
uniform float core_glow : hint_range(0.0, 2.0) = 0.35;
uniform float refraction : hint_range(0.0, 0.2) = 0.05;
uniform float dispersion : hint_range(0.0, 0.1) = 0.015;
uniform float gloss : hint_range(0.0, 1.0) = 0.06;
uniform float rim_light : hint_range(0.0, 2.0) = 0.7;
uniform float iridescence : hint_range(0.0, 1.0) = 0.3;
uniform float wobble = 0.02;
uniform float wobble_freq = 3.0;
uniform float wobble_speed = 2.2;
uniform float flash = 0.0;
instance uniform float seed = 0.0;
instance uniform float jiggle = 0.0;

varying vec3 lpos;

vec3 thin_film(float t) {
	return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

// Organic jelly wobble: three detuned sine waves along the normal, plus a fast jiggle
// term that callers kick on impacts (instance uniform `jiggle`, decays on the CPU).
vec3 jelly_wobble(vec3 v, vec3 n, float t) {
	float w = sin(v.y * wobble_freq + t * wobble_speed + seed) * 0.5
			+ sin(v.x * wobble_freq * 1.3 - t * wobble_speed * 1.4 + seed * 2.1) * 0.3
			+ sin(v.z * wobble_freq * 0.9 + t * wobble_speed * 0.7 + seed * 0.7) * 0.2;
	float j = sin(t * 10.0 + v.y * 4.0 + seed) * jiggle;
	return v + n * (w * wobble + j * 0.06);
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
	body = mix(body, vec3(1.0), flash);
	ALBEDO = color.rgb * 0.08;
	EMISSION = body * 0.78;
	ROUGHNESS = gloss;
	SPECULAR = 0.75;
	ALPHA = 1.0;
}
