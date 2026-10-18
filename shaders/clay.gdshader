// Plasticine clay: thumbprint grain, soft rim light, and a stop-motion "boil" that
// re-sculpts the surface 8 times a second like hand-animated claymation.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.72;
uniform float boil : hint_range(0.0, 0.2) = 0.02;
uniform float rim : hint_range(0.0, 2.0) = 0.22;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float flash = 0.0;

varying vec3 obj_pos;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x),
	               mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
	           mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x),
	               mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

void vertex() {
	float frame = floor(TIME * 8.0);
	vec3 q = VERTEX * 2.7 + vec3(frame * 1.73, frame * 2.31, frame * 0.97);
	VERTEX += NORMAL * (vnoise(q) - 0.5) * boil;
	obj_pos = VERTEX;
}

void fragment() {
	float n = vnoise(obj_pos * 7.0) * 0.6 + vnoise(obj_pos * 19.0) * 0.4;
	vec3 col = albedo.rgb * (0.86 + n * 0.26);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(col, vec3(1.0), flash);
	ROUGHNESS = clamp(roughness - n * 0.12, 0.0, 1.0);
	SPECULAR = 0.35;
	EMISSION = emission_color.rgb * emission_energy + col * fres * rim + vec3(flash) * 0.6;
}
