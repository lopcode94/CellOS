extends Node3D
## The Primordial Sea: food clusters, viral phages, rival protozoans and acid tears,
## all in world space around the host. Everything that touches the host's membrane
## dents it, so the outside world jiggles the inside world.

const Art = preload("res://scripts/art.gd")
const RAM_SPEED := 5.5
const DESPAWN := 48.0


class Food:
	var node: Node3D
	var pos := Vector2.ZERO
	var value := 1.0
	var bob := 0.0
	var dead := false


class Virus:
	var node: Node3D
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var r := 0.75
	var dead := false
	var eyes: Array = []
	var age := 0.0
	var phase := 0.0
	var marker: MeshInstance3D


class Rival:
	var node: Node3D
	var body: Node3D
	var cilia: Array[Node3D] = []
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var r := 1.6
	var dead := false
	var eyes: Array = []
	var age := 0.0
	var cool := 0.0


class Bomb:
	var node: Node3D
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 1.3
	var power := 1.0
	var dead := false


## Macrophage Mom: a giant hungry immune cell that tries to swallow the host.
class Boss:
	var node: Node3D
	var lobes: Array[Node3D] = []
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var r := 4.2
	var hp := 6
	var max_hp := 6
	var cool := 0.0
	var talk := 0.0
	var latched := false
	var latch_n := Vector2.RIGHT
	var slaps := 0
	var peel_cool := 0.0
	var t := 0.0


class Tear:
	var node: Node3D
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 1.4
	var dead := false


var game
var host
var foods: Array[Food] = []
var viruses: Array[Virus] = []
var rivals: Array[Rival] = []
var tears: Array[Tear] = []
var bombs: Array[Bomb] = []
var boss: Boss = null
var passive := true
var squashed := 0
var t := 0.0


func setup(g, h) -> void:
	game = g
	host = h
	reset()


func reset() -> void:
	for f in foods:
		_free(f.node)
	for v in viruses:
		_free(v.node)
		_free(v.marker)
	for r in rivals:
		_free(r.node)
	for tr in tears:
		_free(tr.node)
	foods.clear()
	viruses.clear()
	rivals.clear()
	tears.clear()
	for b in bombs:
		_free(b.node)
	bombs.clear()
	if boss:
		_free(boss.node)
		boss = null
	squashed = 0
	var hp: Vector2 = host.pos
	for c in 2:
		var center := hp + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 16.0)
		for k in 4:
			_spawn_food(center + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)))


func update(dt: float) -> void:
	t += dt
	_maintain()
	_foods(dt)
	_viruses(dt)
	_rivals(dt)
	_tears(dt)
	_bombs(dt)
	_boss_update(dt)
	_cleanup()


func _maintain() -> void:
	var hp: Vector2 = host.pos
	var gen: int = game.gen
	var live := 0
	for f in foods:
		if not f.dead:
			live += 1
	if live < 11:
		var c := hp + Vector2.from_angle(randf() * TAU) * randf_range(16.0, 30.0)
		for k in randi_range(3, 5):
			_spawn_food(c + Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5)))
	var want_v := 2 if passive else mini(1 + gen, 8)
	if viruses.size() < want_v:
		_spawn_virus(hp + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 28.0))
	var want_r := 1 if passive else clampi(gen - 1, 0, 3)
	if rivals.size() < want_r:
		_spawn_rival(hp + Vector2.from_angle(randf() * TAU) * randf_range(22.0, 30.0))


## How far a circle at world point p (radius r) is pushing into the host's membrane.
func _contact(p: Vector2, r: float) -> float:
	var hp: Vector2 = host.pos
	var d := p - hp
	return float(host.membrane.radius_at(d.angle())) + r - d.length()


# ---------------------------------------------------------------- food

func _spawn_food(p: Vector2) -> void:
	var f := Food.new()
	f.pos = p
	f.bob = randf() * TAU
	f.node = Node3D.new()
	add_child(f.node)
	if randf() < 0.65:
		f.value = 1.0
		var cube := Art.add(f.node, Art.box_mesh(Vector3(0.55, 0.55, 0.55)), Art.clay(Color("fff3f8"), 0.45, 0.02))
		cube.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		Art.ball(f.node, 0.1, Art.clay(Color("ff7cc0"), 0.5, 0.0), Vector3(0.0, 0.38, 0.0))
	else:
		f.value = 1.6
		var y := Art.bubble(Color("fff3b8"), 0.05, 1.3)
		Art.ball(f.node, 0.36, y)
		Art.ball(f.node, 0.26, y, Vector3(0.38, -0.05, 0.1))
		Art.ball(f.node, 0.2, y, Vector3(-0.2, 0.05, 0.34))
	f.node.position = Vector3(p.x, 0.7, p.y)
	foods.append(f)


