extends Node3D
## Symbio-Shack: the orchestrator. Builds the world, routes unified touch / mouse /
## keyboard input, runs the generation loop and the Tension Dial, and stages the
## two comedic deaths (Dissolved into Soup / Cellular Supernova).
##
## Command-line (after `--`):  --autotest  plays itself, exercises both deaths, then quits.

const Art = preload("res://scripts/art.gd")
const Tension = preload("res://scripts/tension.gd")
const Host = preload("res://scripts/host.gd")
const EngineRoom = preload("res://scripts/engine_room.gd")
const Sea = preload("res://scripts/sea.gd")
const Hud = preload("res://scripts/hud.gd")
const Synth = preload("res://scripts/synth.gd")
const Mutations = preload("res://scripts/mutations.gd")
const SOUP = preload("res://shaders/soup.gdshader")

const SAVE_PATH := "user://symbio_shack.cfg"
## Tight framing: the host fills ~85% of the play-area height (it was a speck in the soup).
const CAM_OFFSET := Vector3(0.0, 17.5, 11.1)
const BASE_SPEED := 7.0
const BASE_THRUST := 15.0
const JOY_RADIUS := 90.0
const MOUSE_ID := 1000
const WILD_AT := [45.0, 68.0, 86.0]
const WILD_KINDS := ["flagellum", "eye", "arm"]
const WILD_NAMES := {"flagellum": "SPINNY FLAGELLUM", "eye": "NOSY EXTRA EYE", "arm": "FLAILING PSEUDOPOD"}

var cam: Camera3D
var sun: DirectionalLight3D
var soup_floor: MeshInstance3D
var motes: CPUParticles3D
var glint: OmniLight3D
var floaters: CPUParticles3D
var droplets: CPUParticles3D
var host: Host
var room: EngineRoom
var sea: Sea
var hud: Hud
var synth: Synth
var tension: Tension

var state := "title"
var gen := 1
var food_goal := 8
var food_gen := 0
var food_total := 0
var run_time := 0.0
var owned: Array[String] = []
var throttle := 1
var shake := 0.0
var death_kind := ""
var death_t := 0.0
var ejecta: Array = []
var cry_cool := 0.0
var cilia_t := 0.0
var wild_slot: Array[String] = ["", "", ""]
var meta := {"mtdna": 0, "best_gen": 0, "runs": 0, "tutorial": 0}
var idle_t := 0.0
var pops_alive := 0
var _pop_live := {}

# crank: tap toggles I <-> II, HOLD (Space / right mouse / CRANK button) = OVERDRIVE
const TAP_TIME := 0.18
var base_throttle := 1
var overdrive := false
var _space_t := -1.0
var _rmb_t := -1.0
var _crank_ptr := -999
var _crank_t := 0.0

var zoom := 1.0
var event_t := -1.0
var bonus_dna := 0
var bosses_beaten := 0
var _alarm_t := 0.0
var _warned := {"dig": false, "mut": false}

# guided first run: one verb at a time
const TUTORIAL := [
	"STEER into sugar cubes: WASD / arrows, or drag on empty soup",
	"SLINGSHOT ATP: grab a glowing canister, pull back, let go into the purple nucleus",
	"FLICK the angry red free radical hard through the membrane",
	"TAP the CRANK (or Space) to shift the citric cycle up to II",
	"HOLD Space / right-click / CRANK for OVERDRIVE: faster and tougher, but it MUTATES you",
	"Pull a canister ALL the way back until it glows red, then let go: it punches out as an ATP BOMB",
]
var tut_step := -1
var _tut_od := 0.0

# feel / accessibility pass
const PURGE_COOLDOWN := 20.0
const RUSH_TIME := 3.5
var _hitstop := 0.0
var purge_cool := 0.0
var sugar_t := 0.0
var _snack_times: Array[float] = []

var pointers := {}
var joy_id := -999
var joy_origin := Vector2.ZERO
var joy_vec := Vector2.ZERO

var autotest := false
var auto_t := 0.0
var auto_step := 0.0
var auto_runs := 0
var auto_log := 0.0
var shot_dir := ""
var shot_t := 1.0
var shot_n := 0
var title_only := false
var shot_state := ""
var shot_paused := false
var face_test := false
var _face_step := 0
var _t_tut := false
var _t_event := false
var _t_boss := false
var _t_shots := 0
var _t_purge := false


func _ready() -> void:
	randomize()
	var args := OS.get_cmdline_user_args()
	autotest = args.has("--autotest")
	title_only = args.has("--title")
	face_test = args.has("--face-test")
	for a in args:
		if a.begins_with("--shots="):
			shot_dir = a.substr(8)
			autotest = true
	_load_meta()
	_build_world()
	synth = Synth.new()
	add_child(synth)
	tension = Tension.new()
	tension.prime(base_demand())
	sea = Sea.new()
	add_child(sea)
	_spawn_host()
	sea.setup(self, host)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	hud.show_title(meta)
	if autotest and not title_only:
		print("[autotest] starting")
		start_run()


