// Horizontal glass test-tube gauge: cylindrical shading, wobbling meniscus, wavy surface,
// rising carbonation bubbles, and an etched "sweet zone" between zone_lo and zone_hi.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 rect_size = vec2(600.0, 56.0);
uniform float fill = 0.5;
uniform vec4 liquid : source_color = vec4(0.4, 1.0, 0.3, 1.0);
uniform float zone_lo = 0.5;
uniform float zone_hi = 0.675;
uniform float slosh = 0.0;
uniform float helix = 1.0;

float sd_round(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 c = rect_size * 0.5;
	float r = c.y - 1.0;
	float d = sd_round(px - c, c - vec2(1.0), r);
	float inside = 1.0 - smoothstep(-0.75, 0.75, d);
	float din = sd_round(px - c, c - vec2(7.0), r - 6.0);
	float channel = 1.0 - smoothstep(-0.75, 0.75, din);
	vec3 bg = textureLod(screen_tex, SCREEN_UV, 2.5).rgb;
	vec3 col = mix(bg * 0.7, vec3(0.72, 0.9, 1.0), 0.16);
	float inner_w = rect_size.x - 14.0;
	float edge_x = fill * inner_w + 7.0 + sin(UV.y * 9.0 + TIME * 5.0) * (2.0 + slosh * 6.0) + sin(TIME * 2.3) * 1.5;
	float lm = channel * (1.0 - smoothstep(edge_x - 1.5, edge_x + 1.5, px.x));
	float surf_y = 10.0 + sin(px.x * 0.05 + TIME * 3.0) * (1.5 + slosh * 3.0) + sin(px.x * 0.11 - TIME * 2.0) * 0.8;
	lm *= smoothstep(surf_y - 1.0, surf_y + 1.0, px.y);
	float cyl = 1.0 - pow(abs(UV.y - 0.5) * 2.0, 2.0);
	vec3 lc = liquid.rgb * (0.5 + 0.65 * cyl);
	float b = 0.0;
	for (int i = 0; i < 16; i++) {
		float fi = float(i);
		float bx = fract(sin(fi * 91.7) * 4375.85) * rect_size.x + sin(TIME * 3.0 + fi) * 3.0;
		float spd = 14.0 + fract(fi * 0.731) * 26.0;
		float by = rect_size.y - mod(TIME * spd + fi * 13.0, rect_size.y + 10.0);
		float br = 1.6 + fract(fi * 0.37) * 2.4;
		float dd = length(px - vec2(bx, by));
		b += (1.0 - smoothstep(br - 0.8, br, dd)) * (0.35 + 0.65 * smoothstep(br - 1.6, br - 0.4, dd));
	}
	col = mix(col, lc, lm * 0.92);
	// DNA double helix twisting through the tube
	float hph = px.x * 0.055 - TIME * 1.4;
	float amp_h = (rect_size.y * 0.5 - 12.0);
	float s1 = c.y + sin(hph) * amp_h;
	float s2 = c.y + sin(hph + 3.14159) * amp_h;
	float front1 = step(0.0, cos(hph));
	float st1 = 1.0 - smoothstep(1.2, 2.6, abs(px.y - s1));
	float st2 = 1.0 - smoothstep(1.2, 2.6, abs(px.y - s2));
	float rung = (1.0 - smoothstep(0.6, 1.4, abs(fract(px.x / 14.0) - 0.5) * 14.0)) * step(min(s1, s2), px.y) * step(px.y, max(s1, s2));
	vec3 h1 = vec3(0.25, 0.85, 1.0);
	vec3 h2 = vec3(1.0, 0.35, 0.85);
	col = mix(col, mix(h1, vec3(1.0), 0.3), st1 * channel * helix * mix(0.35, 0.85, front1));
	col = mix(col, mix(h2, vec3(1.0), 0.3), st2 * channel * helix * mix(0.85, 0.35, front1));
	col = mix(col, vec3(1.0, 0.95, 0.6), rung * channel * helix * 0.25);
	col += vec3(1.0) * min(b, 1.0) * lm * 0.5;
	float men = (1.0 - smoothstep(0.0, 2.5, abs(px.x - edge_x))) * channel * step(surf_y, px.y);
	col += vec3(1.0) * men * 0.55;
	col += vec3(1.0) * (1.0 - smoothstep(0.0, 1.6, abs(px.y - surf_y))) * channel * step(px.x, edge_x) * 0.35;
	float zl = zone_lo * inner_w + 7.0;
	float zh = zone_hi * inner_w + 7.0;
	col += vec3(1.0) * step(zl, px.x) * step(px.x, zh) * channel * 0.08;
	float ticks = (1.0 - smoothstep(0.5, 1.5, abs(px.x - zl))) + (1.0 - smoothstep(0.5, 1.5, abs(px.x - zh)));
	for (int k = 1; k < 8; k++) {
		float tx = float(k) / 8.0 * inner_w + 7.0;
		ticks += (1.0 - smoothstep(0.4, 1.0, abs(px.x - tx))) * step(rect_size.y - 16.0, px.y) * 0.5;
	}
	col = mix(col, vec3(1.0), min(ticks, 1.0) * channel * 0.7);
	float strip = (1.0 - smoothstep(0.0, 1.0, abs(UV.y - 0.24) / 0.09)) * channel;
	col += vec3(1.0) * strip * 0.45;
	col = mix(col, vec3(0.7, 0.9, 1.0), (1.0 - cyl) * 0.22);
	float border = 1.0 - smoothstep(0.4, 1.4, abs(d + 0.5));
	float inb = 1.0 - smoothstep(0.4, 1.4, abs(din + 0.5));
	col = mix(col, vec3(1.0), border * 0.55 + inb * 0.22);
	COLOR = vec4(col, inside);
}
