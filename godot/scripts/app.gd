extends Node

## Global app singleton: input map, UI theme, save data, audio playback.

const SAVE_PATH := "user://garden.cfg"

const C := {
	"cream": Color("#f6eedb"),
	"paper": Color("#efe4cc"),
	"ink": Color("#221d16"),
	"deep": Color("#16281d"),
	"forest": Color("#274b33"),
	"leaf": Color("#5f9d47"),
	"leaf_hi": Color("#7cbb5c"),
	"gold": Color("#f2c14e"),
	"gold_hi": Color("#ffd977"),
	"danger": Color("#d0503f"),
	"ice": Color("#8fd4ea"),
	"shadow": Color(0.05, 0.06, 0.04, 0.72),
}

var font_body: FontFile
var font_bold: FontFile
var theme: Theme

var save := {
	"stars": {},
	"best": {},
	"unlocked": 0,
	"picks": {},
}
var settings := {
	"sensitivity": 0.0022,
	"volume": 0.7,
	"invert_y": false,
	"shake": true,
}

var _sfx: Dictionary = {}
var _p2d: Array[AudioStreamPlayer] = []
var _p3d: Array[AudioStreamPlayer3D] = []
var _i2d := 0
var _i3d := 0
var _wind: AudioStreamPlayer

const SFX_NAMES := [
	"click", "select", "deny", "plant", "dig", "shoot", "hit", "chomp",
	"explode", "shove", "freeze", "sun", "groan1", "groan2", "groan3",
	"wave", "mower", "step_grass", "step_wood", "step_water", "win", "lose",
	"door_open", "door_close", "chimney",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_fonts()
	_build_theme()
	_load_save()
	_setup_audio()
	DisplayServer.window_set_title("花园防线 3D")


# --- input -----------------------------------------------------------------

func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _setup_input() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_forward", KEY_UP)
	_add_key("move_back", KEY_S)
	_add_key("move_back", KEY_DOWN)
	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT)
	_add_key("jump", KEY_SPACE)
	_add_key("sprint", KEY_SHIFT)
	_add_key("interact", KEY_E)
	_add_key("shove", KEY_F)
	_add_mouse("shove", MOUSE_BUTTON_RIGHT)
	_add_key("dig", KEY_Q)
	_add_key("plant", KEY_R)
	_add_mouse("plant", MOUSE_BUTTON_LEFT)
	_add_key("grid", KEY_TAB)
	_add_key("pause", KEY_ESCAPE)
	for i in range(9):
		_add_key("slot_%d" % (i + 1), KEY_1 + i)


# --- fonts / theme ---------------------------------------------------------

func _setup_fonts() -> void:
	font_body = load("res://fonts/NotoSansSC.otf") as FontFile
	font_bold = load("res://fonts/NotoSansSC-Bold.otf") as FontFile
	if font_body:
		font_body.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font_body.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	if font_bold:
		font_bold.antialiasing = TextServer.FONT_ANTIALIASING_GRAY


func _sb(color: Color, radius := 8, border := 0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.anti_aliasing = true
	return sb


func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font = font_body
	theme.default_font_size = 16

	theme.set_stylebox("panel", "Panel", _sb(Color(0.08, 0.13, 0.10, 0.86), 14, 1, Color(0.55, 0.75, 0.5, 0.25)))
	theme.set_stylebox("panel", "PanelContainer", _sb(Color(0.09, 0.14, 0.11, 0.92), 16, 1, Color(0.6, 0.8, 0.55, 0.22)))

	var b_normal := _sb(Color("#2f5a3c"), 10, 1, Color("#6f9a5f"))
	var b_hover := _sb(Color("#3c6f4a"), 10, 1, Color("#9dc47f"))
	var b_press := _sb(Color("#24462f"), 10, 2, Color("#c8e0a0"))
	var b_disabled := _sb(Color("#2a3029"), 10, 1, Color("#3f4a3d"))
	var b_focus := _sb(Color(0, 0, 0, 0), 10, 2, Color("#f2c14e"))
	for t in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", t, b_normal)
		theme.set_stylebox("hover", t, b_hover)
		theme.set_stylebox("pressed", t, b_press)
		theme.set_stylebox("disabled", t, b_disabled)
		theme.set_stylebox("focus", t, b_focus)
		theme.set_color("font_color", t, Color("#f3ecd9"))
		theme.set_color("font_hover_color", t, Color("#ffffff"))
		theme.set_color("font_pressed_color", t, Color("#ffe9a8"))
		theme.set_color("font_disabled_color", t, Color("#8b9384"))
		theme.set_font_size("font_size", t, 18)

	theme.set_color("font_color", "Label", Color("#f3ecd9"))
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 2)

	theme.set_stylebox("background", "ProgressBar", _sb(Color(0.05, 0.09, 0.07, 0.85), 8))
	theme.set_stylebox("fill", "ProgressBar", _sb(Color("#7cbb5c"), 8))
	theme.set_font_size("font_size", "ProgressBar", 14)

	theme.set_color("font_color", "RichTextLabel", Color("#f3ecd9"))
	theme.set_stylebox("normal", "RichTextLabel", _sb(Color(0, 0, 0, 0), 0))

	var ck_empty := _sb(Color(0, 0, 0, 0), 6)
	ck_empty.content_margin_left = 2
	theme.set_stylebox("normal", "CheckBox", ck_empty)
	theme.set_stylebox("pressed", "CheckBox", ck_empty)
	theme.set_stylebox("hover", "CheckBox", _sb(Color(1, 1, 1, 0.07), 6))
	theme.set_stylebox("disabled", "CheckBox", ck_empty)
	theme.set_font_size("font_size", "CheckBox", 16)
	theme.set_color("font_color", "CheckBox", Color("#e8e0cc"))
	theme.set_color("font_hover_color", "CheckBox", Color("#ffffff"))

	theme.set_stylebox("slider", "HSlider", _sb(Color(0.1, 0.16, 0.12, 0.9), 4))
	theme.set_stylebox("grabber_area", "HSlider", _sb(Color("#7cbb5c"), 4))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _sb(Color("#a4dc7e"), 4))


