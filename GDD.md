# SYMBIO-SHACK: Game Design Document

> **You are an ancient bacterium swallowed by a giant, dim-witted predator amoeba. Cut a deal before the acid kicks in: "Don't digest me! I'll be your engine!"**

An endosymbiosis comedy roguelike. You pilot a gelatinous mech-suit from the inside: you are the mitochondrion running a squishy, leaky power plant while you steer a lumbering, hungry amoeba through the primordial soup.

| | |
|---|---|
| **Engine** | Godot 4.7 (GDScript), Forward+ on desktop, Mobile renderer on phones |
| **Platforms** | Windows / macOS / Linux, Android / iOS, Web (Compatibility renderer) |
| **Session** | 3–10 minute runs, instant restart |
| **Pillars** | 1. Two jobs, one brain: inside and outside are on screen at once. 2. Everything jiggles. 3. Failure is a punchline. |
| **Prototype** | `res://`: fully playable. Run `play.bat`, or open the folder in Godot and press F5. |

---

## 1. Core Systems & Input Architecture

### 1.1 The two layers (on screen at the same time)
The camera looks down at the host from a 57° tilt. Its jelly dome is see-through, so the **Engine Room** and the **Primordial Sea** share one frame. You never switch views: you steer with one thumb and run the plant with the other.

**Interior: the Engine Room** (host-local 2D simulation, rendered in 3D)
```
food ──▶ ER conveyor (can CLOG) ──▶ MITOCHONDRION (you) ──▶ ATP canister ──slingshot──▶ NUCLEUS ──▶ host energy
                                           │
                                           └── byproduct: FREE RADICALS (flick them out through the membrane)
```
| Thing | Behavior |
|---|---|
| **Mitochondrion** (you) | Burns 0.3 fuel per canister. Output rate is set by the **Citric Crank**: I = 0.5/s, II = 0.85/s, III = 1.3/s. It complains when the fuel runs out. |
| **ATP canisters** | Glowing barrels that roll, squash, and bounce off the membrane. You slingshot them into the nucleus. They hold a charge that acid drains. |
| **Nucleus** | The engine. Catches canisters on contact. Its pores glow red as the host gets hungry, and they flash white when your aim line is on target. |
| **Free radicals (ROS)** | Each canister has a chance to spawn one: 6% at I, 15% at II, 32% at III. They buzz around, home in on canisters (**OXIDIZED!**), and zap the nucleus (+3 Mutation). Flick one into the membrane faster than 6 m/s and it pops out: **PTOO!** |
| **ER conveyor** | Food you engulf rides this pipe to the mitochondrion. Each delivery has a 10% chance to clog it with a smug wad of misfolded protein. Tap the gunk to clear it: **SHLORP!** |
| **Acid puddles** | Appear once Digestion passes 35%. They slow everything, drain canister charge (0.45/s), and fizzle canisters outright. Tap one to splat it smaller. |
| **Citric Crank console** | A spring-loaded button. Tap it to cycle I → II → III. A canister hitting it hard can bump it by accident (**OOPS!**). |

**Exterior: the Primordial Sea** (world space)
| Thing | Behavior |
|---|---|
| **Food**: sugar cubes (1.0 fuel), lipid clusters (1.6 fuel) | Engulfed on membrane contact. Each one counts toward the generation goal. |
| **Viral phages** | Angry spiky balls that chase the host. Contact injects 2 radicals and +4 Mutation (**INFECTED!**). Ram one at more than 5.5 m/s to squash it instead (**SPLAT!**). |
| **Rival protozoans** | Smug blue paramecia that steal your food. A slow bump costs 0.6 fuel. Ram one at speed and it bursts into 3 snacks. |

### 1.2 Unified control scheme
Every pointer, whether a mouse or any finger, goes through the same router (`main.gd`, `_pointer_down`):

