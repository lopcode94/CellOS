// Glossy two-tone "Aero" lettering: bright cap, sharp horizon, saturated base.
shader_type canvas_item;

uniform vec4 top_col : source_color = vec4(1.0);
uniform vec4 bottom_col : source_color = vec4(0.18, 0.7, 1.0, 1.0);
uniform float height = 80.0;

varying float ly;

void vertex() {
	ly = VERTEX.y;
}

void fragment() {
	float t = clamp(ly / height, 0.0, 1.0);
	vec3 g = mix(top_col.rgb, bottom_col.rgb, smoothstep(0.42, 0.58, t));
	g += vec3(1.0) * (1.0 - smoothstep(0.0, 0.45, t)) * 0.2;
	g = mix(g, bottom_col.rgb * 0.7, smoothstep(0.8, 1.0, t));
	COLOR = vec4(g, COLOR.a);
}