func title(text: String, size := 34, color := C["cream"]) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", max(0, int(size * 0.14)))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.05, 0.85))
	return l


# --- audio -----------------------------------------------------------------

func _setup_audio() -> void:
	for n in SFX_NAMES:
		var path := "res://audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_sfx[n] = load(path)
	for i in range(10):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_p2d.append(p)
	var holder := Node3D.new()
	holder.name = "SpatialSfx"
	add_child(holder)
	for i in range(12):
		var p := AudioStreamPlayer3D.new()
		p.bus = "Master"
		p.max_distance = 26.0
		p.unit_size = 6.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		holder.add_child(p)
		_p3d.append(p)
	_wind = AudioStreamPlayer.new()
	_wind.stream = load("res://audio/wind.wav")
	_wind.bus = "Master"
	_wind.volume_db = -22.0
	add_child(_wind)
	_wind.play()


func _exit_tree() -> void:
	# the ambience keeps a stream alive past shutdown otherwise, which shows up
	# as "1 resources still in use at exit"
	if _wind != null:
		_wind.stop()
		_wind.stream = null
	_wind = null
	_sfx.clear()


func sfx(name: String, db := 0.0, pitch := 1.0) -> void:
	var s: AudioStream = _sfx.get(name)
	if s == null:
		return
	var p := _p2d[_i2d % _p2d.size()]
	_i2d += 1
	p.stream = s
	p.volume_db = db + linear_to_db(clamp(settings["volume"], 0.0, 1.0))
	p.pitch_scale = pitch
	p.play()


func sfx_at(name: String, pos: Vector3, db := -4.0, pitch := 1.0) -> void:
	var s: AudioStream = _sfx.get(name)
	if s == null:
		return
	var p := _p3d[_i3d % _p3d.size()]
	_i3d += 1
	p.stream = s
	p.global_position = pos
	p.volume_db = db + linear_to_db(clamp(settings["volume"], 0.0, 1.0))
	p.pitch_scale = pitch
	p.play()


func set_wind(on: bool) -> void:
	if on and not _wind.playing:
		_wind.play()
	elif not on and _wind.playing:
		_wind.stop()


# --- save ------------------------------------------------------------------

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for k in save.keys():
		save[k] = cfg.get_value("save", k, save[k])
	for k in settings.keys():
		settings[k] = cfg.get_value("settings", k, settings[k])


func persist() -> void:
	var cfg := ConfigFile.new()
	for k in save.keys():
		cfg.set_value("save", k, save[k])
	for k in settings.keys():
		cfg.set_value("settings", k, settings[k])
	cfg.save(SAVE_PATH)


func stars_for(id: String) -> int:
	return int(save["stars"].get(id, 0))


func record_level(id: String, stars: int, seconds: float) -> void:
	var prev := stars_for(id)
	if stars > prev:
		save["stars"][id] = stars
	var best: float = float(save["best"].get(id, 0.0))
	if best <= 0.0 or seconds < best:
		save["best"][id] = seconds
	persist()


func picks_for(id: String) -> Array:
	var raw = save.get("picks", {}).get(id, [])
	var out: Array = []
	if raw is Array:
		for k in raw:
			if Data.PLANTS.has(str(k)) and not out.has(str(k)):
				out.append(str(k))
	return out


func set_picks(id: String, kinds: Array) -> void:
	var out: Array = []
	for k in kinds:
		if Data.PLANTS.has(str(k)) and not out.has(str(k)):
			out.append(str(k))
	save["picks"][id] = out
	persist()


func unlocked_count() -> int:
	return int(save.get("unlocked", 0))
