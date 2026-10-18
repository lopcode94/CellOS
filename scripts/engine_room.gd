extends Node3D
## The Engine Room: everything inside the host's cytoplasm, simulated in host-local 2D
## (x, y) -> 3D (X, Z). Organelles ride damped springs; loose stuff (ATP canisters, free
## radicals) are free bodies that bounce off the soft-body membrane and shove it around.
##
##   sugar -> ER conveyor -> MITOCHONDRION (you) -> ATP canister -> slingshot -> NUCLEUS

const Art = preload("res://scripts/art.gd")
const MitoExpression = preload("res://scripts/mito_expression.gd")
const MITO_BODY = preload("res://shaders/mito_body.gdshader")

enum Kind { CANISTER, RADICAL }

const CAN_R := 0.56
const CAN_VIS := 1.33
const ORG_SCALE := 1.45
const MITO_SCALE := 1.7
const RAD_R := 0.34
const MAX_PULL := 3.0
const SLING_POWER := 6.8
const EXPEL_SPEED := 6.0
## a canister hitting the membrane faster than this punches out as an ATP bomb
const CAN_EXIT_SPEED := 10.5  # legacy; bombs are now primed by pull distance
## pull past this fraction of MAX_PULL and the canister primes into an ATP bomb
const BOMB_PRIME := 0.8
const CAN_CAP := 8
const FUEL_COST := 0.3
const FUEL_CAP := 6.0
const PROD_RATE := [0.0, 0.5, 0.85, 1.3]
const ROS_CHANCE := [0.0, 0.06, 0.15, 0.32]
const MEMBRANE_PAD := 0.95  # matches the thicker double membrane wall
const PIPE_Y := 0.7
const DOTS := 22


class Body:
	var kind := 0
	var node: Node3D
	var liquid: MeshInstance3D
	var primed := false
	var bomb := false
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var r := 0.4
	var charge := 1.0
	var held := -1
	var dead := false
	var yaw := 0.0
	var roll := 0.0
	var sq := 0.0
	var sqv := 0.0
	var anchor := Vector2.ZERO
	var target := Vector2.ZERO
	var hist: Array[Vector3] = []
	var cool := 0.0
	var age := 0.0


class Organelle:
	var node: Node3D
	var home := Vector2.ZERO
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var r := 1.0
	var sq := 0.0
	var sqv := 0.0
	var eyes: Array = []
	## visual scale of the organelle mesh (collision radius `r` is already scaled)
	var vis := 1.0


class Puddle:
	var node: Node3D
	var pos := Vector2.ZERO
	var r := 0.1
	var target_r := 1.0
	var dead := false


class Sugar:
	var node: Node3D
	var t := 0.0
	var value := 1.0


var game
var host
var bodies: Array[Body] = []
var puddles: Array[Puddle] = []
var sugars: Array[Sugar] = []
var holds := {}
var mito: Organelle
var mito_mat: ShaderMaterial
## Mito's reactive face (see scripts/mito_expression.gd)
var mito_expr: MitoExpression
var nucleus: Organelle
var console: Organelle
var console_spring: Node3D
var console_cap: Node3D
var console_lights: Array[MeshInstance3D] = []
var hole_mat: StandardMaterial3D
var nucleus_shell: MeshInstance3D
var swirl_rings: Array[MeshInstance3D] = []
const PIPE_N := 52
var pipe_base := PackedVector2Array()
var pipe_pts := PackedVector2Array()
var pipe_mesh: MeshInstance3D
var pipe_rings: Array[MeshInstance3D] = []
var pipe_tip: MeshInstance3D
var pipe_collar: MeshInstance3D
var wag := 0.4
var pipe_node: Node3D
var gunk: Node3D
var clogged := false
var fuel := 3.0
var prod_t := 0.0
var starve_t := 0.0
var stun_t := 0.0
var frozen := false
var band: MeshInstance3D
var dots: MultiMeshInstance3D
var sling_ring: MeshInstance3D
var aim_hits_nucleus := false
var _dots_feed: Material
var _dots_bomb: Material
var _liquid_ok: Material = Art.glow(Color("58ff6a"), 2.4)
var _liquid_hot: Material = Art.glow(Color("ff5a1a"), 3.0)
var t := 0.0
var _last_throttle := -1


func build(g, h) -> void:
	game = g
	host = h
	# organelles are ~1.45x bigger and packed closer so the cell reads as crowded and alive
	mito = _organelle(Vector2(-2.0, 2.0), 2.25, MITO_SCALE)
	_build_mito(mito)
	nucleus = _organelle(Vector2(1.6, -1.25), 2.1, ORG_SCALE)
	_build_nucleus(nucleus)
	console = _organelle(Vector2(2.95, 3.0), 1.1, 1.4)
	_build_console(console)
	_build_pipe()
	_build_aim()


# ---------------------------------------------------------------- construction

func _organelle(home: Vector2, r: float, vis: float = 1.0) -> Organelle:
	var o := Organelle.new()
	o.home = home
	o.pos = home
	o.r = r
	o.vis = vis
	o.node = Node3D.new()
	add_child(o.node)
	o.node.position = Vector3(home.x, 0.0, home.y)
	return o


func _build_mito(o: Organelle) -> void:
	# glowing orange jelly bean with purple jelly end-caps and a purple squiggle crest:
	# the original orange + purple design, rendered in the liquid-glass style. No face.
	var n := o.node
	var pivot := Node3D.new()
	pivot.rotation.y = 0.18
	n.add_child(pivot)
	var cap := CapsuleMesh.new()
	cap.radius = 0.82
	cap.height = 2.8
	cap.radial_segments = 32
	cap.rings = 12
	# the face lives *inside* this shader (no separate face meshes -> nothing can clip)
	mito_mat = ShaderMaterial.new()
	mito_mat.shader = MITO_BODY
	var body := Art.add(pivot, cap, mito_mat, Vector3(0.0, 0.95, 0.0))
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.rotation.z = PI * 0.5
	var purple := Art.gel(Color("9b4fe0"), Color("e0a8ff"), 0.6, 0.8, 0.03)
	for side in [-1.0, 1.0]:
		Art.ball(pivot, 0.84, purple, Vector3(side * 0.98, 0.95, 0.0), Vector3(0.6, 1.02, 1.02))
	var crest := PackedVector3Array()
	for i in 23:
		var u := float(i) / 22.0
		var x := -1.0 + u * 2.0
		crest.append(Vector3(x, 1.58 + sin(u * TAU * 3.5) * 0.1 - x * x * 0.08, -0.5 + sin(u * TAU) * 0.05))
	Art.add(pivot, Art.tube_mesh(crest, 0.085, 8), purple)
	o.eyes = []
	mito_expr = MitoExpression.new(mito_mat, o)


