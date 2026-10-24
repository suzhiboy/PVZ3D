class_name Hud
extends CanvasLayer

## All in-game UI: sun counter, seed packets, wave meter, reticle, banners,
## pause menu and the end-of-level screen.

signal resume_pressed
signal restart_pressed
signal menu_pressed
signal next_pressed
signal settings_changed

var match_ref
var player_ref

var root: Control
var _sun: SunPanel
var _wave: WavePanel
var _seed_wrap: Panel
var _seed_box: HBoxContainer
var _cards: Array = []
var _hint: Label
var _reticle: Reticle
var _stamina: StaminaBar
var _prompt: Label
var _banner: Label
var _vignette: ColorRect
var _pause: Control
var _end: Control
var _end_title: Label
var _end_stats: Label
var _end_stars: Array = []
var _next_btn: Button
var _banner_tween: Tween
var _level_name := ""


# ===========================================================================
# custom drawn widgets
# ===========================================================================

class SunPanel extends Control:
	var shown := 150.0
	var target := 150.0
	var _bg: StyleBoxFlat
	var _t := 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(176, 68)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg = StyleBoxFlat.new()
		_bg.bg_color = Color(0.07, 0.12, 0.09, 0.82)
		_bg.set_corner_radius_all(16)
		_bg.set_border_width_all(2)
		_bg.border_color = Color(0.85, 0.72, 0.34, 0.55)
		_bg.shadow_color = Color(0, 0, 0, 0.35)
		_bg.shadow_size = 8

	func _process(delta: float) -> void:
		_t += delta
		shown = lerp(shown, target, delta * 8.0)
		queue_redraw()

	func _draw() -> void:
		draw_style_box(_bg, Rect2(Vector2.ZERO, size))
		var c := Vector2(38, 34)
		var pulse := 1.0 + sin(_t * 2.2) * 0.03
		draw_circle(c, 18.0 * pulse, Color("#f2c14e"))
		draw_circle(c, 14.0 * pulse, Color("#ffd977"))
		for i in range(8):
			var a := TAU * i / 8.0 + _t * 0.25
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * 20.0, c + d * 25.0, Color(1.0, 0.85, 0.42, 0.9), 2.5, true)
		var f: Font = App.font_bold
		draw_string(f, Vector2(68, 44), str(int(round(shown))), HORIZONTAL_ALIGNMENT_LEFT, 100, 30, Color("#ffe9a8"))
		draw_string(App.font_body, Vector2(70, 58), "阳光", HORIZONTAL_ALIGNMENT_LEFT, 60, 11, Color(1, 1, 1, 0.45))


class WavePanel extends Control:
	var level_name := ""
	var progress := 0.0
	var waves := 5
	var alive := 0
	var _bg: StyleBoxFlat
	var _t := 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(470, 62)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg = StyleBoxFlat.new()
		_bg.bg_color = Color(0.07, 0.12, 0.09, 0.78)
		_bg.set_corner_radius_all(14)
		_bg.set_border_width_all(1)
		_bg.border_color = Color(0.7, 0.85, 0.6, 0.22)

	func set_data(p_level: String, p_prog: float, p_waves: int, p_alive: int) -> void:
		level_name = p_level
		progress = p_prog
		waves = max(1, p_waves)
		alive = p_alive
		queue_redraw()

	func _draw() -> void:
		draw_style_box(_bg, Rect2(Vector2.ZERO, size))
		var f: Font = App.font_bold
		draw_string(f, Vector2(18, 24), level_name, HORIZONTAL_ALIGNMENT_LEFT, 260, 16, Color("#f6eedb"))
		draw_string(App.font_body, Vector2(size.x - 130, 24), "僵尸 %d" % alive, HORIZONTAL_ALIGNMENT_RIGHT, 112, 13,
			Color(1.0, 0.82, 0.62) if alive > 0 else Color(1, 1, 1, 0.5))

		var bar := Rect2(18, 34, size.x - 36, 10)
		draw_rect(bar, Color(0.02, 0.05, 0.04, 0.75), true)
		var fill_w: float = bar.size.x * clamp(progress, 0.0, 1.0)
		if fill_w > 0.5:
			draw_rect(Rect2(bar.position, Vector2(fill_w, bar.size.y)), Color("#7cbb5c"), true)
			draw_rect(Rect2(bar.position, Vector2(fill_w, bar.size.y * 0.45)), Color(1, 1, 1, 0.16), true)
		for i in range(waves + 1):
			var x := bar.position.x + bar.size.x * float(i) / float(waves)
			draw_line(Vector2(x, bar.position.y - 2), Vector2(x, bar.position.y + bar.size.y + 2),
				Color(1, 1, 1, 0.22), 1.0)
		# the flag for each wave that has started
		var started := int(round(progress * waves))
		for i in range(started):
			var x2 := bar.position.x + bar.size.x * float(i) / float(waves) + 3.0
			draw_line(Vector2(x2, bar.position.y - 5), Vector2(x2, bar.position.y + bar.size.y + 4), Color("#f2c14e"), 2.0)


