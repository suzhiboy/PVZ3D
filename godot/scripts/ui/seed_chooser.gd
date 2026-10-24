class_name SeedChooser
extends CanvasLayer

## Pre-level loadout screen: pick which seeds go into the belt.
##
## The bank shows every plant once, in Data.SEED_ORDER, so the cards never
## move between levels. A level can force a few "must bring" seeds (the pool
## level hands you a lilypad), and the rest of the slots are free.

signal confirmed(id: String, kinds: Array)
signal cancelled

const SHEET := Vector2(1480, 856)
const TILE := Vector2(126, 126)
const SLOT := Vector2(92, 112)
const GAP := 10
const COLS := 8
const MAX_SLOTS := 9

var level_id := ""
var slots := 6
var must: Array = []
var picks: Array = []

var root: Control
var _lv_name: Label
var _lv_sub: Label
var _counter: Label
var _start: Button
var _tiles: Array = []
var _boxes: Array = []
var _icons: Array = []


# --- cards -----------------------------------------------------------------

class SeedTile extends Control:
	signal tapped(kind: String)

	var kind := ""
	var display_name := ""
	var cost := 100
	var picked_index := -1
	var locked := false
	var disabled := false
	var hover := false
	var icon: PlantIcon
	var _bg: StyleBoxFlat
	var _bg_hover: StyleBoxFlat
	var _bg_pick: StyleBoxFlat
	var _bg_off: StyleBoxFlat
	var _accent := Color("#8fd06a")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_bg = _box_style(Color(0.07, 0.11, 0.08, 0.94), Color(0.72, 0.82, 0.55, 0.16))
		_bg_hover = _box_style(Color(0.17, 0.26, 0.17, 0.98), Color(0.98, 0.84, 0.45, 0.9))
		_bg_pick = _box_style(Color(0.14, 0.2, 0.12, 0.97), Color(0.98, 0.84, 0.45, 0.8))
		_bg_pick.set_border_width_all(2)
		_bg_off = _box_style(Color(0.05, 0.07, 0.06, 0.9), Color(0.5, 0.55, 0.45, 0.1))
		_accent = _accent_for(cost)
		icon = PlantIcon.new()
		icon.kind = kind
		icon.spin = 0.4
		icon.position = Vector2(8, 2)
		icon.size = Vector2(110, 86)
		add_child(icon)
		mouse_entered.connect(func() -> void:
			hover = true
			queue_redraw()
		)
		mouse_exited.connect(func() -> void:
			hover = false
			queue_redraw()
		)

	func _box_style(bg: Color, border: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(1)
		sb.border_color = border
		return sb

	func _accent_for(c: int) -> Color:
		if c >= 175:
			return Color("#c88ce0")
		if c >= 100:
			return Color("#f2c14e")
		return Color("#8fd06a")

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				tapped.emit(kind)
				accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := _bg
		if disabled:
			sb = _bg_off
		elif hover:
			sb = _bg_hover
		elif picked_index >= 0:
			sb = _bg_pick
		draw_style_box(sb, r)
		draw_rect(Rect2(Vector2(0, 12), Vector2(3.5, size.y - 24)), _accent, true)

		# pick badge
		if picked_index >= 0:
			draw_circle(Vector2(size.x - 20, 20), 12.0, Color(0.12, 0.2, 0.12, 0.95))
			draw_string(App.font_bold, Vector2(size.x - 30, 25), str(picked_index + 1),
				HORIZONTAL_ALIGNMENT_CENTER, 20, 15, _accent)
		elif locked:
			draw_circle(Vector2(size.x - 20, 20), 9.0, Color(0.98, 0.84, 0.45, 0.85))

		var name_col := Color("#f6eedb") if not disabled else Color(1, 1, 1, 0.32)
		draw_string(App.font_bold, Vector2(10, 102), display_name, HORIZONTAL_ALIGNMENT_LEFT, 110, 13, name_col)
		draw_circle(Vector2(15, 115), 5.5, Color(0.98, 0.8, 0.32, 0.9))
		draw_string(App.font_body, Vector2(24, 120), str(cost), HORIZONTAL_ALIGNMENT_LEFT, 60, 12,
			Color(1, 1, 1, 0.62) if not disabled else Color(1, 1, 1, 0.2))


class SlotBox extends Control:
	signal tapped(index: int)

	var index := 0
	var kind := ""
	var display_name := ""
	var required := false
	var hover := false
	var pic: TextureRect
	var _bg: StyleBoxFlat
	var _bg_hover: StyleBoxFlat

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_bg = StyleBoxFlat.new()
		_bg.bg_color = Color(0.04, 0.07, 0.05, 0.8)
		_bg.set_corner_radius_all(10)
		_bg.set_border_width_all(1)
		_bg.border_color = Color(0.65, 0.75, 0.5, 0.2)
		_bg_hover = _bg.duplicate()
		_bg_hover.bg_color = Color(0.1, 0.16, 0.1, 0.9)
		_bg_hover.border_color = Color(0.95, 0.8, 0.4, 0.55)
		pic = TextureRect.new()
		pic.position = Vector2(2, 2)
		pic.size = Vector2(size.x - 4, 80)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.visible = false
		add_child(pic)
		mouse_entered.connect(func() -> void:
			hover = true
			queue_redraw()
		)
		mouse_exited.connect(func() -> void:
			hover = false
			queue_redraw()
		)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				tapped.emit(index)
				accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(_bg_hover if hover and kind != "" else _bg, r)
		if kind == "":
			draw_string(App.font_bold, Vector2(0, size.y * 0.5 + 14), "+",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(1, 1, 1, 0.24))
			return
		draw_string(App.font_bold, Vector2(7, 17), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, 20, 11,
			Color(1, 1, 1, 0.5))
		draw_string(App.font_body, Vector2(0, size.y - 8), display_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12,
			Color(1, 1, 1, 0.72))
		if required:
			draw_circle(Vector2(size.x - 12, 13), 10.0, Color(0.16, 0.13, 0.05, 0.95))
			draw_string(App.font_bold, Vector2(size.x - 22, 18), "必", HORIZONTAL_ALIGNMENT_CENTER, 20, 12,
				Color(0.98, 0.84, 0.45, 1.0))


# --- panel -----------------------------------------------------------------

func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	root.theme = App.theme
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.03, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var sheet := Panel.new()
	sheet.position = Vector2(60, 26)
	sheet.size = SHEET
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.09, 0.07, 0.97)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.72, 0.85, 0.55, 0.26)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	sheet.add_theme_stylebox_override("panel", sb)
	root.add_child(sheet)

	var tag := Label.new()
	tag.text = "S E E D   S E L E C T"
	tag.position = Vector2(40, 28)
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 0.7))
	sheet.add_child(tag)

	var title := App.title("选择出战植物", 38)
	title.position = Vector2(38, 50)
	sheet.add_child(title)

	_lv_name = Label.new()
	_lv_name.position = Vector2(40, 112)
	_lv_name.add_theme_font_override("font", App.font_bold)
	_lv_name.add_theme_font_size_override("font_size", 21)
	_lv_name.add_theme_color_override("font_color", Color("#f2c14e"))
	sheet.add_child(_lv_name)

	_lv_sub = Label.new()
	_lv_sub.position = Vector2(40, 142)
	_lv_sub.add_theme_font_size_override("font_size", 14)
	_lv_sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	sheet.add_child(_lv_sub)

	_counter = Label.new()
	_counter.position = Vector2(SHEET.x - 320, 112)
	_counter.size = Vector2(280, 30)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.add_theme_font_override("font", App.font_bold)
	_counter.add_theme_font_size_override("font_size", 20)
	_counter.add_theme_color_override("font_color", Color("#f6eedb"))
	sheet.add_child(_counter)

	var slots_label := Label.new()
	slots_label.text = "出战卡槽"
	slots_label.position = Vector2(40, 178)
	slots_label.add_theme_font_size_override("font_size", 13)
	slots_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.42))
	sheet.add_child(slots_label)

	# slot row
	for i in range(MAX_SLOTS):
		var box := SlotBox.new()
		box.index = i
		box.position = Vector2(40 + i * (SLOT.x + 10), 196)
		box.size = SLOT
		box.tapped.connect(_on_slot_tapped)
		sheet.add_child(box)
		_boxes.append(box)

	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.08)
	rule.position = Vector2(40, 324)
	rule.size = Vector2(SHEET.x - 80, 1)
	sheet.add_child(rule)

	var bank_label := Label.new()
	bank_label.text = "植物园 · 点击卡片放进卡槽"
	bank_label.position = Vector2(40, 336)
	bank_label.add_theme_font_size_override("font_size", 13)
	bank_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.42))
	sheet.add_child(bank_label)

	# bank grid
	var total_w := COLS * TILE.x + (COLS - 1) * GAP
	var x0 := (SHEET.x - total_w) * 0.5
	for i in range(Data.SEED_ORDER.size()):
		var kind := str(Data.SEED_ORDER[i])
		var def := Data.plant(kind)
		var tile := SeedTile.new()
		tile.kind = kind
		tile.display_name = str(def["name"])
		tile.cost = int(def["cost"])
		tile.position = Vector2(x0 + (i % COLS) * (TILE.x + GAP), 362 + (i / COLS) * (TILE.y + GAP))
		tile.size = TILE
		tile.tapped.connect(_on_tile_tapped)
		sheet.add_child(tile)
		_tiles.append(tile)
		_icons.append(tile.icon)

	_start = Button.new()
	_start.text = "开始防守"
	_start.position = Vector2(40, SHEET.y - 84)
	_start.size = Vector2(236, 54)
	_start.add_theme_font_size_override("font_size", 20)
	_start.pressed.connect(_confirm)
	sheet.add_child(_start)

	var reset := Button.new()
	reset.text = "恢复默认"
	reset.position = Vector2(292, SHEET.y - 84)
	reset.size = Vector2(132, 54)
	reset.pressed.connect(_reset_default)
	sheet.add_child(reset)

	var rnd := Button.new()
	rnd.text = "随机"
	rnd.position = Vector2(436, SHEET.y - 84)
	rnd.size = Vector2(108, 54)
	rnd.pressed.connect(_randomise)
	sheet.add_child(rnd)

	var back := Button.new()
	back.text = "返回"
	back.position = Vector2(SHEET.x - 184, SHEET.y - 84)
	back.size = Vector2(144, 54)
	back.pressed.connect(func() -> void: cancelled.emit())
	sheet.add_child(back)

	var hint := Label.new()
	hint.text = "必选植物已锁定 · 点击卡槽可取消 · 回车开始 · Esc 返回"
	hint.position = Vector2(40, SHEET.y - 20)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.34))
	sheet.add_child(hint)

	set_live(false)