func _build_nucleus(o: Organelle) -> void:
	# iridescent soap bubble holding a glowing purple swirl (opaque core, so the
	# refracting shell lenses it)
	var n := o.node
	hole_mat = Art.glow(Color("a03cff"), 0.35).duplicate()
	var core := Art.ball(n, 0.9, hole_mat, Vector3(0.0, 1.45, 0.0))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var swirl := Art.glow(Color("ff7cf0"), 0.45)
	for i in 3:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.55 - i * 0.14
		ring.outer_radius = 0.66 - i * 0.14
		var m := Art.add(n, ring, swirl, Vector3(0.0, 1.45 + i * 0.05, 0.0))
		m.basis = Basis(Quaternion(Vector3.UP, (Art.FACE_DIR + Vector3(sin(i * 2.1), 0.0, cos(i * 2.1)) * 0.35).normalized()))
		swirl_rings.append(m)
		m.position += Art.FACE_DIR * (0.55 + i * 0.12)
	nucleus_shell = Art.ball(n, 1.45, Art.bubble(Color("d8c0ff"), 0.07, 1.0, 0.0, 0.0, 0.03), Vector3(0.0, 1.45, 0.0))


func _build_console(o: Organelle) -> void:
	var n := o.node
	Art.add(n, Art.cyl_mesh(0.72, 0.8, 0.45), Art.clay(Color("6f5cff"), 0.6, 0.02), Vector3(0.0, 0.22, 0.0))
	console_spring = Node3D.new()
	n.add_child(console_spring)
	console_spring.position.y = 0.45
	var coil := PackedVector3Array()
	for i in 64:
		var u := i / 63.0
		var a := u * TAU * 4.5
		coil.append(Vector3(cos(a) * 0.3, u * 0.7, sin(a) * 0.3))
	Art.add(console_spring, Art.tube_mesh(coil, 0.045, 6), Art.metal())
	console_cap = Node3D.new()
	n.add_child(console_cap)
	Art.add(console_cap, Art.cyl_mesh(0.5, 0.52, 0.28), Art.clay(Color("ff3b2f"), 0.5, 0.02))
	Art.add(console_cap, Art.cyl_mesh(0.36, 0.4, 0.1), Art.clay(Color("ff9a2e"), 0.5, 0.02), Vector3(0.0, 0.18, 0.0))
	for i in 3:
		var a := PI * 0.5 + (i - 1) * 0.6
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("2a1640")
		m.emission_enabled = true
		var light := Art.ball(n, 0.1, m, Vector3(cos(a) * 0.62, 0.47, sin(a) * 0.62))
		console_lights.append(light)
	_set_console(1)


func _build_pipe() -> void:
	# The ER enters on the right, wraps three sides of the nucleus (right, top, left) so it
	# frames it, then drops down and plugs *into* the back of the mitochondrion.
	var knots := PackedVector2Array([
		Vector2(6.1, -1.0), Vector2(4.6, -3.4), Vector2(1.6, -4.9), Vector2(-1.4, -3.9),
		Vector2(-2.0, -1.5), Vector2(-1.7, 0.5),
		Vector2(-1.6, 1.3),
	])
	pipe_base.clear()
	pipe_pts.clear()
	var segs := knots.size() - 1
	for i in PIPE_N:
		var f := float(i) / (PIPE_N - 1) * segs
		var k := mini(int(f), segs - 1)
		var a := knots[maxi(k - 1, 0)]
		var b := knots[k]
		var c := knots[k + 1]
		var d := knots[mini(k + 2, segs)]
		var q := b.cubic_interpolate(c, a, d, f - k)
		pipe_base.append(q)
		pipe_pts.append(q)
	pipe_node = Node3D.new()
	add_child(pipe_node)
	pipe_mesh = Art.add(pipe_node, ArrayMesh.new(), Art.gel(Color("c86bff"), Color("ffb8f0"), 0.55, 0.7, 0.0))
	var band_mat := Art.clay(Color("9b6bff"), 0.6, 0.02)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.26
	ring.outer_radius = 0.42
	for i in range(2, PIPE_N - 2, 4):
		pipe_rings.append(Art.add(pipe_node, ring, band_mat))
	pipe_tip = Art.ball(pipe_node, 0.36, Art.clay(Color("ff9a8a"), 0.55, 0.02))
	var collar := TorusMesh.new()
	collar.inner_radius = 0.3
	collar.outer_radius = 0.56
	pipe_collar = Art.add(pipe_node, collar, Art.gel(Color("9b4fe0"), Color("e0a8ff"), 0.6, 0.8, 0.03))
	gunk = Node3D.new()
	pipe_node.add_child(gunk)
	var gm := Art.clay(Color("7a8f4a"), 0.8, 0.05)
	Art.ball(gunk, 0.42, gm)
	Art.ball(gunk, 0.3, gm, Vector3(0.3, 0.1, 0.15))
	Art.ball(gunk, 0.26, gm, Vector3(-0.25, 0.15, -0.2))
	Art.face(gunk, 0.42, "smug", 0.8)
	gunk.visible = false
	_wag_pipe(0.0)


