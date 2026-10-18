extends CanvasLayer
## "Cell OS" HUD: Frutiger Aero / Vista glass over a squishy toybox.
##   right (or top, in portrait): frosted console window with an LCD run clock, liquid orb
##   gauges, oscilloscope graphs and gel buttons; bottom: the ATP test tube + fuel orb.
## Every menu is a frosted Aero window with a glossy title bar.
## In-play buttons ignore the mouse and are hit-tested by main.gd, so every finger
## (not just the first one) can press them while another finger steers.

const Mutations = preload("res://scripts/mutations.gd")
const Aero = preload("res://scripts/aero.gd")

const CONSOLE_W := 300.0
const AQUA := Color("39c8ff")
const DEEP := Color("06406e")
const GREEN := Color("4fe36a")
const AMBER := Color("ffb52e")
const RED := Color("ff4a4a")
const MAGENTA := Color("ff4fd8")
const ACID := Color("c6ff3a")
const ORANGE := Color("ff8a1f")
const HOTPINK := Color("ff3fb4")
const PURPLE := Color("8b5cff")
const LIME := Color("9dff2e")
const CYAN := Color("2fd8ff")
const YELLOW := Color("ffd400")
## Candy rim loops, cycled across windows so no two menus look alike.
const PALETTES := [
	[Color("ff8a1f"), Color("ff3fb4"), Color("8b5cff")],
	[Color("2fd8ff"), Color("9dff2e"), Color("ffd400")],
	[Color("ff3fb4"), Color("ffd400"), Color("2fd8ff")],
	[Color("8b5cff"), Color("2fd8ff"), Color("ff8a1f")],
]

var game
## Chunky cartoon font for the 3D pop text in the world.
var font: SystemFont
var ui_font: SystemFont
var ui_bold: SystemFont
var mono: SystemFont

var root: Control
var play_ui: Control
var console: Control
var console_glass: Aero.GlassRect
var console_title: Label
var btn_mute: Aero.JellyButton
var btn_pause: Aero.JellyButton
var lcd: Aero.Lcd
var orb_dig: Aero.Orb
var orb_mut: Aero.Orb
var orb_food: Aero.Orb
var graph_hunger: Aero.Graph
var graph_ros: Aero.Graph
var stat_rad: Label
var stat_vir: Label
var icon_rad: Aero.IconArt
var icon_vir: Aero.IconArt
var btn_unclog: Aero.JellyButton
var btn_crank: Aero.JellyButton
var btn_cry: Aero.JellyButton
var btn_purge: Aero.JellyButton
var _purge_txt := ""
var fuel_orb: Aero.Orb
var fuel_icon: Aero.IconArt
var tube: Aero.Tube
var tube_caption: Label
var tube_left: Label
var tube_mid: Label
var tube_right: Label
var toast: PanelContainer
var toast_label: Label
var toast_tween: Tween
var joy: Aero.Joystick
var flash_rect: ColorRect

var title_win: Dictionary
var cards_win: Dictionary
var death_win: Dictionary
var pause_win: Dictionary
var title_meta: Label
var cards_sub: Label
var cards_box: BoxContainer
var card_ids: Array = []
var card_cb: Callable
var death_icon: Aero.Orb
var death_title_box: Control
var death_flavor: Label
var death_stats: Label
var death_dna: Label
var death_tube: Aero.Tube
var death_unlock: Label
var pause_sound: Aero.JellyButton

var view := Vector2(1280, 720)
var _hist_t := 0.0
var _win_n := -1
var console_tab: Aero.JellyButton
var tube_tab: Aero.JellyButton
var cap_l: Aero.JellyButton
var cap_r: Aero.JellyButton
var hud_decos: Array[Aero.Deco] = []
var pause_hunger: Aero.Graph
var pause_ros: Aero.Graph
var edge: Aero.EdgeArrows
var hint: PanelContainer
var hint_label: Label
var btn_skip: Aero.JellyButton
var danger_rect: TextureRect
var _danger := 0.0
var _danger_dig := true
var _crank_mode := ""
var _last_throttle := -1


func setup(g) -> void:
	game = g
	layer = 5
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Luckiest Guy", "Bangers", "Impact", "Arial Black", "sans-serif"])
	ui_font = SystemFont.new()
	ui_font.font_names = PackedStringArray(["Segoe UI", "Frutiger", "Myriad Pro", "Helvetica Neue", "Arial", "sans-serif"])
	ui_font.font_weight = 500
	ui_bold = SystemFont.new()
	ui_bold.font_names = ui_font.font_names
	ui_bold.font_weight = 750
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Lucida Console", "Menlo", "Courier New", "monospace"])
	mono.font_weight = 700
	var th := Theme.new()
	th.default_font = ui_font
	th.default_font_size = 18
	root = Control.new()
	root.theme = th
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_play_ui()
	_build_title()
	_build_cards()
	_build_death()
	_build_pause()
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)


# ---------------------------------------------------------------- helpers

func _ls(size: int, color: Color = Color.WHITE, bold: bool = true, glow: Color = Aero.SHADOW, glow_size: int = 6) -> LabelSettings:
	return Aero.label_settings(ui_bold if bold else ui_font, size, color, glow, glow_size)