class Reticle extends Control:
	var valid := false
	var aiming := false
	var has_target := false
	var _t := 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(54, 54)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var col := Color(1, 1, 1, 0.82)
		if aiming:
			col = Color("#9bff7a") if valid else Color("#ff7a68")
		var gap := 6.0
		var ln := 7.0
		var w := 2.0
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(c + d * gap, c + d * (gap + ln), col, w, true)
		draw_circle(c, 1.8, col)
		if aiming and valid:
			var r := 15.0 + sin(_t * 5.0) * 1.2
			draw_arc(c, r, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.5), 1.6, true)


class StaminaBar extends Control:
	var ratio := 1.0

	func _ready() -> void:
		custom_minimum_size = Vector2(190, 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_ratio(r: float) -> void:
		ratio = clamp(r, 0.0, 1.0)
		visible = ratio < 0.995
		queue_redraw()

	func _draw() -> void:
		var bg := Rect2(Vector2.ZERO, size)
		draw_rect(bg, Color(0.03, 0.06, 0.05, 0.7), true)
		var col := Color("#9ad46a") if ratio > 0.3 else Color("#e0a13a")
		draw_rect(Rect2(bg.position + Vector2(2, 2), Vector2((size.x - 4) * ratio, size.y - 4)), col, true)


class SeedCard extends Control:
	signal picked(kind: String)

	var kind := ""
	var display_name := ""
	var cost := 0
	var usable := true
	var cd01 := 0.0
	var cd_left := 0.0
	var affordable := true
	var is_selected := false
	var index := 0
	var _hover := false
	var _bg: StyleBoxFlat
	var _bg_sel: StyleBoxFlat
	var _icon: PlantIcon
	var _t := 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(98, 126)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_bg = StyleBoxFlat.new()
		_bg.bg_color = Color(0.10, 0.16, 0.12, 0.9)
		_bg.set_corner_radius_all(10)
		_bg.set_border_width_all(2)
		_bg.border_color = Color(0.75, 0.68, 0.45, 0.35)
		_bg.shadow_color = Color(0, 0, 0, 0.4)
		_bg.shadow_size = 6
		_bg_sel = _bg.duplicate()
		_bg_sel.border_color = Color("#ffe08a")
		_bg_sel.set_border_width_all(3)
		_bg_sel.bg_color = Color(0.18, 0.27, 0.16, 0.95)
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw()
		)
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw()
		)

	func setup_icon(icon_kind: String) -> void:
		_icon = PlantIcon.new()
		_icon.kind = icon_kind
		_icon.position = Vector2(7, 24)
		_icon.size = Vector2(84, 74)
		add_child(_icon)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				picked.emit(kind)
				accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(_bg_sel if is_selected else _bg, r)
		var txt := Color("#f6eedb") if affordable else Color(0.85, 0.85, 0.8, 0.45)
		if _hover and affordable:
			draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(1, 1, 1, 0.05), true)

		# icon window
		draw_rect(Rect2(Vector2(9, 26), Vector2(80, 70)), Color(0.03, 0.06, 0.05, 0.55), true)

		# cost badge
		draw_circle(Vector2(16, 16), 7.0, Color("#f2c14e"))
		draw_string(App.font_bold, Vector2(25, 22), str(cost), HORIZONTAL_ALIGNMENT_LEFT, 60, 14,
			Color("#ffe9a8") if affordable else Color(1.0, 0.6, 0.5, 0.8))

		# hotkey
		draw_string(App.font_body, Vector2(size.x - 18, 21), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, 16, 12,
			Color(1, 1, 1, 0.4))

		# name
		draw_string(App.font_body, Vector2(0, 116), display_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, txt)

		if cd01 > 0.001:
			var h: float = 70.0 * clamp(cd01, 0.0, 1.0)
			draw_rect(Rect2(Vector2(9, 26), Vector2(80, h)), Color(0.02, 0.05, 0.04, 0.72), true)
			draw_string(App.font_bold, Vector2(0, 70), "%.1f" % cd_left, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20,
				Color(1, 1, 1, 0.85))
		elif not affordable:
			draw_rect(Rect2(Vector2(9, 26), Vector2(80, 70)), Color(0.02, 0.03, 0.05, 0.45), true)