## The ER conveyor wags like a tail: a travelling wave pinned at the membrane end and at
## the mitochondrion end (which also rides the mito's slosh spring). It gets excited when
## food goes down it and strains frantically when clogged.
func _wag_pipe(dt: float) -> void:
	wag = move_toward(wag, 0.35, dt * 0.6)
	var amp := 0.16 + wag * 0.4
	var spd := 3.2 + wag * 3.0 + (6.0 if clogged else 0.0)
	var mito_off := mito.pos - mito.home
	var pts3 := PackedVector3Array()
	for i in PIPE_N:
		var u := float(i) / (PIPE_N - 1)
		var tg := (pipe_base[mini(i + 1, PIPE_N - 1)] - pipe_base[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-tg.y, tg.x)
		var env := sin(PI * u)
		var wave := (sin(t * spd - u * 7.0) + sin(t * spd * 0.53 + u * 3.0) * 0.35) * amp * env
		var q := pipe_base[i] + nrm * wave + mito_off * u * u
		pipe_pts[i] = q
		pts3.append(Vector3(q.x, PIPE_Y + sin(t * spd * 0.8 - u * 6.0) * 0.08 * env, q.y))
	pipe_mesh.mesh = Art.tube_mesh(pts3, 0.3, 12)
	for k in pipe_rings.size():
		var idx := 2 + k * 4
		var tg3 := (pts3[idx + 1] - pts3[idx - 1]).normalized()
		pipe_rings[k].position = pts3[idx]
		pipe_rings[k].basis = Basis(Quaternion(Vector3.UP, tg3))
	pipe_tip.position = pts3[0]
	# purple gasket where the tube sinks into the mitochondrion
	var ci := PIPE_N - 2
	pipe_collar.position = pts3[ci]
	pipe_collar.basis = Basis(Quaternion(Vector3.UP, (pts3[ci + 1] - pts3[ci - 1]).normalized()))
	var gp := _pipe_at(0.5)
	gunk.position.x = gp.x
	gunk.position.z = gp.y


func _build_aim() -> void:
	band = Art.add(self, Art.cyl_mesh(0.07, 0.07, 1.0, 8), Art.clay(Color("ff4fa3"), 0.4, 0.0))
	band.visible = false
	var tm := TorusMesh.new()
	tm.inner_radius = 0.45
	tm.outer_radius = 0.58
	sling_ring = Art.add(self, tm, Art.glow(Color("ffffff"), 0.6))
	sling_ring.visible = false
	dots = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Art.sphere_mesh(0.09, 8)
	mm.instance_count = DOTS
	dots.multimesh = mm
	_dots_feed = Art.glow(Color("fff6a0"), 1.5)
	_dots_bomb = Art.glow(Color("ff4a3a"), 1.8)
	dots.material_override = _dots_feed
	add_child(dots)
	dots.visible = false


# ---------------------------------------------------------------- per frame

func update(dt: float) -> void:
	if frozen:
		return
	t += dt
	_organelles(dt)
	_mito_mood(dt)
	_mito_headbutt(dt)
	if game.state == "play":
		_produce(dt)
		_puddle_spawn(dt)
	_wag_pipe(dt)
	_pipe(dt)
	_bodies(dt)
	_puddles(dt)
	_visuals(dt)
	_aim()


func _organelles(dt: float) -> void:
	var slosh: Vector2 = -host.accel * 0.1
	for org in [mito, nucleus, console]:
		var o: Organelle = org
		o.vel += ((o.home - o.pos) * 38.0 + slosh) * dt
		o.vel *= exp(-6.0 * dt)
		o.pos += o.vel * dt
		o.sqv += (-o.sq * 170.0 - o.sqv * 9.0) * dt
		o.sq = clampf(o.sq + o.sqv * dt, -0.45, 0.45)
		o.node.position = Vector3(o.pos.x, 0.0, o.pos.y)
		o.node.scale = Vector3(1.0 + o.sq * 0.18, 1.0 - o.sq * 0.25, 1.0 + o.sq * 0.18) * o.vis
	# the nucleus' pores glow hot red when the host is starving
	var hunger := clampf(1.0 - float(game.tension.ratio()), 0.0, 1.0)
	hole_mat.emission = Color("c05cff").lerp(Color("ff2a2a"), hunger)
	hole_mat.emission_energy_multiplier = 0.35 + hunger * (1.5 + sin(t * 9.0) * 1.2)
	for i in swirl_rings.size():
		swirl_rings[i].rotate(Art.FACE_DIR, (0.8 + i * 0.5) * (1.0 + hunger * 3.0) * 0.016)
	var th: int = game.throttle
	if th != _last_throttle:
		_set_console(th)
	# mito keeps an eye on its newest canister
	var newest: Body = null
	for b in bodies:
		if b.kind == Kind.CANISTER and not b.dead:
			newest = b
	var look := Vector2.ZERO
	if newest:
		var d := newest.pos - mito.pos
		look = Vector2(d.x, -d.y).normalized()
	for e in mito.eyes:
		e.look(look)


func _set_console(th: int) -> void:
	_last_throttle = th
	var lift: float = [0.0, 0.55, 0.85, 1.15][th]
	console_spring.scale = Vector3(1.0, lift, 1.0)
	console_cap.position = Vector3(0.0, 0.45 + 0.7 * lift + 0.14, 0.0)
	var cols := [Color("5cff6a"), Color("ffd23d"), Color("ff3b3b")]
	for i in console_lights.size():
		var m := console_lights[i].material_override as StandardMaterial3D
		var on := i < th
		m.emission = cols[i] if on else Color.BLACK
		m.emission_energy_multiplier = 2.5 if on else 0.0
		m.albedo_color = cols[i] if on else Color("2a1640")
	console.sqv += 6.0


func _produce(dt: float) -> void:
	var th: int = game.throttle
	stun_t = maxf(0.0, stun_t - dt)
	if stun_t > 0.0:
		return   # dazed after a canister-less emergency purge
	if fuel < FUEL_COST or _count(Kind.CANISTER) >= CAN_CAP:
		starve_t += dt
		if fuel < FUEL_COST and starve_t > 3.0:
			starve_t = 0.0
			game.pop("NEED SUGAR!", _w(mito.pos + Vector2(0.0, -2.8)), Color("ffb02e"), 0.7)
			for e in mito.eyes:
				e.crazy = 0.6
		return
	starve_t = 0.0
	var rate: float = PROD_RATE[th] * float(game.prod_mult())
	prod_t += rate * dt
	if prod_t < 1.0:
		return
	prod_t -= 1.0
	fuel -= FUEL_COST
	spawn_canister(mito.pos + Vector2(3.25, 0.4), Vector2(randf_range(2.5, 4.5), randf_range(-1.5, 1.5)))
	mito.sqv += 7.0
	game.sfx("plop")
	var chance: float = ROS_CHANCE[th] * game.ros_mult()
	if randf() < chance:
		spawn_radical_at_mito()
		game.pop("FREE RADICAL!", _w(mito.pos + Vector2(0.0, -3.0)), Color("ff6a3d"), 0.7)


func _pipe(dt: float) -> void:
	var dig: float = game.tension.digestion
	var speed := 0.3 * (1.0 - dig / 200.0)
	var limit := 1.0
	for s in sugars:
		var cap := limit
		if clogged:
			cap = minf(cap, 0.44)
		s.t = minf(s.t + speed * dt, cap)
		limit = s.t - 0.07
		var p := _pipe_at(s.t)
		s.node.position = Vector3(p.x, PIPE_Y + 0.42 + sin(t * 9.0 + s.t * 20.0) * 0.04, p.y)
	while sugars.size() > 0 and sugars[0].t >= 0.999:
		var s: Sugar = sugars.pop_front()
		fuel = minf(FUEL_CAP, fuel + s.value)
		mito_expr.on_fuel_consumed()
		s.node.queue_free()
		mito.sqv += 4.0
		game.sfx("nom")
		wag = minf(1.5, wag + 0.35)
	if clogged:
		gunk.position.y = PIPE_Y + 0.4 + absf(sin(t * 6.0)) * 0.12
		pipe_node.position = Vector3(sin(t * 40.0) * 0.03, 0.0, 0.0)


func _bodies(dt: float) -> void:
	var slosh: Vector2 = -host.accel * 0.45
	for b in bodies:
		if b.dead:
			continue
		b.age += dt
		b.cool = maxf(0.0, b.cool - dt)
		if b.held >= 0:
			if b.kind == Kind.CANISTER:
				var want := b.anchor + (b.target - b.anchor).limit_length(MAX_PULL)
				b.pos = b.pos.lerp(want, minf(1.0, dt * 25.0))
				b.vel = Vector2.ZERO
			else:
				var np := b.pos.lerp(b.target, minf(1.0, dt * 28.0))
				b.vel = (np - b.pos) / maxf(dt, 0.0001)
				b.pos = np
		else:
			b.vel += slosh * dt
			if b.kind == Kind.RADICAL:
				b.vel += Vector2(randf() - 0.5, randf() - 0.5) * 30.0 * dt
				var prey := _nearest(Kind.CANISTER, b.pos, 4.0)
				if prey:
					b.vel += (prey.pos - b.pos).normalized() * 3.0 * dt
				b.vel *= exp(-1.1 * dt)
				if b.vel.length() < 1.2:
					b.vel = Vector2.from_angle(randf() * TAU) * 1.2 if b.vel.length() < 0.01 else b.vel.normalized() * 1.2
			else:
				b.vel *= exp(-0.75 * dt)
				if b.bomb and b.vel.length() < 2.0:
					b.bomb = false   # fizzled before reaching the wall: back to a normal canister
					b.liquid.material_override = _liquid_ok
				if game.has_mut("magnet") and not b.bomb:
					var to := nucleus.pos - b.pos
					if to.length() < 3.6:
						b.vel += to.normalized() * 14.0 * dt
			b.pos += b.vel * dt
		_membrane_hit(b)
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			_pair(bodies[i], bodies[j])
	for b in bodies:
		_organelle_hit(b, mito)
		_organelle_hit(b, nucleus)
		_organelle_hit(b, console)
	_sweep()


func _sweep() -> void:
	for i in range(bodies.size() - 1, -1, -1):
		if bodies[i].dead:
			bodies.remove_at(i)


func _membrane_hit(b: Body) -> void:
	if b.dead:
		return
	var d := b.pos.length()
	if d < 0.001:
		return
	var n := b.pos / d
	var rm: float = host.membrane.radius_at(b.pos.angle()) - MEMBRANE_PAD
	if d + b.r <= rm:
		return
	var vn := b.vel.dot(n)
	if b.kind == Kind.CANISTER and b.held < 0 and b.bomb:
		_launch_bomb(b, n, maxf(vn, 8.0))
		return
	if b.kind == Kind.RADICAL and b.held < 0 and vn > EXPEL_SPEED:
		_expel(b, n, vn)
		return
	b.pos = n * (rm - b.r)
	if vn > 0.0:
		var rest: float = 0.82 * game.bounce_mult()
		b.vel -= n * vn * (1.0 + rest)
		host.membrane.poke(b.pos, n * vn * 0.9)
		b.sqv += minf(vn, 12.0) * 0.7
		if vn > 2.5:
			game.sfx("boing", clampf(vn / 12.0, 0.25, 1.0))
		if vn > 8.0:
			game.pop("BOING!", _w(b.pos), Color("ffe14d"), 0.7)


func _expel(b: Body, n: Vector2, vn: float) -> void:
	b.dead = true
	host.membrane.poke(b.pos, n * vn * 1.4)
	game.on_radical_expelled(_w(b.pos))
	var node := b.node
	var tw := node.create_tween()
	tw.tween_property(node, "position", node.position + Vector3(n.x, 0.15, n.y) * 4.0, 0.35).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "scale", Vector3.ONE * 0.01, 0.35)
	tw.tween_callback(node.queue_free)