```
pointer down ─▶ on an in-play HUD button?      → press it (any finger, not just the first)
             ─▶ ray-cast onto the engine-room plane, hit a canister/radical/console/gunk/puddle? → interact
             ─▶ otherwise                         → floating virtual joystick (steer)
```

| Action | Touch | Mouse + keyboard |
|---|---|---|
| **Steer the host** | Drag on any empty soup (a floating joystick appears) | **WASD / arrows**, or drag on empty space |
| **Slingshot ATP** | Press a canister, pull back, release | Click a canister, drag back, release |
| **Flick a free radical** | Grab and swipe hard toward the membrane | Click, drag, and release mid-swing |
| **Crank the citric cycle** | Big CRANK button, or tap the console | **Space**, **right-click**, **1 / 2 / 3**, or click the console |
| **Unclog / splat** | Tap the gunk or a puddle | Click |
| **Crying Lysosome Cannon** | CRY button | **E** |
| **Tickle the mitochondrion** | Tap it (**HEE HEE!**) | Click |
| Pause / mute | II / SND buttons | **P** or **Esc** / **M** |
| Pick a mutation card | Tap the card | Click, or **1 / 2 / 3** |

**Simultaneity.** Touch is truly multi-touch. Each finger keeps its own grab, so you can steer with your left thumb, aim a slingshot with your right, and hit CRANK with a third finger. Godot only mouse-emulates the first finger, so the in-play buttons skip Godot's GUI system and are hit-tested by the router. PC players get the same split with WASD in one hand and the mouse in the other.

**Readability aids.** The slingshot shows a stretchy pink band and a dotted trajectory preview that includes membrane bounces. The nucleus flashes white when the shot will land.

**Responsive viewport.** The UI scales by the smaller screen dimension (`canvas_items` stretch, 720 px base, `expand`). Landscape keeps a fixed vertical FOV, while portrait switches the camera to `KEEP_WIDTH`, so the whole cell always fits across the screen. The HUD moves the dial below the info panel and stacks mutation cards vertically in portrait. Orientation follows the phone's sensor.

### 1.3 The 15-second gameplay slice
| t | Inside (right thumb) | Outside (left thumb) |
|---|---|---|
| 0.0 | The needle sits in the white zone. Two canisters roll out of the mitochondrion with a **PLOP**. | You're cruising toward a cluster of sugar cubes. |
| 1.5 | You pull the first canister back. The trajectory dots bank off the membrane and the nucleus flashes white. Release: **GULP! +ATP**. | A phage peels off a rock and starts chasing you. |
| 3.0 | A radical spawns (**FREE RADICAL!**) and heads for the second canister. | You swerve, but you're too slow to ram, so you dodge sideways and the whole cell sloshes. |
| 4.5 | You grab the radical and flick it hard: it hits the membrane, which bulges, then **PTOO!** | You plow into the sugar cubes: **NOM! NOM! NOM!** |
| 6.0 | **CLOGGED!** The conveyor stops with three sugars stuck behind a smug gunk-ball. | The phage closes in. |
| 7.0 | You tap the gunk: **SHLORP!** Sugar flows again. | You turn and floor it toward the phage. Speed is above 5.5: **SPLAT!** |
| 9.0 | The fuel is full and the needle is drifting toward HUNGRY, so you hit CRANK III (**OVERDRIVE!**). | The host surges, since overfed hosts get up to 1.3× speed. |
| 11.0 | Canisters pour out. You chain three slingshots, and one ricochets twice before it lands: **GULP GULP GULP**. | A rival paramecium bumps you: **HEY! MY LUNCH!** You lose 0.6 fuel. |
| 13.0 | The needle swings into MUTATING and the meter climbs to 44%… | …and then **WILD MUTATION: SPINNY FLAGELLUM!** Your steering starts wobbling in circles. |
| 15.0 | You panic-tap back down to CRANK II and the mutation meter starts to cool. | You're steering a spinning amoeba into the next food cluster on purpose. |

---

## 2. The Roguelike Progression Engine