func _input(event: InputEvent) -> void:
	if not root.visible:
		return
	if event.is_action_pressed("pause"):
		App.sfx("click", -6.0)
		cancelled.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER):
			if not _start.disabled:
				_confirm()
				get_viewport().set_input_as_handled()


# --- flow ------------------------------------------------------------------

func open(id: String) -> void:
	level_id = id
	var level := Data.level(id)
	slots = clampi(int(level.get("slots", 8)), 1, MAX_SLOTS)
	must = Array(level.get("must", []))
	var loadout := App.picks_for(id)
	if loadout.is_empty():
		loadout = Array(level["seeds"])
	picks = []
	for k in must:
		if not picks.has(str(k)):
			picks.append(str(k))
	for k in loadout:
		if picks.size() >= slots:
			break
		if not picks.has(str(k)):
			picks.append(str(k))

	_lv_name.text = str(level["name"])
	_lv_sub.text = str(level["subtitle"])
	_start.text = "开始防守"
	root.visible = true
	set_live(true)
	_refresh()
	App.sfx("select", -4.0)


func close() -> void:
	root.visible = false
	set_live(false)


func set_live(on: bool) -> void:
	for ic in _icons:
		if is_instance_valid(ic):
			ic.set_live(on)


func _refresh() -> void:
	for i in range(_boxes.size()):
		var box: SlotBox = _boxes[i]
		box.visible = i < slots
		var k: String = str(picks[i]) if i < picks.size() else ""
		box.kind = k
		box.display_name = str(Data.plant(k)["name"]) if k != "" else ""
		box.required = k != "" and must.has(k)
		box.pic.visible = k != ""
		box.queue_redraw()

	# slot thumbnails reuse the tile viewport — one render per plant, not two
	for i in range(_boxes.size()):
		var box: SlotBox = _boxes[i]
		if box.kind == "":
			continue
		for t in _tiles:
			var tile: SeedTile = t
			if tile.kind == box.kind:
				box.pic.texture = tile.icon.viewport.get_texture()
				break

	for t in _tiles:
		var tile: SeedTile = t
		tile.picked_index = picks.find(tile.kind)
		tile.locked = must.has(tile.kind)
		tile.disabled = tile.picked_index < 0 and picks.size() >= slots
		tile.queue_redraw()

	_counter.text = "已选 %d / %d" % [picks.size(), slots]
	var ok := picks.size() > 0
	for k in must:
		if not picks.has(str(k)):
			ok = false
	_start.disabled = not ok