func _pair(a: Body, b: Body) -> void:
	if a.dead or b.dead:
		return
	var dv := b.pos - a.pos
	var rr := a.r + b.r
	var d2 := dv.length_squared()
	if d2 >= rr * rr or d2 < 0.000001:
		return
	if a.kind != b.kind:
		var can: Body = a if a.kind == Kind.CANISTER else b
		var rad: Body = b if a.kind == Kind.CANISTER else a
		_oxidize(can, rad)
		return
	var d := sqrt(d2)
	var n := dv / d
	var ov := rr - d
	var wa := 0.0 if a.held >= 0 else 1.0
	var wb := 0.0 if b.held >= 0 else 1.0
	var sum := wa + wb
	if sum <= 0.0:
		return
	a.pos -= n * ov * wa / sum
	b.pos += n * ov * wb / sum
	var rv := (b.vel - a.vel).dot(n)
	if rv < 0.0:
		var j := -1.8 * rv
		a.vel -= n * j * wa / sum
		b.vel += n * j * wb / sum
		if rv < -3.0:
			game.sfx("bonk", clampf(-rv / 10.0, 0.2, 1.0))
			a.sqv += 3.0
			b.sqv += 3.0


func _oxidize(can: Body, rad: Body) -> void:
	can.dead = true
	rad.vel = -rad.vel + Vector2.from_angle(randf() * TAU) * 2.0
	game.tension.instability += 1.0
	game.pop("OXIDIZED!", _w(can.pos), Color("d8a060"), 0.75)
	game.sfx("fizz")
	var node := can.node
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3(1.4, 0.1, 1.4), 0.25)
	tw.tween_callback(node.queue_free)