func _foods(dt: float) -> void:
	for f in foods:
		if f.dead:
			continue
		f.bob += dt
		if not passive and game.has_mut("vacuum"):
			var hv: Vector2 = host.pos
			var to := hv - f.pos
			if to.length() < 9.0:
				f.pos += to.normalized() * 3.5 * dt
		f.node.position = Vector3(f.pos.x, 0.7 + sin(f.bob * 2.0) * 0.18, f.pos.y)
		f.node.rotation.y += dt * 0.8
		if (game.state == "play" or game.state == "title") and _contact(f.pos, 0.4) > 0.0:
			_engulf(f)


func _engulf(f: Food) -> void:
	f.dead = true
	var hp: Vector2 = host.pos
	var local := f.pos - hp
	host.membrane.poke(local, -local.normalized() * 6.0)
	var node := f.node
	game.pop("NOM!", node.global_position, Color("fff3f8"), 0.8)
	game.sfx("slurp")
	node.reparent(host)
	var value := f.value
	var g = game
	var tw := node.create_tween()
	tw.tween_property(node, "position", Vector3(-6.3, 1.1, -2.3), 0.35).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(node, "scale", Vector3.ONE * 0.35, 0.35)
	tw.tween_callback(func(): g.on_food_eaten(value))
	tw.tween_callback(node.queue_free)


func nearest_food(p: Vector2) -> Vector2:
	var best := Vector2.INF
	var bd := 1e9
	for f in foods:
		if f.dead:
			continue
		var d := f.pos.distance_to(p)
		if d < bd:
			bd = d
			best = f.pos
	return best


## True when a live (hunting) phage is within `dist` of p. Drives Mito's scared face.
func threat_near(p: Vector2, dist: float) -> bool:
	if passive:
		return false
	for v in viruses:
		if not v.dead and v.pos.distance_to(p) < dist:
			return true
	return false


func nearest_virus(p: Vector2) -> Vector2:
	var best := Vector2.INF
	var bd := 26.0
	for v in viruses:
		if v.dead:
			continue
		var d := v.pos.distance_to(p)
		if d < bd:
			bd = d
			best = v.pos
	return best


# ---------------------------------------------------------------- viruses

func _spawn_virus(p: Vector2) -> void:
	var v := Virus.new()
	v.pos = p
	v.phase = randf() * 100.0
	v.node = Node3D.new()
	add_child(v.node)
	var body := Art.clay(Color("7a2a78"), 0.55, 0.03)
	var tip := Art.clay(Color("d0365f"), 0.5, 0.02)
	Art.ball(v.node, 0.72, body)
	for i in 16:
		var y := 1.0 - (i + 0.5) / 16.0 * 2.0
		var rad := sqrt(maxf(0.0, 1.0 - y * y))
		var a := i * 2.39996
		var dir := Vector3(cos(a) * rad, y, sin(a) * rad)
		var s := Art.add(v.node, Art.cyl_mesh(0.06, 0.08, 0.3, 8), body, dir * 0.82)
		s.basis = Basis(Quaternion(Vector3.UP, dir))
		Art.ball(v.node, 0.14, tip, dir * 1.0)
	v.eyes = Art.face(v.node, 0.72, "angry", 1.3)
	# red target ring that slides along the membrane to show where this phage will hit
	v.marker = Art.add(self, _ring_mesh(), Art.glow(Color("ff2a4a"), 1.6))
	v.marker.visible = false
	v.node.position = Vector3(p.x, 0.9, p.y)
	viruses.append(v)