### 2.1 Run structure
- **Generation N**: eat `8 + 3N` food while you keep the Tension Dial balanced.
- **MITOSIS!** When you hit the goal, the host divides and you **splice one of three mutation cards** into the next generation (Balatro-style draft).
- Each generation, demand rises by `+0.07 ATP/s`, phages gain speed and numbers (`1 + gen`, up to 8), and rival protozoans join from Generation 2 (up to 3).
- The run ends at **100% Digestion** or **100% Mutation**.

### 2.2 Run economy (resources that reset every run)
| Resource | Source | Sink |
|---|---|---|
| **Fuel** (up to 6) | Sugar 1.0, lipid 1.6 (×2 with Gluttonous Vacuole) | 0.3 per canister |
| **ATP rate** | Canisters delivered (exponential window, τ = 6 s) | Host demand |
| **Crank level** | Free to change | A higher level means more ROS and an overfeed risk |
| **Mutation cards** | 1 per generation | Each card's own trade-off |

### 2.3 Meta-progression: mitochondrial DNA (mtDNA)
At death, the mitochondrion stashes mtDNA fragments in the next host it meets. **It persists across runs** (saved at `user://symbio_shack.cfg`).

```
mtDNA earned = 2 × food engulfed  +  15 × (generation − 1)  +  3 × viruses squashed  +  seconds survived / 10
```
| Banked mtDNA | Unlock |
|---|---|
| 0 | Turbo-Cilia Exhaust, Crying Lysosome Cannon, Spicy Cytoplasm Membrane, Gluttonous Vacuole |
| 60 | Antioxidant Sprinkles |
| 150 | Rubber Nucleus |
| *roadmap* | 300: start with a free card. 500: second crank console. 800: "Plastid Pal" co-pilot (photosynthesis side-loop). |

### 2.4 Mutation cards (every one is a trade-off)
| Card | Type | Upside | Downside |
|---|---|---|---|
| **Turbo-Cilia Exhaust** | Passive | +35% top speed and thrust, which makes ramming easy | Above 70% speed, the exhaust farts a free radical into the engine room every 2.6 s |
| **Crying Lysosome Cannon** | Active (E / CRY) | Fires acid tears that pop phages and burst rivals into snacks (1.5 s cooldown) | Every sob leaks an acid puddle into your own cytoplasm |
| **Spicy Cytoplasm Membrane** | Passive | Phages that touch you get fried (**SIZZLE!**), with no infection | Host demand ×1.2, and the membrane gets 22% bouncier, so canisters ricochet wildly |
| **Gluttonous Vacuole** | Passive | Every snack is worth double fuel | −20% speed (bad for ramming), and the conveyor clogs twice as often |
| **Antioxidant Sprinkles** | Passive (unlock 60) | 40% fewer free radicals | Canisters hold 15% less charge |
| **Rubber Nucleus** | Passive (unlock 150) | Catch radius +0.85 m: almost any shot near the nucleus lands | It burps 1 in 6 canisters straight back at you |
| *Emergency Snack Pack* | Filler | Refills fuel | "Tastes like pond." |
| *Membrane Patch Kit* | Filler | −30 Digestion and −30 Mutation | "It's literally a band-aid." |

**Synergies and anti-synergies to discover:**
- **Spicy + Cilia**: you become a bulldozer that fries anything it touches. But both downsides raise the overfeed risk, so you live in CRANK II and steer like a maniac.
- **Lysosome + Antioxidant**: the cannon's puddles hurt less when there are fewer radicals around, making it a clean shooting build.
- **Vacuole + Rubber Nucleus**: food is plentiful and every shot lands. But the clogs and burps make it a slapstick tap-fest.
- **Spicy + Rubber Nucleus**: an anti-synergy. Burped canisters ricochet off the spicier, bouncier membrane like pinballs.