func _organelle_hit(b: Body, o: Organelle) -> void:
	if b.dead:
		return
	var dv := b.pos - o.pos
	var d := dv.length()
	if o == nucleus and b.kind == Kind.CANISTER and b.held < 0 and not b.bomb:
		if d < o.r + b.r + float(game.catch_bonus()):
			_deliver(b)
			return
	var reach := o.r + b.r
	if d >= reach or d < 0.0001:
		return
	var n := dv / d
	b.pos = o.pos + n * reach
	var vn := b.vel.dot(n)
	if vn < 0.0:
		b.vel -= n * vn * 1.7
		o.vel += n * vn * 0.12
		o.sqv += minf(-vn, 10.0) * 0.5
	if b.kind == Kind.RADICAL and b.cool <= 0.0:
		b.cool = 0.7
		if o == nucleus:
			game.tension.instability += 3.0
			game.pop("ZAP! DNA DAMAGE", _w(o.pos), Color("ff5ad1"), 0.8)
			game.sfx("zap")
			o.sqv += 6.0
		elif o == mito:
			game.tension.instability += 1.0
			game.pop("OUCH!", _w(o.pos + Vector2(0.0, -1.0)), Color("ffb02e"), 0.6)
			mito_expr.on_hurt()
			for e in o.eyes:
				e.crazy = 1.5
	elif o == console and vn < -6.0 and b.cool <= 0.0:
		b.cool = 1.0
		game.cycle_throttle()
		game.pop("OOPS! BUMPED THE CRANK", _w(o.pos), Color("ffe14d"), 0.7)


func _deliver(b: Body) -> void:
	if game.has_mut("rubbernuc") and randf() < 1.0 / 6.0:
		var n := (b.pos - nucleus.pos).normalized()
		b.vel = n * 9.0
		b.pos = nucleus.pos + n * (nucleus.r + b.r + float(game.catch_bonus()) + 0.05)
		game.pop("BURP!", _w(nucleus.pos), Color("c9a2ff"), 0.9)
		game.sfx("burp")
		nucleus.sqv += 8.0
		return
	b.dead = true
	game.on_atp_delivered(b.charge, _w(nucleus.pos))
	nucleus.sqv += 9.0
	var node := b.node
	var tw := node.create_tween()
	tw.tween_property(node, "position", Vector3(nucleus.pos.x, 1.4, nucleus.pos.y), 0.15)
	tw.parallel().tween_property(node, "scale", Vector3.ONE * 0.05, 0.15)
	tw.tween_callback(node.queue_free)


func _puddle_spawn(dt: float) -> void:
	var dig: float = game.tension.digestion
	if dig > 35.0 and randf() < (dig - 35.0) / 40.0 * dt * 1.2:
		add_puddle()


func _puddles(dt: float) -> void:
	var dig: float = game.tension.digestion
	for pd in puddles:
		if dig < 25.0 and game.state == "play":
			pd.target_r -= 0.2 * dt
		pd.r = lerpf(pd.r, pd.target_r, minf(1.0, dt * 3.0))
		var s := maxf(pd.r, 0.01)
		pd.node.position = Vector3(pd.pos.x, 0.0, pd.pos.y)
		pd.node.scale = Vector3(s, 1.0 + sin(t * 3.0 + pd.pos.x) * 0.15, s)
		for b in bodies:
			if b.dead or b.pos.distance_to(pd.pos) > pd.r + b.r * 0.3:
				continue
			b.vel *= exp(-2.5 * dt)
			if b.kind == Kind.CANISTER:
				b.charge -= 0.45 * dt
				if b.charge <= 0.12:
					b.dead = true
					game.pop("FIZZLED", _w(b.pos), Color("a6ff3a"), 0.7)
					game.sfx("fizz")
					b.node.queue_free()
		if pd.target_r <= 0.2:
			pd.dead = true
			pd.node.queue_free()
	for i in range(puddles.size() - 1, -1, -1):
		if puddles[i].dead:
			puddles.remove_at(i)
	_sweep()


