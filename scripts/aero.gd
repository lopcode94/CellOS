extends RefCounted
## "Cell OS" widget kit: Frutiger Aero / Vista glass meets retro toybox.
## Frosted acrylic panels, Web 2.0 jelly buttons, liquid orb + test-tube gauges,
## a 7-segment LCD, oscilloscope graphs and hand-drawn organelle icons.

const GLASS_SH := preload("res://shaders/ui_glass.gdshader")
const GEL_SH := preload("res://shaders/ui_gel.gdshader")
const ORB_SH := preload("res://shaders/ui_orb.gdshader")
const TUBE_SH := preload("res://shaders/ui_tube.gdshader")
const GLOSS_SH := preload("res://shaders/ui_gloss_text.gdshader")

const LCD_GREEN := Color("5dff7a")
const SHADOW := Color(0.0, 0.12, 0.28, 0.6)


static func label_settings(font: Font, size: int, color: Color, glow: Color = SHADOW, glow_size: int = 6) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = color
	ls.shadow_color = glow
	ls.shadow_size = glow_size
	ls.shadow_offset = Vector2(0, 2)
	return ls


static func label(text: String, ls: LabelSettings, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = ls
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Glossy two-tone headline: a glow label behind a gradient-shaded label.
static func gloss_title(text: String, font: Font, size: int, top: Color, bottom: Color, glow: Color) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := label(text, label_settings(font, size, bottom.darkened(0.5), glow, 14))
	var front := label(text, label_settings(font, size, Color.WHITE, Color(0, 0, 0, 0), 0))
	var m := ShaderMaterial.new()
	m.shader = GLOSS_SH
	m.set_shader_parameter("top_col", top)
	m.set_shader_parameter("bottom_col", bottom)
	front.material = m
	var ms := front.get_minimum_size()
	m.set_shader_parameter("height", ms.y)
	holder.custom_minimum_size = ms
	for l in [back, front]:
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(l)
	return holder


static func shadow_box(radius: int, size: int = 22, alpha: float = 0.45) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0.0, 0.05, 0.14, alpha)
	sb.shadow_size = size
	sb.shadow_offset = Vector2(0, 8)
	return sb


## Frosted acrylic rectangle. Fills its parent when used inside a container.
class GlassRect extends ColorRect:
	var mat: ShaderMaterial

	## `radius` 0 = flat full-screen frost (no rim, no wobble); otherwise a lopsided pomo blob.
	func _init(tint: Color = Color(0.72, 0.9, 1.0, 0.22), radius: float = 18.0, blur: float = 3.0, dark: float = 0.0, _titlebar: float = 0.0) -> void:
		mat = ShaderMaterial.new()
		mat.shader = GLASS_SH
		mat.set_shader_parameter("tint", tint)
		mat.set_shader_parameter("blur_lod", blur)
		mat.set_shader_parameter("dark", dark)
		if radius <= 0.0:
			mat.set_shader_parameter("radii", Vector4.ZERO)
			mat.set_shader_parameter("wobble", 0.0)
			mat.set_shader_parameter("rim_w", 0.0)
			mat.set_shader_parameter("pattern", 0.0)
		else:
			var k := randf_range(0.85, 1.15)
			mat.set_shader_parameter("radii", Vector4(radius * 1.8 * k, radius * 0.55, radius * 2.1 / k, radius * 0.8))
			mat.set_shader_parameter("seed", randf() * 10.0)
		material = mat
		color = Color.WHITE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(_sync)

	## Candy rim colors (three-stop loop around the perimeter).
	func rims(a: Color, b: Color, c: Color, width: float = 5.0) -> GlassRect:
		mat.set_shader_parameter("rim_a", a)
		mat.set_shader_parameter("rim_b", b)
		mat.set_shader_parameter("rim_c", c)
		mat.set_shader_parameter("rim_w", width)
		return self

	func corners(tl: float, tr: float, br: float, bl: float) -> GlassRect:
		mat.set_shader_parameter("radii", Vector4(tl, tr, br, bl))
		return self

	## Gooey silhouette: shrink the body by `inset` px, then smooth-union two bumps
	## (uv x, uv y, radius px) and carve one scalloped bite. z = 0 disables a shape.
	func blob(inset: float, lobe1: Vector3, lobe2: Vector3 = Vector3.ZERO, bite: Vector3 = Vector3.ZERO) -> GlassRect:
		mat.set_shader_parameter("inset", inset)
		mat.set_shader_parameter("lobe1", lobe1)
		mat.set_shader_parameter("lobe2", lobe2)
		mat.set_shader_parameter("bite", bite)
		return self

	func _sync() -> void:
		mat.set_shader_parameter("rect_size", size)