### 2.5 Wild mutations (the unwanted ones)
Overfeeding sprouts organs you never asked for. They appear at **45 / 68 / 86% Mutation** and shrivel up once the meter drops 15 points below the threshold.
| Wild mutation | Visual | Effect on steering |
|---|---|---|
| **Spinny Flagellum** | A pink tail whipping off the membrane | Rotates your steering input by a sine wave plus drift |
| **Nosy Extra Eye** | A googly eye on a wobbling stalk | Drags the host toward the nearest virus ("ooh, what's that?") |
| **Flailing Pseudopod** | A lumpy arm with a yellow mitten | Lunges in a random direction every 1.8–3.5 s (**FLAIL!**) |

### 2.6 Fail states
**Dissolved into Soup** (Digestion reaches 100%). The host remembers you were lunch.
- The dome sags flat, the membrane shrinks by 55%, and the jelly and cytoplasm sour to acid green.
- Every organelle slumps into a pancake (scale Y → 0.08 over 2.2 s) and acid puddles bloom.
- The host's pupils spin. A long descending **BLORP** plays with gurgling noise, and the camera slowly pushes in.
- *"The host finally remembered you were lunch. You are now a light, zesty bisque."*

**Cellular Supernova** (Mutation reaches 100%). You overclocked the citric acid cycle.
- A white flash fills the screen, the sun light spikes to 6×, and a big camera shake hits.
- The membrane's Verlet points lose their springs and fly outward. The jelly dome stretches into huge translucent shards that fade out.
- The mitochondrion, nucleus, console, conveyor, canisters, and the host's googly eyes are all **reparented to the world as ballistic debris**. They tumble, bounce off the sea floor, and spin out.
- *"You overclocked the citric acid cycle and the host became a tiny, beautiful sun."*

Both deaths finish in under 3 seconds and flow into a results card (mtDNA earned and new unlocks) with a one-tap **SPLIT AND TRY AGAIN**.

---

## 3. Technical Blueprint & Mathematical Model

### 3.1 Tension equilibrium model (`scripts/tension.gd`)
```
# Every frame (dt):
ATP_Output_Rate      *= exp(-dt / 6.0)                 # exponential window, tau = 6 s
                     += charge / 6.0  per delivered canister   # equilibrium = canisters delivered per second

Host_Demand           = (0.45 + 0.07 * (gen - 1) + 0.22 * speed_frac) * demand_mult
ratio                 = ATP_Output_Rate / Host_Demand  # needle position; sweet spot [1.00, 1.35]

deficit               = Host_Demand - ATP_Output_Rate
if deficit > 0:
    Host_Digestion_Meter += 12 * deficit * dt           # starving: acid
else:
    Host_Digestion_Meter -= (10 * min(-deficit, Host_Demand) + 0.5) * dt   # fed: recovers

surplus               = max(0, ATP_Output_Rate - 1.35 * Host_Demand)
Toxic_ROS_Accumulation = live free radicals in the cytoplasm
Mutation_Instability_Index += (14 * surplus + 1.1 * Toxic_ROS_Accumulation - 1.5) * dt

both clamped to [0, 100];  100 Digestion → SOUP;  100 Instability → SUPERNOVA
host_speed_mult       = clamp(0.55 + 0.45 * ratio, 0.55, 1.30)   # starving = sluggish, overfed = turbo
```
Discrete jolts sit on top of the continuous model: a phage infection adds +4 Mutation, a radical zapping the nucleus +3, a radical hitting the mitochondrion +1, an oxidized canister +1, and an expelled radical −1.

**Balance sanity check (Generation 1, cruising at full speed: demand 0.67 ATP/s).**
- CRANK I (0.5/s) leaves a deficit of 0.17, so Digestion climbs about 2%/s and the host slowly starves.
- CRANK II (0.85/s) gives a ratio of 1.27, inside the sweet spot. It produces ≈0.13 radicals/s, so flicking keeps the meter at 0.
- CRANK III (1.3/s) gives a surplus of 0.40 over the 1.35× cap. That's about 5.6%/s from overfeeding, plus ≈0.42 radicals/s, so it mutates in roughly 15 s if you leave it on.
- Every few generations the demand curve overtakes CRANK II at full speed. From then on, the core skill is **pulsing III while dumping radicals**.

