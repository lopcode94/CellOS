extends MeshInstance3D
## Soft-body cell membrane: a ring of Verlet points held by "home" springs (shape memory),
## neighbor distance constraints (the skin) and an inertia term. Anything that hits the
## ring just shoves its points; the springs do the jiggling. The mesh (floor, rim tube,
## see-through jelly dome) is rebuilt from the points every frame.

const N := 48
const SUBSTEPS := 2
const DOME_RINGS := 7
const RIM_SIDES := 8
const LOBES := 3
const LOBE_WIDTH := 0.5

var rest_r := 7.0
var dome_h := 2.6
var pts := PackedVector2Array()
var prev := PackedVector2Array()
var k_home := 70.0
var damping := 0.986
var skin_k := 0.6
var move_dir := Vector2.ZERO
var exploded := false
var deflate := 0.0
var acid := 0.0
var fade := 1.0
## a pressed-in dent (Macrophage Mom latching on): host-local angle + depth in metres
var dent_ang := 0.0
var dent_amt := 0.0
var t := 0.0

var floor_mat: ShaderMaterial
var rim_mat: Material
var dome_mat: ShaderMaterial
var halo_mat: Material
var _mesh := ArrayMesh.new()
var _sdt := 1.0 / 120.0


func setup(radius: float, floor_m: ShaderMaterial, rim_m: Material, dome_m: ShaderMaterial, halo_m: Material = null) -> void:
	rest_r = radius
	floor_mat = floor_m
	rim_mat = rim_m
	dome_mat = dome_m
	halo_mat = halo_m
	pts.resize(N)
	prev.resize(N)
	for i in N:
		var a := TAU * float(i) / N
		pts[i] = Vector2(cos(a), sin(a)) * radius
		prev[i] = pts[i]
	mesh = _mesh
	rebuild()


func dent(angle: float, depth: float) -> void:
	dent_ang = angle
	dent_amt = maxf(dent_amt, depth)


func step(dt: float, host_accel: Vector2) -> void:
	dent_amt = maxf(0.0, dent_amt - dt * 1.5)
	t += dt
	_sdt = dt / SUBSTEPS
	for s in SUBSTEPS:
		_integrate(_sdt, host_accel)
		if not exploded:
			_constrain()
			_constrain()


func _integrate(dt: float, host_accel: Vector2) -> void:
	var r := rest_r * (1.0 - deflate * 0.55)
	var damp := 0.995 if exploded else damping
	# three soft pseudopod lobes that wander around the rim and swell/shrink on their own
	var lobe_ang := PackedFloat32Array()
	var lobe_amp := PackedFloat32Array()
	for k in LOBES:
		var fk := float(k)
		lobe_ang.append(fk * TAU / LOBES + t * (0.07 + 0.03 * fk) + 0.6 * sin(t * (0.11 + 0.05 * fk) + fk * 2.0))
		lobe_amp.append((0.05 + 0.13 * (0.5 + 0.5 * sin(t * (0.45 + 0.17 * fk) + fk * 1.9))) * (1.0 - deflate))
	for i in N:
		var p := pts[i]
		var v := (p - prev[i]) * damp
		var acc := Vector2.ZERO
		if not exploded:
			var a := TAU * float(i) / N
			var dir := Vector2(cos(a), sin(a))
			# breathing + scrolling noise along the perimeter keeps the outline organic
			var wob := 0.03 * sin(t * 1.6 + i * 0.9) + 0.02 * sin(t * 2.7 - i * 1.9)
			wob += 0.035 * sin(a * 3.0 + t * 0.6) + 0.025 * sin(a * 5.0 - t * 0.9 + 1.3) + 0.015 * sin(a * 7.0 + t * 1.3)
			var lobes := 0.0
			for k in LOBES:
				var da := wrapf(a - lobe_ang[k], -PI, PI)
				lobes += lobe_amp[k] * exp(-da * da / (2.0 * LOBE_WIDTH * LOBE_WIDTH))
			var reach := maxf(0.0, dir.dot(move_dir))
			var pod := reach * reach * reach * 0.16
			var home := dir * r * (1.0 + wob + pod + lobes)
			if dent_amt > 0.0:
				var dd := wrapf(a - dent_ang, -PI, PI)
				home -= dir * dent_amt * exp(-dd * dd / 0.25)
			acc = (home - p) * k_home - host_accel * 0.35
		prev[i] = p
		pts[i] = p + v + acc * dt * dt


func _constrain() -> void:
	var rest_len := 2.0 * rest_r * (1.0 - deflate * 0.55) * sin(PI / N)
	for i in N:
		var j := (i + 1) % N
		var d := pts[j] - pts[i]
		var l := d.length()
		if l < 0.0001:
			continue
		var corr := d * ((l - rest_len) / l * 0.5 * skin_k)
		pts[i] += corr
		pts[j] -= corr