func _text(t: String, size: int, color: Color = Color.WHITE, bold: bool = true, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	return Aero.label(t, _ls(size, color, bold), align)


func _wrap(l: Label, w: float = 560.0) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	return l


func _gel(t: String, color: Color, sz: Vector2, fs: int = 20, r: float = -1.0, clickable: bool = true) -> Aero.JellyButton:
	return Aero.JellyButton.new(t, color, sz, sz.y * 0.5 if r < 0.0 else r, _ls(fs), clickable)


## Frosted Aero window with a glossy title bar. Returns {root, vb, panel, close}.
func _window(title: String, icon: String, closable: bool) -> Dictionary:
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.visible = false
	root.add_child(ov)
	var bbc := BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	ov.add_child(bbc)
	var back := Aero.GlassRect.new(Color(0.02, 0.13, 0.22, 0.42), 0.0, 4.5)
	back.mat.set_shader_parameter("sheen", 0.35)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(back)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cc)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Aero.shadow_box(30, 26, 0.5))
	cc.add_child(pc)
	_win_n += 1
	var pal: Array = PALETTES[_win_n % PALETTES.size()]
	var glass := Aero.GlassRect.new(Color(0.1, 0.4, 0.62, 0.46), 22.0, 4.0).rims(pal[0], pal[1], pal[2], 9.0)
	if _win_n % 2 == 0:
		glass.corners(78.0, 16.0, 86.0, 24.0).blob(14.0, Vector3(0.95, 0.07, 46.0), Vector3(0.05, 0.93, 40.0), Vector3(1.0, 0.56, 26.0))
	else:
		glass.corners(20.0, 84.0, 26.0, 74.0).blob(14.0, Vector3(0.06, 0.08, 44.0), Vector3(0.94, 0.94, 42.0), Vector3(0.0, 0.48, 24.0))
	pc.add_child(glass)
	# Memphis confetti pinned to the window's corners (may poke outside the glass)
	var deco := Control.new()
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(deco)
	_pin(deco, Aero.Deco.new("squiggle", 64.0, pal[1], Color.WHITE, -0.3), Control.PRESET_TOP_RIGHT, Vector2(-96, -30))
	_pin(deco, Aero.Deco.new("triangle", 40.0, YELLOW, Color.WHITE, 0.4, 0.4), Control.PRESET_BOTTOM_LEFT, Vector2(-18, -34))
	_pin(deco, Aero.Deco.new("donut", 46.0, pal[2], LIME), Control.PRESET_BOTTOM_RIGHT, Vector2(-30, -28))
	_pin(deco, Aero.Deco.new("dots", 34.0, CYAN, HOTPINK), Control.PRESET_TOP_LEFT, Vector2(-14, 46))
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 26)
	mc.add_theme_constant_override("margin_right", 26)
	mc.add_theme_constant_override("margin_top", -18)
	mc.add_theme_constant_override("margin_bottom", 24)
	pc.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	mc.add_child(vb)
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 40
	bar.add_theme_constant_override("separation", 8)
	vb.add_child(bar)
	# the title is a tilted gel tab hanging off the top edge, not a corporate title bar
	bar.add_child(_tilted(_tab(title, pal[0], 15), -0.045))
	var badge := Aero.IconArt.new(icon, 34.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_tilted(badge, 0.18))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)
	var close: Aero.JellyButton = null
	if closable:
		close = _gel("✕", Color("ff4a3d"), Vector2(44, 40), 16, 20.0)
		close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_child(_tilted(close, 0.1))
	return {"root": ov, "vb": vb, "panel": pc, "close": close}