### 3.2 Soft-body membrane (`scripts/membrane.gd`)
**Approach:** a closed ring of 48 Verlet points, integrated at 2 substeps per frame.

```
for each point i (home angle θi = 2πi/N):
    v      = (p - p_prev) * 0.986                    # Verlet velocity + damping
    home   = dir(θi) * R * (1 + breathing(t, i) + pseudopod(dir·move_dir))
    a      = (home - p) * 70  -  host_accel * 0.35   # shape-memory spring + inertia lag (slosh)
    p_prev = p;   p += v + a * dt²
repeat 2×:  neighbor distance constraint, stiffness 0.6   # the "skin"
```
- **Impacts** = `poke(at, impulse)`: Gaussian-weighted velocity kicks across the 7 nearest points (`p_prev -= impulse * w * dt`). Interior hits bulge the membrane outward, and exterior hits (phages, rivals, food) dent it inward. The springs do all the wobbling, with no animation keyframes.
- **Collision** = `radius_at(angle)`: interpolated between neighboring points, so canisters bounce off the *current* deformed shape. A hard hit bulges the wall, and the next bounce off that bulge comes back different.
- **Amoeba life**: two sine "breathing" waves, plus a cubic pseudopod bulge toward the direction of travel.
- **Mesh**: rebuilt every frame from the ring with `SurfaceTool`, in 3 surfaces: a Memphis-pattern cytoplasm floor (fan), a glossy rim tube, and a 7-ring transparent jelly dome (fresnel alpha, `depth_draw_never`). That's about 800 vertices, which is trivial.
- **Death states**: `deflate` scales home radius, constraint length, and dome height together. `explode()` drops the springs and constraints and gives every point an outward velocity.

Everything else that jiggles uses the same idea in 1D or 2D: damped springs on squash (`sq`, `sqv`) for canisters and organelles, organelles anchored to home spots so the whole engine room sloshes when the host accelerates, and googly-eye pupils on springs that rattle off the rim.

### 3.3 Core slingshot and rubbery rebound (from `scripts/engine_room.gd`)
```gdscript
# --- grab: pin the canister's anchor where you touched it
func try_grab(id: int, p: Vector2) -> bool:
	# ... nearest canister within r + 0.8 (generous for thumbs)
	best.held = id
	best.anchor = best.pos
	holds[id] = best
	return true

# --- while held: the canister follows the finger, leashed to MAX_PULL
if b.held >= 0 and b.kind == Kind.CANISTER:
	var want := b.anchor + (b.target - b.anchor).limit_length(MAX_PULL)
	b.pos = b.pos.lerp(want, minf(1.0, dt * 25.0))
	b.vel = Vector2.ZERO

# --- release: launch opposite the pull, Angry-Birds style
func release(id: int, p: Vector2) -> void:
	var b: Body = holds[id]
	holds.erase(id)
	b.held = -1
	var pull := b.pos - b.anchor
	if pull.length() < 0.3:
		return                               # just a nudge
	b.vel = -pull * SLING_POWER              # up to 3.0 * 6.8 = 20 m/s
	b.sqv += 9.0                             # launch squash

# --- rubbery rebound off the soft-body membrane (it jiggles back)
func _membrane_hit(b: Body) -> void:
	var d := b.pos.length()
	var n := b.pos / d
	var rm: float = host.membrane.radius_at(b.pos.angle()) - MEMBRANE_PAD
	if d + b.r <= rm:
		return
	var vn := b.vel.dot(n)
	if b.kind == Kind.RADICAL and b.held < 0 and vn > EXPEL_SPEED:
		_expel(b, n, vn)                     # PTOO! straight through the pore
		return
	b.pos = n * (rm - b.r)
	if vn > 0.0:
		b.vel -= n * vn * (1.0 + 0.82 * game.bounce_mult())   # restitution 0.82 (1.0 when Spicy)
		host.membrane.poke(b.pos, n * vn * 0.9)               # shove the Verlet ring outward
		b.sqv += minf(vn, 12.0) * 0.7                         # canister squash spring
```
The trajectory preview (`_aim()`) runs the same integrator ahead of time, with drag and reflections off the rest radius, and stops early when it predicts a nucleus catch.

