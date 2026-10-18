# MITO: Character Production Guide
**Blender 4.x → glTF → Godot 4.** A stressed, exhausted mitochondrion in a chunky 90s claymation-toybox style.

---

## 0. Reading the turnaround

| Feature | What the sheet shows | Why it matters for the build |
|---|---|---|
| **Body** | Upright jelly-bean, about **1 : 1.45** (width : height). Belly bulges forward, back is flatter. The top is wider than the hips. | One continuous mesh that does most of the squash and stretch. |
| **Eyes** | Strongly **asymmetric**. Screen-right eye is about **1.3×** the left and sits **higher**. Each sits in a thick raised **purple socket ring**. The sclera is **yellow and bloodshot**, with tiny black pupils and **3 lashes** per eye. | Eyeballs are separate meshes, so they can pop without tearing the face. The sockets are rings in the body topology. |
| **Mouth** | Gaping and lopsided. A **droopy lower lip**, **one buck tooth** (upper left), a pink tongue, and a dark mouth bag. | Needs concentric loops for screaming and sobbing shapes. |
| **Back** | A **purple dorsal stripe** from the forehead to the tailbone, with a **yellow wavy cristae ridge** on top. It reads like mustard on a hot dog, and that's the gag. | Built as separate shells bound to the body, so the ridge can jiggle. |
| **Legs** | Two stubby, slightly pigeon-toed nubs. No arms. | Two bones per leg is plenty. |