# ===========================================================================
# setup
# ===========================================================================

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = App.theme
	add_child(root)

	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = preload("res://shaders/vignette.gdshader")
	_vignette.material = vm
	_vignette.color = Color(1, 1, 1, 0.0)
	root.add_child(_vignette)

	_sun = SunPanel.new()
	_sun.position = Vector2(24, 20)
	_sun.size = Vector2(176, 68)
	root.add_child(_sun)

	_wave = WavePanel.new()
	_wave.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_wave.position = Vector2(-235, 18)
	_wave.size = Vector2(470, 62)
	root.add_child(_wave)

	_reticle = Reticle.new()
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.position = Vector2(-27, -27)
	_reticle.size = Vector2(54, 54)
	root.add_child(_reticle)

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-400, -188)
	_hint.size = Vector2(800, 28)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
	root.add_child(_hint)

	_seed_wrap = Panel.new()
	_seed_wrap.add_theme_stylebox_override("panel", _panel_style())
	_seed_wrap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_seed_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_seed_wrap)

	_stamina = StaminaBar.new()
	_stamina.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_stamina.position = Vector2(800 - 95, 900 - 212)
	_stamina.size = Vector2(190, 12)
	root.add_child(_stamina)

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-260, 42)
	_prompt.size = Vector2(520, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_override("font", App.font_bold)
	_prompt.add_theme_font_size_override("font_size", 17)
	_prompt.add_theme_color_override("font_color", Color("#ffe9a8"))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.03, 0.9))
	_prompt.text = ""
	root.add_child(_prompt)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-500, 150)
	_banner.size = Vector2(1000, 70)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_override("font", App.font_bold)
	_banner.add_theme_font_size_override("font_size", 44)
	_banner.add_theme_color_override("font_color", Color("#ffe08a"))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", Color(0.16, 0.06, 0.02, 0.9))
	_banner.modulate.a = 0.0
	root.add_child(_banner)

	_build_pause()
	_build_end()


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.11, 0.09, 0.86)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.75, 0.8, 0.55, 0.2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	return sb


func bind(m, p) -> void:
	match_ref = m
	player_ref = p
	_level_name = str(m.level["name"])
	_sun.target = float(m.sun)
	_sun.shown = float(m.sun)
	_build_cards(m)
	m.wave_banner.connect(banner)
	m.state_changed.connect(_on_state)
	_hint.text = m.hint_text()


func _build_cards(m) -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()
	var slots: Array = m.seed_slots()
	var w: int = slots.size() * 104 + 20
	_seed_wrap.size = Vector2(w, 142)
	var vp := get_viewport().get_visible_rect().size
	_seed_wrap.position = Vector2(vp.x * 0.5 - w * 0.5, vp.y - 152)
	var i := 0
	for slot in slots:
		var card := SeedCard.new()
		card.kind = str(slot["kind"])
		card.display_name = str(slot["name"])
		card.cost = int(slot["cost"])
		card.index = i
		card.setup_icon(card.kind)
		card.picked.connect(_on_card)
		_seed_wrap.add_child(card)
		card.position = Vector2(10 + i * 104, 8)
		card.size = Vector2(98, 126)
		_cards.append(card)
		i += 1


func _on_card(kind: String) -> void:
	if match_ref == null:
		return
	match_ref.select_seed(kind)
	App.sfx("click", -8.0, 1.1)


func _on_state(s: String) -> void:
	if s == "won" or s == "lost":
		_reticle.visible = false


# ===========================================================================
# per-frame refresh
# ===========================================================================

