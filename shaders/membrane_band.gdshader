// The cell membrane's outer rim: a frosted glass band with neon Memphis motifs
// (zig-zags, dots, squiggles, triangles) printed into it, like the reference's border.
// UV.x runs around the ring (one tile per unit), UV.y around the tube cross-section.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, specular_schlick_ggx;

uniform float acid = 0.0;
uniform float fade = 1.0;

vec3 neon(float i) {
	float k = mod(i, 5.0);
	if (k < 1.0) return vec3(1.0, 0.25, 0.7);
	if (k < 2.0) return vec3(0.6, 1.0, 0.18);
	if (k < 3.0) return vec3(1.0, 0.85, 0.1);
	if (k < 4.0) return vec3(0.2, 0.85, 1.0);
	return vec3(1.0, 0.55, 0.12);
}

void fragment() {
	float tile = floor(UV.x);
	float fu = fract(UV.x);
	float v = UV.y;
	float kind = mod(tile, 4.0);
	float mask = 0.0;
	if (kind < 1.0) {
		float zz = abs(fract(fu * 3.0) - 0.5) * 2.0;
		mask = 1.0 - smoothstep(0.03, 0.07, abs(v - (0.12 + zz * 0.22)));
	} else if (kind < 2.0) {
		vec2 g = vec2(fract(fu * 4.0) - 0.5, (v - 0.25) * 3.0);
		mask = 1.0 - smoothstep(0.16, 0.22, length(g));
	} else if (kind < 3.0) {
		mask = 1.0 - smoothstep(0.03, 0.07, abs(v - (0.25 + sin(fu * 18.85) * 0.08)));
	} else {
		float tri = abs(fract(fu * 2.0) - 0.5) * 2.0;
		mask = step(v, 0.1 + (1.0 - tri) * 0.25) * step(0.06, v);
	}
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 2.0);
	vec3 base = mix(vec3(0.35, 0.85, 1.0), vec3(0.8, 1.0, 0.3), acid);
	vec3 n = neon(tile);
	ALBEDO = mix(base, n, mask);
	EMISSION = n * mask * 1.4 + base * fres * 0.35;
	ROUGHNESS = 0.08;
	SPECULAR = 0.85;
	ALPHA = clamp(0.34 + fres * 0.5 + mask * 0.6, 0.0, 0.95) * fade;
}
