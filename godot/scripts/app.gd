extends Node

## Global app singleton: input map, UI theme, save data, audio playback.

const SAVE_PATH := "user://garden.cfg"

const C := {
	"cream": Color("#f3ecd9"),
	"paper": Color("#e7ddc6"),
	"ink": Color("#20241b"),
	"deep": Color("#0f1d16"),
	"forest": Color("#274535"),
	"leaf": Color("#648e4d"),
	"leaf_hi": Color("#85ae66"),
	"gold": Color("#d8b25e"),
	"gold_hi": Color("#f2d38a"),
	"danger": Color("#c45a48"),
	"ice": Color("#98cedb"),
	"shadow": Color(0.04, 0.06, 0.045, 0.74),
}

var font_body: FontFile
var font_bold: FontFile
var theme: Theme

var save := {
	"stars": {},
	"best": {},
	"unlocked": 0,
	"picks": {},
	"endless_best": 0,
	"endless_runs": 0,
	"coins": 0,
	"upgrades": {},
	"seen": [],
}
var settings := {
	"sensitivity": 0.0022,
	"volume": 0.7,
	"music": 0.7,
	"invert_y": false,
	"shake": true,
}

var _sfx: Dictionary = {}
var _p2d: Array[AudioStreamPlayer] = []
var _p3d: Array[AudioStreamPlayer3D] = []
var _i2d := 0
var _i3d := 0
var _wind: AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_tween: Tween
var _music_track := ""

## One track, three readings: the menu plays it straight, the daytime battle
## sits a little under the mix, and the night levels drop the pitch so the same
## melody reads as uneasy instead of cheerful.
const MUSIC_TRACKS := {
	"menu": {"pitch": 1.0, "db": -6.0},
	"day": {"pitch": 1.0, "db": -9.0},
	"night": {"pitch": 0.91, "db": -10.0},
	"endless": {"pitch": 1.05, "db": -8.0},
}

const SFX_NAMES := [
	"click", "select", "deny", "plant", "dig", "shoot", "hit", "chomp",
	"explode", "shove", "freeze", "sun", "groan1", "groan2", "groan3",
	"wave", "mower", "step_grass", "step_wood", "step_water", "win", "lose",
	"door_open", "door_close", "chimney", "coin",
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
	# A shallow warm-black shadow gives panels and buttons the weight of
	# printed labels instead of flat translucent glass.
	if color.a > 0.2 and radius >= 8:
		sb.shadow_color = Color(0.025, 0.035, 0.025, 0.32)
		sb.shadow_size = 5
		sb.shadow_offset = Vector2(0, 2)
	return sb


func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font = font_body
	theme.default_font_size = 16

	theme.set_stylebox("panel", "Panel", _sb(Color(0.055, 0.095, 0.073, 0.91), 16, 1, Color(0.72, 0.59, 0.34, 0.38)))
	theme.set_stylebox("panel", "PanelContainer", _sb(Color(0.06, 0.105, 0.08, 0.94), 18, 1, Color(0.76, 0.63, 0.37, 0.34)))

	var b_normal := _sb(Color("#294634"), 12, 1, Color("#9a8353"))
	var b_hover := _sb(Color("#385b42"), 12, 1, Color("#d8b668"))
	var b_press := _sb(Color("#20382a"), 12, 2, Color("#eed08a"))
	var b_disabled := _sb(Color("#252c25"), 12, 1, Color("#485244"))
	var b_focus := _sb(Color(0, 0, 0, 0), 12, 2, Color("#e4c173"))
	for t in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", t, b_normal)
		theme.set_stylebox("hover", t, b_hover)
		theme.set_stylebox("pressed", t, b_press)
		theme.set_stylebox("disabled", t, b_disabled)
		theme.set_stylebox("focus", t, b_focus)
		theme.set_color("font_color", t, Color("#f4eddc"))
		theme.set_color("font_hover_color", t, Color("#fff9ea"))
		theme.set_color("font_pressed_color", t, Color("#ffe5a6"))
		theme.set_color("font_disabled_color", t, Color("#8b9384"))
		theme.set_font_size("font_size", t, 18)

	theme.set_color("font_color", "Label", Color("#f2ebda"))
	theme.set_color("font_shadow_color", "Label", Color(0.02, 0.03, 0.02, 0.5))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 2)

	theme.set_stylebox("background", "ProgressBar", _sb(Color(0.035, 0.065, 0.05, 0.88), 8))
	theme.set_stylebox("fill", "ProgressBar", _sb(Color("#6e9a53"), 8))
	theme.set_font_size("font_size", "ProgressBar", 14)

	theme.set_color("font_color", "RichTextLabel", Color("#f2ebda"))
	theme.set_stylebox("normal", "RichTextLabel", _sb(Color(0, 0, 0, 0), 0))

	var ck_empty := _sb(Color(0, 0, 0, 0), 6)
	ck_empty.content_margin_left = 2
	theme.set_stylebox("normal", "CheckBox", ck_empty)
	theme.set_stylebox("pressed", "CheckBox", ck_empty)
	theme.set_stylebox("hover", "CheckBox", _sb(Color(1, 1, 1, 0.07), 6))
	theme.set_stylebox("disabled", "CheckBox", ck_empty)
	theme.set_font_size("font_size", "CheckBox", 16)
	theme.set_color("font_color", "CheckBox", Color("#e8e0cc"))
	theme.set_color("font_hover_color", "CheckBox", Color("#fff7e4"))

	theme.set_stylebox("slider", "HSlider", _sb(Color(0.075, 0.12, 0.085, 0.94), 4))
	theme.set_stylebox("grabber_area", "HSlider", _sb(Color("#6e9a53"), 4))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _sb(Color("#9cc478"), 4))


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

	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = "Master"
	var track := load("res://audio/music/theme.mp3")
	if track is AudioStreamMP3:
		(track as AudioStreamMP3).loop = true
		(track as AudioStreamMP3).loop_offset = 0.0
	_music.stream = track
	_music.volume_db = -46.0
	add_child(_music)


