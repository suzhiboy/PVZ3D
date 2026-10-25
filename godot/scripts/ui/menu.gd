class_name MenuScreen
extends CanvasLayer

## Title screen: level select over a slow pan of the garden.

signal level_chosen(id: String)
signal endless_chosen
signal continue_pressed
signal settings_changed
signal quit_pressed

var root: Control
var cards: Array = []
var _settings: Control
var _sens: HSlider
var _vol: HSlider
var _invert: CheckBox
var _shake: CheckBox
var _continue: Button
var _hero: PlantIcon
var _endless: EndlessCard
var _purse: CoinPurse
var _music: HSlider


## 标题界面的钱袋读数：跨对局累计的金币余额（用途待定，先把账记上）。
class CoinPurse extends Control:
	var shown := 0
	var _bg: StyleBoxFlat

	func _ready() -> void:
		custom_minimum_size = Vector2(280, 46)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg = StyleBoxFlat.new()
		_bg.bg_color = Color(0.06, 0.05, 0.035, 0.72)
		_bg.set_corner_radius_all(16)
		_bg.set_border_width_all(1)
		_bg.border_color = Color(0.85, 0.7, 0.35, 0.3)

	func _draw() -> void:
		draw_style_box(_bg, Rect2(Vector2.ZERO, size))
		var c := Vector2(26, 23)
		draw_circle(c, 13.0, Color("#e7b94e"))
		draw_circle(c, 9.0, Color("#f6d377"))
		draw_arc(c, 13.0, -0.6, PI + 0.6, 22, Color(1.0, 0.92, 0.62, 0.65), 1.4, true)
		draw_string(App.font_bold, Vector2(48, 30), str(shown), HORIZONTAL_ALIGNMENT_LEFT, 130, 21, Color("#ffe6a1"))
		draw_string(App.font_body, Vector2(170, 30), "钱袋 · 用途待定", HORIZONTAL_ALIGNMENT_LEFT, 104, 11, Color(1, 1, 1, 0.38))


## The endless run gets its own card: it has no wave count and no stars, so the
## level-card layout does not fit it.
class EndlessCard extends Control:
	signal chosen

	var best := 0
	var _hover := false
	var _bg: StyleBoxFlat
	var _bg_hover: StyleBoxFlat

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_bg = StyleBoxFlat.new()
		_bg.bg_color = Color(0.105, 0.078, 0.058, 0.94)
		_bg.set_corner_radius_all(18)
		_bg.set_border_width_all(1)
		_bg.border_color = Color(0.8, 0.59, 0.36, 0.34)
		_bg.shadow_color = Color(0.025, 0.018, 0.012, 0.46)
		_bg.shadow_size = 12
		_bg_hover = _bg.duplicate()
		_bg_hover.bg_color = Color(0.17, 0.115, 0.078, 0.97)
		_bg_hover.border_color = Color(0.96, 0.73, 0.42, 0.76)
		mouse_entered.connect(func() -> void:
			_hover = true
		)
		mouse_exited.connect(func() -> void:
			_hover = false
		)

	func _process(_d: float) -> void:
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				chosen.emit()
				accept_event()

	func _draw() -> void:
		draw_style_box(_bg_hover if _hover else _bg, Rect2(Vector2.ZERO, size))
		draw_line(Vector2(20, 1.5), Vector2(size.x - 20, 1.5), Color(1.0, 0.86, 0.6, 0.2), 1.0, true)
		draw_rect(Rect2(Vector2(0, 16), Vector2(5, size.y - 32)), Color("#d5945d"), true)
		# a big infinity mark, half hidden behind the text block
		draw_string(App.font_bold, Vector2(size.x - 210, size.y * 0.5 + 54), "∞",
			HORIZONTAL_ALIGNMENT_RIGHT, 190, 118, Color(1.0, 0.68, 0.42, 0.11))

		draw_string(App.font_body, Vector2(30, 34), "S U R V I V A L", HORIZONTAL_ALIGNMENT_LEFT, 300, 12,
			Color(0.96, 0.72, 0.49, 0.72))
		draw_string(App.font_bold, Vector2(30, 74), "无尽模式", HORIZONTAL_ALIGNMENT_LEFT, 300, 32, Color("#f6e7cf"))
		draw_string(App.font_body, Vector2(30, 104), "没有终点，只有下一波", HORIZONTAL_ALIGNMENT_LEFT, 340, 15,
			Color(1, 1, 1, 0.55))
		var rec := "最佳记录 %d 波" % best if best > 0 else "还没有记录"
		draw_string(App.font_body, Vector2(30, 132), rec, HORIZONTAL_ALIGNMENT_LEFT, 300, 14,
			Color(1.0, 0.82, 0.5, 0.9) if best > 0 else Color(1, 1, 1, 0.35))
		draw_string(App.font_body, Vector2(30, 158), "点击开始 →" if _hover else "会越来越难",
			HORIZONTAL_ALIGNMENT_LEFT, 300, 13,
			Color(1.0, 0.88, 0.55, 0.95) if _hover else Color(1, 1, 1, 0.3))