func _viruses(dt: float) -> void:
	var hp: Vector2 = host.pos
	for v in viruses:
		if v.dead:
			continue
		v.age += dt
		var to := hp - v.pos
		var dist := to.length()
		var want: Vector2
		if not passive and dist < float(game.virus_range()):
			want = to / maxf(dist, 0.01) * (2.4 + 0.25 * float(game.gen))
		else:
			want = Vector2.from_angle(v.age * 0.4 + v.phase) * 1.2
		v.vel = v.vel.move_toward(want, 5.0 * dt)
		if not passive and game.has_mut("vacuum") and dist < 10.0:
			v.vel += to / maxf(dist, 0.01) * 2.5 * dt
		v.pos += v.vel * dt
		_update_marker(v, hp, dist)
		v.node.position = Vector3(v.pos.x, 0.9 + sin(v.age * 3.0) * 0.2, v.pos.y)
		v.node.rotation.z = sin(v.age * 7.0) * 0.15
		var look := Vector2(to.x, -to.y).normalized()
		for e in v.eyes:
			e.look(look)
		if _contact(v.pos, v.r) > 0.0:
			_virus_hit(v)


func _virus_hit(v: Virus) -> void:
	var hp: Vector2 = host.pos
	var local := v.pos - hp
	var n := local.normalized()
	if passive:
		v.vel = n * 4.0
		v.pos = hp + n * (float(host.membrane.radius_at(n.angle())) + v.r + 0.05)
		host.membrane.poke(local, -n * 4.0)
		return
	v.dead = true
	var hv: Vector2 = host.vel
	var ram := hv.dot(n)
	var at: Vector3 = v.node.global_position
	if game.has_mut("spicy"):
		squashed += 1
		game.pop("SIZZLE!", at, Color("ff6a2a"), 1.0)
		game.sfx("fizz")
		host.membrane.poke(local, -n * 5.0)
	elif ram > float(game.ram_speed()):
		squashed += 1
		game.pop("SPLAT!", at, Color("ff5ad1"), 1.1)
		game.sfx("splat")
		game.add_shake(0.5)
		host.membrane.poke(local, -n * 10.0)
	else:
		host.membrane.poke(local, -n * 16.0)
		host.knock(-n * 3.0)
		game.on_infected(n.angle(), at)
	_burst(v.node)


# ---------------------------------------------------------------- rivals

func _spawn_rival(p: Vector2) -> void:
	var r := Rival.new()
	r.pos = p
	r.node = Node3D.new()
	add_child(r.node)
	r.body = Node3D.new()
	r.node.add_child(r.body)
	var cap := CapsuleMesh.new()
	cap.radius = 1.0
	cap.height = 3.2
	var m := Art.add(r.body, cap, Art.gel(Color("3fe0b0"), Color("b8ff6a"), 0.6, 1.0, 0.04), Vector3(0.0, 0.9, 0.0))
	m.rotation.z = PI * 0.5
	Art.ball(r.body, 0.45, Art.clay(Color("2f6fd6"), 0.5, 0.02), Vector3(-0.7, 1.25, 0.35))
	var cil := Art.gel(Color("ff9a3a"), Color("ffd27a"), 0.8, 0.6, 0.0)
	var squig := PackedVector3Array()
	for k in 9:
		squig.append(Vector3(k * 0.11, sin(k * 1.4) * 0.09, cos(k * 1.1) * 0.05))
	var stick_mesh := Art.tube_mesh(squig, 0.05, 6, 0.6)
	for i in 18:
		var a := TAU * i / 18.0
		var c := Node3D.new()
		r.body.add_child(c)
		c.position = Vector3(cos(a) * 1.5, 0.9, sin(a) * 0.95)
		c.rotation.y = -a
		Art.add(c, stick_mesh, cil)
		r.cilia.append(c)
	r.eyes = Art.face(r.node, 1.0, "smug", 2.0, Vector3(0.0, 0.9, 0.0))
	r.node.position = Vector3(p.x, 0.0, p.y)
	rivals.append(r)