## Cross-fades to `track` (menu / day / night / endless). Calling it with the
## track that is already playing is a no-op, so state changes are cheap.
func play_music(track: String) -> void:
	if _music == null or _music.stream == null:
		return
	if track == _music_track and _music.playing:
		return
	_music_track = track
	var cfg: Dictionary = MUSIC_TRACKS.get(track, MUSIC_TRACKS["day"])
	_music.pitch_scale = float(cfg["pitch"])
	var target := float(cfg["db"]) + music_gain_db()
	if not _music.playing:
		_music.volume_db = -46.0
		_music.play()
	if _music_tween and _music_tween.is_running():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", target, 1.2).set_trans(Tween.TRANS_SINE)


func stop_music(fade := 0.8) -> void:
	_music_track = ""
	if _music == null or not _music.playing:
		return
	if _music_tween and _music_tween.is_running():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -46.0, fade).set_trans(Tween.TRANS_SINE)
	_music_tween.tween_callback(func() -> void:
		if _music != null:
			_music.stop()
	)


## Re-applies the music slider without restarting the track.
func refresh_music_volume() -> void:
	if _music == null or not _music.playing:
		return
	var cfg: Dictionary = MUSIC_TRACKS.get(_music_track, MUSIC_TRACKS["day"])
	_music.volume_db = float(cfg["db"]) + music_gain_db()


func music_gain_db() -> float:
	return linear_to_db(clamp(float(settings.get("music", 0.7)), 0.001, 1.0))


func _exit_tree() -> void:
	# NOTE: stopping the pooled players here does NOT clear the "ObjectDB
	# instances were leaked" / "resources still in use at exit" warnings. With
	# --verbose the survivors are AudioStreamPlaybackWAV/MP3 + the .wav/.mp3
	# behind them, i.e. playbacks the AudioServer already owns at teardown; by
	# the time an autoload sees _exit_tree the audio server is on its way out, so
	# stop() cannot unregister them. Measured: identical counts with and without
	# a stop()+stream=null sweep over _p2d/_p3d (store 18/8, plants 22/7), and 0/0
	# only when no sound happens to be in flight — a timing race, not a leak we
	# can fix from here. Kept the wind/music teardown, which does help.
	if _wind != null:
		_wind.stop()
		_wind.stream = null
		_wind = null
	if _music != null:
		_music.stop()
		_music.stream = null
		_music = null
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