class LevelCard extends Control:
	signal chosen(id: String)

	var level_id := ""
	var index := 0
	var level_name := ""
	var subtitle := ""
	var stars := 0
	var locked := false
	var waves := 0
	var _hover := false
	var _bg: StyleBoxFlat
	var _bg_hover: StyleBoxFlat

	func _ready() -> void:
		custom_minimum_size = Vector2(580, 98)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_bg = StyleBoxFlat.new()
		_bg.bg_color = Color(0.061, 0.104, 0.081, 0.94)
		_bg.set_corner_radius_all(16)
		_bg.set_border_width_all(1)
		_bg.border_color = Color(0.72, 0.61, 0.4, 0.26)
		_bg.shadow_color = Color(0.015, 0.022, 0.016, 0.4)
		_bg.shadow_size = 10
		_bg_hover = _bg.duplicate()
		_bg_hover.bg_color = Color(0.13, 0.21, 0.145, 0.95)
		_bg_hover.border_color = Color(0.93, 0.79, 0.48, 0.65)
		mouse_entered.connect(func() -> void:
			_hover = true
		)
		mouse_exited.connect(func() -> void:
			_hover = false
		)

	func _process(delta: float) -> void:
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if locked:
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				chosen.emit(level_id)
				accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(_bg_hover if _hover and not locked else _bg, r)
		draw_line(Vector2(20, 1.5), Vector2(size.x - 20, 1.5), Color(1.0, 0.9, 0.68, 0.13), 1.0, true)
		var accent: Color = [Color("#7fae63"), Color("#d2ae60"), Color("#70b8c4"), Color("#a988c9")][index % 4]
		draw_rect(Rect2(Vector2(0, 14), Vector2(5, size.y - 28)), accent if not locked else Color(1, 1, 1, 0.1), true)

		# index badge
		var badge := Vector2(52, 30)
		draw_circle(Vector2(52, size.y * 0.5), 19.0, Color(accent.r, accent.g, accent.b, 0.16))
		draw_arc(Vector2(52, size.y * 0.5), 19.5, 0.0, TAU, 30, Color(accent.r, accent.g, accent.b, 0.32), 1.0, true)
		draw_string(App.font_bold, Vector2(32, size.y * 0.5 + 7), "%02d" % (index + 1), HORIZONTAL_ALIGNMENT_CENTER, 40, 18,
			accent if not locked else Color(1, 1, 1, 0.25))

		var name_col := Color("#f3ecdc") if not locked else Color(1, 1, 1, 0.28)
		draw_string(App.font_bold, Vector2(88, 40), level_name, HORIZONTAL_ALIGNMENT_LEFT, 280, 24, name_col)
		draw_string(App.font_body, Vector2(88, 66), subtitle, HORIZONTAL_ALIGNMENT_LEFT, 430, 14,
			Color(0.91, 0.89, 0.8, 0.56) if not locked else Color(1, 1, 1, 0.2))
		draw_string(App.font_body, Vector2(88, 86), "波次 %d" % waves, HORIZONTAL_ALIGNMENT_LEFT, 120, 12,
			Color(0.9, 0.86, 0.76, 0.36))

		# stars
		for i in range(3):
			var s := "★" if i < stars else "☆"
			draw_string(App.font_bold, Vector2(size.x - 108 + i * 30, 44), s, HORIZONTAL_ALIGNMENT_LEFT, 30, 22,
				Color("#dfbb69") if i < stars else Color(1, 1, 1, 0.16))

		if locked:
			draw_string(App.font_body, Vector2(size.x - 112, 74), "通关上一关解锁", HORIZONTAL_ALIGNMENT_LEFT, 110, 11,
				Color(1, 1, 1, 0.28))
		elif _hover:
			draw_string(App.font_body, Vector2(size.x - 112, 74), "点击开始 →", HORIZONTAL_ALIGNMENT_LEFT, 110, 12,
				Color(0.97, 0.86, 0.56, 0.92))


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = App.theme
	add_child(root)

	var grad := ColorRect.new()
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/gradient.gdshader")
	grad.material = gm
	root.add_child(grad)

	var tag := Label.new()
	tag.text = "G A R D E N   D E F E N S E"
	tag.position = Vector2(92, 96)
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 0.85))
	root.add_child(tag)

	var title := App.title("花园防线 3D", 64)
	title.position = Vector2(86, 122)
	root.add_child(title)

	var sub := Label.new()
	sub.text = "第一人称 · 亲手走过庭院，种下每一株植物"
	sub.position = Vector2(92, 206)
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.62))
	root.add_child(sub)

	var header := Label.new()
	header.text = "选择关卡"
	header.position = Vector2(92, 232)
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	root.add_child(header)

	for i in range(Data.LEVELS.size()):
		var lv: Dictionary = Data.LEVELS[i]
		var c := LevelCard.new()
		c.level_id = str(lv["id"])
		c.index = i
		c.level_name = str(lv["name"])
		c.subtitle = str(lv["subtitle"])
		c.waves = lv["waves"].size()
		c.chosen.connect(_on_level)
		root.add_child(c)
		c.position = Vector2(90, 256 + i * 110)
		c.size = Vector2(580, 98)
		cards.append(c)

	_purse = CoinPurse.new()
	_purse.position = Vector2(1120, 114)
	_purse.size = Vector2(280, 46)
	root.add_child(_purse)

	_endless = EndlessCard.new()
	_endless.position = Vector2(700, 256)
	_endless.size = Vector2(520, 180)
	_endless.tooltip_text = "无尽模式"
	_endless.chosen.connect(func() -> void:
		App.sfx("click", -4.0)
		endless_chosen.emit()
	)
	root.add_child(_endless)

	_continue = Button.new()
	_continue.text = "继续游戏"
	_continue.position = Vector2(90, 706)
	_continue.size = Vector2(210, 52)
	_continue.pressed.connect(func() -> void: continue_pressed.emit())
	root.add_child(_continue)

	var sbtn := Button.new()
	sbtn.text = "设置"
	sbtn.position = Vector2(312, 706)
	sbtn.size = Vector2(132, 52)
	sbtn.pressed.connect(_open_settings)
	root.add_child(sbtn)

	var qbtn := Button.new()
	qbtn.text = "退出"
	qbtn.position = Vector2(456, 706)
	qbtn.size = Vector2(132, 52)
	qbtn.pressed.connect(func() -> void: quit_pressed.emit())
	root.add_child(qbtn)

	var hint := Label.new()
	hint.text = "点击关卡 → 挑选出战植物 · 无尽模式没有终点 · WASD 移动 · 左键种植 · 1-9 选卡"
	hint.position = Vector2(92, 780)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	root.add_child(hint)

	var pedestal := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.09, 0.07, 0.55)
	ps.set_corner_radius_all(140)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.85, 0.9, 0.6, 0.22)
	pedestal.add_theme_stylebox_override("panel", ps)
	pedestal.position = Vector2(1268, 486)
	pedestal.size = Vector2(272, 272)
	root.add_child(pedestal)

	_hero = PlantIcon.new()
	_hero.kind = "peashooter"
	_hero.position = Vector2(1284, 502)
	_hero.size = Vector2(240, 240)
	root.add_child(_hero)

	var note := Label.new()
	note.text = "%d 种植物 · %d 种僵尸 · 一座完整的院子" % [Data.PLANTS.size(), Data.zombie_kinds().size()]
	note.position = Vector2(1240, 800)
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	root.add_child(note)

	_build_settings()