func _rivals(dt: float) -> void:
	var hp: Vector2 = host.pos
	for r in rivals:
		if r.dead:
			continue
		r.age += dt
		r.cool = maxf(0.0, r.cool - dt)
		var target: Food = null
		var bd := 16.0
		for f in foods:
			if f.dead:
				continue
			var d := f.pos.distance_to(r.pos)
			if d < bd:
				bd = d
				target = f
		var want := Vector2.from_angle(r.age * 0.3) * 1.5
		if target:
			want = (target.pos - r.pos).normalized() * 3.2
		r.vel = r.vel.move_toward(want, 3.0 * dt)
		r.pos += r.vel * dt
		if target and target.pos.distance_to(r.pos) < r.r + 0.3:
			target.dead = true
			_burst(target.node)
			if not passive:
				game.pop("MINE!", target.node.global_position, Color("4aa8ff"), 0.7)
				game.sfx("nom")
		r.node.position = Vector3(r.pos.x, 0.0, r.pos.y)
		if r.vel.length() > 0.2:
			r.body.rotation.y = lerp_angle(r.body.rotation.y, atan2(-r.vel.y, r.vel.x), minf(1.0, dt * 3.0))
		for i in r.cilia.size():
			r.cilia[i].rotation.z = sin(r.age * 14.0 + i * 0.8) * 0.5
		var look := Vector2(hp.x - r.pos.x, r.pos.y - hp.y).normalized()
		for e in r.eyes:
			e.look(look)
		if _contact(r.pos, r.r) > 0.0:
			_rival_hit(r)


func _rival_hit(r: Rival) -> void:
	var hp: Vector2 = host.pos
	var local := r.pos - hp
	var n := local.normalized()
	var hv: Vector2 = host.vel
	var rel := (hv - r.vel).dot(n)
	if not passive and rel > float(game.ram_speed()):
		r.dead = true
		for k in 3:
			_spawn_food(r.pos + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)))
		game.pop("RAMMED! LUNCH IS SERVED", r.node.global_position, Color("4aa8ff"), 1.0)
		game.sfx("pop")
		game.sfx("boing")
		game.add_shake(0.6)
		host.membrane.poke(local, -n * 12.0)
		_burst(r.node)
		return
	r.pos = hp + n * (float(host.membrane.radius_at(n.angle())) + r.r + 0.05)
	r.vel = n * 5.0
	host.knock(-n * 2.5)
	host.membrane.poke(local, -n * 9.0)
	if not passive and r.cool <= 0.0:
		r.cool = 1.2
		game.on_rival_bump(r.node.global_position)


# ---------------------------------------------------------------- tears (lysosome cannon)

func fire_tear(from: Vector2, vel: Vector2) -> void:
	var tr := Tear.new()
	tr.pos = from
	tr.vel = vel
	tr.node = Node3D.new()
	add_child(tr.node)
	Art.ball(tr.node, 0.35, Art.bubble(Color("8ff0ff"), 0.06, 1.2), Vector3.ZERO, Vector3(1.0, 1.4, 1.0))
	tr.node.position = Vector3(from.x, 1.0, from.y)
	tears.append(tr)


func _tears(dt: float) -> void:
	for tr in tears:
		if tr.dead:
			continue
		tr.life -= dt
		tr.pos += tr.vel * dt
		tr.node.position = Vector3(tr.pos.x, 1.0, tr.pos.y)
		if tr.life <= 0.0:
			tr.dead = true
		for v in viruses:
			if tr.dead:
				break
			if not v.dead and v.pos.distance_to(tr.pos) < v.r + 0.45:
				v.dead = true
				tr.dead = true
				squashed += 1
				game.pop("POP!", v.node.global_position, Color("6fe8ff"), 0.9)
				game.sfx("pop")
				_burst(v.node)
		for r in rivals:
			if tr.dead:
				break
			if not r.dead and r.pos.distance_to(tr.pos) < r.r + 0.45:
				r.dead = true
				tr.dead = true
				for k in 3:
					_spawn_food(r.pos + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)))
				game.pop("WAAAH... SORRY!", r.node.global_position, Color("6fe8ff"), 0.8)
				game.sfx("pop")
				_burst(r.node)
		if tr.dead:
			_free(tr.node)


# ---------------------------------------------------------------- housekeeping

func _cleanup() -> void:
	var hp: Vector2 = host.pos
	for i in range(foods.size() - 1, -1, -1):
		var f := foods[i]
		if not f.dead and f.pos.distance_to(hp) > DESPAWN:
			f.dead = true
			_free(f.node)
		if f.dead:
			foods.remove_at(i)
	for i in range(viruses.size() - 1, -1, -1):
		var v := viruses[i]
		if not v.dead and v.pos.distance_to(hp) > DESPAWN:
			v.dead = true
			_free(v.node)
		if v.dead:
			_free(v.marker)
			viruses.remove_at(i)
	for i in range(rivals.size() - 1, -1, -1):
		var r := rivals[i]
		if not r.dead and r.pos.distance_to(hp) > DESPAWN:
			r.dead = true
			_free(r.node)
		if r.dead:
			rivals.remove_at(i)
	for i in range(tears.size() - 1, -1, -1):
		if tears[i].dead:
			tears.remove_at(i)