**Scale:** model at **1.6 m total height** in Blender (the feet's ground contact sits at the origin). In Godot, the in-game Mito (`engine_room.gd`) is about 1.9 units across, so import at scale 1.0 and size it on the node.

---

## 1. Blender modeling and topology

**Budget**
| LOD | Use | Tris (all parts) |
|---|---|---|
| LOD0 | PC, close-ups, menus | 5–7k |
| LOD1 | Mobile gameplay | 2–3k |
| LOD2 | Tiny or far away | ~800 |

Keep the base cage at **~600–900 quads** and export LOD0 with *Subdivision Surface level 1 applied*. Create LOD1/LOD2 with a *Decimate (Collapse)* modifier on a copy, **after** you've baked normals from LOD0.

### 1.1 Scene setup
1. Set Units → Metric and scale 1.0. Add two **Image Empties** (front and side) from the turnaround, with opacity 0.35 and *Depth: Back*.
2. Save `mito_v001.blend`. Iterate by version, because you'll destructively apply the Mirror later.

### 1.2 Base bean (symmetric first)
1. Add a **Cube** → *Subdivision Surface* level 2 → **Apply**. Then use *Cast to Sphere* (factor 1.0) to get an even quad-sphere with **no triangle poles**. A UV sphere's poles would pinch when it stretches.
2. Scale Z ×1.45. Then use **Proportional Edit (O)** with *Smooth* falloff to:
   - push the belly forward (+Y front) by about 8%
   - flatten the back slightly
   - widen the top third by about 6% so it looks top-heavy and tired
3. Add a **Mirror** modifier on X (Clipping on) for the symmetric phase. The target cage is about 24 vertical loops × 16 rings.
4. **Edge-flow rules for squash.** Rings must run *horizontally around the body* so vertical scale compresses them evenly. Keep 5-poles out of the eye and mouth zones, and park them on the cheeks and flanks.

### 1.3 Mouth (still symmetric, then break it)
1. Select a 4×2 face patch below the eye line → **Inset (I)** twice. That gives 3 concentric loops: lip outer, lip inner, and mouth edge.
2. Select the inner patch → **Extrude (E)** inward 3 times, scaling each down (`S 0.7`), to build the mouth bag. Assign the *Mouth Inner* material slot.
3. **Apply the Mirror now.** Then make it asymmetric:
   - Select the lower-lip loop. Use Proportional Edit (radius ~0.12) to drag it **down and forward**, and sag the screen-left corner more for the lopsided pout.
   - Pull the upper-left lip slightly up to make room for the tooth.
4. **Tongue:** a separate cube → *Subdivision* 2 → flatten and curl. Give it 2 bones later.
5. **Tooth:** a separate *Bevel*-ed cube (3 segments), tucked under the upper-left lip. Parent it to the head bone, not the jaw.

### 1.4 Asymmetric eye sockets (the tricky part)
These are built **after** the mirror is applied, so each eye can have its own size and height.
1. **Small eye (screen-left).** Select a roughly circular 3×3 face patch on the upper-left face → `I` (inset) 0.03 → `I` 0.03 again. You now have **two concentric rings plus a center patch**.
2. **Big eye (screen-right).** Select a 4×4 patch. Scale it by ×1.3 (`S 1.3`) and move it **up 0.06 m**, then inset twice the same way. The extra loop count keeps the bigger socket as smooth as the small one.
3. **Raise the purple rim.** Select the *middle* ring of each socket → `Alt+S` (shrink/fatten) +0.025 to puff it out like a rolled clay snake. Then push the **center patch** inward with `Alt+S` −0.04 to make the recess the eyeball sits in.
4. Make each socket circular: select the ring → **LoopTools → Circle** (built-in add-on), then *Relax* to even the spacing.
5. Assign the ring faces to the **Purple** material slot. Put the ring vertices in vertex groups `socket_L` / `socket_R` for rigging.
6. **Eyeballs:** add separate **quad spheres** (Cube → Subdivision 2 → Cast), not UV spheres, so there are no poles at the pupil.
   - Small eye radius 0.13 m; big eye radius 0.17 m. Leave a 2–3 mm gap from the recess so they can rotate and pop freely.
   - **Pupils:** a separate tiny flattened sphere (radius about 18% of the eyeball), sitting 1 mm proud of the sclera. That lets a bone scale it for panic dilation.
7. **Lashes:** 3 per eye. Each is a **Bezier curve** with bevel depth 0.008 m, resolution 2, tapered using point radius (`Alt+S` to 0.2 at the tip). Curl the tips up and out, then *Convert → Mesh*. That's about 40 tris per lash.

### 1.5 Dorsal stripe and wavy cristae ridge
These are build-on shells, kept off the body cage so they can jiggle independently.
1. **Stripe:** on the body, select a strip of faces **2–3 faces wide** down the back centerline, forehead to tailbone. `Shift+D` to duplicate, then `P` → *Selection* to separate.
   - Add **Solidify** (thickness 0.018 m, offset +1, *Even Thickness* on) and a **Bevel** (2 segments) so the edges look like a pressed clay rope.
   - Purple material.
2. **Cristae ridge, the wave:**
   1. Add a **Bezier curve**. In Edit Mode, snap with *Face Project* and *Align Rotation to Target* on, then lay about 24 points down the stripe's center.
   2. **Select → Checker Deselect**, then `G X` ±0.035 in **Normal** orientation. Every other point now sits left and right of center, and with *Auto* handles you get a smooth sine wave.
   3. Set Bevel depth 0.022 m, resolution 3, with *Fill Caps* on. Taper both ends by shrinking point radius to 0.3.
   4. Set **Tilt** to follow the back's curve, and Resolution U to 6. *Convert → Mesh* gives about 1.2k tris; on mobile, decimate to about 500.
   - *Procedural alternative (Geometry Nodes):* Curve Line → Resample (48) → **Set Position**, with offset = `normal × sin(index × 0.6) × 0.035` → Curve to Mesh with a Curve Circle (8 points, radius 0.022). The amplitude stays exposed if you want to tweak the wave.
3. **Bind both shells to the body** with a **Surface Deform** modifier (target: Body, then *Bind*). They now follow every squash for free. For export, either apply the modifier and weight-transfer instead (§3.4), or keep both approaches available.

### 1.6 Legs
1. On the underside, select two 2×2 face patches → `E` down 0.12 → `E` 0.08 more → `S 1.25` to round out the feet.
2. Add an edge loop at the **hip** and the **ankle** only. Anything more just fights the clay look.
3. Toe them in slightly (rotate Z ±8°) so they're pigeon-toed like the sheet.

### 1.7 UVs, sculpt detail, bakes
1. **Seams:** run down the back centerline *under the stripe* (where it's hidden), around each sole, and around the mouth-bag throat. Use *Unwrap (Angle Based)*, then *Pack Islands* with a margin of 0.005.
2. **Texel density:** 1 × 2048² for PC and 1 × 1024² for mobile, with the eyes on their own 512².
3. **Clay detail:** duplicate the body and add **Multires** level 4. Sculpt:
   - **thumbprints**: *Draw Sharp* + a fingerprint alpha at 0.04 strength, sparsely across the belly and back
   - **smudge drags**: *Smooth* + *Clay Strips* at low strength, following the sculptor's imagined thumb direction
   - **lumpy noise**: a *Layer* brush with a cloud texture at 0.01 m
   - Leave the face cleaner. Readability beats texture there.
4. **Bake** (Cycles, 64 samples) from Multires to the low poly with cage extrusion 0.02 m:
   - *Normal* (tangent space, OpenGL / Y+), which is what Godot expects
   - *AO* (16 samples) → multiply into the albedo at 30%, to darken the creases between the stripe and body and inside the sockets
5. **Bloodshot sclera:** paint thin red veins (#C2281E) radiating from the eye edges inward in *Texture Paint*, with soft falloff at 60% opacity.

---

## 2. Material and shader specs (glossy plasticine)

Clay toys aren't matte. Polymer clay has a **soft wax sheen**, **shallow subsurface glow** at thin edges, and **micro-grain** that breaks up the highlight.

### 2.1 Blender Principled BSDF values (4.x; colors are sRGB hex)
| Material | Base Color | Subsurface (Weight · Radius RGB · Scale) | Roughness | Specular IOR Level | Coat (Weight · Rough) | Normal / bump |
|---|---|---|---|---|---|---|
| **Body orange** | `#F2741F` | 0.25 · (1.0, 0.35, 0.15) · 0.05 m | **0.42** | 0.5 (IOR 1.45) | 0.15 · 0.25 | baked normal + Noise bump (Scale 18, Detail 6, **Strength 0.12**, Distance 0.02) + Voronoi thumb-dents (Scale 4, Strength 0.05) |
| **Purple stripe / sockets** | `#7B3FBF` | 0.20 · (0.6, 0.3, 0.9) · 0.04 m | 0.38 | 0.5 | 0.2 · 0.22 | same noise, strength 0.10 |
| **Yellow cristae** | `#F2C21A` | 0.25 · (1.0, 0.8, 0.3) · 0.03 m | 0.35 | 0.5 | 0.25 · 0.2 | noise strength 0.08 |
| **Sclera (yellow, wet)** | `#F5E33A` + vein texture | 0.10 · (1.0, 0.6, 0.4) · 0.01 m | **0.18** | 0.6 | **0.6 · 0.05** | none (wet surfaces read as smooth) |
| **Pupil** | `#0D0A12` | 0 | 0.08 | 0.8 | 0.5 · 0.03 | none |
| **Lashes** | `#120E14` | 0 | 0.5 | 0.4 | 0 | none |
| **Mouth inner** | `#3A0E16` | 0.15 · (1, 0.2, 0.2) · 0.02 m | 0.6 | 0.4 | 0 | low noise 0.05 |
| **Tongue** | `#E8707A` | 0.30 · (1, 0.3, 0.3) · 0.03 m | 0.30 | 0.5 | 0.3 · 0.15 | noise 0.06 |
| **Tooth** | `#F4EBD4` | 0.05 | 0.30 | 0.6 | 0.4 · 0.1 | none |

Metallic is **0** everywhere. Turn on *Emission* only for the panic glow (orange `#FF5A1A`, strength 0.0–0.6, driven by animation).

### 2.2 Godot 4 StandardMaterial3D equivalents
| Property | Body | Stripe | Cristae | Sclera |
|---|---|---|---|---|
| `albedo_color` | `#F2741F` | `#7B3FBF` | `#F2C21A` | `#F5E33A` |
| `roughness` / `metallic` | 0.42 / 0 | 0.38 / 0 | 0.35 / 0 | 0.18 / 0 |
| `metallic_specular` | 0.5 | 0.5 | 0.5 | 0.6 |
| `clearcoat_enabled` · `clearcoat` · `clearcoat_roughness` | ✓ · 0.15 · 0.25 | ✓ · 0.2 · 0.22 | ✓ · 0.25 · 0.2 | ✓ · 0.6 · 0.05 |
| `subsurf_scatter_enabled` · `strength` | ✓ · 0.25 | ✓ · 0.2 | ✓ · 0.25 | ✓ · 0.1 |
| `normal_enabled` · `normal_scale` | ✓ · 1.0 (baked) | ✓ · 0.8 | ✓ · 0.8 | ✗ |
| `detail_enabled` (grain normal) | ✓ noise normal, UV1 ×8, blend *Mix* | ✓ | ✓ | ✗ |
| `rim_enabled` · `rim` · `rim_tint` | ✓ · 0.25 · 0.5 | ✓ · 0.2 · 0.5 | ✓ · 0.2 · 0.5 | ✗ |

> **Mobile renderer note:** screen-space subsurface scattering only works in **Forward+**. On phones, fake it with `backlight_enabled` (body backlight `#FF5A26` at 0.35, which reads like light glowing through clay) plus the rim light above. The custom shader below does both automatically.

### 2.3 Drop-in Godot shader: `shaders/mito_clay.gdshader`
This is included in the project. It combines PBR clay, procedural grain (so it works without any bake), fake SSS for mobile, and the same **stop-motion boil** as the rest of the game's clay.
```glsl
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
```

### 2.4 Other engines (same look)
| Spec | Unity URP (Lit) | Three.js `MeshPhysicalMaterial` |
|---|---|---|
| Body roughness 0.42 | Smoothness **0.58** | `roughness: 0.42` |
| Coat 0.15 / 0.25 | (URP: none; use HDRP *Coat Mask 0.15*, or a fresnel term in Shader Graph) | `clearcoat: 0.15, clearcoat_roughness: 0.25` |
| SSS 0.25 | HDRP *Subsurface Scattering* profile (radius 5 mm); URP: wrap lighting in Shader Graph | `transmission: 0.0`, `thickness: 0.05`, plus `sheen: 0.2, sheenColor: #FF7A3A` as a cheap glow |
| Grain bump 0.12 | Detail normal map, strength 0.4, tiling 8 | `normalMap` + `normalScale (0.4, 0.4)` |

---

## 3. Squash and stretch rig

### 3.1 Design rules
1. **Everything engine-bound must be plain bone TRS plus shape keys.** Blender **B-Bones, Stretch-To and IK constraints do not survive glTF export**. Use them as *controllers* in Blender, then **bake** to deform bones before exporting.
2. **Volume preservation:** when stretching by `sy`, scale the other axes by `sx = sz = 1 / sqrt(sy)`. It applies to every squash key, and the game's runtime spring does the same.
3. **Stop-motion timing:** animate at 24 fps but key **on twos** (12 poses/s). Import into Godot with *Nearest* interpolation on these clips for the claymation stutter. Leave *Linear* on the runtime spring layer.

### 3.2 Bone hierarchy (deform bones marked ●, control-only ○)
```
root ○ ............................ ground at feet, world mover
└─ COG ○ .......................... pelvis; whole-body translate / tilt
   └─ squash ● .................... base→head-top, the master squash & stretch bone
      ├─ spine_01 ● ............... hips → belly        (weights: lower body)
      │  └─ spine_02 ● ............ belly → brow        (weights: mid body, stripe)
      │     └─ head ● ............. brow → crown        (weights: top, sockets 60%)
      │        ├─ eye_L ●  eye_R ● .. eyeball centers  (eyeball meshes 100%; sockets 40%)
      │        │  └─ pupil_L ● pupil_R ● ... pupil meshes, scale = dilation
      │        ├─ socket_L ● socket_R ● ..... rim ring loops (from vertex groups)
      │        ├─ lash_L ● lash_R ● ......... lash meshes; SpringBone jiggle
      │        ├─ jaw ● ................... lower lip + mouth-bag floor
      │        │  └─ tongue_01 ● → tongue_02 ●
      │        ├─ lip_corner_L ● lip_corner_R ●
      │        └─ tooth (no bone: parent mesh to head)
      │     └─ crista_01..06 ● ..... chain along the cristae ridge; SpringBone jiggle
      ├─ thigh_L ● → foot_L ●
      └─ thigh_R ● → foot_R ●
IK_foot_L ○  IK_foot_R ○  (Blender-only, baked before export)
```
- **Why a dedicated `squash` bone:** one non-uniform scale on it squashes the body, the stripe, and the ridge together, while the eyes can counter-animate on their own bones.
- **Leg bones are children of `squash`**, so set `thigh_*` *Inherit Scale = None* in Blender to keep the feet from shrinking. Bake before export (glTF stores only the final local TRS).
- **Weights:** a smooth gradient between spine_01, spine_02 and head (overlapping by 1–2 edge loops). Sockets go 60% head, 40% eye bone, so the rim stretches when the eye pops. Lips go to jaw and lip_corner bones. Copy the stripe and ridge weights from the body with a **Data Transfer** modifier (*Vertex Groups*, Nearest Face Interpolated), then add the crista bones on top for the ridge.

### 3.3 Shape keys (blend shapes, exported in glTF and supported by Godot)
| Key | Use |
|---|---|
| `squash_bulge` | Belly and flanks bulge outward on top of the bone squash: the "fat sack" look. |
| `stretch_thin` | Waist pinches inward during stretch. |
| `mouth_scream` | Huge open oval, lower lip drooping, tongue down. |
| `mouth_sob` | Lips pursed and trembling, corners down. |
| `mouth_o` | Small panicked "o". |
| `brow_worry_L/R` | Socket rings tilt upward toward the center. |
| `blink_L/R` | A purple lid rolls down over the eyeball (a socket-ring loop pulled down). |

### 3.4 Key animations
**Frantic walk.** 8 poses on twos, looping (16 frames at 24 fps).
| Pose | Feet | `squash` scale (x, y, z) | COG | Notes |
|---|---|---|---|---|
| 1 Contact | L forward, R back | (1.07, 0.88, 1.07) | down 3 cm | eyes lag down 4° (secondary) |
| 2 Recoil | — | (1.03, 0.95, 1.03) | | `squash_bulge` 0.5 |
| 3 Passing | R swings | (0.96, 1.08, 0.96) | up 4 cm | lashes flick back |
| 4 High | — | (0.97, 1.06, 0.97) | up 5 cm | `stretch_thin` 0.4 |
| 5–8 | mirror | mirror | | |
Add a constant forward tilt of COG X +8° ("running away from its own feelings"), plus jaw jitter of ±3° every pose with `mouth_o` at 0.6.

**Crying (sob loop).** 12 poses on twos.
- `squash` pulses as sobs: (1.05, 0.9, 1.05) for 2 poses, then (0.98, 1.04, 0.98) for 4 poses, then repeat at an irregular rhythm (3, 5, 4 poses).
- Eyes squint: `eye_*` scale Y 0.8 with `blink` at 0.35, and `brow_worry` at 1.0.
- `mouth_sob` at 1.0, with the jaw trembling ±2° on every pose.
- Tears come from two **BoneAttachment3D** nodes on `socket_L/R` (lower rim) driving `GPUParticles3D`: jelly droplets with gravity 2 m/s² and a squash-on-land shader.
- crista_01..06 droop by rotating −10° each, cascading.

**Panicked eye-pop (one-shot, 10 poses).**
| Pose | eye_* scale | eye_* translate (forward) | pupil scale | squash | Notes |
|---|---|---|---|---|---|
| 1–2 Anticipation | 0.85 | −1 cm | 1.1 | (1.04, 0.94, 1.04) | eyes sink, body tenses |
| 3 **POP** | **1.75** (big eye) / 1.6 (small) | **+6 cm** | **0.35** | (0.9, 1.18, 0.9) | `mouth_scream` 1.0, `panic_glow` 0.6 |
| 4 Overshoot | 1.9 / 1.7 | +7 cm | 0.3 | (0.88, 1.2, 0.88) | lashes fully back |
| 5–10 Settle | spring back: 1.4 → 1.15 → 1.25 → 1.05 → 1.1 → 1.0 | ease to 0 | → 0.6 | → (1, 1, 1) | the asymmetry sells it: let the small eye settle one pose *later* |

### 3.5 Export settings (Blender → glTF 2.0 `.glb`)
- Apply all modifiers except Armature. Use *+Y Up*. Turn on **Include: Shape Keys, Skinning, Animations**, plus **Always Sample Animations** (this bakes the IK and constraints).
- In Godot's import dock, set Animations → FPS 24. Loop *walk* and *cry*. Turn off *Optimizer* for the stop-motion clips so the held poses stay intact.
- Add a `SpringBoneSimulator3D` (Godot 4.4+) on the skeleton, with chains for `crista_01→06` (stiffness 0.6, drag 0.4, gravity 0.2) and `lash_L/R` (stiffness 1.2, drag 0.3). The ridge then wobbles after every hop with no extra keyframes.

### 3.6 Runtime squash layer (Godot)
Layer procedural springs on top of the baked clips. This uses the same math as the in-game prototype's `sq`/`sqv` springs:
```gdscript
# attach to the Mito scene root; `skel` is its Skeleton3D
@onready var skel: Skeleton3D = $Armature/Skeleton3D
var squash_bone := -1
var eye_bones: Array[int] = []
var sq := 0.0      # + = squashed, - = stretched
var sqv := 0.0
var pop := 0.0
var popv := 0.0

func _ready() -> void:
	squash_bone = skel.find_bone("squash")
	eye_bones = [skel.find_bone("eye_L"), skel.find_bone("eye_R")]

func hit(strength: float) -> void:        # call on bumps / landings
	sqv += strength * 8.0

func panic() -> void:                     # call when a free radical zaps the nucleus
	popv += 14.0

func _process(dt: float) -> void:
	sqv += (-sq * 220.0 - sqv * 12.0) * dt          # damped spring, like engine_room.gd
	sq = clampf(sq + sqv * dt, -0.45, 0.45)
	popv += (-pop * 160.0 - popv * 9.0) * dt
	pop = clampf(pop + popv * dt, -0.2, 1.0)
	var sy := 1.0 - sq * 0.35
	var sxz := 1.0 / sqrt(sy)                       # volume preservation
	skel.set_bone_pose_scale(squash_bone, Vector3(sxz, sy, sxz))
	for i in eye_bones.size():
		var s := 1.0 + pop * (0.75 if i == 1 else 0.6)  # big eye pops harder
		skel.set_bone_pose_scale(eye_bones[i], Vector3.ONE * s)
```
(When this runs alongside baked clips, apply it in an `AnimationTree` *Add* layer or after the AnimationPlayer has updated. Otherwise the clip overwrites the bone pose.)

---

## 4. The ER conveyor tube ("tail")
- **In-game now (procedural):** `engine_room.gd → _wag_pipe()` rebuilds the tube every frame as a **travelling sine wave**. It's pinned at the membrane end and at Mito's end (which rides Mito's slosh spring). Wag energy jumps when food goes down it, rises again when a snack arrives, and becomes a frantic strain while clogged. The bands and the clog gunk ride along the animated curve.
- **If you sculpt it as a rigged asset:** use an 8-bone chain from the membrane end to the Mito end, with a `SpringBoneSimulator3D` (stiffness 0.35, drag 0.25) plus a small procedural sine on the middle bones' local Z rotation (`sin(t × 3.2 − i × 0.9) × 12°`, zero at both ends). It wags on its own, and impacts still ripple through it.