func _build_world() -> void:
	# --- Liquid-glass lighting rig (see docs/GLASS_JELLY_LOOK.md) ---
	# A bright cyan sky exists only to be *reflected*: glass needs something to mirror.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("9fe8ff")
	sky_mat.sky_horizon_color = Color("5fd0ff")
	sky_mat.ground_bottom_color = Color("06264a")
	sky_mat.ground_horizon_color = Color("2a8fd0")
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("06294a")
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5fd4ff")
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.88
	env.glow_enabled = true
	env.glow_intensity = 1.3
	env.glow_bloom = 0.0           # no "bloom everything": only highlights over the threshold glow
	env.glow_hdr_scale = 1.0
	env.glow_strength = 1.0
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = Color("0a3d6a")
	env.fog_density = 0.009
	env.ssr_enabled = true
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 0.8
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Key: warm-white, high and from the top-left, gives the big glossy hotspot on every bubble.
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_color = Color.WHITE
	sun.light_energy = 1.3
	sun.light_specular = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	# Fill: cool cyan from the opposite side, lifts the shadow side into the water color.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, 145.0, 0.0)
	fill.light_color = Color("7fe6ff")
	fill.light_energy = 0.45
	fill.light_specular = 0.4
	add_child(fill)
	# Rim / backlight: low and from behind the subjects toward the camera, pink-white and
	# specular-heavy, so every glass edge gets a bright outline against the blue.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18.0, 180.0, 0.0)
	rim.light_color = Color("ffd6f5")
	rim.light_energy = 1.4
	rim.light_specular = 2.2
	add_child(rim)
	# Glint: a pure-white point light hovering over the cell (follows the host) so every
	# bubble and jelly body catches a crisp, bright specular sparkle.
	glint = OmniLight3D.new()
	glint.light_color = Color.WHITE
	glint.light_energy = 0.6
	glint.light_specular = 2.4
	glint.omni_range = 26.0
	glint.omni_attenuation = 0.6
	add_child(glint)

	cam = Camera3D.new()
	cam.fov = 42.0
	add_child(cam)
	cam.position = CAM_OFFSET
	cam.look_at(Vector3.ZERO)
	cam.current = true

	soup_floor = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(220.0, 220.0)
	soup_floor.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = SOUP
	soup_floor.material_override = sm
	soup_floor.position.y = -1.6
	add_child(soup_floor)

	motes = CPUParticles3D.new()
	motes.amount = 140
	motes.lifetime = 8.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(32.0, 4.0, 24.0)
	# glassy soup bubbles drifting up past the camera (Frutiger Aero ambience)
	motes.mesh = Art.sphere_mesh(0.2, 16)
	motes.material_override = Art.bubble(Color("e8fbff"), 0.0, 1.6, 0.02, 0.85)
	motes.scale_amount_min = 0.4
	motes.scale_amount_max = 1.6
	motes.gravity = Vector3(0.0, 0.35, 0.0)
	motes.spread = 180.0
	motes.initial_velocity_min = 0.1
	motes.initial_velocity_max = 0.4
	motes.local_coords = false
	add_child(motes)

	# Foreground "surface floaters": buoyant iridescent bubbles + micro-droplets drifting
	# between the camera and the cell. Their height gives free parallax as the camera follows.
	floaters = CPUParticles3D.new()
	floaters.amount = 20
	floaters.lifetime = 14.0
	floaters.preprocess = 14.0
	floaters.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	floaters.emission_box_extents = Vector3(22.0, 3.0, 14.0)
	floaters.mesh = Art.sphere_mesh(0.4, 20)
	floaters.material_override = Art.bubble(Color("f2fdff"), 0.0, 1.9, 0.0, 0.9)
	floaters.scale_amount_min = 0.5
	floaters.scale_amount_max = 1.5
	floaters.direction = Vector3(1.0, 0.15, 0.35)
	floaters.spread = 25.0
	floaters.initial_velocity_min = 0.3
	floaters.initial_velocity_max = 0.8
	floaters.gravity = Vector3(0.0, 0.06, 0.0)
	floaters.local_coords = false
	add_child(floaters)
	droplets = floaters.duplicate() as CPUParticles3D
	droplets.amount = 40
	droplets.mesh = Art.sphere_mesh(0.09, 10)
	droplets.scale_amount_max = 1.0
	add_child(droplets)


func _spawn_host() -> void:
	if host and is_instance_valid(host):
		host.queue_free()
	host = Host.new()
	add_child(host)
	room = EngineRoom.new()
	host.add_child(room)
	room.build(self, host)
	if sea:
		sea.host = host


# ---------------------------------------------------------------- run flow

func start_run() -> void:
	for e in ejecta:
		if is_instance_valid(e["node"]):
			e["node"].queue_free()
	ejecta.clear()
	gen = 1
	_spawn_host()
	sea.reset()
	tension = Tension.new()
	tension.prime(base_demand())
	food_gen = 0
	food_goal = _goal(1)
	food_total = 0
	run_time = 0.0
	owned.clear()
	throttle = 1
	base_throttle = 1
	overdrive = false
	wild_slot = ["", "", ""]
	cry_cool = 0.0
	cilia_t = 0.0
	death_kind = ""
	shake = 0.0
	event_t = -1.0
	bonus_dna = 0
	bosses_beaten = 0
	purge_cool = 0.0
	sugar_t = 0.0
	_snack_times.clear()
	_warned = {"dig": false, "mut": false}
	_drop_pointers()
	state = "play"
	hud.hide_overlays()
	hud.set_cry_visible(false)
	hud.banner("DON'T DIGEST ME!", Color("ffb02e"))
	tut_step = 0 if int(meta.get("tutorial", 0)) == 0 and not autotest else -1
	_tut_od = 0.0
	_show_tutorial()
	sfx("chime")
	cam.position = host.position + CAM_OFFSET


func _goal(g: int) -> int:
	return 8 + g * 3


func base_demand() -> float:
	return 0.45 + 0.07 * (gen - 1)


func _gen_complete() -> void:
	state = "cards"
	_drop_pointers()
	sfx("chime")
	hud.banner("MITOSIS!", Color("ffe14d"))
	hud.show_cards(Mutations.roll(owned, int(meta["mtdna"]), 3), gen + 1, _pick_card)


func _pick_card(id: String) -> void:
	if state != "cards":
		return
	if Mutations.CARDS.has(id):
		owned.append(id)
	elif id == "snack":
		room.fuel = EngineRoom.FUEL_CAP
	elif id == "patch":
		tension.instability = maxf(0.0, tension.instability - 30.0)
		tension.digestion = maxf(0.0, tension.digestion - 30.0)
	gen += 1
	food_gen = 0
	food_goal = _goal(gen)
	tension.atp_rate = maxf(tension.atp_rate, base_demand())
	state = "play"
	hud.hide_overlays()
	hud.set_cry_visible(has_mut("lysosome"))
	hud.banner("GENERATION %d" % gen, Color("7dff6a"))
	sfx("chime")
	# every generation gets one surprise, and every 5th brings Macrophage Mom
	event_t = randf_range(8.0, 18.0)
	if gen % 5 == 0:
		sea.spawn_boss(4 + gen / 5 * 2)
		hud.banner("MACROPHAGE MOM IS HUNGRY!", Color("ff4fd8"), 46)
		sfx("alarm")


