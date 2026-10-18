// Cytoplasm: a deep radial fluid, glowing cyan/turquoise at the heart fading into
// translucent deep-jelly purple/magenta at the membrane, with two layers of animated
// caustic light shimmering across it. No tiles, grids or repeating patterns.
// Opaque on purpose: every glass/gel body in the cell refracts this layer.
// UV is the cell-local position (0.5, 0.5 = center; ~0.05 / 0.95 = membrane).
shader_type spatial;
render_mode cull_disabled;

uniform float acid = 0.0;
uniform vec4 core_col : source_color = vec4(0.0, 0.898, 1.0, 1.0);   // #00E5FF luminous cyan
uniform vec4 mid_col : source_color = vec4(0.02, 0.42, 0.86, 1.0);   // ocean blue
uniform vec4 rim_col : source_color = vec4(0.102, 0.063, 0.329, 1.0); // #1A1054 deep blue-purple
uniform vec4 edge_col : source_color = vec4(0.051, 0.125, 0.251, 1.0); // #0D2040 abyss
uniform float caustic_strength = 0.26;  // additive caustic overlay opacity
uniform float rush = 0.0;               // Sugar Rush chromatic shimmer

// warped-sine caustic web: cheap, smooth, never tiles visibly
float caustic(vec2 p, float t) {
	float c = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 q = p * (1.0 + fi * 0.65) + vec2(t * (0.35 + fi * 0.17), -t * (0.28 - fi * 0.05));
		q += vec2(sin(q.y * 0.7 + t * 0.6), cos(q.x * 0.6 - t * 0.5)) * 0.6;
		c += abs(sin(q.x + sin(q.y * 1.3 + t)) * sin(q.y + sin(q.x * 1.1 - t)));
	}
	return c / 3.0;
}

void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float ang = atan(c.y, c.x);
	float t = TIME;
	// gently swirling radial gradient (the fluid slowly circulates)
	float swirl = r + sin(ang * 3.0 + t * 0.25) * 0.04 + sin(ang * 5.0 - t * 0.33) * 0.025;
	vec3 col = mix(core_col.rgb, mid_col.rgb, smoothstep(0.15, 0.65, swirl));
	col = mix(col, rim_col.rgb, smoothstep(0.6, 0.95, swirl));
	col = mix(col, edge_col.rgb, smoothstep(0.85, 1.05, swirl) * 0.7);
	// two caustic layers at different scales/speeds, brightest in the bright core
	vec2 p = c * 9.0;
	float c1 = caustic(p, t * 0.5);
	float c2 = caustic(p * 1.9 + vec2(3.1, 1.7), t * 0.8);
	float light = smoothstep(0.5, 0.95, c1) + smoothstep(0.58, 1.0, c2) * 0.7;
	float fall = 1.0 - smoothstep(0.3, 1.0, r) * 0.55;
	col += vec3(0.85, 1.0, 1.0) * light * caustic_strength * fall;
	col += mix(core_col.rgb, vec3(1.0), 0.5) * pow(1.0 - clamp(r, 0.0, 1.0), 3.0) * 0.25;
	col = mix(col, vec3(0.55, 0.95, 0.25), acid * 0.55);
	vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + r * 1.5 - t * 0.8 + ang * 0.16));
	col = mix(col, rainbow, rush * (0.12 + light * 0.25));
	ALBEDO = col * 0.3;
	EMISSION = col * 0.27 + core_col.rgb * pow(1.0 - clamp(r, 0.0, 1.0), 2.0) * 0.12;
	ROUGHNESS = 0.25;
	SPECULAR = 0.5;
}