## Web 2.0 jelly button. Sinks 3px and dims its crescent when pressed.
class JellyButton extends Control:
	signal tapped

	var bg: ColorRect
	var text_label: Label
	var mat: ShaderMaterial
	var base := Color.ORANGE
	var enabled := true
	var attention := false
	var interactive := true
	var radius := 22.0
	var _down := false
	var _hover := false
	var _vis := 0.0
	var _hold := 0.0
	var _jig := 0.0
	var _radii := Vector4.ONE

	func _init(text: String, color: Color, min_size: Vector2, r: float, ls: LabelSettings, clickable: bool = true) -> void:
		base = color
		radius = r
		interactive = clickable
		custom_minimum_size = min_size
		size = min_size
		mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
		bg = ColorRect.new()
		mat = ShaderMaterial.new()
		mat.shader = GEL_SH
		mat.set_shader_parameter("base", color)
		var k := randf_range(0.8, 1.2)
		_radii = Vector4(r * 1.7 * k, r * 0.3, r * 1.8 / k, r * 0.4)
		mat.set_shader_parameter("radii", _radii)
		mat.set_shader_parameter("seed", randf() * 10.0)
		bg.material = mat
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		text_label = Aero_label(text, ls)
		add_child(text_label)
		resized.connect(_sync)
		mouse_entered.connect(func(): _hover = true)
		mouse_exited.connect(_on_exit)
		_sync()

	static func Aero_label(text: String, ls: LabelSettings) -> Label:
		var l := Label.new()
		l.text = text
		l.label_settings = ls
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return l

	func _on_exit() -> void:
		_hover = false
		_down = false

	func _sync() -> void:
		bg.size = size
		text_label.size = size
		mat.set_shader_parameter("rect_size", size)
		queue_redraw()

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.0, 0.08, 0.16, 0.25)
		var cap := size.y * 0.5
		sb.corner_radius_top_left = int(minf(_radii.x, cap))
		sb.corner_radius_top_right = int(minf(_radii.y, cap))
		sb.corner_radius_bottom_right = int(minf(_radii.z, cap))
		sb.corner_radius_bottom_left = int(minf(_radii.w, cap))
		sb.shadow_color = Color(0.0, 0.05, 0.12, 0.3)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 4)
		draw_style_box(sb, Rect2(Vector2(3, 5), size - Vector2(6, 4)))

	func _gui_input(e: InputEvent) -> void:
		if not interactive or not enabled:
			return
		if e is InputEventMouseButton:
			var mb := e as InputEventMouseButton
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			if mb.pressed:
				_down = true
			elif _down:
				_down = false
				if Rect2(Vector2.ZERO, size).has_point(mb.position):
					_jig = 1.0
					tapped.emit()
			accept_event()

	func flash_press() -> void:
		_hold = 0.14
		_jig = 1.0

	func set_text(t: String) -> void:
		text_label.text = t

	func set_color(c: Color) -> void:
		base = c
		mat.set_shader_parameter("base", c)

	func _process(dt: float) -> void:
		if bg.size != size:
			_sync()
		_hold = maxf(0.0, _hold - dt)
		var down := (_down or _hold > 0.0) and enabled
		_vis = move_toward(_vis, 1.0 if down else 0.0, dt * 14.0)
		var off := 3.0 * _vis
		bg.position = Vector2(0.0, off)
		text_label.position = Vector2(0.0, off)
		mat.set_shader_parameter("pressed", _vis)
		_jig = maxf(0.0, _jig - dt * 2.2)
		mat.set_shader_parameter("jiggle", _jig * _jig)
		mat.set_shader_parameter("hover", 1.0 if _hover and enabled else 0.0)
		mat.set_shader_parameter("disabled", 0.0 if enabled else 1.0)
		mat.set_shader_parameter("pulse", (0.5 + 0.5 * sin(Time.get_ticks_msec() / 110.0)) if attention else 0.0)
		text_label.modulate.a = 1.0 if enabled else 0.55


