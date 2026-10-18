# Liquid Glass & Jelly Look: Shaders, Wobble, Lighting
**Art direction:** Windows Vista / Frutiger Aero meets postmodern wacky. Translucent soap-bubble membranes, iridescent caustics, and squishy jelly bodies. Expressions live *inside* the gel (no stuck-on googly eyes).
**Engine:** Godot 4.7 (Forward+ on desktop, Mobile renderer on phones). Every shader below is a real file in `shaders/`, and the game already uses all of them.

| File | Used for |
|---|---|
| `shaders/glass_bubble.gdshader` | Cell membrane dome, floating bubbles (film mode). Nucleus shell, ER pipe, canister glass, lipid bubbles, acid tears (refraction mode). |
| `shaders/gel_body.gdshader` | Every jelly body: Mito, viruses, free radicals, rival bacteria, sugar cubes, console, puddles. |
| `shaders/membrane_band.gdshader` | The frosted neon Memphis band around the membrane rim. |
| `shaders/cytoplasm.gdshader` | The aqua caustic water inside the cell. It's opaque on purpose, because it's what the glass refracts. |

---

## 1. Translucent bubble and jelly shaders

### 1.1 How the layering works (read this first)
Godot copies the screen **after the opaque pass**, and that copy is what `hint_screen_texture` returns. That copy is the only image refraction can bend. So:
- **The things you see through glass must be opaque:** the cytoplasm floor, the canister liquid, the nucleus's purple swirl core, and the ink faces.
- **Glass shells that refract** (`refraction > 0`) draw that copy, bent by the surface normal with RGB dispersion, as emission. They behave like solid lenses.
- **Thin films** (`refraction = 0`: the membrane dome and bubbles) are plain alpha-blended. They're almost invisible face-on and bright at the rim, so the jelly bodies inside stay visible through them. They draw last (`render_priority` 10).
- **Faces are opaque ink meshes 7% under the gel surface.** The gel refracts them, so the expression looks printed *into* the jelly.

### 1.2 `glass_bubble.gdshader` (soap bubble / liquid glass)
Key pieces (see the file for the full shader):
```glsl
// thin-film interference: phase-shifted cosines per RGB channel
vec3 thin_film(float t) { return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t)); }

void fragment() {
	if (refraction > 0.0 && !FRONT_FACING) discard;            // lenses: front faces only
	float ndv  = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, fresnel_power);                // Fresnel rim (power 2.2)
	// drifting film thickness -> swirling soap colors; view angle shifts the hue band
	float thick = vnoise(wpos * 0.9 + vec3(0.0, TIME * film_speed, TIME * film_speed * 0.7)) * 0.7
	            + vnoise(wpos * 2.3 - vec3(TIME * film_speed)) * 0.3;
	vec3 film = thin_film(thick * film_scale + (1.0 - ndv) * 0.8 + seed * 0.1);
	if (refraction > 0.0) {
		// screen-space refraction + chromatic dispersion (R, G, B sampled at 3 offsets)
		vec2 dir = vec2(NORMAL.x, -NORMAL.y) * refraction * (0.35 + fres * 1.5);
		vec3 bg;
		bg.r = textureLod(screen_tex, SCREEN_UV - dir, 0.5).r;
		bg.g = textureLod(screen_tex, SCREEN_UV - dir * (1.0 + dispersion * 5.0), 0.5).g;
		bg.b = textureLod(screen_tex, SCREEN_UV - dir * (1.0 + dispersion * 10.0), 0.5).b;
		ALBEDO = vec3(0.0);                                    // lit specular only...
		EMISSION = bg * mix(vec3(1.0), tint.rgb, 0.35)         // ...the "transmission" is emission
		         + film * fres * film_strength * 0.6 + tint.rgb * fres * 0.3;
		ALPHA = fade;
	} else {
		ALBEDO = mix(tint.rgb, film, clamp(fres * film_strength, 0.0, 1.0));
		EMISSION = film * fres * film_strength * 0.35;
		ALPHA = clamp(base_alpha + fres * (rim_alpha + film_strength * 0.12), 0.0, 0.95) * fade;
	}
	ROUGHNESS = roughness;                                     // 0.04: mirror-glossy
	SPECULAR = refraction > 0.0 ? 0.9 : 0.45;
}
```
| Preset (`Art.bubble(...)`) | tint | refraction | film | base α / rim α | wobble |
|---|---|---|---|---|---|
| Membrane dome | `#C8F7FF` | 0 | 1.1 | 0.035 / 0.7 | 0.05 (+ hunger pulse) |
| Floating bubbles | `#E8FBFF` | 0 | 1.6 | 0.02 / 0.85 | 0 |
| Nucleus shell | `#E6D6FF` | 0.07 | 1.4 | n/a | 0.03 |
| ER pipe | `#F2A8FF` | 0.045 | 0.9 | n/a | 0 |
| Canister glass | `#DFFFE8` | 0.035 | 0.7 | n/a | 0 |
| Lipid bubbles | `#FFF3B8` | 0.05 | 1.3 | n/a | 0 |
| Acid tears | `#8FF0FF` | 0.06 | 1.2 | n/a | 0 |

