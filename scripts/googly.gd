extends Node3D
## Googly eye: a white ball with a pupil on a damped spring. The pupil lags behind
## the body's motion and rattles off the rim, so every bump reads as a cartoon double-take.

var r := 0.2
var pupil: MeshInstance3D
var off := Vector2.ZERO
var vel := Vector2.ZERO
var target := Vector2.ZERO
var crazy := 0.0
var blink_t := 0.0
var _last := Vector3.ZERO
var _primed := false


func setup(radius: float, white_mat: Material, pupil_mat: Material, pupil_frac: float = 0.5) -> void:
	r = radius
	var w := MeshInstance3D.new()
	var wm := SphereMesh.new()
	wm.radius = r
	wm.height = r * 2.0
	w.mesh = wm
	w.material_override = white_mat
	add_child(w)
	pupil = MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = r * pupil_frac
	pm.height = r * pupil_frac * 2.0
	pupil.mesh = pm
	pupil.material_override = pupil_mat
	pupil.scale = Vector3(1.0, 1.0, 0.5)
	add_child(pupil)
	blink_t = randf_range(1.0, 4.0)


## Where to look, in face-plane coordinates (x right, y up), length <= 1.
func look(v: Vector2) -> void:
	target = v.limit_length(1.0)


func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	if dt <= 0.0 or pupil == null:
		return
	var gp := global_position
	if _primed:
		var mv := gp - _last
		if mv.length() < 2.0:
			vel += Vector2(-mv.x, mv.z) * 38.0
	_primed = true
	_last = gp
	var jit := Vector2(randf() - 0.5, randf() - 0.5) * crazy * 2.0
	crazy = maxf(0.0, crazy - dt)
	vel += ((target + jit) - off) * 120.0 * dt
	vel *= exp(-7.0 * dt)
	off += vel * dt
	if off.length() > 1.0:
		off = off.normalized()
		vel *= -0.4
	pupil.position = Vector3(off.x * r * 0.42, off.y * r * 0.42, r * (0.84 - 0.12 * off.length_squared()))
	blink_t -= dt
	if blink_t < -0.12:
		blink_t = randf_range(2.0, 5.0)
	var want := 0.12 if blink_t < 0.0 else 1.0
	scale.y = lerpf(scale.y, want, minf(1.0, dt * 30.0))
