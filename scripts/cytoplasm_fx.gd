extends Node3D
## Lightweight "crowded cytoplasm" depth layer that lives inside the host (host-local),
## under the organelles and above the floor:
##   * soft-focus vesicles drifting in the deep jelly (CPUParticles3D, one draw call)
##   * tiny lipid droplets with a soap-film sheen
##   * faint actin / cytoskeleton filaments that slowly drift, sway and turn
## Purely visual: nothing here touches physics or gameplay.

const Art = preload("res://scripts/art.gd")
const SOFT := preload("res://shaders/soft_vesicle.gdshader")

const FIELD_R := 4.8
const FILAMENTS := 7

var _filaments: Array[MeshInstance3D] = []
var _fil_base: Array[Vector3] = []
var _fil_spin: Array[float] = []
var _t := 0.0


func _ready() -> void:
	_add_vesicles()
	_add_droplets()
	_add_filaments()


func _soft_mat(opacity: float, softness: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SOFT
	m.set_shader_parameter("opacity", opacity)
	m.set_shader_parameter("softness", softness)
	return m


func _fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.2, Color(1, 1, 1, 1))
	g.add_point(0.8, Color(1, 1, 1, 1))
	return g


func _disc_emitter(p: CPUParticles3D, height: float) -> void:
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = FIELD_R
	p.emission_ring_inner_radius = 0.0
	p.emission_ring_height = height
	p.direction = Vector3(1, 0, 0)
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.color_ramp = _fade_ramp()


func _add_vesicles() -> void:
	var p := CPUParticles3D.new()
	p.amount = 34
	p.lifetime = 11.0
	p.preprocess = 11.0
	_disc_emitter(p, 0.3)
	p.position.y = 0.35
	p.initial_velocity_min = 0.04
	p.initial_velocity_max = 0.18
	p.scale_amount_min = 0.35
	p.scale_amount_max = 1.0
	p.mesh = Art.sphere_mesh(0.55, 16)
	var tints := Gradient.new()
	tints.set_color(0, Color("c07bff"))
	tints.set_color(1, Color("5fe8ff"))
	tints.add_point(0.5, Color("ff8ad8"))
	p.color_initial_ramp = tints
	p.material_override = _soft_mat(0.4, 1.6)
	add_child(p)


func _add_droplets() -> void:
	var p := CPUParticles3D.new()
	p.amount = 26
	p.lifetime = 8.0
	p.preprocess = 8.0
	_disc_emitter(p, 0.8)
	p.position.y = 0.6
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0, 0.03, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.mesh = Art.sphere_mesh(0.12, 10)
	p.material_override = Art.bubble(Color("fff6d8"), 0.0, 1.6, 0.05, 0.85)
	add_child(p)


func _add_filaments() -> void:
	var mat := _soft_mat(0.32, 0.8)
	mat.set_shader_parameter("tint", Color("ffd8f4"))
	for i in FILAMENTS:
		var pts := PackedVector3Array()
		var length := randf_range(2.6, 4.6)
		var phase := randf() * TAU
		for k in 18:
			var u := float(k) / 17.0
			pts.append(Vector3((u - 0.5) * length, sin(u * TAU * 1.5 + phase) * 0.06, sin(u * TAU + phase) * 0.35))
		var mi := MeshInstance3D.new()
		mi.mesh = Art.tube_mesh(pts, 0.035, 5)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var at := Vector2.from_angle(randf() * TAU) * randf_range(0.8, FIELD_R - 0.6)
		var base := Vector3(at.x, 0.12, at.y)
		mi.position = base
		mi.rotation.y = randf() * TAU
		add_child(mi)
		_filaments.append(mi)
		_fil_base.append(base)
		_fil_spin.append(randf_range(-0.06, 0.06))


func _process(dt: float) -> void:
	_t += dt
	for i in _filaments.size():
		var f := _filaments[i]
		f.rotation.y += _fil_spin[i] * dt
		f.position = _fil_base[i] + Vector3(sin(_t * 0.21 + i) * 0.35, 0.0, cos(_t * 0.17 + i * 1.7) * 0.35)