### 3.4 Architecture
```
main.tscn ── main.gd           orchestrator: world, camera, input router, run loop, deaths, save, autopilot
             ├─ host.gd        amoeba body: movement, face, wild mutations
             │   ├─ membrane.gd   Verlet soft body + mesh rebuild
             │   └─ engine_room.gd  interior sim: organelles, canisters, radicals, conveyor, puddles, slingshot
             ├─ sea.gd         exterior: food, phages, rivals, tears
             ├─ hud.gd         CanvasLayer: Tension Dial (custom _draw), joystick, buttons, overlays
             ├─ synth.gd       procedural audio (AudioStreamGenerator, 5 waveforms, ~30 presets)
             ├─ tension.gd     the math model (pure, no nodes)
             └─ mutations.gd   card data, rolls, unlocks
art.gd + googly.gd             clay material/mesh kit, googly eyes
shaders/  clay (stop-motion boil + thumbprint grain + rim), jelly, cytoplasm (Memphis), soup (caustics)
```
- **No imported art.** Every prop is built from primitives and procedural tubes in `art.gd`, so it's easy to swap in sculpted meshes later without touching gameplay.
- **Claymation look**: the clay shader re-displaces vertices with value noise that only changes 8 times per second, so surfaces "boil" like hand-animated stop-motion. Faces always point at `FACE_DIR`, toward the camera, so expressions read from above.
- **Audio**: every boing, squelch, gulp, ptoo, and kaboom is synthesized at runtime (`synth.gd`), with per-sound throttling.
- **Stability**: frame time is clamped to 1/30 s, so a shader-compile hitch can't detonate the Verlet ring.
- **Self-test**: `godot --headless --path . -- --autotest` plays two full runs (card pick, cannon, supernova, soup) and exits. Add `--shots=<dir>` (windowed) to capture screenshots every 1.5 s.

### 3.5 Performance budget (mid-range phone target)
- Draw calls: about 150–250, mostly small primitive meshes. Next step: merge static organelle parts into a single `ArrayMesh` and move radical spikes to a `MultiMesh`.
- CPU: membrane ~0.1 ms, interior physics O(n²) over ≤ 20 bodies, synth ≤ 2 ms per frame in GDScript. If profiling flags the synth, move it to a C# or GDExtension voice mixer.
- Mobile: the Mobile renderer, with SSAO auto-disabled and MSAA 2×. Glow stays on, because the canisters' glow is the "ATP reads as energy" cue.

### 3.6 Roadmap after the prototype
1. Sculpted clay meshes with baked thumbprint normals, while keeping the vertex boil.
2. Real squelch and boing foley layered over the synth.
3. Biome rotation by generation: tide pools, a hydrothermal vent (heat drains fuel), and the "Gut of a Bigger Thing."
4. Boss: **Macrophage Mom**, who tries to engulf *your* host. You win by overfeeding on purpose and **supernova-ing her from inside**.
5. Daily seed plus a leaderboard, and a co-op mode where one player steers and one runs the engine room, *Lovers in a Dangerous Spacetime* style.

---

## 4. UI / HUD Art Direction: "Cell OS" (Frutiger Aero × retro toybox)

The whole interface pretends to be a 2007-era glossy operating system that runs a cell. Every panel is glass, every button is gel, and every gauge is a vessel of liquid.