func endless_best() -> int:
	return int(save.get("endless_best", 0))


## Returns true when this run beat the stored record.
func record_endless(waves: int) -> bool:
	save["endless_runs"] = int(save.get("endless_runs", 0)) + 1
	var best := endless_best()
	var beat := waves > best
	if beat:
		save["endless_best"] = waves
	persist()
	return beat


## 钱袋余额：跨对局累计。
func wallet() -> int:
	return int(save.get("coins", 0))


## 对局结束时把捡到的金币存进钱袋。用途待定（商店/解锁在计划里）。
func add_coins(n: int) -> void:
	if n <= 0:
		return
	save["coins"] = wallet() + n
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


# --- 图鉴 -------------------------------------------------------------------

## Every plant or zombie the gardener has actually met, so the almanac can hide
## things they have not seen yet instead of spoiling the next wave.
func mark_seen(kind: String) -> void:
	if kind == "":
		return
	var list: Array = save.get("seen", [])
	if list.has(kind):
		return
	list.append(kind)
	save["seen"] = list
	persist()


func seen(kind: String) -> bool:
	return (save.get("seen", []) as Array).has(kind)


func seen_count() -> int:
	return (save.get("seen", []) as Array).size()


func species_total() -> int:
	return Data.PLANTS.size() + Data.zombie_kinds().size()


# --- 商店 --------------------------------------------------------------------

## Permanent upgrades bought with coins — the sink the coin drops were missing.
## Each level of an upgrade is applied at match start, never inside the old save,
## so the numbers stay readable and a fresh profile behaves like the original.
const UPGRADES := {
	"sun_bank": {
		"name": "阳光储蓄",
		"desc": "每局开局额外 +25 阳光",
		"cost": [120, 260, 480],
		"unit": "级",
	},
	"spare_mower": {
		"name": "备用小推车",
		"desc": "每局多一辆应急小推车",
		"cost": [300, 620],
		"unit": "辆",
	},
	"shovel": {
		"name": "铲子回收",
		"desc": "铲除植物返还 25% 阳光",
		"cost": [150, 330],
		"unit": "级",
	},
	"purse": {
		"name": "钱袋衬里",
		"desc": "捡到的金币 +25%",
		"cost": [200],
		"unit": "级",
	},
}


func upgrade_level(id: String) -> int:
	return int((save.get("upgrades", {}) as Dictionary).get(id, 0))


func upgrade_max(id: String) -> int:
	return (UPGRADES.get(id, {}) as Dictionary).get("cost", []).size()


## -1 once the upgrade is maxed out.
func upgrade_cost(id: String) -> int:
	var costs: Array = (UPGRADES.get(id, {}) as Dictionary).get("cost", [])
	var lv := upgrade_level(id)
	if lv >= costs.size():
		return -1
	return int(costs[lv])


func can_buy_upgrade(id: String) -> bool:
	var c := upgrade_cost(id)
	return c >= 0 and wallet() >= c


func buy_upgrade(id: String) -> bool:
	if not can_buy_upgrade(id):
		return false
	var c := upgrade_cost(id)
	var ups: Dictionary = save.get("upgrades", {})
	ups[id] = upgrade_level(id) + 1
	save["upgrades"] = ups
	save["coins"] = wallet() - c
	persist()
	sfx("coin", -3.0)
	return true


func starting_sun_bonus() -> int:
	return upgrade_level("sun_bank") * 25


func spare_mowers() -> int:
	return upgrade_level("spare_mower")


func shovel_refund() -> float:
	return 0.25 * float(upgrade_level("shovel"))


func coin_multiplier() -> float:
	return 1.0 + 0.25 * float(upgrade_level("purse"))