func _burst(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * 1.6, 0.08)
	tw.tween_property(node, "scale", Vector3.ONE * 0.01, 0.14)
	tw.tween_callback(node.queue_free)


func _free(node: Node3D) -> void:
	if is_instance_valid(node):
		node.queue_free()


# ---------------------------------------------------------------- virus target rings

var _ring: TorusMesh


func _ring_mesh() -> TorusMesh:
	if _ring == null:
		_ring = TorusMesh.new()
		_ring.inner_radius = 0.55
		_ring.outer_radius = 0.78
	return _ring


## Telegraph: when a hunting phage closes in, a pulsing red ring sits on the membrane
## exactly where it will hit, so you can ram it, bomb it or dodge.
func _update_marker(v: Virus, hp: Vector2, dist: float) -> void:
	var m := v.marker
	if passive or dist > float(game.virus_range()):
		m.visible = false
		return
	var n := (v.pos - hp) / maxf(dist, 0.01)
	var rm: float = host.membrane.radius_at(n.angle())
	var gap := dist - rm - v.r
	if gap > 9.0:
		m.visible = false
		return
	m.visible = true
	var urgency := clampf(1.0 - gap / 9.0, 0.0, 1.0)
	m.position = Vector3(hp.x + n.x * rm, 0.75, hp.y + n.y * rm)
	m.scale = Vector3.ONE * (0.8 + urgency * 0.6 + sin(t * (6.0 + urgency * 10.0)) * 0.12)


# ---------------------------------------------------------------- ATP bombs

## A canister slingshotted hard enough leaves the cell as an ATP bomb.
func fire_bomb(p: Vector2, v: Vector2, charge: float) -> void:
	var b := Bomb.new()
	b.pos = p
	b.vel = v
	b.power = charge
	b.node = Node3D.new()
	add_child(b.node)
	Art.ball(b.node, 0.4, Art.glow(Color("58ff6a"), 2.2))
	Art.ball(b.node, 0.62, Art.bubble(Color("c8ffd0"), 0.0, 1.6, 0.05, 0.9))
	b.node.position = Vector3(p.x, 1.0, p.y)
	bombs.append(b)


func _bombs(dt: float) -> void:
	for b in bombs:
		if b.dead:
			continue
		b.life -= dt
		b.vel *= exp(-0.5 * dt)
		b.pos += b.vel * dt
		b.node.position = Vector3(b.pos.x, 1.0 + sin(b.life * 20.0) * 0.1, b.pos.y)
		b.node.rotate_y(dt * 8.0)
		var hit := b.life <= 0.0
		for v in viruses:
			if not v.dead and v.pos.distance_to(b.pos) < v.r + 0.7:
				hit = true
		for r in rivals:
			if not r.dead and r.pos.distance_to(b.pos) < r.r + 0.6:
				hit = true
		if boss and boss.pos.distance_to(b.pos) < boss.r + 0.6:
			hit = true
		if hit:
			_explode(b)
	for i in range(bombs.size() - 1, -1, -1):
		if bombs[i].dead:
			bombs.remove_at(i)


func _explode(b: Bomb) -> void:
	b.dead = true
	var volatile: bool = game.has_mut("volatile")
	var radius := 3.2 * (2.0 if volatile else 1.0)
	var kills := 0
	for v in viruses:
		if not v.dead and v.pos.distance_to(b.pos) < radius + v.r:
			v.dead = true
			kills += 1
			squashed += 1
			_burst(v.node)
	for r in rivals:
		if not r.dead and r.pos.distance_to(b.pos) < radius + r.r:
			r.dead = true
			for k in 3:
				_spawn_food(r.pos + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)))
			_burst(r.node)
	var boss_hit := boss != null and boss.pos.distance_to(b.pos) < radius + boss.r
	if boss_hit:
		damage_boss(2, (boss.pos - b.pos).normalized())
	# hit-stop on the big moments: a boss direct hit or wiping 2+ viruses at once
	if boss_hit or kills >= 2:
		game.hit_stop(0.045)
	if volatile:
		game.tension.deliver(0.5)
	var at := Vector3(b.pos.x, 1.0, b.pos.y)
	game.pop("KA-POW!" if kills == 0 else "KA-POW! x%d" % kills, at, Color("7dff6a"), 1.1)
	game.sfx("kaboom", 0.5)
	game.add_shake(0.5)
	# expanding glass shockwave
	var fx := Art.ball(self, 1.0, Art.bubble(Color("b8ffc8"), 0.0, 2.0, 0.1, 0.9), at)
	fx.scale = Vector3.ONE * 0.3
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector3.ONE * radius, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_callback(fx.queue_free)
	_free(b.node)