| Element | Spec | Implementation |
|---|---|---|
| **Frosted acrylic windows** | Blurred and tinted backdrop, 1px white border at 40%, glossy top falloff, drifting caustic sheen bands, Vista title-bar band with a separator line | `shaders/ui_glass.gdshader`: mip-blurred `hint_screen_texture` (≈12px backdrop blur), rounded-rect SDF, animated sheen |
| **Gel buttons** | Candy gradient, bottom inner glow, a 50%-opacity white crescent specular on the top half. On press the button **sinks 3px** and the crescent **drops to 20%** | `shaders/ui_gel.gdshader` + `Aero.JellyButton` (pressed/hover/disabled/attention-pulse states) |
| **Liquid orbs** | Lens-refracted glass sphere, sine-wave fluid surface, rising carbonation, fresnel rim, crescent and glint, red alarm pulse | `shaders/ui_orb.gdshader` + `Aero.Orb`. The fill rides a spring, so it **sloshes** when the value jumps |
| **ATP test tube** | Horizontal glass cylinder, wobbling meniscus, fizzy bubbles, etched sweet zone (ratio 1.0–1.35) | `shaders/ui_tube.gdshader` + `Aero.Tube`. The liquid shifts acid-green → green → magenta |
| **LCD** | Backlit green 7-segment run clock with ghost "8" segments, GEN counter, fuel equalizer | `Aero.Lcd`, drawn with polygons (no font) |
| **Oscilloscopes** | Smoked-glass wells, cyan grid, glowing trace with a gradient fill | `Aero.Graph`: AMOEBA HUNGER (Digestion) and ROS HEAT (Mutation) |
| **Glossy headlines** | Two-tone "horizon" gradient lettering over a colored glow | `shaders/ui_gloss_text.gdshader` + `Aero.gloss_title` |
| **Toasts** | Vista balloon notifications that slide in with a glow | Glass pill + glow `LabelSettings` |
| **Type** | Segoe UI / Frutiger for the interface, Consolas for the LCD, and the cartoon Impact face kept for the comedy pop text in the world | `SystemFont` fallbacks |

**Layout.** In landscape, the Cell OS console window runs down the right edge, with the ATP tube along the bottom and the MITO FUEL vortex orb in the bottom-left. In portrait, the console becomes a top strip without graphs, and the gel buttons, tube, and fuel orb sit in the thumb zone. Every menu (Control Panel, Mitosis Wizard, Cellular Event Viewer, Paused) is a frosted window that pops in with a scale-and-fade animation.

---

## 5. Gameplay pass 2: decisions, telegraphing, variety

