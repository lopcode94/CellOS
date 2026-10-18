// Soap-bubble / liquid-glass shell.
//   * thin-film iridescence: a cosine rainbow driven by a drifting film-thickness noise
//     plus view angle, so colors swirl like a real soap film
//   * Fresnel: nearly invisible face-on, bright glassy rim at grazing angles
//   * optional screen-space refraction with RGB dispersion (refraction > 0): the shell
//     bends whatever opaque stuff sits behind it (floor, canister liquid, nucleus core)
//   * optional organic wobble in the vertex stage (wobble / pulse)
// refraction = 0  -> alpha-blended film (cell membrane dome, floating bubbles)
// refraction > 0  -> solid glass lens (nucleus shell, ER pipe, canister glass, lipids)
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.75, 0.95, 1.0, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.05;
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.75;
uniform float fresnel_power = 2.2;
uniform float film_strength : hint_range(0.0, 2.0) = 1.0;
uniform float film_scale = 1.6;
uniform float film_speed = 0.15;
uniform float refraction : hint_range(0.0, 0.2) = 0.0;
uniform float dispersion : hint_range(0.0, 0.1) = 0.02;
uniform float roughness : hint_range(0.0, 1.0) = 0.04;
uniform float wobble = 0.0;
uniform float wobble_freq = 2.5;
uniform float wobble_speed = 1.6;
uniform float pulse = 0.0;
uniform float acid = 0.0;
uniform float fade = 1.0;
instance uniform float seed = 0.0;

varying vec3 wpos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
	               mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
	               mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

// Thin-film interference approximation: phase-shifted cosines per RGB channel.
vec3 thin_film(float t) {
	return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

// Living soap-bubble wobble: two travelling sine lobes plus slow noise, along the normal.
vec3 bubble_wobble(vec3 v, vec3 n, float t) {
	float w = sin(v.x * wobble_freq + t * wobble_speed + seed)
			* sin(v.z * wobble_freq * 0.8 - t * wobble_speed * 1.3 + seed * 1.7)
			+ 0.5 * sin(v.y * wobble_freq * 1.7 + t * wobble_speed * 0.6 + seed * 0.5);
	w += (vnoise(v * 1.5 + vec3(t * 0.4)) - 0.5) * 0.8;
	return v + n * w * (wobble + pulse);
}

void vertex() {
	if (wobble + pulse > 0.0) {
		VERTEX = bubble_wobble(VERTEX, NORMAL, TIME);
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (refraction > 0.0 && !FRONT_FACING) {
		discard;
	}
	float ndv = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, fresnel_power);
	float thick = vnoise(wpos * 0.9 + vec3(0.0, TIME * film_speed, TIME * film_speed * 0.7)) * 0.7
			+ vnoise(wpos * 2.3 - vec3(TIME * film_speed)) * 0.3;
	vec3 film = thin_film(thick * film_scale + (1.0 - ndv) * 0.8 + seed * 0.1);
	vec3 t = mix(tint.rgb, vec3(0.78, 1.0, 0.2), acid);
	ROUGHNESS = roughness;
	SPECULAR = refraction > 0.0 ? 0.9 : 0.45;
	METALLIC = 0.0;
	if (refraction > 0.0) {
		vec2 dir = vec2(NORMAL.x, -NORMAL.y) * refraction * (0.35 + fres * 1.5);
		vec3 bg;
		bg.r = textureLod(screen_tex, SCREEN_UV - dir, 0.5).r;
		bg.g = textureLod(screen_tex, SCREEN_UV - dir * (1.0 + dispersion * 5.0), 0.5).g;
		bg.b = textureLod(screen_tex, SCREEN_UV - dir * (1.0 + dispersion * 10.0), 0.5).b;
		ALBEDO = vec3(0.0);
		EMISSION = bg * mix(vec3(1.0), t, 0.35) * 0.82 + film * fres * film_strength * 0.45 + t * fres * 0.22;
		ALPHA = fade;
	} else {
		ALBEDO = mix(t, film, clamp(fres * film_strength, 0.0, 1.0));
		EMISSION = film * fres * film_strength * 0.35;
		ALPHA = clamp(base_alpha + fres * (rim_alpha + film_strength * 0.12), 0.0, 0.95) * fade;
	}
}