func _process(delta: float) -> void:
	if match_ref == null or not is_instance_valid(match_ref):
		return
	_sun.target = float(match_ref.sun)
	_wave.set_data(_level_name, match_ref.progress(), match_ref.level["waves"].size(), match_ref.zombies.size())
	_hint.text = match_ref.hint_text()

	var slots: Array = match_ref.seed_slots()
	for i in range(min(_cards.size(), slots.size())):
		var card: SeedCard = _cards[i]
		var s: Dictionary = slots[i]
		card.usable = bool(s["ready"])
		card.cd01 = float(s["cooldown01"])
		card.cd_left = float(s["cooldown01"]) * float(Data.plant(str(s["kind"]))["recharge"])
		card.affordable = bool(s["affordable"])
		card.is_selected = bool(s["selected"])

	_reticle.aiming = match_ref.selected != ""
	_reticle.valid = match_ref._aim_ok
	_reticle.visible = match_ref.state == "playing"

	if player_ref and is_instance_valid(player_ref):
		_stamina.set_ratio(player_ref.stamina / PlayerController.STAMINA_MAX)

	# danger vignette
	var danger := 0.0
	if player_ref and is_instance_valid(player_ref) and match_ref.state == "playing":
		var pp: Vector3 = player_ref.global_position
		for z in match_ref.zombies:
			if not is_instance_valid(z):
				continue
			var d: float = Vector2(z.global_position.x - pp.x, z.global_position.z - pp.z).length()
			if d < 7.0:
				danger = max(danger, (7.0 - d) / 7.0)
	var mat := _vignette.material as ShaderMaterial
	mat.set_shader_parameter("tint", Color(0.55, 0.04, 0.02, 0.5 * danger))


func banner(text: String, big: bool) -> void:
	_banner.text = text
	_banner.add_theme_font_size_override("font_size", 52 if big else 34)
	_banner.add_theme_color_override("font_color", Color("#ffd06a") if big else Color("#f2e7cf"))
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.86, 0.86)
	_banner.modulate.a = 0.0
	if _banner_tween and _banner_tween.is_running():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.16)
	_banner_tween.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.35 if big else 0.9)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)


# ===========================================================================
# pause menu
# ===========================================================================

var _sens: HSlider
var _vol: HSlider
var _shake_cb: CheckBox
var _invert_cb: CheckBox


func _build_pause() -> void:
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	root.add_child(_pause)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-270, -318)
	panel.size = Vector2(540, 636)
	panel.add_theme_stylebox_override("panel", _dialog_style())
	_pause.add_child(panel)

	var v := VBoxContainer.new()
	v.position = Vector2(26, 22)
	v.size = Vector2(488, 592)
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var t := App.title("暂停", 34)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)

	var sub := Label.new()
	sub.text = "花园暂时安静了下来"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	sub.add_theme_font_size_override("font_size", 13)
	v.add_child(sub)

	v.add_child(_spacer(8))
	v.add_child(_button("继续游戏", func() -> void: resume_pressed.emit()))
	v.add_child(_button("重新开始本关", func() -> void: restart_pressed.emit()))
	v.add_child(_button("返回关卡选择", func() -> void: menu_pressed.emit()))

	v.add_child(_spacer(10))
	var sl := App.title("设置", 19)
	v.add_child(sl)

	var sens_row := HBoxContainer.new()
	sens_row.add_theme_constant_override("separation", 12)
	var sens_lbl := Label.new()
	sens_lbl.text = "鼠标灵敏度"
	sens_lbl.custom_minimum_size = Vector2(120, 0)
	sens_row.add_child(sens_lbl)
	_sens = HSlider.new()
	_sens.min_value = 0.0006
	_sens.max_value = 0.006
	_sens.step = 0.0001
	_sens.value = App.settings["sensitivity"]
	_sens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sens.value_changed.connect(func(v2: float) -> void:
		App.settings["sensitivity"] = v2
		settings_changed.emit()
	)
	sens_row.add_child(_sens)
	v.add_child(sens_row)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	var vol_lbl := Label.new()
	vol_lbl.text = "音量"
	vol_lbl.custom_minimum_size = Vector2(120, 0)
	vol_row.add_child(vol_lbl)
	_vol = HSlider.new()
	_vol.min_value = 0.0
	_vol.max_value = 1.0
	_vol.step = 0.02
	_vol.value = App.settings["volume"]
	_vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vol.value_changed.connect(func(v2: float) -> void:
		App.settings["volume"] = v2
		settings_changed.emit()
	)
	vol_row.add_child(_vol)
	v.add_child(vol_row)

	_shake_cb = CheckBox.new()
	_shake_cb.text = "屏幕震动"
	_shake_cb.button_pressed = App.settings["shake"]
	_shake_cb.toggled.connect(func(on: bool) -> void:
		App.settings["shake"] = on
		settings_changed.emit()
	)
	v.add_child(_shake_cb)

	_invert_cb = CheckBox.new()
	_invert_cb.text = "反转垂直视角"
	_invert_cb.button_pressed = App.settings["invert_y"]
	_invert_cb.toggled.connect(func(on: bool) -> void:
		App.settings["invert_y"] = on
		settings_changed.emit()
	)
	v.add_child(_invert_cb)

	var keys := Label.new()
	keys.text = "WASD 移动 · Shift 冲刺 · 空格 跳跃 · 1-9 选卡 · 左键 种植\nQ 铲除 · E 开门/收阳光 · F 推开僵尸"
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.add_theme_font_size_override("font_size", 12)
	keys.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	v.add_child(keys)