func _die(kind: String) -> void:
	state = "dying"
	death_kind = kind
	death_t = 0.0
	_drop_pointers()
	if kind == "soup":
		room.melt()
		hud.banner("DISSOLVED INTO SOUP", Color("b6ff3a"), 60)
		sfx("blorp")
		for e in host.eyes:
			e.crazy = 3.0
	else:
		host.membrane.explode()
		ejecta = room.eject() + host.eject_face()
		hud.banner("CELLULAR SUPERNOVA!", Color("ffe14d"), 60)
		hud.flash(Color(1.0, 1.0, 0.85, 0.95), 0.9)
		sfx("kaboom")
		shake = 2.5
		sun.light_energy = 6.0


func _show_death() -> void:
	state = "dead"
	sun.light_energy = 1.25
	var earned := food_total * 2 + (gen - 1) * 15 + sea.squashed * 3 + int(run_time / 10.0) + bonus_dna
	var before := int(meta["mtdna"])
	meta["mtdna"] = before + earned
	meta["best_gen"] = maxi(int(meta["best_gen"]), gen)
	meta["runs"] = int(meta["runs"]) + 1
	_save_meta()
	var soup := death_kind == "soup"
	var flavor := "The host finally remembered you were lunch. You are now a light, zesty bisque." if soup \
		else "You overclocked the citric acid cycle and the host became a tiny, beautiful sun."
	var stats := "Generation reached: %d\nFood engulfed: %d\nViruses squashed: %d\nMacrophages beaten: %d\nSurvived: %ds" % [gen, food_total, sea.squashed, bosses_beaten, int(run_time)]
	hud.show_death({
		"title": "DISSOLVED INTO SOUP" if soup else "CELLULAR SUPERNOVA!",
		"flavor": flavor, "stats": stats, "earned": earned, "total": meta["mtdna"],
		"unlocks": Mutations.newly_unlocked(before, int(meta["mtdna"])), "soup": soup,
	})
	if autotest:
		print("[autotest] death=%s gen=%d food=%d squashed=%d t=%.1f earned=%d" % [death_kind, gen, food_total, sea.squashed, run_time, earned])


func toggle_pause() -> void:
	if state == "play":
		state = "paused"
		_drop_pointers()
		hud.show_pause(true)
	elif state == "paused":
		state = "play"
		hud.show_pause(false)


## Abandon the current run (no mtDNA payout) and go back to the title window.
func quit_to_title() -> void:
	for e in ejecta:
		if is_instance_valid(e["node"]):
			e["node"].queue_free()
	ejecta.clear()
	gen = 1
	_spawn_host()
	sea.reset()
	tension = Tension.new()
	tension.prime(base_demand())
	owned.clear()
	throttle = 1
	base_throttle = 1
	overdrive = false
	tut_step = -1
	hud.set_hint("")
	wild_slot = ["", "", ""]
	run_time = 0.0
	food_gen = 0
	_drop_pointers()
	state = "title"
	hud.show_title(meta)


func toggle_mute() -> void:
	synth.muted = not synth.muted
	hud.set_muted(synth.muted)


# ---------------------------------------------------------------- frame loop

func _process(delta: float) -> void:
	# clamp hitches (shader compiles, window drags) so the Verlet membrane never explodes
	var dt := minf(delta, 1.0 / 30.0)
	# hit-stop: a few frozen frames sell big impacts (camera + HUD keep drawing)
	if _hitstop > 0.0:
		_hitstop -= delta
		hud.update_hud(0.0)
		return
	match state:
		"title", "dead":
			idle_t += dt
			var idle: Vector2 = Vector2(cos(idle_t * 0.35), sin(idle_t * 0.5)) * 0.3 if state == "title" else Vector2.ZERO
			host.move(dt, idle, BASE_SPEED, BASE_THRUST)
			room.update(dt)
			sea.passive = true
			sea.update(dt)
			_tick_ejecta(dt)
		"play":
			_tick_play(dt)
		"dying":
			_tick_dying(dt)
	_update_camera(dt)
	_update_markers()
	hud.update_hud(dt)
	if autotest:
		_autopilot(dt)


func _tick_play(dt: float) -> void:
	run_time += dt
	var steer := _steer_input()
	if host.has_wild("flagellum"):
		steer = steer.rotated(sin(run_time * 2.3) * 1.1) + Vector2(cos(run_time * 1.7), sin(run_time * 1.3)) * 0.35
	if host.has_wild("eye"):
		var v := sea.nearest_virus(host.pos)
		if v != Vector2.INF:
			steer += (v - host.pos).normalized() * 0.45
	_update_overdrive(dt)
	var top := BASE_SPEED * speed_mult()
	host.hunger = tension.digestion / 100.0
	host.move(dt, steer.limit_length(1.0), top * tension.energy_factor(), BASE_THRUST * speed_mult())
	if host.lunged:
		host.lunged = false
		pop("FLAIL!", host.position + Vector3(0.0, 2.5, 0.0), Color("ff6fae"), 0.9)
		sfx("boing")
	room.update(dt)
	sea.passive = false
	sea.update(dt)
	if has_mut("cilia") and host.vel.length() > top * 0.7:
		cilia_t += dt
		if cilia_t > 2.6:
			cilia_t = 0.0
			room.spawn_radical_at_mito()
			pop("PFFT! CILIA EXHAUST", host.position + Vector3(0.0, 2.5, 0.0), Color("ff8a2b"), 0.7)
	cry_cool = maxf(0.0, cry_cool - dt)
	var speed_frac := clampf(host.vel.length() / top, 0.0, 1.0)
	var inst_before := tension.instability
	tension.step(dt, base_demand(), speed_frac, room.radical_count(), demand_mult())
	if overdrive:
		tension.instability = minf(100.0, tension.instability + 2.5 * dt)
	_tick_sugar_rush(dt, inst_before)
	purge_cool = maxf(0.0, purge_cool - dt)
	if tut_step >= 0:
		# the tutorial is a safe sandbox: meters can't reach lethal levels
		tension.digestion = minf(tension.digestion, 45.0)
		tension.instability = minf(tension.instability, 60.0)
		_tick_tutorial(dt)
	if event_t > 0.0:
		event_t -= dt
		if event_t <= 0.0:
			_run_event()
	_danger_warnings(dt)
	_check_wild()
	if tension.digestion >= 100.0:
		_die("soup")
	elif tension.instability >= 100.0:
		_die("supernova")