### 1.3 `gel_body.gdshader` (squishy jelly)
```glsl
void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 2.5);
	float thickness = mix(0.25, 1.0, ndv);                    // thick middle, thin edges
	vec2 dir = vec2(NORMAL.x, -NORMAL.y) * refraction * (0.4 + fres);
	vec3 bg = /* 3-tap dispersed screen sample, as in glass_bubble */;
	// Beer-Lambert: light passing through more jelly picks up more color
	vec3 absorb = pow(max(color.rgb, vec3(0.001)), vec3(density * thickness * 2.0));
	vec3 body = mix(bg * absorb, color.rgb, 0.42 + 0.25 * ndv);
	body += core_color.rgb * pow(ndv, 3.0) * core_glow;        // trapped glow = fake subsurface
	body += thin_film(fres * 1.2 + lpos.y * 0.3 + TIME * 0.05 + seed * 0.1) * fres * iridescence;
	body += mix(color.rgb, vec3(1.0), 0.6) * fres * rim_light * 0.5;   // colored rim light
	ALBEDO = color.rgb * 0.08;  EMISSION = body;  ROUGHNESS = gloss;  SPECULAR = 0.75;  ALPHA = 1.0;
}
```
| Body (`Art.gel(color, core, glow, density, wobble)`) | color | core | glow | density | wobble |
|---|---|---|---|---|---|
| Mito | `#FF7A1A` | `#FFD35A` | 0.6 | 0.55 | 0.035 |
| Mito cristae crest | `#FFB02E` | `#FF7AD8` | 0.9 | 0.6 | 0.02 |
| Rival bacterium | `#3FE0B0` | `#B8FF6A` | 0.6 | 1.0 | 0.04 |
| Bacterium squiggles | `#FF9A3A` | `#FFD27A` | 0.8 | 0.6 | 0 |
| Acid puddle | `#7DFF3A` | `#E0FF8A` | 0.7 | 0.8 | 0.05 |
| Anything that still calls `Art.clay(color)` | that color | color +45% white | 0.35 (+0.8 × old emission) | 1.2 | 0.02 |

Shared defaults: refraction 0.05, dispersion 0.015, gloss (roughness) 0.06, rim_light 0.7, iridescence 0.3.

### 1.4 Embedded expressions (no googly eyes)
`Art.face(parent, body_r, mood, scale, center)` drops glossy ink (`Art.ink()`: `#2A0A22`, roughness 0.12, clearcoat 0.6) on a face plane at **0.93 × the body radius** along the camera direction, just inside the gel:
| Mood | Eyes | Mouth | Extras |
|---|---|---|---|
| `happy` (Mito) | closed "^ ^" arcs | small open smile + pink tongue | pink blush ellipses |
| `angry` (viruses, radicals) | slanted ink slits + white glints | zig-zag | slanted brows |
| `smug` (rivals, clog gunk) | half-lidded ellipses + lid lines | smirk | n/a |
| `worried` | tall round ovals + glints | wavy line | n/a |

---

## 2. Membrane wobble (the "living soap bubble")
The membrane jiggles on **two layers that stack**:

**A. CPU soft body (`scripts/membrane.gd`):** the big, physical deformation. A 48-point Verlet ring with home springs, neighbor constraints, inertia lag, breathing sine waves, and a pseudopod that bulges toward the direction of travel. Every collision calls `poke()`, which dents or bulges the ring locally, and the springs ring out the wobble.