## Glass sphere with sloshing liquid. Value text sits inside, caption below.
class Orb extends Control:
	var rect: ColorRect
	var mat: ShaderMaterial
	var value_label: Label
	var caption: Label
	var diam := 80.0
	var target := 0.0
	var _fill := 0.0
	var _vel := 0.0

	func _init(d: float, liquid: Color, caption_text: String, value_ls: LabelSettings, cap_ls: LabelSettings) -> void:
		diam = d
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(d, d + (20.0 if caption_text != "" else 0.0))
		size = custom_minimum_size
		rect = ColorRect.new()
		rect.size = Vector2(d, d)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mat = ShaderMaterial.new()
		mat.shader = ORB_SH
		mat.set_shader_parameter("liquid", liquid)
		rect.material = mat
		add_child(rect)
		value_label = JellyButton.Aero_label("", value_ls)
		value_label.size = Vector2(d, d)
		add_child(value_label)
		caption = JellyButton.Aero_label(caption_text, cap_ls)
		caption.position = Vector2(-30.0, d)
		caption.size = Vector2(d + 60.0, 20.0)
		add_child(caption)

	func set_value(f: float, text: String, alarm: float = 0.0) -> void:
		target = clampf(f, 0.0, 1.0)
		value_label.text = text
		mat.set_shader_parameter("alarm", alarm)

	func set_rim(c: Color) -> Orb:
		mat.set_shader_parameter("rim_col", c)
		return self

	func set_liquid(c: Color) -> void:
		mat.set_shader_parameter("liquid", c)

	func _process(dt: float) -> void:
		_vel += (target - _fill) * 40.0 * dt
		_vel *= exp(-6.0 * dt)
		_fill += _vel * dt
		mat.set_shader_parameter("fill", clampf(_fill, 0.0, 1.0))
		mat.set_shader_parameter("slosh", clampf(absf(_vel) * 4.0, 0.0, 3.0))


## Horizontal glass test tube full of fizzy liquid, with an etched sweet zone.
class Tube extends Control:
	var rect: ColorRect
	var mat: ShaderMaterial
	var target := 0.5
	var _fill := 0.5
	var _vel := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect = ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mat = ShaderMaterial.new()
		mat.shader = TUBE_SH
		rect.material = mat
		add_child(rect)
		resized.connect(func():
			rect.size = size
			mat.set_shader_parameter("rect_size", size))

	func set_fill(f: float, c: Color) -> void:
		target = clampf(f, 0.0, 1.0)
		mat.set_shader_parameter("liquid", c)

	func set_zone(lo: float, hi: float) -> void:
		mat.set_shader_parameter("zone_lo", lo)
		mat.set_shader_parameter("zone_hi", hi)

	func _process(dt: float) -> void:
		_vel += (target - _fill) * 30.0 * dt
		_vel *= exp(-5.0 * dt)
		_fill += _vel * dt
		mat.set_shader_parameter("fill", clampf(_fill, 0.0, 1.0))
		mat.set_shader_parameter("slosh", clampf(absf(_vel) * 3.0, 0.0, 2.0))