# ---------------------------------------------------------------- generation events

func spawn_swarm(count: int) -> void:
	var hp: Vector2 = host.pos
	var a := randf() * TAU
	for k in count:
		_spawn_virus(hp + Vector2.from_angle(a + randf_range(-0.5, 0.5)) * randf_range(17.0, 22.0))


func spawn_bloom() -> void:
	var hp: Vector2 = host.pos
	for c in 3:
		var center := hp + Vector2.from_angle(randf() * TAU) * randf_range(9.0, 15.0)
		for k in 5:
			_spawn_food(center + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)))


# ---------------------------------------------------------------- boss: Macrophage Mom

func boss_active() -> bool:
	return boss != null


func spawn_boss(hp_points: int) -> void:
	if boss:
		return
	var hp: Vector2 = host.pos
	boss = Boss.new()
	boss.hp = hp_points
	boss.max_hp = hp_points
	boss.pos = hp + Vector2.from_angle(randf() * TAU) * 26.0
	boss.node = Node3D.new()
	add_child(boss.node)
	var flesh := Art.gel(Color("c23cff"), Color("ff8ad8"), 0.6, 0.9, 0.05)
	Art.ball(boss.node, boss.r, flesh, Vector3(0.0, 1.6, 0.0), Vector3(1.0, 0.55, 1.0))
	for i in 5:
		var lobe := Node3D.new()
		boss.node.add_child(lobe)
		Art.ball(lobe, 1.5, flesh, Vector3(boss.r * 0.95, 1.0, 0.0), Vector3(1.2, 0.6, 1.0))
		lobe.rotation.y = TAU * i / 5.0
		boss.lobes.append(lobe)
	Art.face(boss.node, 2.6, "angry", 4.0, Vector3(0.0, 1.6, 0.0))
	boss.node.position = Vector3(boss.pos.x, 0.0, boss.pos.y)


func damage_boss(amount: int, push: Vector2) -> void:
	if boss == null:
		return
	boss.hp -= amount
	boss.vel += push * 8.0
	game.pop("OUCH! %d/%d" % [maxi(boss.hp, 0), boss.max_hp], boss.node.global_position + Vector3(0.0, 3.0, 0.0), Color("ff8ad8"), 1.2)
	game.sfx("splat")
	if boss.hp <= 0:
		var at := boss.node.global_position
		for k in 8:
			_spawn_food(boss.pos + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)))
		_burst(boss.node)
		boss = null
		game.on_boss_defeated(at)


