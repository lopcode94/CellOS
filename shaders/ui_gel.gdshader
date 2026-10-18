// Web 2.0 jelly button, postmodern edition: lopsided blob silhouette that wobbles and
// jiggles when pressed, candy gradient, bottom inner glow, 50% white crescent specular
// on the top half (dims to 20% when pressed; the node itself sinks 3px).
shader_type canvas_item;

uniform vec4 base : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform vec2 rect_size = vec2(200.0, 70.0);
uniform vec4 radii = vec4(26.0, 12.0, 28.0, 10.0);
uniform float wobble = 1.2;
uniform float jiggle = 0.0;
uniform float seed = 0.0;
uniform float pressed = 0.0;
uniform float hover = 0.0;
uniform float disabled = 0.0;
uniform float pulse = 0.0;

float sd_round4(vec2 p, vec2 b, vec4 r) {
	float rr = (p.x > 0.0) ? ((p.y > 0.0) ? r.z : r.y) : ((p.y > 0.0) ? r.w : r.x);
	vec2 q = abs(p) - b + vec2(rr);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rr;
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 c = rect_size * 0.5;
	vec2 p = px - c;
	float amp = wobble + jiggle * 3.5;
	float m = min(c.x, c.y);
	vec4 r = min(radii, vec4(m - amp - 2.0));
	float ang = atan(p.y, p.x);
	float wob = sin(ang * 3.0 + TIME * (1.2 + jiggle * 14.0) + seed) * 0.6 + sin(ang * 5.0 - TIME * (1.7 + jiggle * 11.0) + seed * 1.7) * 0.4;
	float d = sd_round4(p, c - vec2(amp + 2.0), r) + wob * amp;
	float aa = 1.0 - smoothstep(-0.8, 0.8, d);
	vec3 b = mix(base.rgb, vec3(dot(base.rgb, vec3(0.3, 0.59, 0.11))) * vec3(0.8, 0.9, 1.0), disabled * 0.85);
	float y = UV.y;
	vec3 col = mix(mix(b, vec3(1.0), 0.3), b * 0.6, smoothstep(0.05, 1.0, y));
	float cx = 1.0 - smoothstep(0.0, 0.5, abs(UV.x - 0.5));
	col += mix(b, vec3(1.0), 0.55) * smoothstep(0.55, 1.0, y) * cx * 0.6;
	col = mix(col, b * 0.36, smoothstep(-6.0, 0.0, d) * 0.7);
	vec2 cp = p - vec2(0.0, -c.y * 0.48);
	float dc = sd_round4(cp, vec2(c.x - 8.0 - amp, c.y * 0.38), max(r - vec4(6.0), vec4(2.0))) + wob * amp * 0.6;
	float cres = (1.0 - smoothstep(-1.5, 1.5, dc)) * smoothstep(0.62, 0.04, y);
	col = mix(col, vec3(1.0), cres * mix(0.5, 0.2, pressed));
	col *= 1.0 + hover * 0.12 - pressed * 0.1;
	float glow = pulse * (1.0 - smoothstep(0.0, 4.0, abs(d + 2.0)));
	col += vec3(1.0, 0.9, 0.6) * glow * 0.8;
	float border = 1.0 - smoothstep(0.0, 1.3, abs(d));
	col = mix(col, vec3(1.0), border * 0.45);
	COLOR = vec4(col, aa * base.a * mix(1.0, 0.8, disabled));
}