## Membrane radius at an angle (host-local), interpolated between the nearest points.
func radius_at(angle: float) -> float:
	var f := wrapf(angle, 0.0, TAU) / TAU * N
	var i0 := int(f) % N
	var i1 := (i0 + 1) % N
	return lerpf(pts[i0].length(), pts[i1].length(), f - floorf(f))


## Kick the membrane near a host-local point. Outward impulse bulges it, inward dents it.
func poke(at: Vector2, impulse: Vector2) -> void:
	var c := wrapf(at.angle(), 0.0, TAU) / TAU * N
	var ci := int(roundf(c))
	for k in range(-3, 4):
		var i := posmod(ci + k, N)
		var w := exp(-float(k * k) / 3.0)
		prev[i] -= impulse * w * _sdt


func explode() -> void:
	exploded = true
	for i in N:
		prev[i] = pts[i] - pts[i].normalized() * randf_range(0.25, 0.55)


func rebuild() -> void:
	_mesh.clear_surfaces()
	if dome_mat:
		dome_mat.set_shader_parameter("acid", acid)
		dome_mat.set_shader_parameter("fade", fade)
	if floor_mat:
		floor_mat.set_shader_parameter("acid", acid)
	if not exploded:
		_build_floor()
		_build_rim()
		if halo_mat:
			# inner glowing refractive halo: the second layer of a thick, double membrane
			_build_rim(0.38, 0.3, 0.115, halo_mat)
	_build_dome()


func _build_floor() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uvs := 0.5 / (rest_r * 1.0)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0.5, 0.5))
	st.add_vertex(Vector3(0.0, 0.04, 0.0))
	for i in N:
		var p := pts[i] * 0.96
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0.5) + p * uvs)
		st.add_vertex(Vector3(p.x, 0.04, p.y))
	for i in N:
		st.add_index(0)
		st.add_index(1 + i)
		st.add_index(1 + (i + 1) % N)
	st.set_material(floor_mat)
	st.commit(_mesh)


func _build_rim(rim_r: float = 0.78, rim_y: float = 0.45, inward: float = 0.0, mat: Material = null) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stride := RIM_SIDES + 1
	# one extra ring and one extra side so the Memphis band's UVs wrap without a seam
	for i in N + 1:
		var p := pts[i % N] * (1.0 - inward)
		var n2 := p.normalized()
		var n3 := Vector3(n2.x, 0.0, n2.y)
		for k in stride:
			var th := TAU * float(k) / RIM_SIDES
			var o := n3 * cos(th) + Vector3.UP * sin(th)
			st.set_normal(o)
			st.set_uv(Vector2(float(i) / N * 16.0, float(k) / RIM_SIDES))
			st.add_vertex(Vector3(p.x, rim_y, p.y) + o * rim_r)
	for i in N:
		for k in RIM_SIDES:
			var a := i * stride + k
			var b := (i + 1) * stride + k
			var c := (i + 1) * stride + k + 1
			var d := i * stride + k + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(a)
			st.add_index(c)
			st.add_index(d)
	st.set_material(mat if mat else rim_mat)
	st.commit(_mesh)


func _build_dome() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := dome_h * (1.0 - deflate * 0.92)
	for k in DOME_RINGS:
		var ph := float(k) / DOME_RINGS * PI * 0.5
		var sc := cos(ph)
		var y := h * sin(ph) + 0.05
		for i in N:
			var p := pts[i] * sc * 1.02
			st.set_uv(Vector2(float(i) / N, float(k) / DOME_RINGS))
			st.add_vertex(Vector3(p.x, y, p.y))
	var top := DOME_RINGS * N
	st.set_uv(Vector2(0.5, 1.0))
	st.add_vertex(Vector3(0.0, h + 0.05, 0.0))
	for k in DOME_RINGS - 1:
		for i in N:
			var i1 := (i + 1) % N
			var a := k * N + i
			var b := k * N + i1
			var c := (k + 1) * N + i1
			var d := (k + 1) * N + i
			st.add_index(d)
			st.add_index(a)
			st.add_index(b)
			st.add_index(d)
			st.add_index(b)
			st.add_index(c)
	var last := (DOME_RINGS - 1) * N
	for i in N:
		st.add_index(top)
		st.add_index(last + i)
		st.add_index(last + (i + 1) % N)
	st.generate_normals()
	st.set_material(dome_mat)
	st.commit(_mesh)


## Smooth 1D value noise in [0, 1] (scrolls along the perimeter for organic wobble).
func _noise1(x: float) -> float:
	var i := floorf(x)
	var f := x - i
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_hash1(i), _hash1(i + 1.0), f)


func _hash1(n: float) -> float:
	var s := sin(n * 127.1 + 311.7) * 43758.5453
	return s - floorf(s)