func _visuals(dt: float) -> void:
	for b in bodies:
		b.sqv += (-b.sq * 220.0 - b.sqv * 12.0) * dt
		b.sq = clampf(b.sq + b.sqv * dt, -0.5, 0.5)
		var grow := minf(1.0, b.age * 6.0 + 0.15)
		var sp := b.vel.length()
		if b.kind == Kind.CANISTER:
			var tension_f := 0.0
			if b.held >= 0:
				var pull := b.pos - b.anchor
				tension_f = clampf(pull.length() / MAX_PULL, 0.0, 1.0)
				if pull.length() > 0.05:
					b.yaw = lerp_angle(b.yaw, atan2(pull.x, pull.y), minf(1.0, dt * 14.0))
				# priming: past 80% of max pull the canister becomes a bomb
				var primed := tension_f >= BOMB_PRIME
				if primed != b.primed:
					b.primed = primed
					b.liquid.material_override = _liquid_hot if primed else _liquid_ok
					if primed:
						game.sfx("zap")
						game.pop("PRIMED!", _w(b.pos), Color("ff6a2a"), 0.6)
			elif sp > 0.4:
				b.yaw = lerp_angle(b.yaw, atan2(b.vel.x, b.vel.y), minf(1.0, dt * 10.0))
			b.roll += sp * dt / b.r if b.held < 0 else 0.0
			var shake := Vector3.ZERO
			if b.primed:
				shake = Vector3(randf() - 0.5, 0.0, randf() - 0.5) * 0.09
			b.node.position = Vector3(b.pos.x, b.r, b.pos.y) + shake
			b.node.basis = Basis(Vector3.UP, b.yaw) * Basis(Vector3.RIGHT, b.roll)
			# bubble-gum stretch: elongate along the pull (local Z), pinch the other axes
			var along := 1.0 + tension_f * 0.55 - b.sq * 0.3
			var pinch := 1.0 - tension_f * 0.22 + b.sq * 0.3
			b.node.scale = Vector3(pinch, pinch, along) * grow * CAN_VIS
			b.liquid.scale = Vector3(1.0, clampf(b.charge, 0.05, 1.2), 1.0)
		else:
			b.node.position = Vector3(b.pos.x, b.r + 0.1 + sin(b.age * 22.0) * 0.06, b.pos.y)
			b.node.rotation = Vector3(0.0, 0.0, sin(b.age * 25.0) * 0.25)
			b.node.scale = Vector3.ONE * (1.0 + b.sq * 0.3) * grow


func _aim() -> void:
	var aiming: Body = null
	for id in holds:
		var hb: Body = holds[id]
		if not hb.dead and hb.kind == Kind.CANISTER:
			aiming = hb
	band.visible = aiming != null
	dots.visible = aiming != null
	sling_ring.visible = aiming != null
	aim_hits_nucleus = false
	if aiming == null:
		return
	var a3 := Vector3(aiming.anchor.x, 0.45, aiming.anchor.y)
	var c3 := Vector3(aiming.pos.x, 0.45, aiming.pos.y)
	sling_ring.position = a3
	var blen := a3.distance_to(c3)
	if blen > 0.02:
		var thin := clampf(1.4 - blen * 0.25, 0.5, 1.4)
		band.position = (a3 + c3) * 0.5
		band.basis = Basis(Quaternion(Vector3.UP, (c3 - a3) / blen)) * Basis.from_scale(Vector3(thin, blen, thin))
	else:
		band.visible = false
	var v := -(aiming.pos - aiming.anchor) * SLING_POWER
	var p := aiming.pos
	var rm: float = host.membrane.rest_r - MEMBRANE_PAD - aiming.r
	var rest: float = 0.82 * game.bounce_mult()
	var reach: float = nucleus.r + aiming.r + float(game.catch_bonus())
	var mm := dots.multimesh
	var shown := 0
	var step := 0.05
	var exits := false
	for i in DOTS:
		for k in 2:
			v *= exp(-0.75 * step * 0.5)
			p += v * step * 0.5
			var d := p.length()
			if d > rm:
				var n := p / d
				p = n * rm
				var vn := v.dot(n)
				if aiming.primed and vn > 0.0:
					exits = true      # this shot punches out of the cell as an ATP bomb
				elif vn > 0.0:
					v -= n * vn * (1.0 + rest)
			if p.distance_to(nucleus.pos) < reach:
				aim_hits_nucleus = true
		var s := (1.0 - float(i) / DOTS * 0.6) * (1.0 + (0.3 * sin(t * 16.0 - i * 0.6) if aiming.primed else 0.0))
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(p.x, 0.5, p.y)))
		shown = i + 1
		if aim_hits_nucleus or exits or v.length() < 0.6:
			break
	mm.visible_instance_count = shown
	# red dots = "this will leave the cell as a bomb", yellow = stays inside
	dots.material_override = _dots_bomb if exits else _dots_feed
	if aim_hits_nucleus:
		hole_mat.emission = Color("ffffff")
		hole_mat.emission_energy_multiplier = 0.9


# ---------------------------------------------------------------- spawning

func spawn_canister(p: Vector2, v: Vector2) -> Body:
	var b := Body.new()
	b.kind = Kind.CANISTER
	b.r = CAN_R
	b.pos = p
	b.vel = v
	b.charge = game.charge_mult()
	b.node = Node3D.new()
	add_child(b.node)
	var piv := Node3D.new()
	piv.rotation.z = PI * 0.5
	b.node.add_child(piv)
	var purple_first := randf() < 0.5
	var c1: Color = Color("8a4bd8") if purple_first else Color("3fcf5a")
	var c2: Color = Color("3fcf5a") if purple_first else Color("8a4bd8")
	b.liquid = Art.add(piv, Art.cyl_mesh(0.27, 0.27, 0.62), _liquid_ok)
	for k in 3:
		Art.ball(piv, 0.05 + k * 0.015, Art.glow(Color("eaffd0"), 2.0), Vector3(randf_range(-0.12, 0.12), randf_range(-0.22, 0.22), randf_range(-0.12, 0.12)))
	Art.add(piv, Art.cyl_mesh(0.12, 0.12, 0.5, 12), Art.glow(Color("1fbf3a"), 1.4))
	Art.add(piv, Art.cyl_mesh(0.34, 0.34, 0.74), Art.glass())
	for side in [-1.0, 1.0]:
		Art.add(piv, Art.cyl_mesh(0.39, 0.39, 0.16), Art.clay(c1, 0.55, 0.015), Vector3(0.0, side * 0.43, 0.0))
		Art.add(piv, Art.cyl_mesh(0.22, 0.24, 0.1), Art.clay(c2, 0.55, 0.015), Vector3(0.0, side * 0.55, 0.0))
	bodies.append(b)
	return b