## Smoked-glass oscilloscope with a glowing trace and a filled area.
class Graph extends Control:
	var title := ""
	var color := Color.GREEN
	var data := PackedFloat32Array()
	var font: Font
	var max_v := 100.0
	var readout := ""

	func _init(t: String, c: Color, f: Font) -> void:
		title = t
		color = c
		font = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func push(v: float, cap: int = 60) -> void:
		data.append(v)
		if data.size() > cap:
			data.remove_at(0)
		queue_redraw()

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.01, 0.09, 0.13, 0.66)
		sb.border_color = color.lightened(0.2)
		sb.set_border_width_all(3)
		sb.corner_radius_top_left = 22
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_right = 26
		sb.corner_radius_bottom_left = 10
		sb.skew = Vector2(-0.04, 0.0)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var plot := Rect2(Vector2(28.0, 22.0), size - Vector2(36.0, 30.0))
		var grid := Color(0.55, 1.0, 0.95, 0.13)
		for i in 5:
			var y := plot.position.y + plot.size.y * i / 4.0
			draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), grid, 1.0)
		for i in 7:
			var x := plot.position.x + plot.size.x * i / 6.0
			draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), grid, 1.0)
		for k in [0, 50, 100]:
			var y: float = plot.end.y - plot.size.y * k / 100.0
			draw_string(font, Vector2(2.0, y + 4.0), str(k), HORIZONTAL_ALIGNMENT_RIGHT, 22.0, 10, Color(0.7, 0.95, 1.0, 0.7))
		draw_string(font, Vector2(10.0, 16.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		draw_string(font, Vector2(size.x - 70.0, 16.0), readout, HORIZONTAL_ALIGNMENT_RIGHT, 60.0, 13, color)
		if data.size() >= 2 and data[data.size() - 1] >= 0.0:
			var n := data.size()
			var pts := PackedVector2Array()
			for i in n:
				pts.append(Vector2(plot.position.x + plot.size.x * i / float(n - 1), plot.end.y - plot.size.y * clampf(data[i] / max_v, 0.0, 1.0)))
			# gradient fill under the trace, one quad per segment (never degenerate)
			var base_y := plot.end.y + 1.0
			var fade := Color(color, 0.04)
			for i in n - 1:
				var a := pts[i]
				var b := pts[i + 1]
				if base_y - a.y < 1.5 and base_y - b.y < 1.5:
					continue
				var ka := Color(color, 0.05 + 0.32 * (1.0 - (a.y - plot.position.y) / plot.size.y))
				var kb := Color(color, 0.05 + 0.32 * (1.0 - (b.y - plot.position.y) / plot.size.y))
				draw_polygon(PackedVector2Array([a, b, Vector2(b.x, base_y), Vector2(a.x, base_y)]), PackedColorArray([ka, kb, fade, fade]))
			draw_polyline(pts, Color(color, 0.25), 6.0, true)
			draw_polyline(pts, color.lightened(0.3), 2.0, true)
			draw_circle(pts[n - 1], 4.0, Color.WHITE)
			draw_circle(pts[n - 1], 7.0, Color(color, 0.3))
		var gloss := PackedVector2Array([Vector2(1, 1), Vector2(size.x - 1, 1), Vector2(size.x - 1, size.y * 0.35), Vector2(1, size.y * 0.35)])
		draw_polygon(gloss, PackedColorArray([Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))


## Backlit green LCD: 7-segment run clock, generation counter, fuel equalizer.
class Lcd extends Control:
	const SEGS := {
		"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
		"5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
	}
	var seconds := 0
	var gen := 1
	var fuel := 0.0
	var line := ""
	var font: Font

	func _init(f: Font) -> void:
		font = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.01, 0.07, 0.035, 0.88)
		sb.border_color = Color("9dff2e")
		sb.set_border_width_all(3)
		sb.corner_radius_top_left = 22
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_right = 26
		sb.corner_radius_bottom_left = 10
		sb.skew = Vector2(-0.04, 0.0)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var on := Aero_lcd()
		var ghost := Color(on, 0.07)
		var clock := "%02d%02d" % [mini(seconds / 60, 99), seconds % 60]
		var x := 12.0
		for i in 4:
			if i == 2:
				for cy in [0.33, 0.7]:
					draw_rect(Rect2(x - 1.0, 12.0 + 40.0 * cy - 2.5, 5.0, 5.0), on)
				x += 10.0
			_digit(x, 12.0, 22.0, 40.0, 5.0, "8", ghost, false)
			_digit(x, 12.0, 22.0, 40.0, 5.0, clock[i], on, true)
			x += 30.0
		var gx := size.x - 54.0
		draw_line(Vector2(gx - 12.0, 10.0), Vector2(gx - 12.0, 54.0), Color(on, 0.18), 1.0)
		draw_string(font, Vector2(gx, 20.0), "GEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(on, 0.8))
		var g := "%02d" % mini(gen, 99)
		for i in 2:
			_digit(gx + i * 20.0, 28.0, 13.0, 24.0, 3.5, "8", ghost, false)
			_digit(gx + i * 20.0, 28.0, 13.0, 24.0, 3.5, g[i], on, true)
		var bars := 14
		var lit := int(round(clampf(fuel / 6.0, 0.0, 1.0) * bars))
		var bw := (size.x - 52.0 - 112.0) / bars
		draw_string(font, Vector2(12.0, size.y - 12.0), "FUEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(on, 0.8))
		for i in bars:
			var h := 6.0 + 8.0 * float(i) / bars
			var c := on if i < lit else ghost
			if i < lit and i < 3:
				c = Color("ffd23d")
			draw_rect(Rect2(52.0 + i * bw, size.y - 10.0 - h, bw - 2.0, h), c)
		if line != "":
			draw_string(font, Vector2(size.x - 110.0, size.y - 12.0), line, HORIZONTAL_ALIGNMENT_RIGHT, 98.0, 11, Color(on, 0.85))

	static func Aero_lcd() -> Color:
		return Color("5dff7a")

	func _digit(x: float, y: float, w: float, h: float, t: float, ch: String, col: Color, glow: bool) -> void:
		var segs: String = SEGS.get(ch, "")
		var hh := h * 0.5
		for s in segs:
			var poly: PackedVector2Array
			match s:
				"a": poly = _hseg(x, x + w, y, t)
				"g": poly = _hseg(x, x + w, y + hh, t)
				"d": poly = _hseg(x, x + w, y + h, t)
				"f": poly = _vseg(x, y, y + hh, t)
				"b": poly = _vseg(x + w, y, y + hh, t)
				"e": poly = _vseg(x, y + hh, y + h, t)
				"c": poly = _vseg(x + w, y + hh, y + h, t)
			for i in poly.size():
				var q := poly[i]
				q.x += (y + hh - q.y) * 0.12
				poly[i] = q
			if glow:
				var big := PackedVector2Array()
				var ctr := Vector2.ZERO
				for p in poly:
					ctr += p
				ctr /= poly.size()
				for p in poly:
					big.append(ctr + (p - ctr) * 1.6)
				draw_colored_polygon(big, Color(col, 0.18))
			draw_colored_polygon(poly, col)

	func _hseg(x0: float, x1: float, y: float, t: float) -> PackedVector2Array:
		var a := x0 + t * 0.7
		var b := x1 - t * 0.7
		var ht := t * 0.5
		return PackedVector2Array([Vector2(a, y), Vector2(a + ht, y - ht), Vector2(b - ht, y - ht), Vector2(b, y), Vector2(b - ht, y + ht), Vector2(a + ht, y + ht)])

	func _vseg(x: float, y0: float, y1: float, t: float) -> PackedVector2Array:
		var a := y0 + t * 0.7
		var b := y1 - t * 0.7
		var ht := t * 0.5
		return PackedVector2Array([Vector2(x, a), Vector2(x + ht, a + ht), Vector2(x + ht, b - ht), Vector2(x, b), Vector2(x - ht, b - ht), Vector2(x - ht, a + ht)])


## Little clay-toy icons drawn in 2D (mitochondrion, virus, free radical, mtDNA, alert).
class IconArt extends Control:
	var kind := "mito"
	var tint := Color.WHITE

	func _init(k: String, s: float, c: Color = Color.WHITE) -> void:
		kind = k
		tint = c
		custom_minimum_size = Vector2(s, s)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var s := minf(size.x, size.y)
		var ink := Color("1d0b2b")
		match kind:
			"mito":
				var body := Rect2(c - Vector2(s * 0.42, s * 0.22), Vector2(s * 0.84, s * 0.44))
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color("ff8a2b")
				sb.border_color = ink
				sb.set_border_width_all(2)
				sb.set_corner_radius_all(int(s * 0.22))
				draw_style_box(sb, body)
				var zz := PackedVector2Array()
				for i in 7:
					zz.append(Vector2(body.position.x + s * 0.12 + i * s * 0.08, c.y - s * 0.08 + (s * 0.07 if i % 2 == 0 else -s * 0.03)))
				draw_polyline(zz, Color("9b4fe0"), maxf(2.0, s * 0.06), true)
				for ex in [0.12, 0.27]:
					draw_circle(c + Vector2(s * ex, s * 0.02), s * 0.08, Color.WHITE)
					draw_circle(c + Vector2(s * ex + s * 0.02, s * 0.03), s * 0.04, ink)
			"virus", "radical":
				var body_col := Color("7a2a78") if kind == "virus" else Color("ff4a2a")
				var tip := Color("ff5aa0") if kind == "virus" else Color("ffb02e")
				var rr := s * (0.3 if kind == "virus" else 0.26)
				var n := 10 if kind == "virus" else 8
				for i in n:
					var d := Vector2.from_angle(TAU * i / n + 0.2)
					draw_line(c + d * rr, c + d * rr * 1.45, body_col.darkened(0.2), maxf(2.0, s * 0.06))
					draw_circle(c + d * rr * 1.5, s * 0.06, tip)
				draw_circle(c, rr, body_col)
				draw_arc(c, rr, 0.0, TAU, 32, ink, 2.0, true)
				for ex in [-1.0, 1.0]:
					var e := c + Vector2(ex * rr * 0.38, -rr * 0.1)
					draw_circle(e, rr * 0.24, Color.WHITE)
					draw_circle(e + Vector2(0, rr * 0.05), rr * 0.11, ink)
					draw_line(e + Vector2(-ex * rr * 0.3, -rr * 0.42), e + Vector2(ex * rr * 0.25, -rr * 0.24), ink, 2.0)
			"dna":
				for i in 12:
					var u := float(i) / 11.0
					var y := c.y - s * 0.4 + u * s * 0.8
					var w := sin(u * TAU * 1.2) * s * 0.26
					draw_line(Vector2(c.x - w, y), Vector2(c.x + w, y), Color(1, 1, 1, 0.6), 2.0)
					draw_circle(Vector2(c.x - w, y), s * 0.06, Color("39c8ff"))
					draw_circle(Vector2(c.x + w, y), s * 0.06, Color("ff5ad1"))
			"alert":
				draw_string(ThemeDB.fallback_font, c + Vector2(-s * 0.13, s * 0.28), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.8), tint)


## Aero joystick: frosted ring + gel knob.
class Joystick extends Control:
	var active := false
	var origin := Vector2.ZERO
	var vec := Vector2.ZERO

	func _draw() -> void:
		if not active:
			return
		draw_circle(origin, 92.0, Color(0.7, 0.92, 1.0, 0.13))
		draw_arc(origin, 92.0, 0.0, TAU, 64, Color(1, 1, 1, 0.55), 2.0, true)
		draw_arc(origin, 60.0, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 1.0, true)
		var k := origin + vec * 90.0
		draw_circle(k + Vector2(0, 5), 38.0, Color(0, 0.05, 0.15, 0.25))
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 40:
			var p := k + Vector2.from_angle(TAU * i / 40.0) * 36.0
			pts.append(p)
			cols.append(Color("8fe4ff").lerp(Color("0f6fd6"), (p.y - (k.y - 36.0)) / 72.0))
		draw_polygon(pts, cols)
		var hl := PackedVector2Array()
		var hc := PackedColorArray()
		for i in 24:
			var p := k + Vector2(cos(PI + PI * i / 23.0) * 26.0, -4.0 + sin(PI + PI * i / 23.0) * 24.0)
			hl.append(p)
			hc.append(Color(1, 1, 1, 0.55))
		draw_polygon(hl, hc)
		draw_arc(k, 36.0, 0.0, TAU, 40, Color(1, 1, 1, 0.6), 1.5, true)


## Memphis confetti: squiggles, triangles, donuts, dot grids, zig-zags and bolts that
## bob and spin around the glass. Purely decorative, never blocks input.
class Deco extends Control:
	var kind := "squiggle"
	var col := Color.WHITE
	var col2 := Color.WHITE
	var spin := 0.0
	var _t := 0.0
	var _base_rot := 0.0

	func _init(k: String, s: float, c: Color, c2: Color = Color.WHITE, rot: float = 0.0, spin_speed: float = 0.0) -> void:
		kind = k
		col = c
		col2 = c2
		spin = spin_speed
		_base_rot = rot
		_t = randf() * 10.0
		custom_minimum_size = Vector2(s, s)
		size = custom_minimum_size
		pivot_offset = size * 0.5
		rotation = rot
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		_t += dt
		rotation = _base_rot + (_t * spin if spin != 0.0 else sin(_t * 1.3) * 0.12)
		position.y += sin(_t * 2.0) * 0.12

	func _draw() -> void:
		var s := size.x
		var c := size * 0.5
		var ink := Color("1d0b2b")
		var w := maxf(3.0, s * 0.12)
		match kind:
			"squiggle":
				var pts := PackedVector2Array()
				for i in 17:
					var u := float(i) / 16.0
					pts.append(Vector2(u * s, c.y + sin(u * TAU * 1.5) * s * 0.22))
				draw_polyline(pts, Color(ink, 0.35), w + 3.0, true)
				draw_polyline(pts, col, w, true)
				draw_polyline(pts, Color(1, 1, 1, 0.45), w * 0.3, true)
			"zigzag":
				var zz := PackedVector2Array()
				for i in 6:
					zz.append(Vector2(i * s / 5.0, c.y + (s * 0.2 if i % 2 == 0 else -s * 0.2)))
				draw_polyline(zz, Color(ink, 0.35), w + 3.0)
				draw_polyline(zz, col, w)
			"triangle":
				var tri := PackedVector2Array([Vector2(c.x, s * 0.08), Vector2(s * 0.94, s * 0.88), Vector2(s * 0.06, s * 0.88)])
				draw_colored_polygon(tri, col)
				var hl := PackedVector2Array([Vector2(c.x, s * 0.2), Vector2(s * 0.62, s * 0.5), Vector2(s * 0.38, s * 0.5)])
				draw_colored_polygon(hl, Color(1, 1, 1, 0.35))
				tri.append(tri[0])
				draw_polyline(tri, Color(ink, 0.4), 2.0, true)
			"donut":
				draw_arc(c, s * 0.34, 0.0, TAU, 40, Color(ink, 0.35), s * 0.26, true)
				draw_arc(c, s * 0.34, 0.0, TAU, 40, col, s * 0.22, true)
				draw_arc(c, s * 0.38, PI * 1.1, PI * 1.7, 16, Color(1, 1, 1, 0.55), s * 0.06, true)
				for i in 6:
					draw_circle(c + Vector2.from_angle(TAU * i / 6.0 + 0.4) * s * 0.34, s * 0.035, col2)
			"dots":
				for yy in 3:
					for xx in 3:
						draw_circle(Vector2((xx + 0.5) * s / 3.0, (yy + 0.5) * s / 3.0), s * 0.09, col if (xx + yy) % 2 == 0 else col2)
			"bolt":
				var b := PackedVector2Array([Vector2(s * 0.55, 0), Vector2(s * 0.15, s * 0.55), Vector2(s * 0.45, s * 0.55), Vector2(s * 0.3, s), Vector2(s * 0.85, s * 0.4), Vector2(s * 0.55, s * 0.4), Vector2(s * 0.75, 0)])
				draw_colored_polygon(b, col)
				b.append(b[0])
				draw_polyline(b, Color(ink, 0.45), 2.0, true)
			"blob":
				var pts := PackedVector2Array()
				for i in 28:
					var a := TAU * i / 28.0
					var rr := s * (0.38 + 0.07 * sin(a * 3.0 + _t) + 0.04 * sin(a * 5.0 - _t * 1.3))
					pts.append(c + Vector2.from_angle(a) * rr)
				draw_colored_polygon(pts, col)
				draw_circle(c + Vector2(-s * 0.12, -s * 0.14), s * 0.08, Color(1, 1, 1, 0.55))
				queue_redraw()


## Off-screen markers: glossy gel arrows pinned to the edge of the play area, pointing at
## things outside the view. kind: "food" (lime), "virus" (red, pulses with urgency), "boss".
class EdgeArrows extends Control:
	var marks: Array = []
	var area := Rect2()

	func _draw() -> void:
		if marks.is_empty():
			return
		var inner := area.grow(-34.0)
		var c := inner.get_center()
		var tnow := Time.get_ticks_msec() / 1000.0
		for m in marks:
			var p: Vector2 = m["p"]
			if inner.has_point(p):
				continue
			var dir := p - c
			if dir.length() < 1.0:
				continue
			# clamp the ray from the center to the inner rect edge
			var sx: float = (inner.size.x * 0.5) / maxf(absf(dir.x), 0.001)
			var sy: float = (inner.size.y * 0.5) / maxf(absf(dir.y), 0.001)
			var at := c + dir * minf(sx, sy)
			var kind: String = m["kind"]
			var u: float = m["u"]
			var col := Color("9dff2e")
			var rad := 15.0
			if kind == "virus":
				col = Color("ff3b5a")
				rad = 15.0 + 5.0 * u + sin(tnow * (6.0 + 10.0 * u)) * 2.5 * u
			elif kind == "boss":
				col = Color("ff4fd8")
				rad = 24.0 + sin(tnow * 5.0) * 3.0
			var n := dir.normalized()
			var side := Vector2(-n.y, n.x)
			var tip := at + n * (rad + 12.0)
			draw_colored_polygon(PackedVector2Array([tip, at + side * rad * 0.7, at - side * rad * 0.7]), col.darkened(0.15))
			draw_circle(at + Vector2(0, 3), rad + 2.0, Color(0.0, 0.05, 0.15, 0.3))
			draw_circle(at, rad, col)
			draw_circle(at + Vector2(0.0, -rad * 0.35), rad * 0.55, Color(1, 1, 1, 0.45))
			draw_arc(at, rad, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 2.0, true)
			if kind == "virus":
				for k in 6:
					var d := Vector2.from_angle(TAU * k / 6.0 + tnow)
					draw_line(at + d * rad, at + d * (rad + 5.0), col, 3.0)