func _tick_dying(dt: float) -> void:
	death_t += dt
	host.move(dt, Vector2.ZERO, BASE_SPEED, BASE_THRUST)
	if death_kind == "soup":
		host.membrane.deflate = minf(1.0, death_t / 2.0)
		host.membrane.acid = minf(1.0, death_t)
	else:
		host.membrane.fade = maxf(0.0, 1.0 - death_t / 1.2)
	_tick_ejecta(dt)
	sea.passive = true
	sea.update(dt)
	if death_t > 2.8:
		_show_death()


func _tick_ejecta(dt: float) -> void:
	for e in ejecta:
		var node: Node3D = e["node"]
		if not is_instance_valid(node):
			continue
		var v: Vector3 = e["vel"]
		v.y -= 16.0 * dt
		v *= exp(-0.4 * dt)
		var p := node.position + v * dt
		if p.y < -1.3:
			p.y = -1.3
			v = Vector3(v.x * 0.7, absf(v.y) * 0.35, v.z * 0.7)
		node.position = p
		e["vel"] = v
		var spin: Vector3 = e["spin"]
		if spin.length() > 0.05:
			node.rotate(spin.normalized(), spin.length() * dt)
			e["spin"] = spin * exp(-0.8 * dt)


func _check_wild() -> void:
	for i in 3:
		var th: float = WILD_AT[i]
		if wild_slot[i] == "" and tension.instability >= th:
			var free_kinds := WILD_KINDS.filter(func(k): return not wild_slot.has(k))
			if free_kinds.is_empty():
				continue
			var k: String = free_kinds.pick_random()
			wild_slot[i] = k
			host.add_wild(k)
			hud.banner("WILD MUTATION: %s!" % WILD_NAMES[k], Color("ff5ad1"), 44)
			sfx("mutate")
			add_shake(0.6)
		elif wild_slot[i] != "" and tension.instability < th - 15.0:
			hud.banner("phew, the %s shriveled up" % String(WILD_NAMES[wild_slot[i]]).to_lower(), Color("b6ff5a"), 32)
			host.remove_wild(wild_slot[i])
			wild_slot[i] = ""


func _update_camera(dt: float) -> void:
	var target := host.global_position
	var off := CAM_OFFSET
	if state == "dying" and death_kind == "soup":
		off = CAM_OFFSET * lerpf(1.0, 0.62, minf(1.0, death_t / 2.5))
	# reactive zoom: pull back while racing or when something dangerous is closing in
	var want_zoom := 1.0
	if state == "play" and (host.vel.length() > BASE_SPEED * 0.65 or sea.threat_near(host.pos, 16.0) or sea.boss_active()):
		want_zoom = 1.32
	zoom = lerpf(zoom, want_zoom, minf(1.0, dt * 1.4))
	off *= zoom
	glint.position = target + Vector3(-2.0, 9.0, 3.0)
	# with the tight zoom, re-center the cell in the free play area (left of the sidebar,
	# above the ATP energy bar) instead of the raw screen center
	var vs := get_viewport().get_visible_rect().size
	if state in ["play", "cards", "paused", "dying"]:
		var vh := 2.0 * off.length() * tan(deg_to_rad(cam.fov) * 0.5)
		if vs.x > vs.y:
			var vw := vh * vs.x / vs.y
			target.x += (Hud.CONSOLE_W + 24.0) * 0.5 / vs.x * vw
			target.z += 60.0 / vs.y * vh / 0.84
		else:
			target.z += -40.0 / vs.y * vh / 0.84
	cam.position = cam.position.lerp(target + off, minf(1.0, dt * 4.0))
	shake = maxf(0.0, shake - dt * 2.5)
	var s := shake * shake
	cam.h_offset = randf_range(-1.0, 1.0) * s * 0.6
	cam.v_offset = randf_range(-1.0, 1.0) * s * 0.6
	soup_floor.position = Vector3(snappedf(target.x, 10.0), -1.6, snappedf(target.z, 10.0))
	motes.position = target
	floaters.position = target + Vector3(0.0, 11.0, 4.0)
	droplets.position = target + Vector3(0.0, 7.0, 3.0)


func _on_resize() -> void:
	var s := get_viewport().get_visible_rect().size
	if s.x < s.y:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = 46.0
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = 42.0
	if hud:
		hud.layout(s)


# ---------------------------------------------------------------- events from room / sea

func on_atp_delivered(charge: float, at: Vector3) -> void:
	tension.deliver(charge)
	room.mito_expr.on_fuel_consumed()
	pop("+ATP", at, Color("7dff6a"), 0.9)
	sfx("gulp")
	_tutorial_event("atp")


## A canister slammed through the membrane becomes an ATP bomb out in the sea:
## you spend the host's food to defend it (feed vs. defend).
func on_canister_launched(exit: Vector2, vel: Vector2, charge: float) -> void:
	sea.fire_bomb(exit, vel, charge)
	if autotest:
		print("[autotest] ATP bomb launched")
	if has_mut("volatile"):
		tension.instability = minf(100.0, tension.instability + 4.0)
	pop("ATP BOMB!", Vector3(exit.x, 1.5, exit.y), Color("7dff6a"), 1.0)
	sfx("sling")
	add_shake(0.3)
	_tutorial_event("bomb")


func on_boss_defeated(at: Vector3) -> void:
	bosses_beaten += 1
	if autotest:
		print("[autotest] boss defeated")
	bonus_dna += 40
	pop("MACROPHAGE MOM DEFEATED! +40 mtDNA", at + Vector3(0.0, 3.0, 0.0), Color("ff4fd8"), 1.3)
	hud.banner("MACROPHAGE MOM DEFEATED!", Color("ff4fd8"), 44)
	sfx("chime")
	sfx("kaboom", 0.6)
	add_shake(1.2)
	tension.digestion = maxf(0.0, tension.digestion - 25.0)


func on_food_eaten(value: float) -> void:
	if state != "play":
		return
	room.add_food(value)
	food_gen += 1
	_count_snack()
	food_total += 1
	if food_gen >= food_goal:
		_gen_complete()


func on_infected(angle: float, at: Vector3) -> void:
	room.inject_radicals(2, angle)
	room.mito_expr.on_hurt()
	tension.instability += 4.0
	pop("INFECTED!", at, Color("ff5ad1"), 1.0)
	sfx("infect")
	add_shake(0.7)
	hud.flash(Color(1.0, 0.3, 0.7, 0.35), 0.3)


