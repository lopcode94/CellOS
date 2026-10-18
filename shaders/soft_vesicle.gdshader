// Soft-focus "deep jelly" blob for background vesicles and actin filaments: unlit,
// brightest at the center and dissolving to nothing at the silhouette, so it reads as
// out-of-focus depth rather than a hard object. Particle color/alpha comes in via COLOR.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec4 tint : source_color = vec4(1.0);
uniform float softness : hint_range(0.3, 4.0) = 1.4;
uniform float opacity : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float core = pow(ndv, softness);
	ALBEDO = COLOR.rgb * tint.rgb * (0.8 + core * 0.5);
	ALPHA = core * opacity * COLOR.a * tint.a;
}