func spawn_radical(p: Vector2, v: Vector2) -> Body:
	var b := Body.new()
	b.kind = Kind.RADICAL
	b.r = RAD_R
	b.pos = p
	b.vel = v
	b.node = Node3D.new()
	add_child(b.node)
	Art.ball(b.node, 0.3, Art.clay(Color("ff4a2a"), 0.5, 0.04, Color("ff3a00"), 0.6))
	var spike := Art.clay(Color("ffb02e"), 0.5, 0.02)
	for i in 10:
		var y := 1.0 - (i + 0.5) / 10.0 * 2.0
		var rad := sqrt(maxf(0.0, 1.0 - y * y))
		var a := i * 2.39996
		var dir := Vector3(cos(a) * rad, y, sin(a) * rad)
		var cone := Art.add(b.node, Art.cyl_mesh(0.0, 0.08, 0.24, 8), spike, dir * 0.33)
		cone.basis = Basis(Quaternion(Vector3.UP, dir))
	Art.face(b.node, 0.3, "angry", 0.6)
	bodies.append(b)
	game.sfx("squeak")
	return b


func spawn_radical_at_mito() -> void:
	spawn_radical(mito.pos + Vector2(0.5, -3.1), Vector2(randf_range(-2.0, 2.0), -2.5))


func inject_radicals(count: int, angle: float) -> void:
	for k in count:
		var dir := Vector2.from_angle(angle + randf_range(-0.3, 0.3))
		spawn_radical(dir * 5.4, -dir * randf_range(2.0, 4.0))


func add_food(value: float) -> void:
	var s := Sugar.new()
	s.value = value * game.food_mult()
	s.node = Art.ball(self, 0.24, Art.clay(Color("fff0f6"), 0.5, 0.03))
	var p := _pipe_at(0.0)
	s.node.position = Vector3(p.x, PIPE_Y + 0.42, p.y)
	sugars.append(s)
	wag = 1.2
	if not clogged and randf() < 0.1 * game.clog_mult():
		clogged = true
		gunk.visible = true
		game.pop("CLOGGED! TAP THE GUNK!", _w(_pipe_at(0.5)), Color("b6d35a"), 0.8)
		game.sfx("squelch")


func add_puddle(p: Vector2 = Vector2.INF) -> void:
	if puddles.size() >= 7:
		return
	if p == Vector2.INF:
		p = Vector2.from_angle(randf() * TAU) * randf_range(1.0, 4.8)
	var pd := Puddle.new()
	pd.pos = p
	pd.r = 0.1
	pd.target_r = randf_range(0.8, 1.3)
	pd.node = Node3D.new()
	add_child(pd.node)
	var mat := Art.gel(Color("7dff3a"), Color("e0ff8a"), 0.7, 0.8, 0.05)
	Art.ball(pd.node, 0.55, mat, Vector3(0.0, 0.05, 0.0), Vector3(1.0, 0.3, 1.0))
	for k in 4:
		Art.ball(pd.node, randf_range(0.25, 0.4), mat, Vector3(randf_range(-0.5, 0.5), 0.05, randf_range(-0.5, 0.5)), Vector3(1.0, 0.35, 1.0))
	puddles.append(pd)
	game.sfx("splat", 0.6)
	game.pop("ACID!", _w(p), Color("a6ff3a"), 0.7)


# ---------------------------------------------------------------- pointer API

func try_grab(id: int, p: Vector2) -> bool:
	var best: Body = null
	var bd := 1e9
	for b in bodies:
		if b.dead or b.held >= 0:
			continue
		var d := b.pos.distance_to(p)
		if d < b.r + 0.8 and d < bd:
			best = b
			bd = d
	if best:
		best.held = id
		best.target = p
		holds[id] = best
		if best.kind == Kind.CANISTER:
			best.anchor = best.pos
			game.sfx("stretch")
		else:
			best.hist.clear()
			best.hist.append(Vector3(p.x, p.y, _now()))
			game.sfx("grab")
		return true
	if p.distance_to(console.pos) < console.r + 0.45:
		game.cycle_throttle()
		return true
	if clogged and p.distance_to(_pipe_at(0.5)) < 1.2:
		unclog()
		return true
	for pd in puddles:
		if p.distance_to(pd.pos) < pd.r + 0.2:
			pd.target_r -= 0.4
			game.pop("SPLAT!", _w(pd.pos), Color("a6ff3a"), 0.7)
			game.sfx("splat", 0.5)
			return true
	if p.distance_to(mito.pos) < mito.r + 0.2:
		mito.sqv += 6.0
		game.sfx("giggle")
		game.pop("HEE HEE!", _w(mito.pos), Color("ffb02e"), 0.6)
		for e in mito.eyes:
			e.crazy = 1.0
		return true
	if p.distance_to(nucleus.pos) < nucleus.r:
		nucleus.sqv += 6.0
		game.sfx("boop")
		return true
	return false


func drag(id: int, p: Vector2) -> void:
	if not holds.has(id):
		return
	var b: Body = holds[id]
	b.target = p
	if b.kind == Kind.RADICAL:
		var now := _now()
		b.hist.append(Vector3(p.x, p.y, now))
		while b.hist.size() > 2 and now - b.hist[0].z > 0.1:
			b.hist.pop_front()


func release(id: int, p: Vector2) -> void:
	if not holds.has(id):
		return
	var b: Body = holds[id]
	holds.erase(id)
	b.held = -1
	if b.dead:
		return
	if b.kind == Kind.CANISTER:
		var pull := b.pos - b.anchor
		if pull.length() < 0.3:
			return
		b.vel = -pull * SLING_POWER
		b.sqv += 9.0
		game.sfx("sling")
		# released while primed: it's an ATP bomb and will punch out through the membrane
		b.bomb = b.primed
		if b.bomb:
			game.pop("BOMBS AWAY!", _w(b.pos), Color("ff6a2a"), 0.7)
		b.primed = false
		b.liquid.material_override = _liquid_hot if b.bomb else _liquid_ok
	else:
		b.hist.append(Vector3(p.x, p.y, _now()))
		var h0 := b.hist[0]
		var h1 := b.hist[b.hist.size() - 1]
		var dtt := maxf(0.016, h1.z - h0.z)
		b.vel = (Vector2(h1.x - h0.x, h1.y - h0.y) / dtt).limit_length(28.0)
		game.sfx("whoosh")