func on_radical_expelled(at: Vector3) -> void:
	tension.instability = maxf(0.0, tension.instability - 1.0)
	pop("PTOO!", at, Color("ffb02e"), 0.9)
	sfx("ptoo")
	_tutorial_event("radical")


func on_rival_bump(at: Vector3) -> void:
	room.fuel = maxf(0.0, room.fuel - 0.6)
	pop("HEY! MY LUNCH!", at, Color("4aa8ff"), 0.9)
	sfx("bonk")


# ---------------------------------------------------------------- mutation hooks

func has_mut(id: String) -> bool:
	return owned.has(id)


func speed_mult() -> float:
	var m := 1.0
	if has_mut("cilia"):
		m += 0.35
	if has_mut("vacuole"):
		m -= 0.2
	if overdrive:
		m += 0.3
	return m


## Ramming speed needed to squash a virus / damage a boss (much lower in OVERDRIVE).
func ram_speed() -> float:
	return 3.0 if overdrive else 5.5


func virus_range() -> float:
	return 30.0 if has_mut("magnet") else 22.0


func in_danger() -> bool:
	return tension.digestion >= 75.0 or tension.instability >= 75.0


func demand_mult() -> float:
	return 1.2 if has_mut("spicy") else 1.0


func bounce_mult() -> float:
	return 1.22 if has_mut("spicy") else 1.0


func prod_mult() -> float:
	return 2.0 if sugar_t > 0.0 else 1.0


func ros_mult() -> float:
	if sugar_t > 0.0:
		return 0.0
	return 0.6 if has_mut("antiox") else 1.0


func charge_mult() -> float:
	return 0.85 if has_mut("antiox") else 1.0


func food_mult() -> float:
	return 2.0 if has_mut("vacuole") else 1.0


func clog_mult() -> float:
	return 2.0 if has_mut("vacuole") else 1.0


func catch_bonus() -> float:
	return 0.85 if has_mut("rubbernuc") else 0.0


# ---------------------------------------------------------------- actions

## Tap the crank: toggle the citric cycle between I (idle) and II (cruise).
func cycle_throttle() -> void:
	set_throttle(2 if base_throttle == 1 else 1)


func set_throttle(v: int) -> void:
	if state != "play":
		return
	if v >= 3:
		pop("HOLD FOR OVERDRIVE", room.console_world(), Color("ff4a3d"), 0.7)
		return
	v = clampi(v, 1, 2)
	if v == base_throttle:
		return
	base_throttle = v
	if not overdrive:
		throttle = v
	sfx("crank", 0.8 + v * 0.25)
	pop(["IDLE", "CRUISE"][v - 1], room.console_world(), [Color("7dff6a"), Color("ffe14d")][v - 1], 0.8)


## OVERDRIVE is held, not toggled: Space, right mouse, or pressing and holding CRANK.
## While held: production III, +30% speed, cheap rams, but Mutation climbs fast.
func _update_overdrive(dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var held := (_space_t >= 0.0 and now - _space_t > TAP_TIME) \
		or (_rmb_t >= 0.0 and now - _rmb_t > TAP_TIME) \
		or (_crank_ptr != -999 and now - _crank_t > TAP_TIME)
	if held != overdrive:
		overdrive = held
		if overdrive:
			pop("OVERDRIVE!", host.position + Vector3(0.0, 3.0, 0.0), Color("ff4a3d"), 1.2)
			sfx("crank", 1.6)
			sfx("zap")
		else:
			sfx("crank", 0.7)
	throttle = 3 if overdrive else base_throttle
	if overdrive:
		shake = maxf(shake, 0.22)
		_tut_od += dt


func _crank_press(id: int) -> void:
	_crank_ptr = id
	_crank_t = Time.get_ticks_msec() / 1000.0
	hud.activate("crank_visual")


func _crank_release() -> void:
	if _crank_ptr == -999:
		return
	if Time.get_ticks_msec() / 1000.0 - _crank_t <= TAP_TIME:
		cycle_throttle()
	_crank_ptr = -999


func fire_cry() -> void:
	if state != "play" or not has_mut("lysosome") or cry_cool > 0.0:
		return
	cry_cool = 1.5
	var dir: Vector2 = host.vel.normalized() if host.vel.length() > 0.5 else Vector2(0.0, -1.0)
	sea.fire_tear(host.pos + dir * (Host.R + 0.8), dir * 17.0 + host.vel)
	room.add_puddle()
	pop("WAAAH!", host.position + Vector3(0.0, 2.5, 0.0), Color("6fe8ff"), 1.0)
	sfx("cry")


func pop(text: String, at: Vector3, color: Color, size: float = 1.0) -> void:
	# merge repeats ("NOM! NOM! NOM!" -> "NOM! x3") instead of stacking clutter
	var now := Time.get_ticks_msec() / 1000.0
	if _pop_live.has(text):
		var e: Dictionary = _pop_live[text]
		var ref = e["label"]
		if not is_instance_valid(ref):
			_pop_live.erase(text)
		elif now - float(e["t"]) < 0.8 and (ref as Label3D).position.distance_to(at) < 7.0:
			var old := ref as Label3D
			e["count"] = int(e["count"]) + 1
			e["t"] = now
			old.text = "%s x%d" % [text, e["count"]]
			var bump := old.create_tween()
			bump.tween_property(old, "scale", Vector3.ONE * 1.3, 0.06)
			bump.tween_property(old, "scale", Vector3.ONE, 0.12)
			return
	if pops_alive > 24:
		return
	pops_alive += 1
	var l := Label3D.new()
	l.text = text
	l.font = hud.font
	l.font_size = int(64.0 * size)
	l.outline_size = 18
	l.modulate = color
	l.outline_modulate = Art.INK
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.012
	l.render_priority = 10
	l.position = at + Vector3(0.0, 1.0, 0.0)
	l.scale = Vector3.ONE * 0.2
	_pop_live[text] = {"label": l, "count": 1, "t": now}
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.15, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE, 0.1)
	tw.parallel().tween_property(l, "position:y", l.position.y + 2.2, 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		pops_alive -= 1
		l.queue_free())


