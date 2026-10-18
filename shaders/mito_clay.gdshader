shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.949, 0.455, 0.122, 1.0);   // #F2741F
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;      // baked sculpt (optional)
uniform float roughness : hint_range(0.0, 1.0) = 0.42;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float coat : hint_range(0.0, 1.0) = 0.15;
uniform float coat_roughness : hint_range(0.0, 1.0) = 0.25;
uniform float sss : hint_range(0.0, 1.0) = 0.25;                        // Forward+ only
uniform vec4 backlight_tint : source_color = vec4(1.0, 0.35, 0.15, 1.0); // fake SSS (Mobile)
uniform float backlight_amount : hint_range(0.0, 1.0) = 0.35;
uniform float grain_scale = 18.0;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.12;
uniform float boil = 0.006;            // metres of stop-motion re-sculpt
uniform float boil_fps = 12.0;         // animate "on twos" at 24 fps
uniform float panic_glow : hint_range(0.0, 1.0) = 0.0;

float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return vnoise(p) * 0.55 + vnoise(p * 2.1) * 0.3 + vnoise(p * 4.3) * 0.15; }

varying vec3 obj;

void vertex() {
	float frame = floor(TIME * boil_fps);
	VERTEX += NORMAL * (vnoise(VERTEX * 6.0 + vec3(frame * 1.7, frame * 2.3, frame * 0.9)) - 0.5) * boil;
	obj = VERTEX;
}

void fragment() {
	vec3 q = obj * grain_scale;
	float g = fbm(q);
	float gx = fbm(q + vec3(0.05, 0.0, 0.0)) - g;
	float gy = fbm(q + vec3(0.0, 0.05, 0.0)) - g;
	vec3 baked = texture(normal_tex, UV).xyz * 2.0 - 1.0;
	vec3 n = normalize(baked + vec3(-gx, -gy, 0.0) * grain_strength * 12.0);
	NORMAL_MAP = n * 0.5 + 0.5;
	vec3 base = albedo.rgb * texture(albedo_tex, UV).rgb;
	ALBEDO = base * (0.92 + g * 0.16);
	ROUGHNESS = clamp(roughness + (g - 0.5) * 0.12, 0.0, 1.0);
	SPECULAR = specular;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = coat_roughness;
	SSS_STRENGTH = sss;
	BACKLIGHT = backlight_tint.rgb * backlight_amount;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = base * fres * 0.18 + vec3(1.0, 0.35, 0.1) * panic_glow * (0.6 + 0.4 * sin(TIME * 14.0));
}