**B. GPU vertex wobble (in both shaders):** the fine, organic surface shimmer.
```glsl
// glass_bubble.gdshader: living soap-bubble wobble
vec3 bubble_wobble(vec3 v, vec3 n, float t) {
	float w = sin(v.x * wobble_freq + t * wobble_speed + seed)
	        * sin(v.z * wobble_freq * 0.8 - t * wobble_speed * 1.3 + seed * 1.7)  // travelling lobes
	        + 0.5 * sin(v.y * wobble_freq * 1.7 + t * wobble_speed * 0.6 + seed * 0.5);
	w += (vnoise(v * 1.5 + vec3(t * 0.4)) - 0.5) * 0.8;                         // slow organic drift
	return v + n * w * (wobble + pulse);                                         // push along normal
}
void vertex() { if (wobble + pulse > 0.0) VERTEX = bubble_wobble(VERTEX, NORMAL, TIME); }

// gel_body.gdshader: jelly wobble + impact jiggle
vec3 jelly_wobble(vec3 v, vec3 n, float t) {
	float w = sin(v.y * wobble_freq + t * wobble_speed + seed) * 0.5
	        + sin(v.x * wobble_freq * 1.3 - t * wobble_speed * 1.4 + seed * 2.1) * 0.3
	        + sin(v.z * wobble_freq * 0.9 + t * wobble_speed * 0.7 + seed * 0.7) * 0.2;
	float j = sin(t * 10.0 + v.y * 4.0 + seed) * jiggle;     // kick `jiggle` on impacts, decay it on the CPU
	return v + n * (w * wobble + j * 0.06);
}
```
- `seed` is an **`instance uniform`**. `Art.add()` randomizes it per mesh, so a hundred bubbles sharing one material still wobble out of sync.
- `pulse` is the "heartbeat". `host.gd` sets it on the dome every frame to `0.02 + hunger × 0.06`, so a starving host visibly throbs.
- `jiggle` (gel bodies) is per instance too. Set it with `mesh.set_instance_shader_parameter("jiggle", 1.0)` on a hit and let it decay toward 0 (×0.9 per frame) for a jelly shudder.
- Tuning: wobble amplitude 0.02–0.05 m, frequency 2.5–3.0, speed 1.6–2.2. Higher frequency looks like a nervous tremble, lower like a slow breath.

---

## 3. Color and lighting guidelines
Glass is defined almost entirely by **what it reflects and how its edges catch light**. Diffuse lighting barely matters.

### 3.1 The three-light rig (`main.gd → _build_world`)
| Light | Direction (rotation°) | Color | Energy | Specular | Job |
|---|---|---|---|---|---|
| **Key** | (−55, −35, 0): high, from top-left | `#FFF6EC` warm white | 1.3 | 1.2 | The big glossy hotspot on every bubble. Casts the only shadows. |
| **Fill** | (−25, 145, 0): low, from the opposite side | `#7FE6FF` cyan | 0.45 | 0.4 | Lifts the shadow side into the water color, so nothing goes muddy. |
| **Rim / back** | (−18, 180, 0): low, from *behind* the subjects toward the camera | `#FFD6F5` pink-white | 1.4 | **2.2** | The money light. A bright edge outline on every glass silhouette against the blue. |

Rules of thumb:
- Keep the **rim light's specular about 2× its energy**. You want glints, not a wash.
- Key and rim should be **complementary-ish warm vs. pink**, with the fill **cool cyan**. Highlights then read white-warm and shadows read aqua, the classic Frutiger Aero palette.
- Turn **shadows on for the key light only**. Transparent bodies don't cast shadows in Godot anyway, and the soft drop shadows of opaque props stay readable.

### 3.2 Environment
| Setting | Value | Why |
|---|---|---|
| Background | `#06294A` deep ocean blue | Saturated dark backdrop, so the glass rims pop. |
| **Reflection sky** | ProceduralSky: top `#9FE8FF`, horizon `#5FD0FF`, ground `#06264A` | Never rendered; it exists **only to be reflected**, which gives every bubble a cyan-to-white sky gradient across its top. |
| Reflected light | Sky | |
| Ambient | `#5FD4FF` at 0.45 | Tints the shadow sides cyan. |
| Tonemap | **AgX**, exposure 1.05 | Keeps the glints and neon bright without clipping to flat white. |
| Glow | intensity 0.85, bloom 0.12, HDR threshold 1.0, **Screen** blend | Lets specular hits and gel cores bloom softly, the Vista "aura". |
| SSR | on (Forward+) | Glass reflects nearby organelles. |
| SSAO | radius 1.0, intensity 0.8 | Contact grounding, kept light so jelly doesn't look dirty. |
| Fog | `#0A3D6A`, density 0.009 | Depth falloff into blue water. |
| Saturation | 1.15 | Pushes the candy neon. |

### 3.3 Color palette
- **Water:** `#06294A` (deep), `#1A8CD8` (mid), `#5FD0FF` (bright), with caustic highlights `#D9FFFF`.
- **Gel bodies:** saturated candy colors. Orange `#FF7A1A`, hot pink `#FF3FB4`, lime `#7DFF3A`, teal `#3FE0B0`, violet `#A03CFF`. Each has a **lighter core** (+45% white or a warm hue shift) for the trapped glow.
- **Neon Memphis accents** (membrane band, confetti): `#FF40B2`, `#99FF2E`, `#FFD91A`, `#33D9FF`, `#FF8C1F`.
- **Ink** (faces): `#2A0A22`. It's never pure black, which would look like a hole in the glass.

### 3.4 Mobile notes
- The Mobile renderer supports `hint_screen_texture` refraction and glow but **not SSR**, and the reflection sky still works. Expect about 70% of the desktop sparkle.
- Each refracting object costs 3 screen-texture taps, which is fine for the few dozen on screen. If it's a problem, set `dispersion = 0` and reuse one tap for all three channels.