func sfx(sound: String, amt: float = 1.0) -> void:
	synth.play(sound, amt)


func add_shake(a: float) -> void:
	shake = minf(shake + a, 2.5)


# ---------------------------------------------------------------- input

func _steer_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	return (v.limit_length(1.0) + joy_vec).limit_length(1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			_on_key(k.physical_keycode)
		elif not k.pressed and k.physical_keycode == KEY_SPACE and _space_t >= 0.0:
			# Space: quick tap toggles I/II, holding it is OVERDRIVE
			if Time.get_ticks_msec() / 1000.0 - _space_t <= TAP_TIME:
				cycle_throttle()
			_space_t = -1.0
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_pointer_down(st.index, st.position)
		else:
			_pointer_up(st.index, st.position)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_pointer_move(sd.index, sd.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pointer_down(MOUSE_ID, mb.position)
			else:
				_pointer_up(MOUSE_ID, mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			# right mouse: quick click toggles I/II, hold = OVERDRIVE
			if mb.pressed:
				_rmb_t = Time.get_ticks_msec() / 1000.0
			elif _rmb_t >= 0.0:
				if Time.get_ticks_msec() / 1000.0 - _rmb_t <= TAP_TIME:
					cycle_throttle()
				_rmb_t = -1.0
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_pointer_move(MOUSE_ID, mm.position)


func _on_key(k: int) -> void:
	match k:
		KEY_SPACE, KEY_ENTER:
			if state == "play" and k == KEY_SPACE:
				_space_t = Time.get_ticks_msec() / 1000.0
			elif state == "title" or state == "dead":
				start_run()
			elif state == "paused":
				toggle_pause()
		KEY_1, KEY_2, KEY_3:
			if state == "cards":
				hud.pick_index(k - KEY_1)
			else:
				set_throttle(k - KEY_1 + 1)
		KEY_F:
			emergency_purge()
		KEY_E:
			fire_cry()
		KEY_P, KEY_ESCAPE:
			toggle_pause()
		KEY_M:
			toggle_mute()


func _pointer_down(id: int, pos: Vector2) -> void:
	if state != "play":
		return
	var b := hud.button_at(pos)
	if b == "crank":
		pointers[id] = "crank"
		_crank_press(id)
		return
	if b != "":
		hud.activate(b)
		return
	# slapping the wall where Macrophage Mom is latched knocks her loose
	if sea.slap_latch(_screen_to_local(pos)):
		return
	if room.try_grab(id, _screen_to_local(pos)):
		pointers[id] = "room"
		return
	if joy_id == -999:
		joy_id = id
		joy_origin = pos
		joy_vec = Vector2.ZERO
		pointers[id] = "joy"


func _pointer_move(id: int, pos: Vector2) -> void:
	if id == joy_id:
		joy_vec = ((pos - joy_origin) / JOY_RADIUS).limit_length(1.0)
	elif pointers.get(id, "") == "room":
		room.drag(id, _screen_to_local(pos))


func _pointer_up(id: int, pos: Vector2) -> void:
	if id == joy_id:
		joy_id = -999
		joy_vec = Vector2.ZERO
	elif pointers.get(id, "") == "room":
		room.release(id, _screen_to_local(pos))
	elif pointers.get(id, "") == "crank":
		_crank_release()
	pointers.erase(id)


func _drop_pointers() -> void:
	pointers.clear()
	joy_id = -999
	joy_vec = Vector2.ZERO
	_crank_ptr = -999
	_space_t = -1.0
	_rmb_t = -1.0
	if room:
		room.release_all()


## Screen point -> host-local point on the engine-room plane.
func _screen_to_local(pos: Vector2) -> Vector2:
	var o := cam.project_ray_origin(pos)
	var d := cam.project_ray_normal(pos)
	if absf(d.y) < 0.001:
		return Vector2(1e6, 1e6)
	var w := o + d * ((0.45 - o.y) / d.y)
	return Vector2(w.x - host.position.x, w.z - host.position.z)


# ---------------------------------------------------------------- save

func _load_meta() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		for k in meta.keys():
			meta[k] = int(cf.get_value("meta", k, meta[k]))


func _save_meta() -> void:
	if autotest:
		return
	var cf := ConfigFile.new()
	for k in meta.keys():
		cf.set_value("meta", k, meta[k])
	cf.save(SAVE_PATH)


# ---------------------------------------------------------------- self-test autopilot

func _autopilot(dt: float) -> void:
	auto_t += dt
	auto_step -= dt
	auto_log -= dt
	if shot_dir != "":
		shot_t -= dt
		if state != shot_state:
			# grab every new window (cards, pause, death) once its pop-in animation settles
			shot_state = state
			shot_t = minf(shot_t, 0.7)
			if state == "dead" or state == "cards":
				auto_step = 1.5
		if shot_t <= 0.0:
			shot_t = 1.5
			shot_n += 1
			get_viewport().get_texture().get_image().save_png("%s/shot_%02d_%s.png" % [shot_dir, shot_n, state])
		if title_only and auto_t > 1.5:
			get_tree().quit()
			return
	if title_only:
		return
	if face_test and state == "play":
		_face_test_step()
		return
	if auto_log <= 0.0 and state == "play":
		auto_log = 4.0
		print("[autotest] t=%.1f gen=%d food=%d/%d fuel=%.1f atp=%.2f/%.2f dig=%.0f inst=%.0f bodies=%d rads=%d" % [
			run_time, gen, food_gen, food_goal, room.fuel, tension.atp_rate, tension.demand,
			tension.digestion, tension.instability, room.bodies.size(), room.radical_count()])
		if sea.boss:
			print("[autotest] boss hp=%d latched=%s dist=%.1f" % [sea.boss.hp, sea.boss.latched, sea.boss.pos.distance_to(host.pos)])
	match state:
		"dead":
			if auto_step <= 0.0:
				auto_runs += 1
				if auto_runs >= 2:
					print("[autotest] done, all good")
					get_tree().quit()
					return
				auto_step = 1.0
				start_run()
			return
		"cards":
			if auto_step <= 0.0:
				auto_step = 1.4 if shot_dir != "" else 0.4
				hud.pick_index(randi() % 3)
			return
		"paused":
			if auto_step <= 0.0:
				toggle_pause()
			return
		"play":
			if shot_dir != "" and auto_runs == 1 and run_time > 5.0 and not shot_paused:
				shot_paused = true
				auto_step = 1.4
				toggle_pause()
				return
			# exercise the new systems: tutorial (run 2), an event + a boss fight (run 1),
			# and periodic OVERDRIVE holds (simulated held Space) in every run
			if auto_runs == 1 and not _t_tut:
				_t_tut = true
				tut_step = 0
				_show_tutorial()
				print("[autotest] tutorial started")
			if auto_runs == 0 and run_time > 3.0 and not _t_event:
				_t_event = true
				_run_event()
				print("[autotest] event fired")
			if auto_runs == 0 and run_time > 5.0 and not _t_boss:
				_t_boss = true
				sea.spawn_boss(4)
				sea.boss.pos = host.pos + Vector2(1.0, 0.3).normalized() * (Host.R + sea.boss.r - 0.2)
				print("[autotest] boss spawned")
			_space_t = Time.get_ticks_msec() / 1000.0 - 1.0 if fmod(run_time, 6.0) > 4.5 else -1.0
			if auto_runs == 0 and run_time > 9.0 and not _t_purge:
				_t_purge = true
				emergency_purge()
				print("[autotest] purge fired (cooldown %.0f)" % purge_cool)
			if sea.boss_latched() and randf() < 0.1:
				sea.slap_latch(sea.latch_point())
		_:
			return
	var f := sea.nearest_food(host.pos)
	joy_vec = (f - host.pos).normalized() * 0.9 if f != Vector2.INF else Vector2.ZERO
	if sea.boss and sea.boss.pos.distance_to(host.pos) < 16.0:
		joy_vec = (sea.boss.pos - host.pos).normalized() * 0.2   # let her latch on so we can test peeling
	if room.clogged and randf() < dt * 1.5:
		room.unclog()
	# scripted beats: a card pick at 6s, then a supernova (run 1) and a soup death (run 2)
	if auto_runs == 0 and gen == 1 and run_time > 6.0:
		food_gen = food_goal - 1
		on_food_eaten(1.0)
		return
	if auto_runs == 0 and run_time > 8.0 and not has_mut("lysosome"):
		owned.append("lysosome")
		hud.set_cry_visible(true)
	if has_mut("lysosome") and cry_cool <= 0.0 and randf() < 0.3:
		fire_cry()
	if auto_runs == 0 and run_time > 13.0:
		tension.instability += dt * 25.0
	if auto_runs == 1 and run_time > 12.0:
		tension.digestion += dt * 30.0
	if auto_step > 0.0:
		return
	auto_step = 0.35
	set_throttle(2)
	if room.holds.has(901):
		room.release(901, Vector2.ZERO)
		return
	var rad = room.first_body(EngineRoom.Kind.RADICAL)
	if rad:
		var out: Vector2 = rad.pos.normalized()
		room.try_grab(902, rad.pos)
		room.drag(902, rad.pos + out * 0.2)
		room.release(902, rad.pos + out * 1.0)
		return
	var can = room.first_body(EngineRoom.Kind.CANISTER)
	if can:
		var to: Vector2 = (room.nucleus_pos() - can.pos).normalized()
		_t_shots += 1
		if _t_shots % 3 == 0:
			to = can.pos.normalized()   # every 3rd shot: slam it out as an ATP bomb
		if room.try_grab(901, can.pos):
			room.drag(901, can.pos - to * (2.95 if _t_shots % 3 == 0 else 2.1))


## Debug: `-- --shots=DIR --face-test` triggers each Mito expression and screenshots it.
func _face_test_step() -> void:
	var beats := [[2.0, "idle"], [3.0, "feed"], [3.45, "shot_happy"], [5.0, "hurt"], [5.3, "shot_scared"], [6.0, "quit"]]
	if _face_step >= beats.size() or run_time < float(beats[_face_step][0]):
		return
	var what: String = beats[_face_step][1]
	_face_step += 1
	match what:
		"idle", "shot_happy", "shot_scared":
			get_viewport().get_texture().get_image().save_png("%s/face_%s.png" % [shot_dir, what.replace("shot_", "")])
		"feed":
			room.mito_expr.on_fuel_consumed()
		"hurt":
			room.mito_expr.on_hurt()
		"quit":
			get_tree().quit()


# ---------------------------------------------------------------- off-screen markers

## Glossy edge arrows for things you can't see: nearest snacks (green), hunting
## viruses (red, pulsing as they close in) and Macrophage Mom (big magenta).
func _update_markers() -> void:
	var marks: Array = []
	if state == "play":
		var hp: Vector2 = host.pos
		var near_food: Array = []
		for f in sea.foods:
			if not f.dead:
				near_food.append([f.pos.distance_squared_to(hp), f.pos])
		near_food.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(3, near_food.size()):
			var p: Vector2 = near_food[i][1]
			marks.append({"p": cam.unproject_position(Vector3(p.x, 0.7, p.y)), "kind": "food", "u": 0.0})
		for v in sea.viruses:
			if v.dead:
				continue
			var d := v.pos.distance_to(hp)
			if d < 40.0:
				marks.append({"p": cam.unproject_position(Vector3(v.pos.x, 0.9, v.pos.y)), "kind": "virus", "u": clampf(1.0 - (d - Host.R) / 16.0, 0.0, 1.0)})
		if sea.boss:
			var bp: Vector2 = sea.boss.pos
			marks.append({"p": cam.unproject_position(Vector3(bp.x, 1.5, bp.y)), "kind": "boss", "u": 1.0})
	hud.set_markers(marks)


# ---------------------------------------------------------------- generation events

func _run_event() -> void:
	var kind: String = ["swarm", "bloom", "acid", "storm"].pick_random()
	match kind:
		"swarm":
			sea.spawn_swarm(4 + gen / 2)
			hud.banner("VIRUS SWARM INCOMING!", Color("ff3b5a"), 44)
			sfx("alarm")
		"bloom":
			sea.spawn_bloom()
			hud.banner("FOOD BLOOM!", Color("9dff2e"), 44)
			sfx("chime")
		"acid":
			tension.digestion = minf(95.0, tension.digestion + 12.0)
			for k in 3:
				room.add_puddle()
			hud.banner("ACID TIDE!", Color("c6ff3a"), 44)
			sfx("blorp", 0.6)
		"storm":
			room.inject_radicals(3, randf() * TAU)
			hud.banner("RADICAL STORM!", Color("ff6a3d"), 44)
			sfx("zap")
	add_shake(0.6)


# ---------------------------------------------------------------- danger warnings

## Telegraph death well before it happens: alarms, red/magenta pulses, membrane shudder,
## a one-time callout per meter, and Mito panics (engine_room asks in_danger()).
func _danger_warnings(dt: float) -> void:
	var dig := tension.digestion
	var mut := tension.instability
	for key in ["dig", "mut"]:
		var val: float = dig if key == "dig" else mut
		if val >= 75.0 and not _warned[key]:
			_warned[key] = true
			hud.banner("DIGESTION CRITICAL!" if key == "dig" else "MUTATION CRITICAL!", Color("c6ff3a") if key == "dig" else Color("ff4fd8"), 44)
		elif val < 62.0:
			_warned[key] = false
	var worst := maxf(dig, mut)
	hud.set_danger(clampf((worst - 75.0) / 25.0, 0.0, 1.0), dig >= mut)
	if worst < 75.0:
		_alarm_t = 0.0
		return
	_alarm_t -= dt
	if _alarm_t <= 0.0:
		_alarm_t = lerpf(0.9, 0.35, (worst - 75.0) / 25.0)
		sfx("alarm", 0.8)
		var a := randf() * TAU
		host.membrane.poke(Vector2.from_angle(a) * Host.R, Vector2.from_angle(a) * -6.0)


# ---------------------------------------------------------------- tutorial

func _show_tutorial() -> void:
	if tut_step < 0 or tut_step >= TUTORIAL.size():
		hud.set_hint("")
		return
	hud.set_hint("STEP %d/%d   %s" % [tut_step + 1, TUTORIAL.size(), TUTORIAL[tut_step]])
	if tut_step == 2:
		room.spawn_radical_at_mito()


func _advance_tutorial() -> void:
	tut_step += 1
	if autotest:
		print("[autotest] tutorial step -> %d" % tut_step)
	sfx("chime")
	if tut_step >= TUTORIAL.size():
		tut_step = -1
		meta["tutorial"] = 1
		_save_meta()
		hud.set_hint("")
		hud.banner("YOU'RE A NATURAL ENGINE!", Color("9dff2e"), 44)
		return
	_show_tutorial()


func _tick_tutorial(_dt: float) -> void:
	match tut_step:
		0:
			if food_gen >= 2:
				_advance_tutorial()
		3:
			if base_throttle == 2:
				_advance_tutorial()
		4:
			if _tut_od > 1.0:
				_advance_tutorial()


func _tutorial_event(what: String) -> void:
	if (tut_step == 1 and what == "atp") or (tut_step == 2 and what == "radical") or (tut_step == 5 and what == "bomb"):
		_advance_tutorial()


func skip_tutorial() -> void:
	tut_step = TUTORIAL.size() - 1
	_advance_tutorial()


## Title screen "TUTORIAL" button: replay the guided first run.
func replay_tutorial() -> void:
	meta["tutorial"] = 0
	_save_meta()
	start_run()


# ---------------------------------------------------------------- feel / accessibility

## Freeze gameplay for a few frames (bomb direct hits, multi-kills, peel-offs).
func hit_stop(seconds: float) -> void:
	_hitstop = maxf(_hitstop, seconds)


## Sugar Rush: 3 snacks within 4 seconds -> 3.5 s of doubled ATP production that
## generates no mutation, with a chromatic shimmer over the water.
func _count_snack() -> void:
	var now := run_time
	_snack_times.append(now)
	while _snack_times.size() > 0 and now - _snack_times[0] > 4.0:
		_snack_times.pop_front()
	if _snack_times.size() >= 3:
		_snack_times.clear()
		var fresh := sugar_t <= 0.0
		sugar_t = RUSH_TIME
		if autotest and fresh:
			print("[autotest] sugar rush")
		if fresh:
			pop("SUGAR RUSH!", host.position + Vector3(0.0, 3.2, 0.0), Color("ff7ad8"), 1.5)
			hud.banner("SUGAR RUSH!  x2 ATP, no mutation", Color("ff7ad8"), 44)
			sfx("chime")
			sfx("giggle")
			room.mito_expr.on_fuel_consumed()


func _tick_sugar_rush(dt: float, inst_before: float) -> void:
	if sugar_t > 0.0:
		sugar_t = maxf(0.0, sugar_t - dt)
		# no mutation is generated while the rush lasts
		tension.instability = minf(tension.instability, inst_before)
	var shimmer := clampf(sugar_t / 0.5, 0.0, 1.0)
	(soup_floor.material_override as ShaderMaterial).set_shader_parameter("rush", shimmer)
	host.membrane.floor_mat.set_shader_parameter("rush", shimmer)


## EMERGENCY PURGE (F / the red PURGE gel): instantly vents 35% off both meters.
## Costs 2 ATP canisters, or dazes Mito for 1.5 s if there aren't two. 20 s cooldown.
func emergency_purge() -> void:
	if state != "play":
		return
	if purge_cool > 0.0:
		sfx("denied")
		pop("PURGE RECHARGING: %ds" % ceili(purge_cool), room.console_world(), Color("ff8a8a"), 0.7)
		return
	purge_cool = PURGE_COOLDOWN
	var paid: bool = room.purge_cost()
	tension.digestion = maxf(0.0, tension.digestion - 35.0)
	tension.instability = maxf(0.0, tension.instability - 35.0)
	for k in 10:
		var a := TAU * k / 10.0
		host.membrane.poke(Vector2.from_angle(a) * Host.R, Vector2.from_angle(a) * 9.0)
	for k in 4:
		var d := Vector2.from_angle(randf() * TAU)
		sea.bubble_burst(host.pos + d * Host.R, d, 6)
	pop("EMERGENCY PURGE!" if paid else "PURGE! (MITO DAZED)", host.position + Vector3(0.0, 3.0, 0.0), Color("6fe8ff"), 1.3)
	hud.flash(Color(0.6, 1.0, 1.0, 0.45), 0.5)
	sfx("ptoo")
	sfx("squelch")
	add_shake(0.8)
