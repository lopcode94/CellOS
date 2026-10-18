extends Node3D
## The host: a giant, dim-witted predator amoeba you pilot from the inside.
## Owns the soft-body membrane, its dopey face, and any wild mutations it sprouts.

const Art = preload("res://scripts/art.gd")
const Membrane = preload("res://scripts/membrane.gd")
const CYTO = preload("res://shaders/cytoplasm.gdshader")
const CytoplasmFx = preload("res://scripts/cytoplasm_fx.gd")

const R := 7.0

var membrane: Membrane
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var accel := Vector2.ZERO
var eyes: Array = []
var grin: MeshInstance3D
var gape: MeshInstance3D
var tooth: MeshInstance3D
var wild := {}
var wild_angle := {}
var lunged := false
var hunger := 0.0
var t := 0.0
var _lunge_t := 2.5


func _ready() -> void:
	membrane = Membrane.new()
	add_child(membrane)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = CYTO
	# soap-bubble membrane: neon Memphis rim band + iridescent film dome that wobbles on the GPU
	# plain liquid-glass rim: just a thicker, glossier edge of the same soap film
	# thick glossy outer membrane wall: strong Fresnel + rainbow film
	var rim_mat := Art.bubble(Color("a8eeff"), 0.0, 1.25, 0.05, 0.85).duplicate() as ShaderMaterial
	rim_mat.render_priority = 9
	var dome_mat := Art.bubble(Color("b8f2ff"), 0.0, 1.0, 0.02, 0.6, 0.05).duplicate() as ShaderMaterial
	dome_mat.render_priority = 10
	# inner refractive halo that glows with rainbow caustics just inside the wall
	var halo_mat := Art.bubble(Color("6fdcff"), 0.06, 1.25).duplicate() as ShaderMaterial
	halo_mat.render_priority = 8
	membrane.setup(R, floor_mat, rim_mat, dome_mat, halo_mat)
	add_child(CytoplasmFx.new())


func move(dt: float, steer: Vector2, max_speed: float, thrust: float) -> void:
	t += dt
	var before := vel
	vel = vel.move_toward(steer * max_speed, thrust * dt)
	if wild.has("arm"):
		_lunge_t -= dt
		if _lunge_t <= 0.0:
			_lunge_t = randf_range(1.8, 3.5)
			var d := Vector2.from_angle(randf() * TAU)
			vel += d * 6.0
			membrane.poke(d * R, d * 14.0)
			lunged = true
	pos += vel * dt
	accel = (vel - before) / maxf(dt, 0.0001)
	position = Vector3(pos.x, 0.0, pos.y)
	membrane.move_dir = (vel / maxf(max_speed, 0.1)).limit_length(1.0)
	membrane.step(dt, accel)
	membrane.rebuild()
	# the dome breathes faster as the host gets hungry
	membrane.dome_mat.set_shader_parameter("pulse", 0.02 + hunger * 0.06)
	_update_wild()


func knock(v: Vector2) -> void:
	vel += v


func has_wild(kind: String) -> bool:
	return wild.has(kind)


func add_wild(kind: String) -> void:
	if wild.has(kind):
		return
	var n := Node3D.new()
	add_child(n)
	wild[kind] = n
	wild_angle[kind] = randf() * TAU
	var flesh := Art.clay(Color("ff6fae"), 0.55, 0.03)
	match kind:
		"flagellum":
			var mi := MeshInstance3D.new()
			mi.material_override = flesh
			n.add_child(mi)
		"eye":
			var stalk := PackedVector3Array([Vector3.ZERO, Vector3(0.0, 1.0, 0.3), Vector3(0.0, 2.2, 0.2)])
			Art.add(n, Art.tube_mesh(stalk, 0.2, 8, 0.3), flesh)
			# a jelly eye-bulb with the pupil floating inside the gel
			Art.ball(n, 0.75, Art.gel(Color("f4fbff"), Color("ffffff"), 0.6, 0.4), Vector3(0.0, 2.5, 0.2))
			Art.ball(n, 0.28, Art.ink(), Vector3(0.0, 2.5, 0.2) + Art.FACE_DIR * 0.45, Vector3(1.0, 1.0, 0.4))
		"arm":
			for i in 3:
				var cap := CapsuleMesh.new()
				cap.radius = 0.32 - i * 0.04
				cap.height = 1.3
				var seg := Art.add(n, cap, flesh, Vector3(0.6 + i * 1.0, 0.6, 0.0))
				seg.rotation.z = PI * 0.5
			Art.ball(n, 0.45, Art.clay(Color("ffe14d"), 0.5, 0.03), Vector3(3.3, 0.6, 0.0))
	n.scale = Vector3.ONE * 0.05
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func remove_wild(kind: String) -> void:
	if not wild.has(kind):
		return
	var n: Node3D = wild[kind]
	wild.erase(kind)
	wild_angle.erase(kind)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


func _update_wild() -> void:
	for kind in wild:
		var n: Node3D = wild[kind]
		var a: float = wild_angle[kind]
		var dir := Vector2.from_angle(a)
		var edge := membrane.radius_at(a)
		var base := Vector3(dir.x * edge, 0.4, dir.y * edge)
		match kind:
			"flagellum":
				var side := Vector2(-dir.y, dir.x)
				var pts := PackedVector3Array()
				for i in 14:
					var s := float(i) / 13.0
					var along := dir * (s * 5.0)
					var wig := side * sin(t * 9.0 - s * 6.0) * s * 1.3
					pts.append(base + Vector3(along.x + wig.x, 0.2 * sin(t * 5.0 + s * 3.0), along.y + wig.y))
				(n.get_child(0) as MeshInstance3D).mesh = Art.tube_mesh(pts, 0.2, 8, 0.8)
			"eye":
				n.position = base
				n.rotation.z = sin(t * 3.0) * 0.25
				n.rotation.x = cos(t * 2.3) * 0.2
			"arm":
				n.position = base
				n.rotation.y = -a + sin(t * 4.0) * 0.6


## For the supernova: hand the face over to the explosion as flying debris.
func eject_face() -> Array:
	var out: Array = []
	var scene := get_tree().current_scene
	for n in eyes + [grin, tooth, gape]:
		var node: Node3D = n
		if not is_instance_valid(node):
			continue
		var lp := node.position
		node.reparent(scene)
		var d := Vector3(lp.x, 0.0, lp.z).normalized()
		out.append({"node": node, "vel": d * randf_range(8.0, 14.0) + Vector3(0.0, randf_range(10.0, 16.0), 0.0), "spin": Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 12.0})
	eyes.clear()
	return out