func release_all() -> void:
	for id in holds.keys():
		var b: Body = holds[id]
		b.held = -1
	holds.clear()


func unclog() -> void:
	clogged = false
	gunk.visible = false
	pipe_node.position = Vector3.ZERO
	game.pop("SHLORP!", _w(_pipe_at(0.5)), Color("b6ff5a"), 0.9)
	game.sfx("squelch")
	game.add_shake(0.3)


# ---------------------------------------------------------------- queries & deaths

func radical_count() -> int:
	return _count(Kind.RADICAL)


func first_body(kind: int) -> Body:
	for b in bodies:
		if b.kind == kind and not b.dead and b.held < 0:
			return b
	return null


func console_world() -> Vector3:
	return _w(console.pos)


func nucleus_pos() -> Vector2:
	return nucleus.pos


## Soup death: everything slumps into goo.
func melt() -> void:
	frozen = true
	holds.clear()
	var nodes: Array[Node3D] = [mito.node, nucleus.node, console.node, pipe_node]
	for b in bodies:
		nodes.append(b.node)
	for n in nodes:
		var tw := n.create_tween()
		tw.set_parallel(true)
		tw.tween_property(n, "scale", Vector3(1.5, 0.08, 1.5), 2.2).set_ease(Tween.EASE_IN)
		tw.tween_property(n, "position:y", -0.2, 2.2)
	band.visible = false
	dots.visible = false
	sling_ring.visible = false


## Supernova death: hand every organelle to the explosion as flying debris.
func eject() -> Array:
	frozen = true
	holds.clear()
	band.visible = false
	dots.visible = false
	sling_ring.visible = false
	var out: Array = []
	var scene := get_tree().current_scene
	var nodes: Array[Node3D] = [mito.node, nucleus.node, console.node, pipe_node]
	for b in bodies:
		nodes.append(b.node)
	for pd in puddles:
		nodes.append(pd.node)
	for n in nodes:
		if not is_instance_valid(n):
			continue
		var lp := n.position
		n.reparent(scene)
		var flat := Vector2(lp.x, lp.z)
		var dir := Vector3(lp.x, 0.0, lp.z).normalized() if flat.length() > 0.1 else Vector3(randf() - 0.5, 0.0, randf() - 0.5).normalized()
		out.append({"node": n, "vel": dir * randf_range(10.0, 20.0) + Vector3(0.0, randf_range(8.0, 16.0), 0.0), "spin": Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 16.0})
	bodies.clear()
	return out


func _count(kind: int) -> int:
	var c := 0
	for b in bodies:
		if b.kind == kind and not b.dead:
			c += 1
	return c


func _nearest(kind: int, p: Vector2, max_d: float) -> Body:
	var best: Body = null
	var bd := max_d
	for b in bodies:
		if b.kind != kind or b.dead:
			continue
		var d := b.pos.distance_to(p)
		if d < bd:
			bd = d
			best = b
	return best


func _pipe_at(u: float) -> Vector2:
	var f := clampf(u, 0.0, 1.0) * (pipe_pts.size() - 1)
	var i := mini(int(f), pipe_pts.size() - 2)
	return pipe_pts[i].lerp(pipe_pts[i + 1], f - i)


func _w(local: Vector2) -> Vector3:
	return host.position + Vector3(local.x, 1.2, local.y)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Feeds Mito's expression controller: scared while a phage is closing on the host or a
## free radical is buzzing right next to Mito; relaxes once safe.
func _mito_mood(dt: float) -> void:
	var threat := false
	if game.state == "play":
		threat = bool(game.sea.threat_near(host.pos, 12.0)) or _nearest(Kind.RADICAL, mito.pos, 3.4) != null or bool(game.in_danger())
	mito_expr.on_hazard_threat(threat)
	mito_expr.update(dt)


## A canister slammed into the membrane leaves the cell as an ATP bomb (feed vs. defend).
func _launch_bomb(b: Body, n: Vector2, vn: float) -> void:
	b.dead = true
	# punch-through: shove the wall hard outward at the exit point; the Verlet springs
	# snap it back, so it reads as the bomb stretching the membrane before tearing free
	host.membrane.poke(b.pos, n * maxf(vn, 10.0) * 2.6)
	var hp: Vector2 = host.pos
	var hv: Vector2 = host.vel
	var exit := hp + n * (float(host.membrane.radius_at(n.angle())) + 0.5)
	game.sea.bubble_burst(exit, n)
	game.on_canister_launched(exit, n * maxf(b.vel.length(), 14.0) + hv, b.charge)
	b.node.queue_free()


## OVERDRIVE + Macrophage Mom latched on: Mito strains toward her dent and headbutts the
## wall from the inside, peeling her off (and hurting her).
func _mito_headbutt(dt: float) -> void:
	if game.state != "play" or not game.overdrive or not game.sea.boss_latched():
		return
	var lp: Vector2 = game.sea.latch_point()
	var d := lp - mito.pos
	mito.vel += d.normalized() * 260.0 * dt
	if d.length() < mito.r + 1.1:
		game.sea.peel_boss(true)
		mito.sqv += 10.0
		mito_expr.on_hurt()


## EMERGENCY PURGE cost: burn two ATP canisters. Returns false (and stuns Mito for
## 1.5 s instead) when there aren't two to spare.
func purge_cost() -> bool:
	var cans: Array[Body] = []
	for b in bodies:
		if b.kind == Kind.CANISTER and not b.dead:
			cans.append(b)
	if cans.size() < 2:
		stun_t = 1.5
		mito_expr.on_hurt()
		mito.sqv += 12.0
		game.pop("MITO IS DAZED!", _w(mito.pos + Vector2(0.0, -2.6)), Color("ffd400"), 0.9)
		return false
	for i in 2:
		var b := cans[i]
		b.dead = true
		if b.held >= 0:
			holds.erase(b.held)
		var node := b.node
		var tw := node.create_tween()
		tw.tween_property(node, "scale", Vector3.ONE * 0.05, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(node.queue_free)
	_sweep()
	return true