func _boss_update(dt: float) -> void:
	if boss == null:
		return
	var hp: Vector2 = host.pos
	boss.t += dt
	boss.cool = maxf(0.0, boss.cool - dt)
	boss.talk = maxf(0.0, boss.talk - dt)
	boss.peel_cool = maxf(0.0, boss.peel_cool - dt)
	var to := hp - boss.pos
	var dist := to.length()
	var n := -to / maxf(dist, 0.01)
	if not passive and boss.peel_cool <= 0.0:
		boss.vel = boss.vel.move_toward(-n * 2.3, 1.6 * dt)
	else:
		boss.vel = boss.vel.move_toward(Vector2.ZERO, (8.0 if boss.peel_cool > 0.0 else 1.2) * dt)
	boss.pos += boss.vel * dt
	boss.node.position = Vector3(boss.pos.x, 0.0, boss.pos.y)
	for i in boss.lobes.size():
		var s := 1.0 + sin(boss.t * 1.7 + i * 1.3) * 0.18
		boss.lobes[i].scale = Vector3(s, 1.0, s)
		boss.lobes[i].rotation.y += dt * 0.15
	var overlap := float(host.membrane.radius_at(n.angle())) + boss.r - dist
	boss.latched = overlap > -0.3 and not passive and boss.peel_cool <= 0.0
	if boss.latched:
		# latched: she presses a deep visible dent into the wall at the contact point
		boss.latch_n = n
		host.membrane.dent(n.angle(), 1.6)
	else:
		boss.slaps = 0
	if overlap > 0.0 and not passive:
		var hv: Vector2 = host.vel
		var ram := (hv - boss.vel).dot(n)
		boss.pos += n * overlap
		host.membrane.poke(boss.pos - hp, -n * 6.0)
		if ram > float(game.ram_speed()) and boss.cool <= 0.0:
			boss.cool = 0.8
			host.knock(-n * 5.0)
			damage_boss(1, n)
			game.add_shake(0.6)
			return
		# she's trying to engulf us: digestion floods in while she's pressed against us
		game.tension.digestion = minf(100.0, game.tension.digestion + 14.0 * dt)
		host.knock(-n * 3.0 * dt)
		if boss.talk <= 0.0:
			boss.talk = 1.4
			game.pop("SHE'S EATING US!", boss.node.global_position + Vector3(0.0, 3.0, 0.0), Color("ff4fd8"), 1.0)
			game.sfx("blorp", 0.5)


## Small iridescent bubble spray (bomb punching through the membrane, purge vents...).
func bubble_burst(p: Vector2, dir: Vector2, count: int = 9) -> void:
	var mat := Art.bubble(Color("e8fbff"), 0.0, 1.8, 0.05, 0.9)
	for k in count:
		var spread := Vector2.from_angle(dir.angle() + randf_range(-0.9, 0.9)) * randf_range(1.5, 4.0)
		var b := Art.ball(self, randf_range(0.12, 0.3), mat, Vector3(p.x, 0.9, p.y))
		var to := b.position + Vector3(spread.x, randf_range(0.3, 1.6), spread.y)
		var tw := b.create_tween()
		tw.set_parallel(true)
		tw.tween_property(b, "position", to, randf_range(0.35, 0.6)).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector3.ONE * 0.05, 0.6).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(b.queue_free)


# ---------------------------------------------------------------- boss latch / peel-off

func boss_latched() -> bool:
	return boss != null and boss.latched


## Host-local point at the middle of her dent.
func latch_point() -> Vector2:
	if boss == null:
		return Vector2.INF
	return boss.latch_n * float(host.membrane.radius_at(boss.latch_n.angle()))


## Slapping/clicking the dented wall: 3 slaps knock her loose. Returns true if it hit.
func slap_latch(local_p: Vector2) -> bool:
	if not boss_latched() or local_p.distance_to(latch_point()) > 2.4:
		return false
	boss.slaps += 1
	host.membrane.poke(latch_point(), boss.latch_n * 10.0)
	boss.vel += boss.latch_n * 3.0
	game.sfx("bonk")
	game.add_shake(0.25)
	var at: Vector3 = host.position + Vector3(latch_point().x, 1.5, latch_point().y)
	if boss.slaps >= 3:
		peel_boss(false)
	else:
		game.pop("SLAP! %d/3" % boss.slaps, at, Color("ffd400"), 0.9)
	return true


## Knock her off the wall. A headbutt (OVERDRIVE ram) also hurts her.
func peel_boss(headbutt: bool) -> void:
	if boss == null:
		return
	var n := boss.latch_n
	boss.latched = false
	boss.slaps = 0
	boss.peel_cool = 2.5
	if game.autotest:
		print("[autotest] boss peeled off (headbutt=%s)" % headbutt)
	boss.vel = n * 11.0
	boss.pos += n * 1.2
	host.membrane.poke(latch_point(), n * 14.0)
	host.knock(-n * 2.0)
	var at: Vector3 = boss.node.global_position + Vector3(0.0, 3.0, 0.0)
	game.pop("HEADBUTT! PEELED OFF!" if headbutt else "PEELED OFF!", at, Color("ffd400"), 1.2)
	game.sfx("boing")
	game.add_shake(0.7)
	game.hit_stop(0.04)
	if headbutt:
		damage_boss(1, n)