## Containers reset child rotation, so tilted widgets ride inside a plain holder.
func _tilted(c: Control, angle: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = c.get_combined_minimum_size()
	holder.size_flags_horizontal = c.size_flags_horizontal
	holder.size_flags_vertical = c.size_flags_vertical
	holder.add_child(c)
	c.rotation = angle
	holder.resized.connect(func():
		c.position = Vector2.ZERO
		c.size = holder.size
		c.pivot_offset = holder.size * 0.5)
	c.minimum_size_changed.connect(func(): holder.custom_minimum_size = c.get_combined_minimum_size())
	return holder


## A gel pill sized to its text, used as a tilted tab label.
func _tab(t: String, color: Color, fs: int = 14) -> Aero.JellyButton:
	var w := ui_bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 40.0
	var b := _gel(t, color, Vector2(w, fs + 20.0), fs, (fs + 20.0) * 0.5, false)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


func _pin(parent: Control, c: Control, preset: int, off: Vector2) -> void:
	parent.add_child(c)
	c.set_anchors_preset(preset)
	c.position = Vector2.ZERO
	var anchor := Vector2(c.anchor_left, c.anchor_top)
	c.set_meta("pin", [anchor, off])
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.x + c.custom_minimum_size.x
	c.offset_bottom = off.y + c.custom_minimum_size.y


func _lcd_strip(t: String) -> Array:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.07, 0.035, 0.85)
	sb.border_color = Color(1, 1, 1, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	pc.add_theme_stylebox_override("panel", sb)
	var l := Aero.label(t, Aero.label_settings(mono, 16, Aero.LCD_GREEN, Color(0.36, 1.0, 0.48, 0.45), 8))
	pc.add_child(l)
	return [pc, l]


# ---------------------------------------------------------------- in-play HUD

func _build_play_ui() -> void:
	play_ui = Control.new()
	play_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(play_ui)

	# --- console window
	console = Control.new()
	console.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_ui.add_child(console)
	var cs := Panel.new()
	cs.add_theme_stylebox_override("panel", Aero.shadow_box(30, 18, 0.4))
	cs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cs.set_anchors_preset(Control.PRESET_FULL_RECT)
	console.add_child(cs)
	console_glass = Aero.GlassRect.new(Color(0.55, 0.82, 1.0, 0.22), 18.0, 3.2)
	console_glass.rims(ORANGE, HOTPINK, PURPLE, 8.0).corners(70.0, 18.0, 74.0, 26.0)
	console_glass.blob(12.0, Vector3(0.16, 0.06, 40.0), Vector3(0.86, 0.95, 34.0), Vector3(0.0, 0.6, 22.0))
	console_glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	console.add_child(console_glass)
	console_title = _text("", 1)
	console_title.visible = false
	console.add_child(console_title)
	console_tab = _tab("MUTATION SIDEBAR", PURPLE, 14)
	console_tab.rotation = -0.05
	console.add_child(console_tab)
	btn_mute = _gel("♪", CYAN, Vector2(42, 36), 16, 18.0, false)
	btn_pause = _gel("❚❚", HOTPINK, Vector2(42, 36), 12, 18.0, false)
	btn_mute.rotation = 0.06
	btn_pause.rotation = -0.07
	console.add_child(btn_mute)
	console.add_child(btn_pause)
	lcd = Aero.Lcd.new(mono)
	lcd.rotation = -0.012
	console.add_child(lcd)
	var vls := _ls(19)
	var cls := _ls(11, Color(0.9, 0.98, 1.0))
	orb_dig = Aero.Orb.new(76.0, ACID, "DIGESTION", vls, cls).set_rim(LIME)
	orb_mut = Aero.Orb.new(76.0, MAGENTA, "MUTATION", vls, cls).set_rim(HOTPINK)
	orb_food = Aero.Orb.new(76.0, Color("ff9ad5"), "FOOD", _ls(16), cls).set_rim(ORANGE)
	for o in [orb_dig, orb_mut, orb_food]:
		console.add_child(o)
	graph_hunger = Aero.Graph.new("AMOEBA HUNGER", ACID, ui_bold)
	graph_ros = Aero.Graph.new("ROS HEAT", MAGENTA, ui_bold)
	console.add_child(graph_hunger)
	console.add_child(graph_ros)
	icon_rad = Aero.IconArt.new("radical", 34.0)
	icon_vir = Aero.IconArt.new("virus", 34.0)
	stat_rad = _text("0  RADICALS", 13, Color.WHITE, true, HORIZONTAL_ALIGNMENT_LEFT)
	stat_vir = _text("0  PHAGES NEAR", 13, Color.WHITE, true, HORIZONTAL_ALIGNMENT_LEFT)
	for c in [icon_rad, icon_vir, stat_rad, stat_vir]:
		console.add_child(c)
	btn_unclog = _gel("UNCLOG!", Color("ff5a1f"), Vector2(86, 66), 15, 20.0, false)
	btn_crank = _gel("CRANK\nI", YELLOW, Vector2(86, 66), 15, 20.0, false)
	btn_cry = _gel("CRY!", Color("2f9bff"), Vector2(86, 66), 15, 20.0, false)
	var tilts := [-0.06, 0.04, -0.03]
	for i in 3:
		var b: Aero.JellyButton = [btn_unclog, btn_crank, btn_cry][i]
		b.rotation = tilts[i]
		console.add_child(b)
	for d in [
		Aero.Deco.new("squiggle", 58.0, LIME, Color.WHITE, -0.4),
		Aero.Deco.new("triangle", 34.0, YELLOW, Color.WHITE, 0.5, 0.5),
		Aero.Deco.new("donut", 40.0, HOTPINK, CYAN),
	]:
		console.add_child(d)
		hud_decos.append(d)

	# --- ATP energy bar: glass tube with gel end caps and a DNA helix inside
	tube = Aero.Tube.new()
	tube.set_zone(0.5, 0.675)
	play_ui.add_child(tube)
	cap_l = _gel("", ORANGE, Vector2(40, 70), 1, 18.0, false)
	cap_r = _gel("", ORANGE, Vector2(40, 70), 1, 18.0, false)
	play_ui.add_child(cap_l)
	play_ui.add_child(cap_r)
	tube_tab = _tab("ATP ENERGY BAR", HOTPINK, 14)
	tube_tab.rotation = -0.03
	play_ui.add_child(tube_tab)
	tube_caption = _text("ATP OUTPUT", 13)
	tube_left = _text("HUNGRY", 12, ACID)
	tube_mid = _text("JUST RIGHT", 12, Color.WHITE)
	tube_right = _text("MUTATING", 12, MAGENTA)
	for l in [tube_caption, tube_left, tube_mid, tube_right]:
		play_ui.add_child(l)
	fuel_orb = Aero.Orb.new(128.0, AMBER, "MITO FUEL", _ls(24), _ls(13)).set_rim(PURPLE)
	fuel_orb.mat.set_shader_parameter("swirl", 1.0)
	play_ui.add_child(fuel_orb)
	fuel_icon = Aero.IconArt.new("mito", 46.0)
	# EMERGENCY PURGE panic valve (F): vents 35% off both meters, 20 s cooldown
	btn_purge = _gel("PURGE\n[F]", Color("ff2a4a"), Vector2(128, 56), 15, 22.0, false)
	btn_purge.rotation = -0.04
	play_ui.add_child(btn_purge)
	play_ui.add_child(fuel_icon)
	for d in [Aero.Deco.new("bolt", 34.0, YELLOW, Color.WHITE, 0.3), Aero.Deco.new("dots", 30.0, CYAN, HOTPINK)]:
		play_ui.add_child(d)
		hud_decos.append(d)

	# --- toast notification (Vista balloon, gone wobbly)
	toast = PanelContainer.new()
	toast.add_theme_stylebox_override("panel", Aero.shadow_box(30, 14, 0.35))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.modulate.a = 0.0
	toast.rotation = -0.025
	toast.add_child(Aero.GlassRect.new(Color(0.3, 0.6, 0.9, 0.36), 26.0, 3.0).rims(CYAN, LIME, YELLOW, 7.0).corners(40.0, 12.0, 44.0, 14.0).blob(6.0, Vector3(0.03, 0.5, 26.0)))
	var tm := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		tm.add_theme_constant_override(side, 26)
	for side in ["margin_top", "margin_bottom"]:
		tm.add_theme_constant_override(side, 8)
	toast.add_child(tm)
	toast_label = _text("", 34)
	tm.add_child(toast_label)
	play_ui.add_child(toast)

	# danger vignette: radial edge glow that pulses as a meter nears 100%
	danger_rect = TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gg := Gradient.new()
	gg.set_color(0, Color(1, 1, 1, 0))
	gg.set_color(1, Color(1, 1, 1, 1))
	gg.add_point(0.62, Color(1, 1, 1, 0))
	gt.gradient = gg
	danger_rect.texture = gt
	danger_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	danger_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	danger_rect.stretch_mode = TextureRect.STRETCH_SCALE
	danger_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger_rect.modulate.a = 0.0
	play_ui.add_child(danger_rect)
	play_ui.move_child(danger_rect, 0)

	# off-screen markers
	edge = Aero.EdgeArrows.new()
	edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_ui.add_child(edge)

	# tutorial hint bar (glass pill + SKIP gel)
	hint = PanelContainer.new()
	hint.add_theme_stylebox_override("panel", Aero.shadow_box(30, 12, 0.35))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(Aero.GlassRect.new(Color(0.12, 0.35, 0.6, 0.55), 22.0, 3.0).rims(LIME, CYAN, YELLOW, 5.0))
	var hm := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		hm.add_theme_constant_override(side, 20)
	for side in ["margin_top", "margin_bottom"]:
		hm.add_theme_constant_override(side, 8)
	hint.add_child(hm)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hm.add_child(hb)
	hint_label = _text("", 16, Color.WHITE)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size.x = 420
	hb.add_child(hint_label)
	btn_skip = _gel("SKIP", Color("ff5a7a"), Vector2(80, 40), 15, 20.0, false)
	btn_skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(btn_skip)
	hint.visible = false
	play_ui.add_child(hint)

	joy = Aero.Joystick.new()
	joy.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_ui.add_child(joy)


# ---------------------------------------------------------------- menus

func _build_title() -> void:
	title_win = _window("Symbio-Shack  —  Endosymbiosis Control Panel", "mito", not OS.has_feature("mobile"))
	var vb: VBoxContainer = title_win["vb"]
	if title_win["close"]:
		title_win["close"].tapped.connect(func(): get_tree().quit())
	var logo := Aero.gloss_title("SYMBIO-SHACK", ui_bold, 68, Color.WHITE, Color("2fb5ff"), Color(0.0, 0.35, 0.75, 0.75))
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(_tilted(logo, -0.03))
	vb.add_child(_text("the endosymbiosis roguelike  ·  Cell OS 2.0", 16, Color("d8f4ff"), false))
	vb.add_child(_wrap(_text("A giant, dim-witted amoeba just swallowed you. Cut a deal before the acid kicks in: DON'T DIGEST ME, I'LL BE YOUR ENGINE!", 17, Color.WHITE, false)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rows := [
		["STEER", AQUA, "WASD / arrows, or drag on empty soup"],
		["SLINGSHOT", AMBER, "grab a glowing ATP canister, pull back, let go into the purple Nucleus"],
		["FLICK", RED, "fling the angry red free radicals hard through the membrane"],
		["CRANK", GREEN, "citric cycle I · II · III  —  Space, right-click, or the CRANK gel"],
		["UNCLOG", Color("b07cff"), "tap the gunk on the conveyor, splat acid puddles"],
	]
	for row in rows:
		var key := _gel(row[0], row[1], Vector2(124, 38), 14, 19.0, false)
		key.rotation = [-0.06, 0.05, -0.03, 0.06, -0.05][grid.get_child_count() / 2 % 5]
		grid.add_child(_tilted(key, key.rotation))
		var d := _text(row[2], 15, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 400
		grid.add_child(d)
	vb.add_child(grid)
	vb.add_child(_wrap(_text("Keep the ATP tube in the etched sweet zone. Starve the host and it DIGESTS you. Overfeed it and it MUTATES.", 15, Color("ffe7a8"))))
	var start := _gel("LET ME BE YOUR ENGINE!", GREEN, Vector2(440, 66), 26)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.tapped.connect(func(): game.start_run())
	var start_row := HBoxContainer.new()
	start_row.alignment = BoxContainer.ALIGNMENT_CENTER
	start_row.add_theme_constant_override("separation", 14)
	start_row.add_child(start)
	var tut := _gel("TUTORIAL", Color("2f9bff"), Vector2(150, 56), 18)
	tut.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tut.tapped.connect(func(): game.replay_tutorial())
	start_row.add_child(tut)
	vb.add_child(start_row)
	var strip := _lcd_strip("")
	strip[0].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(strip[0])
	title_meta = strip[1]


func _build_cards() -> void:
	cards_win = _window("Mitosis Wizard", "dna", false)
	var vb: VBoxContainer = cards_win["vb"]
	var head := Aero.gloss_title("MITOSIS!", ui_bold, 54, Color("fff6c8"), Color("ffb52e"), Color(0.6, 0.3, 0.0, 0.7))
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(head)
	cards_sub = _text("", 16, Color("d8f4ff"), false)
	vb.add_child(cards_sub)
	cards_box = BoxContainer.new()
	cards_box.add_theme_constant_override("separation", 14)
	cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(cards_box)
	vb.add_child(_text("press 1 / 2 / 3, or tap SPLICE", 13, Color("bfe9ff"), false))


func _build_death() -> void:
	death_win = _window("Cellular Event Viewer", "alert", false)
	var vb: VBoxContainer = death_win["vb"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	death_icon = Aero.Orb.new(84.0, RED, "", _ls(44), _ls(10))
	death_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(death_icon)
	death_title_box = Control.new()
	death_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(death_title_box)
	death_flavor = _wrap(_text("", 17, Color.WHITE, false))
	vb.add_child(death_flavor)
	var strip := _lcd_strip("")
	strip[0].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(strip[0])
	death_stats = strip[1]
	death_dna = _text("", 20, Color("ffe7a8"))
	vb.add_child(death_dna)
	death_tube = Aero.Tube.new()
	death_tube.set_zone(2.0, 2.0)
	death_tube.custom_minimum_size = Vector2(460, 40)
	death_tube.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(death_tube)
	death_unlock = _wrap(_text("", 15, Color("ffd0f4")))
	vb.add_child(death_unlock)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 14)
	var again := _gel("SPLIT & TRY AGAIN", GREEN, Vector2(270, 60), 21)
	again.tapped.connect(func(): game.start_run())
	var menu := _gel("MAIN MENU", Color("2f8fff"), Vector2(180, 60), 19)
	menu.tapped.connect(func(): game.quit_to_title())
	btns.add_child(again)
	btns.add_child(menu)
	vb.add_child(btns)
	vb.add_child(_text("Space / Enter also restarts", 12, Color("bfe9ff"), false))


func _build_pause() -> void:
	pause_win = _window("Cell OS  —  Paused", "mito", true)
	pause_win["close"].tapped.connect(func(): game.toggle_pause())
	var vb: VBoxContainer = pause_win["vb"]
	var head := Aero.gloss_title("PAUSED", ui_bold, 54, Color.WHITE, Color("5aa7ff"), Color(0.0, 0.25, 0.6, 0.7))
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(head)
	vb.add_child(_text("The amoeba is holding its breath. It does not have lungs.", 16, Color.WHITE, false))
	# the oscilloscopes live here now: in play they were just repeating the orbs
	pause_hunger = Aero.Graph.new("AMOEBA HUNGER", ACID, ui_bold)
	pause_ros = Aero.Graph.new("ROS HEAT", MAGENTA, ui_bold)
	for g in [pause_hunger, pause_ros]:
		g.custom_minimum_size = Vector2(460, 104)
		g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(g)
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	btns.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var resume := _gel("BACK TO THE SOUP", GREEN, Vector2(320, 58), 21)
	resume.tapped.connect(func(): game.toggle_pause())
	pause_sound = _gel("SOUND: ON", AQUA, Vector2(320, 50), 18)
	pause_sound.tapped.connect(func(): game.toggle_mute())
	var quit := _gel("QUIT TO MAIN MENU", Color("e8433f"), Vector2(320, 50), 18)
	quit.tapped.connect(func(): game.quit_to_title())
	for b in [resume, pause_sound, quit]:
		btns.add_child(b)
	vb.add_child(btns)


# ---------------------------------------------------------------- layout

func layout(sz: Vector2) -> void:
	view = sz
	var portrait := sz.x < sz.y
	var m := 12.0
	if not portrait:
		console.position = Vector2(sz.x - CONSOLE_W - m, m)
		console.size = Vector2(CONSOLE_W, sz.y - m * 2.0)
		var w := CONSOLE_W - 24.0
		console_title.position = Vector2(14, 8)
		console_title.size = Vector2(170, 24)
		btn_pause.position = Vector2(CONSOLE_W - 14 - 42, 6)
		btn_mute.position = Vector2(CONSOLE_W - 14 - 42 - 48, 8)
		var y := 52.0
		lcd.position = Vector2(12, y)
		lcd.size = Vector2(w, 92)
		y += 104.0
		_place_orbs(12.0, y, w)
		y += 104.0
		# compact sidebar: graphs moved to the pause window, so the console only covers
		# the top of the right column and the play area gets the rest
		graph_hunger.visible = false
		graph_ros.visible = false
		_place_stats(12.0, y, w)
		var btn_y := y + 52.0
		_place_buttons(12.0, btn_y, w, Vector2(86, 66))
		console.size.y = btn_y + 66.0 + 16.0
		fuel_orb.position = Vector2(m + 4.0, sz.y - m - 128.0 - 22.0)
		var tx := m + 128.0 + 26.0
		var tw := console.position.x - 18.0 - tx
		tube.position = Vector2(tx, sz.y - m - 56.0)
		tube.size = Vector2(tw, 50)
		hud_decos[0].position = Vector2(-40, 150)
		hud_decos[1].position = Vector2(CONSOLE_W - 22, console.size.y * 0.5)
		hud_decos[2].position = Vector2(-26, console.size.y - 150)
	else:
		console.position = Vector2(m, m)
		console.size = Vector2(sz.x - m * 2.0, 216)
		var w := console.size.x - 24.0
		console_title.position = Vector2(14, 8)
		console_title.size = Vector2(220, 24)
		btn_pause.position = Vector2(console.size.x - 14 - 42, 6)
		btn_mute.position = Vector2(console.size.x - 14 - 42 - 48, 8)
		lcd.position = Vector2(14, 52)
		lcd.size = Vector2(minf(250.0, w * 0.42), 92)
		var ox := 12.0 + lcd.size.x + 10.0
		_place_orbs(ox, 48.0, w - lcd.size.x - 10.0)
		graph_hunger.visible = false
		graph_ros.visible = false
		_place_stats(12.0, 162.0, w)
		# gel buttons live in the console node but float at the bottom-right of the screen
		var bs := Vector2(108, 82)
		var bw := bs.x * 3.0 + 20.0
		_place_buttons(sz.x - m - bw - console.position.x, sz.y - m - bs.y - console.position.y, bw, bs)
		fuel_orb.position = Vector2(m + 4.0, sz.y - m - 128.0 - 22.0)
		tube.position = Vector2(m, sz.y - m - 150.0 - 34.0 - 50.0)
		tube.size = Vector2(sz.x - m * 2.0 - 30.0, 50)
		tube.position.x += 15.0
		hud_decos[0].position = Vector2(console.size.x - 80, console.size.y - 20)
		hud_decos[1].position = Vector2(-10, console.size.y - 26)
		hud_decos[2].position = Vector2(console.size.x - 26, 60)
	fuel_icon.position = fuel_orb.position + Vector2(64.0 - 23.0, 8.0)
	btn_purge.position = Vector2(150.0, sz.y - 12.0 - 76.0) if portrait else fuel_orb.position + Vector2(0.0, -66.0)
	btn_purge.custom_minimum_size = Vector2(140, 70) if portrait else Vector2(128, 56)
	btn_purge.size = btn_purge.custom_minimum_size
	console_tab.position = Vector2(20, -16)
	cap_l.position = tube.position + Vector2(-22.0, -10.0)
	cap_r.position = tube.position + Vector2(tube.size.x - 18.0, -10.0)
	tube_tab.position = tube.position + Vector2(tube.size.x * 0.5 - tube_tab.size.x * 0.5, -34.0)
	tube_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_decos[3].position = fuel_orb.position + Vector2(108.0, -8.0)
	hud_decos[4].position = tube.position + Vector2(tube.size.x * 0.18, -36.0)
	tube_caption.position = tube.position + Vector2(0.0, -24.0 + 0.0)
	tube_caption.size = Vector2(tube.size.x - 30.0, 22.0)
	tube_left.position = tube.position + Vector2(14.0, tube.size.y)
	tube_left.size = Vector2(80, 18)
	tube_mid.position = tube.position + Vector2(tube.size.x * 0.5875 - 50.0, tube.size.y)
	tube_mid.size = Vector2(100, 18)
	tube_right.position = tube.position + Vector2(tube.size.x - 94.0, tube.size.y)
	tube_right.size = Vector2(80, 18)
	var free_w := sz.x if portrait else sz.x - CONSOLE_W - m
	toast.reset_size()
	toast.position = Vector2(free_w * 0.5 - toast.size.x * 0.5, 240.0 if portrait else 20.0)
	edge.area = Rect2(0.0, 236.0, sz.x, sz.y - 236.0 - 270.0) if portrait else Rect2(0.0, 0.0, sz.x - CONSOLE_W - 24.0, sz.y - 100.0)
	hint.reset_size()
	hint.position = Vector2(free_w * 0.5 - hint.size.x * 0.5, 300.0 if portrait else 86.0)
	var wrap_w := minf(560.0, sz.x - 120.0)
	for win in [title_win, cards_win, death_win, pause_win]:
		for c in win["vb"].get_children():
			if c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
				(c as Label).custom_minimum_size.x = wrap_w
	cards_box.vertical = portrait


func _place_orbs(x: float, y: float, w: float) -> void:
	var gap := (w - 76.0 * 3.0) / 4.0
	for i in 3:
		var o: Aero.Orb = [orb_dig, orb_mut, orb_food][i]
		o.position = Vector2(x + gap + i * (76.0 + gap), y)


func _place_stats(x: float, y: float, w: float) -> void:
	icon_rad.position = Vector2(x, y)
	stat_rad.position = Vector2(x + 38.0, y + 6.0)
	stat_rad.size = Vector2(w * 0.5 - 40.0, 24.0)
	icon_vir.position = Vector2(x + w * 0.5, y)
	stat_vir.position = Vector2(x + w * 0.5 + 38.0, y + 6.0)
	stat_vir.size = Vector2(w * 0.5 - 40.0, 24.0)


func _place_buttons(x: float, y: float, w: float, bs: Vector2) -> void:
	var gap := (w - bs.x * 3.0) / 2.0
	for i in 3:
		var b: Aero.JellyButton = [btn_unclog, btn_crank, btn_cry][i]
		b.custom_minimum_size = bs
		b.size = bs
		b.position = Vector2(x + i * (bs.x + gap), y)


# ---------------------------------------------------------------- per frame

func update_hud(dt: float) -> void:
	var st: String = game.state
	play_ui.visible = st in ["play", "cards", "paused", "dying"]
	if not play_ui.visible:
		return
	var tn = game.tension
	var dig: float = tn.digestion
	var inst: float = tn.instability
	orb_dig.set_value(dig / 100.0, "%d%%" % int(dig), 1.0 if dig > 70.0 else 0.0)
	orb_mut.set_value(inst / 100.0, "%d%%" % int(inst), 1.0 if inst > 70.0 else 0.0)
	var fg: int = game.food_gen
	var goal: int = game.food_goal
	orb_food.set_value(float(fg) / maxf(1.0, goal), "%d/%d" % [fg, goal])
	var fuel: float = game.room.fuel
	fuel_orb.set_value(fuel / 6.0, "%.1f" % fuel, 1.0 if fuel < 0.3 else 0.0)
	var th: int = game.throttle
	fuel_orb.mat.set_shader_parameter("swirl", float(th))
	var ratio: float = tn.ratio()
	var lc := ACID.lerp(GREEN, clampf(ratio, 0.0, 1.0))
	if ratio > 1.35:
		lc = GREEN.lerp(MAGENTA, clampf((ratio - 1.35) / 0.4, 0.0, 1.0))
	tube.set_fill(ratio / 2.0, lc)
	tube_caption.text = "ATP OUTPUT  %.2f  /  DEMAND  %.2f" % [float(tn.atp_rate), float(tn.demand)]
	lcd.seconds = int(game.run_time)
	lcd.gen = int(game.gen)
	lcd.fuel = fuel
	lcd.line = "mtDNA %04d" % int(game.meta["mtdna"])
	lcd.queue_redraw()
	_hist_t -= dt
	if _hist_t <= 0.0:
		_hist_t = 0.25
		graph_hunger.push(dig)
		graph_ros.push(inst)
		graph_hunger.readout = "%d%%" % int(dig)
		graph_ros.readout = "%d%%" % int(inst)
	var rads: int = game.room.radical_count()
	stat_rad.text = "%d  RADICALS" % rads
	var hp: Vector2 = game.host.pos
	var near := 0
	for v in game.sea.viruses:
		if not v.dead and v.pos.distance_to(hp) < 22.0:
			near += 1
	stat_vir.text = "%d  PHAGES NEAR" % near
	var mode: String = "OVER\nDRIVE!" if bool(game.overdrive) else "CRANK\n" + ["I", "II", "III"][clampi(th, 1, 3) - 1]
	if mode != _crank_mode:
		_crank_mode = mode
		btn_crank.set_color([GREEN, AMBER, RED][clampi(th, 1, 3) - 1])
		btn_crank.set_text(mode)
	btn_crank.attention = bool(game.overdrive)
	# danger vignette pulse
	var pulse := _danger * (0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * (5.0 + _danger * 7.0)))
	danger_rect.modulate = Color(ACID if _danger_dig else MAGENTA, pulse * 0.75)
	btn_unclog.enabled = bool(game.room.clogged)
	btn_unclog.attention = btn_unclog.enabled
	btn_cry.enabled = game.has_mut("lysosome") and float(game.cry_cool) <= 0.0
	btn_cry.set_text("CRY" if game.has_mut("lysosome") else "CRY\nlocked")
	var pc: float = game.purge_cool
	var ptxt: String = "PURGE\n[F]" if pc <= 0.0 else "PURGE\n%ds" % ceili(pc)
	if ptxt != _purge_txt:
		_purge_txt = ptxt
		btn_purge.set_text(ptxt)
	btn_purge.enabled = pc <= 0.0
	btn_purge.attention = pc <= 0.0 and bool(game.in_danger())
	joy.active = int(game.joy_id) != -999
	joy.origin = game.joy_origin
	joy.vec = game.joy_vec
	joy.queue_redraw()


# ---------------------------------------------------------------- API used by main.gd

func button_at(pos: Vector2) -> String:
	if not play_ui.visible:
		return ""
	var pairs := [["skip", btn_skip], ["purge", btn_purge], ["unclog", btn_unclog], ["crank", btn_crank], ["cry", btn_cry], ["pause", btn_pause], ["mute", btn_mute]]
	for pair in pairs:
		var b: Control = pair[1]
		if b.is_visible_in_tree() and b.get_global_rect().grow(8.0).has_point(pos):
			return pair[0]
	return ""


func activate(which: String) -> void:
	var b: Aero.JellyButton = {"skip": btn_skip, "purge": btn_purge, "unclog": btn_unclog, "crank": btn_crank, "crank_visual": btn_crank, "cry": btn_cry, "pause": btn_pause, "mute": btn_mute}[which]
	b.flash_press()
	match which:
		"purge":
			game.emergency_purge()
		"skip":
			game.skip_tutorial()
		"unclog":
			if game.room.clogged:
				game.room.unclog()
			else:
				game.sfx("boop")
		"crank":
			game.cycle_throttle()
		"cry":
			game.fire_cry()
		"pause":
			game.toggle_pause()
		"mute":
			game.toggle_mute()


func set_muted(m: bool) -> void:
	btn_mute.set_text("✕" if m else "♪")
	pause_sound.set_text("SOUND: OFF" if m else "SOUND: ON")


func set_cry_visible(_v: bool) -> void:
	pass


func set_markers(marks: Array) -> void:
	edge.marks = marks
	edge.queue_redraw()


## Tutorial hint bar; empty text hides it.
func set_hint(text: String) -> void:
	hint.visible = text != ""
	hint_label.text = text
	hint.reset_size()
	var free_w := view.x if view.x < view.y else view.x - CONSOLE_W - 12.0
	hint.position = Vector2(free_w * 0.5 - hint.size.x * 0.5, 300.0 if view.x < view.y else 86.0)


## 0..1 danger level for the edge vignette; tint lime for digestion, magenta for mutation.
func set_danger(level: float, digestion: bool) -> void:
	_danger = level
	_danger_dig = digestion


func banner(text: String, color: Color, fs: int = 54) -> void:
	toast_label.text = text
	toast_label.label_settings = _ls(clampi(int(fs * 0.62), 22, 40), Color.WHITE, true, Color(color, 0.95), 12)
	toast.reset_size()
	var free_w := view.x if view.x < view.y else view.x - CONSOLE_W - 12.0
	var y := 240.0 if view.x < view.y else 20.0
	toast.position = Vector2(free_w * 0.5 - toast.size.x * 0.5, y - 30.0)
	if toast_tween:
		toast_tween.kill()
	toast.modulate.a = 0.0
	toast_tween = create_tween()
	toast_tween.set_parallel(true)
	toast_tween.tween_property(toast, "modulate:a", 1.0, 0.18)
	toast_tween.tween_property(toast, "position:y", y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	toast_tween.chain().tween_interval(1.5)
	toast_tween.chain().tween_property(toast, "modulate:a", 0.0, 0.4)


func flash(color: Color, dur: float) -> void:
	flash_rect.color = color
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, dur)


func hide_overlays() -> void:
	for win in [title_win, cards_win, death_win, pause_win]:
		win["root"].visible = false


func _open(win: Dictionary) -> void:
	hide_overlays()
	var ov: Control = win["root"]
	var pc: Control = win["panel"]
	ov.visible = true
	pc.pivot_offset = pc.size * 0.5
	pc.scale = Vector2(0.92, 0.92)
	pc.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(pc, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pc, "modulate:a", 1.0, 0.18)


func show_title(meta: Dictionary) -> void:
	title_meta.text = "mtDNA %04d   BEST GEN %02d   MUTATIONS %d/%d" % [
		int(meta["mtdna"]), int(meta["best_gen"]), Mutations.unlocked(int(meta["mtdna"])).size(), Mutations.CARDS.size()]
	_open(title_win)


func show_pause(on: bool) -> void:
	if on:
		pause_hunger.data = graph_hunger.data.duplicate()
		pause_ros.data = graph_ros.data.duplicate()
		pause_hunger.readout = graph_hunger.readout
		pause_ros.readout = graph_ros.readout
		pause_hunger.queue_redraw()
		pause_ros.queue_redraw()
		_open(pause_win)
	else:
		pause_win["root"].visible = false


func show_cards(ids: Array, next_gen: int, cb: Callable) -> void:
	card_ids = ids
	card_cb = cb
	cards_sub.text = "Step 1 of 1  ·  splice one mutation into Generation %d" % next_gen
	for c in cards_box.get_children():
		c.queue_free()
	var portrait := view.x < view.y
	for i in ids.size():
		cards_box.add_child(_tilted(_card(ids[i], i, portrait), [-0.035, 0.025, -0.02][i % 3] * (0.4 if portrait else 1.0)))
	_open(cards_win)


func _card(id: String, idx: int, portrait: bool) -> Control:
	var info := Mutations.info(id)
	var col := Color(String(info.get("color", "ffffff")))
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Aero.shadow_box(30, 12, 0.22))
	pc.custom_minimum_size = Vector2(minf(560.0, view.x - 140.0), 0.0) if portrait else Vector2(248.0, 330.0)
	var cg := Aero.GlassRect.new(Color(col.r, col.g, col.b, 0.34), 20.0, 3.0).rims(col.lightened(0.25), YELLOW, Color.WHITE, 6.0)
	if idx % 2 == 1:
		cg.corners(16.0, 60.0, 18.0, 54.0).blob(10.0, Vector3(0.86, 0.06, 30.0))
	else:
		cg.corners(58.0, 14.0, 62.0, 18.0).blob(10.0, Vector3(0.14, 0.94, 28.0))
	pc.add_child(cg)
	var mc := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		mc.add_theme_constant_override(side, 14)
	pc.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	mc.add_child(vb)
	var badge := Aero.Orb.new(58.0, col, "", _ls(22), _ls(10))
	badge.set_value(0.62, String(info.get("type", "?")).substr(0, 1))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(badge)
	vb.add_child(_text(String(info.get("type", "")), 12, Color("e8f8ff")))
	var title := _text(String(info.get("name", id)), 21, Color.WHITE, true)
	title.label_settings = _ls(21, Color.WHITE, true, Color(col.darkened(0.4), 0.9), 8)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(title)
	var pro := _text("+ " + String(info.get("pro", "")), 15, Color("eaffd8"), false)
	pro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(pro)
	var con := _text("− " + String(info.get("con", "")), 15, Color("ffd6dc"), false)
	con.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	con.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(con)
	var b := _gel("SPLICE  %d" % (idx + 1), col, Vector2(0, 48), 18, 16.0)
	b.tapped.connect(func(): _pick(id))
	vb.add_child(b)
	return pc


func pick_index(i: int) -> void:
	if cards_win["root"].visible and i >= 0 and i < card_ids.size():
		_pick(card_ids[i])


func _pick(id: String) -> void:
	if not cards_win["root"].visible:
		return
	cards_win["root"].visible = false
	card_cb.call(id)


func show_death(info: Dictionary) -> void:
	var soup: bool = info["soup"]
	var c := ACID if soup else AMBER
	death_icon.set_liquid(Color("8dff4a") if soup else Color("ff5a3a"))
	death_icon.set_value(0.7, "!")
	for ch in death_title_box.get_children():
		ch.queue_free()
	var t := Aero.gloss_title(String(info["title"]), ui_bold, 44, Color.WHITE, c, Color(c.darkened(0.55), 0.85))
	death_title_box.custom_minimum_size = t.custom_minimum_size
	death_title_box.add_child(t)
	death_flavor.text = info["flavor"]
	death_stats.text = String(info["stats"]).replace("\n", "\n")
	var total := int(info["total"])
	var next := -1
	for id in Mutations.CARDS:
		var u := int(Mutations.CARDS[id]["unlock"])
		if u > total and (next < 0 or u < next):
			next = u
	death_dna.text = "+%d mtDNA  ·  banked %d" % [int(info["earned"]), total]
	if next > 0:
		death_tube.set_fill(float(total) / next, Color("39c8ff"))
		death_dna.text += "  ·  next unlock at %d" % next
	else:
		death_tube.set_fill(1.0, Color("ffd23d"))
	var unl: Array = info["unlocks"]
	death_unlock.text = ("NEW MUTATIONS UNLOCKED: " + ", ".join(PackedStringArray(unl))) if unl.size() > 0 else ""
	_open(death_win)
