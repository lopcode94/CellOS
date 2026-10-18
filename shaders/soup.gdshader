// The primordial soup sea floor: drifting caustics plus Memphis specks and rings.
shader_type spatial;

uniform vec4 deep : source_color = vec4(0.02, 0.11, 0.26, 1.0);
uniform vec4 shallow : source_color = vec4(0.1, 0.5, 0.8, 1.0);
uniform vec4 speck : source_color = vec4(0.45, 0.9, 1.0, 1.0);
uniform float rush = 0.0;   // Sugar Rush chromatic shimmer (0..1)

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz * 0.12;
	float t = TIME * 0.35;
	float c = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 q = p * (1.0 + fi * 0.8) + vec2(t * (0.3 + fi * 0.2), -t * 0.25);
		c += abs(sin(q.x + sin(q.y * 1.3 + t)) * sin(q.y + sin(q.x * 1.1 - t)));
	}
	c = pow(c / 3.0, 2.5);
	vec3 col = mix(deep.rgb, shallow.rgb, c);
	// broad, slow light pools instead of any repeating grid
	float pool = sin(wp.x * 0.031 + t * 0.4) * sin(wp.z * 0.027 - t * 0.3) * 0.5 + 0.5;
	col = mix(col, speck.rgb * 0.6, pool * 0.12);
	vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + wp.x * 0.04 + wp.z * 0.03 + TIME * 0.7));
	col = mix(col, rainbow, rush * (0.1 + 0.1 * c));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	EMISSION = shallow.rgb * c * 0.25;
}