| Change | How it plays | Code |
|---|---|---|
| **Reactive zoom** | The camera pulls back about 30% while you race or when a phage or the boss is near, then settles back in. | `main.gd` `_update_camera` |
| **Edge arrows** | Gel arrows at the edge of the play area point to the 3 nearest snacks (lime), hunting viruses (red, pulsing harder as they close in) and Macrophage Mom (magenta). | `aero.gd` `EdgeArrows`, `main.gd` `_update_markers` |
| **ATP bombs (feed vs. defend)** | A canister that hits the membrane faster than 10.5 m/s punches out as an ATP bomb that pops viruses and rivals (blast radius 3.2, ×2 with Volatile ATP) and chips the boss. The aim dots turn **red** when a shot will exit. Every bomb is ATP the host doesn't eat. | `engine_room.gd` `_launch_bomb`, `sea.gd` `fire_bomb/_explode` |
| **Hold-to-OVERDRIVE** | A tap on the crank (Space, right-click or the CRANK gel) toggles I and II. **Holding** any of them is OVERDRIVE: production III, +30% speed, ramming threshold 5.5 → 3.0 m/s, and +2.5 Mutation per second. It's a nitro button, not a setting. | `main.gd` `_update_overdrive` |
| **Danger warnings** | At 75% on either meter: a callout, alarms that speed up, a pulsing lime or magenta vignette, the membrane shuddering, and Mito switching to his scared face. | `main.gd` `_danger_warnings`, `hud.set_danger` |
| **Virus target rings** | A pulsing red ring sits on the membrane exactly where a hunting phage will hit. | `sea.gd` `_update_marker` |
| **Popup merging** | Repeats within 0.8 s and 7 m merge into one label: "NOM! x3". | `main.gd` `pop` |
| **Compact sidebar** | The oscilloscopes moved into the pause window, and the sidebar shrank to the top of the right column. | `hud.gd` `layout`, `show_pause` |
| **New cards** | **Magnetic Membrane** (canisters home into the nucleus; viruses sense you from 30 m), **Hoover Pseudopods** (snacks and viruses get pulled in; unlocks at 80 mtDNA), **Volatile ATP** (double blast and an ATP refund; +4 Mutation per bomb; unlocks at 200 mtDNA). | `mutations.gd` |
| **Generation events** | Each generation after the first fires one surprise 8–18 s in: Virus Swarm, Food Bloom, Acid Tide or Radical Storm. | `main.gd` `_run_event` |
| **Boss: Macrophage Mom** | Every 5th generation. A giant gel immune cell that chases you, and digestion floods in while she's pressed against you. Damage her with ATP bombs (2) or OVERDRIVE rams (1). Beating her gives +40 mtDNA, a snack burst and −25 Digestion. | `sea.gd` `spawn_boss/_boss_update` |
| **Guided first run** | Six steps, one action each: steer, slingshot, flick, tap the crank, hold OVERDRIVE, launch a bomb. The meters can't kill you during it. SKIP is always available, and there's a TUTORIAL button on the title screen. It runs once per save. | `main.gd` tutorial block |

---

## 6. Feel & accessibility pass

| Change | Details | Code |
|---|---|---|
| **Distance-primed bombs** | Pull a canister past **80% of max drag** to prime it: it vibrates, the liquid turns hot orange, a "PRIMED!" zap plays, and the aim dots turn pulsing red. Release primed = ATP bomb that always exits through the membrane. Release below 80% = feeding shot that always stays inside. The old 10.5 m/s rule is gone. | `engine_room.gd` `BOMB_PRIME`, `_visuals`, `release`, `_aim` |
| **Bubble-gum tension** | While pulled, the canister stretches up to +55% along the pull and pinches 22% across it. | `engine_room.gd` `_visuals` |
| **Hit-stop** | A 45 ms freeze on bomb direct hits on the boss, multi-kills (2+ viruses) and peel-offs. | `main.gd` `hit_stop` |
| **Punch-through** | The membrane is shoved hard outward at the exit point and springs back, and an iridescent bubble spray fires. | `engine_room.gd` `_launch_bomb`, `sea.gd` `bubble_burst` |
| **EMERGENCY PURGE** | `F` or the red PURGE gel button (it pulses when either meter is critical). Vents 35 points off Digestion and Mutation. Costs 2 canisters, or dazes Mito for 1.5 s (production stops) if there aren't 2. 20 s cooldown shown on the button. | `main.gd` `emergency_purge`, `engine_room.gd` `purge_cost` |
| **Boss latch and peel-off** | Macrophage Mom presses a deep visible dent into the wall. Peel her off by slapping or tapping the dent 3 times, or by holding OVERDRIVE so Mito strains across the cell and headbutts the dent from inside (that one also does 1 damage). She's knocked away with a 2.5 s cooldown before she can latch again. | `membrane.gd` `dent`, `sea.gd` `slap_latch/peel_boss`, `engine_room.gd` `_mito_headbutt` |
| **Sugar Rush** | 3 snacks within 4 s gives 3.5 s of ×2 ATP production, no radicals, no Mutation gain, a subtle rainbow shimmer over the water and cytoplasm, and Mito's happy face. | `main.gd` `_count_snack/_tick_sugar_rush` |
