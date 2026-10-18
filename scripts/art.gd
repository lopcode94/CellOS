extends RefCounted
## Art kit: shared materials and procedural mesh builders. Every prop in the game is
## assembled from primitives here, so the project needs no imported art at all.
##
## Art direction: Frutiger Aero x postmodern wacky. Liquid-glass soap bubbles, iridescent
## films and squishy translucent jelly. Faces are ink embedded *inside* the gel.

const CLAY := preload("res://shaders/clay.gdshader")
const JELLY := preload("res://shaders/jelly.gdshader")
const GEL := preload("res://shaders/gel_body.gdshader")
const BUBBLE := preload("res://shaders/glass_bubble.gdshader")

## Faces point here (toward the camera) so expressions always read from above.
const FACE_DIR := Vector3(0.0, 0.844, 0.537)
const INK := Color("1d0b2b")

static var _mats := {}
static var _meshes := {}


## Legacy name kept so every prop converts in one place: "clay" now means jelly.
## An emissive color becomes the jelly's glowing core.
static func clay(color: Color, _rough: float = 0.72, _boil: float = 0.02, emit: Color = Color.BLACK, emit_energy: float = 0.0, _rim: float = 0.22) -> ShaderMaterial:
	var core := emit if emit_energy > 0.0 else color.lightened(0.45)
	return gel(color, core, 0.35 + emit_energy * 0.8)


## Translucent jelly body (see shaders/gel_body.gdshader).
static func gel(color: Color, core: Color = Color(1, 1, 1, 0), glow: float = 0.35, density: float = 1.2, wobble: float = 0.02) -> ShaderMaterial:
	var c := core if core.a > 0.0 else color.lightened(0.45)
	var key := "gel|%s|%s|%.2f|%.2f|%.3f" % [color.to_html(), c.to_html(), glow, density, wobble]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = GEL
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("core_color", c)
	m.set_shader_parameter("core_glow", glow)
	m.set_shader_parameter("density", density)
	m.set_shader_parameter("wobble", wobble)
	_mats[key] = m
	return m


## Liquid-glass / soap-bubble shell (see shaders/glass_bubble.gdshader).
## refraction 0 = alpha film, > 0 = solid refracting lens.
static func bubble(tint: Color, refraction: float = 0.0, film: float = 1.0, base_alpha: float = 0.05, rim_alpha: float = 0.75, wobble: float = 0.0) -> ShaderMaterial:
	var key := "bub|%s|%.3f|%.2f|%.2f|%.2f|%.3f" % [tint.to_html(), refraction, film, base_alpha, rim_alpha, wobble]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = BUBBLE
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("refraction", refraction)
	m.set_shader_parameter("film_strength", film)
	m.set_shader_parameter("base_alpha", base_alpha)
	m.set_shader_parameter("rim_alpha", rim_alpha)
	m.set_shader_parameter("wobble", wobble)
	_mats[key] = m
	return m


## Glossy dark "ink" for expressions embedded inside gel bodies.
static func ink(color: Color = Color("2a0a22")) -> StandardMaterial3D:
	var key := "ink|" + color.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.12
	m.metallic_specular = 0.8
	m.clearcoat_enabled = true
	m.clearcoat = 0.6
	_mats[key] = m
	return m