func _on_level(id: String) -> void:
	App.sfx("click", -4.0)
	level_chosen.emit(id)


func refresh() -> void:
	var prev_ok := true
	for i in range(cards.size()):
		var c: LevelCard = cards[i]
		c.stars = App.stars_for(c.level_id)
		c.locked = not prev_ok
		prev_ok = c.stars > 0
	var any := false
	for i in range(Data.LEVELS.size()):
		if App.stars_for(str(Data.LEVELS[i]["id"])) > 0:
			any = true
	_continue.visible = any
	_continue.text = "继续游戏"
	if _endless:
		_endless.best = App.endless_best()
	if _purse:
		_purse.shown = App.wallet()
		_purse.queue_redraw()
	if _hero:
		_hero.kind = "peashooter"


func show_menu(on: bool) -> void:
	root.visible = on
	if on:
		refresh()
		_settings.visible = false


func _build_settings() -> void:
	_settings = Control.new()
	_settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings.visible = false
	root.add_child(_settings)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.03, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings.add_child(dim)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260, -240)
	panel.size = Vector2(520, 480)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.12, 0.09, 0.98)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.7, 0.85, 0.55, 0.3)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	_settings.add_child(panel)

	var v := VBoxContainer.new()
	v.position = Vector2(26, 22)
	v.size = Vector2(468, 436)
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var t := App.title("设置", 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)

	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 12)
	var sl := Label.new()
	sl.text = "鼠标灵敏度"
	sl.custom_minimum_size = Vector2(130, 0)
	srow.add_child(sl)
	_sens = HSlider.new()
	_sens.min_value = 0.0006
	_sens.max_value = 0.006
	_sens.step = 0.0001
	_sens.value = App.settings["sensitivity"]
	_sens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sens.value_changed.connect(func(x: float) -> void:
		App.settings["sensitivity"] = x
		settings_changed.emit()
	)
	srow.add_child(_sens)
	v.add_child(srow)

	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 12)
	var vl := Label.new()
	vl.text = "音量"
	vl.custom_minimum_size = Vector2(130, 0)
	vrow.add_child(vl)
	_vol = HSlider.new()
	_vol.min_value = 0.0
	_vol.max_value = 1.0
	_vol.step = 0.02
	_vol.value = App.settings["volume"]
	_vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vol.value_changed.connect(func(x: float) -> void:
		App.settings["volume"] = x
		settings_changed.emit()
	)
	vrow.add_child(_vol)
	v.add_child(vrow)

	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 12)
	var ml := Label.new()
	ml.text = "音乐音量"
	ml.custom_minimum_size = Vector2(130, 0)
	mrow.add_child(ml)
	_music = HSlider.new()
	_music.min_value = 0.0
	_music.max_value = 1.0
	_music.step = 0.02
	_music.value = App.settings.get("music", 0.7)
	_music.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music.value_changed.connect(func(x: float) -> void:
		App.settings["music"] = x
		App.refresh_music_volume()
		settings_changed.emit()
	)
	mrow.add_child(_music)
	v.add_child(mrow)

	_shake = CheckBox.new()
	_shake.text = "屏幕震动"
	_shake.button_pressed = App.settings["shake"]
	_shake.toggled.connect(func(on: bool) -> void:
		App.settings["shake"] = on
		settings_changed.emit()
	)
	v.add_child(_shake)

	_invert = CheckBox.new()
	_invert.text = "反转垂直视角"
	_invert.button_pressed = App.settings["invert_y"]
	_invert.toggled.connect(func(on: bool) -> void:
		App.settings["invert_y"] = on
		settings_changed.emit()
	)
	v.add_child(_invert)

	var close := Button.new()
	close.text = "返回"
	close.custom_minimum_size = Vector2(0, 46)
	close.pressed.connect(func() -> void: _settings.visible = false)
	v.add_child(close)


func _open_settings() -> void:
	_settings.visible = true
	_sens.value = App.settings["sensitivity"]
	_vol.value = App.settings["volume"]
	_music.value = float(App.settings.get("music", 0.7))
	_shake.button_pressed = App.settings["shake"]
	_invert.button_pressed = App.settings["invert_y"]