func _dialog_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.12, 0.09, 0.97)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.7, 0.85, 0.55, 0.32)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 24
	return sb


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(cb)
	return b


func set_prompt(text: String) -> void:
	if _prompt.text != text:
		_prompt.text = text


func set_paused(on: bool) -> void:
	_pause.visible = on
	if on:
		_sens.value = App.settings["sensitivity"]
		_vol.value = App.settings["volume"]
		_shake_cb.button_pressed = App.settings["shake"]
		_invert_cb.button_pressed = App.settings["invert_y"]
		_reticle.visible = false
	elif match_ref and is_instance_valid(match_ref) and match_ref.state == "playing":
		_reticle.visible = true


# ===========================================================================
# end screen
# ===========================================================================

func _build_end() -> void:
	_end = Control.new()
	_end.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end.visible = false
	root.add_child(_end)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.03, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end.add_child(dim)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-290, -200)
	panel.size = Vector2(580, 400)
	panel.add_theme_stylebox_override("panel", _dialog_style())
	_end.add_child(panel)

	var v := VBoxContainer.new()
	v.position = Vector2(26, 22)
	v.size = Vector2(528, 356)
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	_end_title = App.title("草坪安全了", 40)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_title)

	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 14)
	for i in range(3):
		var s := Label.new()
		s.text = "★"
		s.add_theme_font_size_override("font_size", 44)
		s.add_theme_color_override("font_color", Color(1, 1, 1, 0.16))
		stars_row.add_child(s)
		_end_stars.append(s)
	v.add_child(stars_row)

	_end_stats = Label.new()
	_end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_stats.add_theme_font_size_override("font_size", 16)
	_end_stats.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
	v.add_child(_end_stats)

	v.add_child(_spacer(10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var retry := _button("重玩本关", func() -> void: retry_signal())
	retry.custom_minimum_size = Vector2(150, 46)
	row.add_child(retry)
	_next_btn = _button("下一关", func() -> void: next_pressed.emit())
	_next_btn.custom_minimum_size = Vector2(150, 46)
	row.add_child(_next_btn)
	var menu := _button("关卡选择", func() -> void: menu_pressed.emit())
	menu.custom_minimum_size = Vector2(150, 46)
	row.add_child(menu)
	v.add_child(row)


func retry_signal() -> void:
	restart_pressed.emit()


func show_end(won: bool, stats: Dictionary) -> void:
	_end.visible = true
	_seed_wrap.visible = false
	_hint.visible = false
	_reticle.visible = false

	_end_title.text = "草坪安全了！" if won else "僵尸吃掉了脑子……"
	_end_title.add_theme_color_override("font_color", Color("#ffe08a") if won else Color("#ff9d8a"))

	var stars := int(stats.get("stars", 0))
	for i in range(_end_stars.size()):
		var s: Label = _end_stars[i]
		s.add_theme_color_override("font_color", Color("#f2c14e") if i < stars else Color(1, 1, 1, 0.16))

	_end_stats.text = "用时 %s    击杀 %d    种植 %d\n剩余小推车 %d    收集阳光 %d" % [
		fmt_time(float(stats.get("time", 0.0))),
		int(stats.get("kills", 0)),
		int(stats.get("plants", 0)),
		int(stats.get("mowers", 0)),
		int(stats.get("sun", 0)),
	]
	_next_btn.visible = bool(stats.get("has_next", false)) and won
	_end.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_end, "modulate:a", 1.0, 0.3)


func hide_end() -> void:
	_end.visible = false
	_seed_wrap.visible = true
	_hint.visible = true
	_reticle.visible = true


func fmt_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