func _on_tile_tapped(kind: String) -> void:
	var at := picks.find(kind)
	if at >= 0:
		if must.has(kind):
			App.sfx("deny", -8.0)
			return
		picks.remove_at(at)
		App.sfx("click", -8.0)
	elif picks.size() >= slots:
		App.sfx("deny", -8.0)
		return
	else:
		picks.append(kind)
		App.sfx("select", -10.0)
	_refresh()


func _on_slot_tapped(index: int) -> void:
	if index >= picks.size():
		return
	var kind := str(picks[index])
	if must.has(kind):
		App.sfx("deny", -8.0)
		return
	picks.remove_at(index)
	App.sfx("click", -8.0)
	_refresh()


func _reset_default() -> void:
	var level := Data.level(level_id)
	picks = []
	for k in must:
		picks.append(str(k))
	for k in level["seeds"]:
		if picks.size() >= slots:
			break
		if not picks.has(str(k)):
			picks.append(str(k))
	App.sfx("click", -6.0)
	_refresh()


func _randomise() -> void:
	var pool: Array = []
	for k in Data.SEED_ORDER:
		if not must.has(str(k)):
			pool.append(str(k))
	pool.shuffle()
	picks = []
	for k in must:
		picks.append(str(k))
	while picks.size() < slots and pool.size() > 0:
		picks.append(str(pool.pop_back()))
	# keep the belt ordered like the bank so it is easy to read
	picks.sort_custom(func(a: String, b: String) -> bool:
		return Data.SEED_ORDER.find(a) < Data.SEED_ORDER.find(b)
	)
	App.sfx("select", -6.0)
	_refresh()


func _confirm() -> void:
	App.set_picks(level_id, picks)
	App.sfx("click", -4.0)
	confirmed.emit(level_id, picks)