## Tiny emissive catch-light for eyes.
static func glint() -> StandardMaterial3D:
	if _mats.has("glint"):
		return _mats["glint"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.WHITE
	_mats["glint"] = m
	return m


static func jelly(tint: Color, base_alpha: float = 0.1, rim_alpha: float = 0.8) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = JELLY
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("base_alpha", base_alpha)
	m.set_shader_parameter("rim_alpha", rim_alpha)
	return m


## Canister glass: a refracting liquid-glass lens with a hint of mint.
static func glass() -> ShaderMaterial:
	return bubble(Color("dfffe8"), 0.035, 0.7)


static func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "glow|%s|%.2f" % [color.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	_mats[key] = m
	return m


static func metal() -> StandardMaterial3D:
	if _mats.has("metal"):
		return _mats["metal"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("c9c6dd")
	m.metallic = 0.85
	m.roughness = 0.3
	_mats["metal"] = m
	return m


static func pupil_mat() -> StandardMaterial3D:
	if _mats.has("pupil"):
		return _mats["pupil"]
	var m := StandardMaterial3D.new()
	m.albedo_color = INK
	m.roughness = 0.12
	m.metallic_specular = 0.9
	_mats["pupil"] = m
	return m


static func sphere_mesh(r: float, segs: int = 24) -> SphereMesh:
	var key := "sphere|%.3f|%d" % [r, segs]
	if _meshes.has(key):
		return _meshes[key]
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segs
	m.rings = maxi(4, segs / 2)
	_meshes[key] = m
	return m


static func box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func cyl_mesh(r_top: float, r_bot: float, h: float, segs: int = 20) -> CylinderMesh:
	var key := "cyl|%.3f|%.3f|%.3f|%d" % [r_top, r_bot, h, segs]
	if _meshes.has(key):
		return _meshes[key]
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	_meshes[key] = m
	return m


static func add(parent: Node, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	if mat is ShaderMaterial and ((mat as ShaderMaterial).shader == GEL or (mat as ShaderMaterial).shader == BUBBLE):
		mi.set_instance_shader_parameter("seed", randf() * 10.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func ball(parent: Node, r: float, mat: Material, pos: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	return add(parent, sphere_mesh(r), mat, pos, scl)


## A smooth tube along a polyline, with parallel-transport frames so it never twists.
static func tube_mesh(points: PackedVector3Array, radius: float, sides: int = 10, taper: float = 0.0) -> ArrayMesh:
	var n := points.size()
	if n < 2:
		return ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t0 := (points[1] - points[0]).normalized()
	var nrm := t0.cross(Vector3.UP)
	if nrm.length() < 0.01:
		nrm = t0.cross(Vector3.RIGHT)
	nrm = nrm.normalized()
	for i in n:
		var tg: Vector3
		if i == 0:
			tg = points[1] - points[0]
		elif i == n - 1:
			tg = points[n - 1] - points[n - 2]
		else:
			tg = points[i + 1] - points[i - 1]
		tg = tg.normalized()
		nrm = (nrm - tg * nrm.dot(tg)).normalized()
		var bin := tg.cross(nrm)
		var rr := radius * (1.0 - taper * float(i) / float(n - 1))
		for k in sides:
			var a := TAU * float(k) / float(sides)
			var o := nrm * cos(a) + bin * sin(a)
			st.set_normal(o)
			st.set_uv(Vector2(float(k) / sides, float(i) / (n - 1)))
			st.add_vertex(points[i] + o * rr)
	for i in n - 1:
		for k in sides:
			var k1 := (k + 1) % sides
			var a := i * sides + k
			var b := (i + 1) * sides + k
			var c := (i + 1) * sides + k1
			var d := i * sides + k1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(a)
			st.add_index(c)
			st.add_index(d)
	return st.commit()


## Orientation of a face plane: +Z toward the camera, +Y up on screen.
static func face_basis() -> Basis:
	return Basis(Vector3.RIGHT, FACE_DIR.cross(Vector3.RIGHT), FACE_DIR)


## Embeds an expression *inside* a gel body: glossy ink marks just under the surface,
## refracted by the jelly around them. No stuck-on googly eyes. Returns [] (nothing to aim).
static func face(parent: Node3D, body_r: float, mood: String, s: float = 1.0, center: Vector3 = Vector3.ZERO, surface: float = 0.93) -> Array:
	var f := Node3D.new()
	f.basis = face_basis()
	f.position = center + FACE_DIR * body_r * surface
	parent.add_child(f)
	var ink_m := ink()
	var gap := 0.24 * s
	var ey := 0.08 * s
	match mood:
		"happy":
			# closed, content "^ ^" eyes like the reference jelly bean
			for side in [-1.0, 1.0]:
				var arc := PackedVector3Array()
				for i in 9:
					var a := PI * float(i) / 8.0
					arc.append(Vector3(side * gap + cos(a) * 0.085 * s, ey + sin(a) * 0.065 * s - 0.03 * s, 0.0))
				add(f, tube_mesh(arc, 0.026 * s, 6), ink_m)
				ball(f, 1.0, ink(Color("ff6fae")), Vector3(side * gap * 1.45, -0.06 * s, -0.01 * s), Vector3(0.07, 0.04, 0.015) * s)
			ball(f, 1.0, ink_m, Vector3(0.0, -0.13 * s, 0.0), Vector3(0.11, 0.075, 0.03) * s)
			ball(f, 1.0, ink(Color("ff5a7a")), Vector3(0.0, -0.165 * s, 0.012 * s), Vector3(0.06, 0.03, 0.02) * s)
		"stressed":
			_stressed_face(f, s)
		"angry":
			for side in [-1.0, 1.0]:
				var e := ball(f, 1.0, ink_m, Vector3(side * gap, ey, 0.0), Vector3(0.075, 0.045, 0.025) * s)
				e.rotation.z = side * 0.35
				ball(f, 1.0, glint(), Vector3(side * gap - 0.02 * s, ey + 0.015 * s, 0.02 * s), Vector3.ONE * 0.016 * s)
				var brow := PackedVector3Array([Vector3(side * gap * 1.5, ey + 0.13 * s, 0.0), Vector3(side * gap * 0.35, ey + 0.07 * s, 0.0)])
				add(f, tube_mesh(brow, 0.024 * s, 6), ink_m)
			var zig := PackedVector3Array()
			for i in 7:
				zig.append(Vector3((-0.13 + i * 0.043) * s, (-0.17 + (0.025 if i % 2 == 0 else -0.025)) * s, 0.0))
			add(f, tube_mesh(zig, 0.022 * s, 6), ink_m)
		"smug":
			for side in [-1.0, 1.0]:
				ball(f, 1.0, ink_m, Vector3(side * gap, ey, 0.0), Vector3(0.075, 0.028, 0.02) * s)
				var lid := PackedVector3Array([Vector3(side * gap - 0.09 * s, ey + 0.04 * s, 0.0), Vector3(side * gap + 0.09 * s, ey + 0.05 * s, 0.0)])
				add(f, tube_mesh(lid, 0.018 * s, 6), ink_m)
			var smirk := PackedVector3Array()
			for i in 7:
				var u := float(i) / 6.0
				smirk.append(Vector3((-0.12 + u * 0.26) * s, (-0.16 + u * u * 0.06) * s, 0.0))
			add(f, tube_mesh(smirk, 0.022 * s, 6), ink_m)
		"worried":
			for side in [-1.0, 1.0]:
				ball(f, 1.0, ink_m, Vector3(side * gap, ey, 0.0), Vector3(0.055, 0.07, 0.025) * s)
				ball(f, 1.0, glint(), Vector3(side * gap - 0.015 * s, ey + 0.025 * s, 0.02 * s), Vector3.ONE * 0.016 * s)
			var wav := PackedVector3Array()
			for i in 7:
				wav.append(Vector3((-0.12 + i * 0.04) * s, (-0.16 + sin(i * 1.6) * 0.02) * s, 0.0))
			add(f, tube_mesh(wav, 0.02 * s, 6), ink_m)
	return []


## Mito's signature look from the turnaround: mismatched glowing-yellow eyes in dark
## purple rings with lashes, tiny panicked pupils, worried brows, gaping "o" mouth with
## one buck tooth. Bold outlines so it reads instantly at play distance.
static func _stressed_face(f: Node3D, s: float) -> void:
	var ring := ink(Color("3a1060"))
	var sclera := glow(Color("ffd51a"), 0.3)
	var dark := ink()
	var gap := 0.25 * s
	for side in [-1.0, 1.0]:
		var k: float = 0.85 if side < 0.0 else 1.18
		var ex: float = side * gap * (1.0 if side < 0.0 else 1.12)
		var ey: float = 0.07 * s + (0.0 if side < 0.0 else 0.035 * s)
		ball(f, 1.0, ring, Vector3(ex, ey, -0.006 * s), Vector3(0.155, 0.155, 0.03) * s * k)
		ball(f, 1.0, sclera, Vector3(ex, ey, 0.0), Vector3(0.12, 0.12, 0.035) * s * k)
		ball(f, 1.0, dark, Vector3(ex + side * 0.012 * s, ey - 0.012 * s, 0.03 * s), Vector3(0.034, 0.034, 0.02) * s * k)
		ball(f, 1.0, glint(), Vector3(ex - 0.045 * s * k, ey + 0.045 * s * k, 0.035 * s), Vector3.ONE * 0.016 * s)
		for j in 3:
			var a := PI * (0.62 + 0.13 * j) if side < 0.0 else PI * (0.38 - 0.13 * j)
			var root := Vector3(ex + cos(a) * 0.15 * s * k, ey + sin(a) * 0.15 * s * k, 0.0)
			var tip := root + Vector3(cos(a) * 0.07, sin(a) * 0.08 + 0.02, 0.0) * s
			add(f, tube_mesh(PackedVector3Array([root, root.lerp(tip, 0.5) + Vector3(0.0, 0.012 * s, 0.0), tip]), 0.011 * s, 5, 0.6), dark)
		var brow := PackedVector3Array([
			Vector3(ex + side * 0.13 * s * k, ey + 0.2 * s * k, 0.0),
			Vector3(ex - side * 0.02 * s, ey + 0.26 * s * k, 0.0),
			Vector3(ex - side * 0.12 * s * k, ey + 0.29 * s * k, 0.0)])
		add(f, tube_mesh(brow, 0.022 * s, 6), dark)
	ball(f, 1.0, dark, Vector3(0.02 * s, -0.2 * s, 0.0), Vector3(0.085, 0.07, 0.03) * s)
	ball(f, 1.0, ink(Color("ff5a7a")), Vector3(0.03 * s, -0.235 * s, 0.018 * s), Vector3(0.05, 0.025, 0.015) * s)
	ball(f, 1.0, glint(), Vector3(-0.025 * s, -0.15 * s, 0.025 * s), Vector3(0.018, 0.022, 0.01) * s)
