// Wobbly gelatin: mostly see-through in the middle, glossy and solid at the edges.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.55, 1.0, 0.62, 1.0);
uniform float base_alpha = 0.1;
uniform float rim_alpha = 0.8;
uniform float acid = 0.0;
uniform float fade = 1.0;

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	vec3 c = mix(tint.rgb, vec3(0.78, 1.0, 0.18), acid);
	ALBEDO = c;
	ALPHA = clamp(base_alpha + fres * rim_alpha, 0.0, 0.95) * fade;
	ROUGHNESS = 0.06;
	SPECULAR = 0.85;
	EMISSION = c * (fres * 0.35 + acid * 0.2);
}
