class_name AlmanacScreen
extends CanvasLayer

## 图鉴：把院子里的 23 种植物和 12 种僵尸摊开给玩家看。
## 左边是索引，右边是实时 3D 模型 + 数值；没遇见过的条目只留一个剪影，
## 所以图鉴进度本身就是一条轻量的收集线（存档键 save["seen"]）。

signal closed

const CARD_W := 132
const CARD_H := 116
const COLS := 3

var root: Control
var _panel: Panel
var _grid: GridContainer
var _scroll: ScrollContainer
var _icon: PlantIcon
var _name: Label
var _tags: Label
var _body: Label
var _hint: Label
var _count: Label
var _tab_plants: Button
var _tab_zombies: Button
var tab := "plants"
var selected := "sunflower"


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = App.theme
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.03, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-640, -330)
	_panel.size = Vector2(1280, 660)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.1, 0.08, 0.99)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.7, 0.85, 0.55, 0.28)
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)

	var title := App.title("图鉴", 40)
	title.position = Vector2(36, 26)
	_panel.add_child(title)

	var sub := Label.new()
	sub.text = "遇见过的植物与僵尸都会记录在这里"
	sub.position = Vector2(38, 76)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	_panel.add_child(sub)

	_count = Label.new()
	_count.position = Vector2(38, 100)
	_count.add_theme_font_size_override("font_size", 13)
	_count.add_theme_color_override("font_color", Color(0.85, 0.9, 0.6, 0.75))
	_panel.add_child(_count)

	_tab_plants = _tab("植物", Vector2(330, 36), func() -> void: _switch("plants"))
	_tab_zombies = _tab("僵尸", Vector2(430, 36), func() -> void: _switch("zombies"))

	var close := Button.new()
	close.text = "关闭"
	close.position = Vector2(1130, 30)
	close.size = Vector2(116, 44)
	close.pressed.connect(_close)
	_panel.add_child(close)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(34, 132)
	_scroll.size = Vector2(608, 496)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_scroll.add_child(_grid)

	var cardPanel := Panel.new()
	cardPanel.position = Vector2(672, 132)
	cardPanel.size = Vector2(574, 496)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.09, 0.15, 0.11, 0.92)
	cs.set_corner_radius_all(16)
	cs.set_border_width_all(1)
	cs.border_color = Color(0.75, 0.85, 0.6, 0.18)
	cardPanel.add_theme_stylebox_override("panel", cs)
	_panel.add_child(cardPanel)

	_icon = PlantIcon.new()
	_icon.zoom = 1.45
	_icon.position = Vector2(14, 16)
	_icon.size = Vector2(250, 250)
	cardPanel.add_child(_icon)

	_name = Label.new()
	_name.position = Vector2(286, 22)
	_name.size = Vector2(272, 44)
	_name.add_theme_font_size_override("font_size", 28)
	_name.add_theme_color_override("font_color", App.C["cream"])
	cardPanel.add_child(_name)

	_tags = Label.new()
	_tags.position = Vector2(288, 68)
	_tags.size = Vector2(272, 28)
	_tags.add_theme_font_size_override("font_size", 14)
	_tags.add_theme_color_override("font_color", Color(0.85, 0.9, 0.6, 0.85))
	cardPanel.add_child(_tags)

	_body = Label.new()
	_body.position = Vector2(288, 106)
	_body.size = Vector2(270, 190)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 15)
	_body.add_theme_color_override("font_color", Color(1, 1, 1, 0.86))
	cardPanel.add_child(_body)

	_hint = Label.new()
	_hint.position = Vector2(24, 292)
	_hint.size = Vector2(526, 176)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.94, 0.86, 0.62, 0.95))
	cardPanel.add_child(_hint)

	root.visible = false


func _tab(text: String, pos: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(92, 44)
	b.pressed.connect(cb)
	_panel.add_child(b)
	return b


func open(which := "plants") -> void:
	root.visible = true
	_switch(which)
	set_live(true)


func close() -> void:
	set_live(false)
	root.visible = false
	closed.emit()


## Hides without telling the caller — used when the whole menu is reset.
func force_hide() -> void:
	set_live(false)
	root.visible = false


func _close() -> void:
	App.sfx("click", -4.0)
	close()


func _switch(which: String) -> void:
	tab = which
	App.sfx("click", -4.0)
	# active tab reads bright, the other one dims — never disabled, so it still
	# looks clickable
	_tab_plants.modulate = Color(1, 1, 1, 1) if which == "plants" else Color(0.7, 0.73, 0.68, 0.85)
	_tab_zombies.modulate = Color(1, 1, 1, 1) if which == "zombies" else Color(0.7, 0.73, 0.68, 0.85)
	var kinds := kinds_in_tab()
	selected = str(kinds[0])
	_rebuild_grid(kinds)
	_select(selected)


func kinds_in_tab() -> Array:
	if tab == "zombies":
		return Data.zombie_kinds()
	var order: Array = []
	for k in Data.SEED_ORDER:
		if Data.PLANTS.has(k):
			order.append(k)
	for k in Data.PLANTS.keys():
		if not order.has(k):
			order.append(k)
	return order


func _rebuild_grid(kinds: Array) -> void:
	for c in _grid.get_children():
		c.queue_free()
	var got := 0
	for k in kinds:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(CARD_W, CARD_H)
		btn.toggle_mode = true
		var known := App.seen(str(k))
		var label := str(Data.plant(k)["name"]) if tab == "plants" else str(Data.zombie(k)["name"])
		btn.text = label
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.disabled = false
		btn.modulate = Color(1, 1, 1, 1) if known else Color(0.72, 0.76, 0.7, 0.9)
		btn.pressed.connect(_select.bind(str(k)))
		_grid.add_child(btn)
		got += 0 if not known else 1
	_count.text = "已记录 %d / %d 种" % [App.seen_count(), App.species_total()]


func _select(kind: String) -> void:
	selected = kind
	var known := App.seen(kind)
	var is_zombie := tab == "zombies"
	# force a rebuild so the shared viewport switches plant/zombie models
	_icon.zombie = is_zombie
	_icon.kind = ""
	_icon.set_kind(kind)
	_icon.set_live(known or true)
	if not is_zombie:
		var d: Dictionary = Data.plant(kind)
		_name.text = str(d["name"])
		_tags.text = "# " + str(d.get("tags", "")) if known else "# 未遇见"
		var lines: Array[String] = []
		if known:
			lines.append("阳光 %d · 冷却 %.0f 秒 · 生命 %d" % [int(d["cost"]), float(d["recharge"]), int(d["hp"])])
			if d.has("shot"):
				lines.append("伤害 %d · 节奏 %.2f 秒" % [int(d["shot"]), float(d.get("cadence", 1.4))])
			if d.has("freeze"):
				lines.append("减速 %.1f 秒" % float(d["freeze"]))
		_body.text = "\n".join(lines)
		_hint.text = str(d["hint"]) if known else "在关卡里种下它之后，这里会解锁它的数值与心得。"
	else:
		var z: Dictionary = Data.zombie(kind)
		_name.text = str(z["name"])
		var feats: Array[String] = []
		if z.has("armor"):
			feats.append("护甲 %d" % int(z["armor"]))
		if z.has("fly"):
			feats.append("飞行")
		if z.has("vault"):
			feats.append("撑杆跳")
		if z.has("smash"):
			feats.append("砸击")
		if z.has("summon"):
			feats.append("召唤伴舞")
		if z.has("rage_speed"):
			feats.append("狂暴加速")
		_tags.text = ("# " + " · ".join(feats)) if known and feats.size() > 0 else "# 未遇见"
		var lines2: Array[String] = []
		if known:
			lines2.append("生命 %d · 速度 %.2f" % [int(z["hp"]), float(z["speed"])])
			lines2.append("啃食伤害 %d / 秒" % int(z["dps"]))
		_body.text = "\n".join(lines2)
		_hint.text = _zombie_hint(kind) if known else "它在关卡里出现过之后，这里会解锁它的应对方式。"


func _zombie_hint(kind: String) -> String:
	match kind:
		"cone":
			return "路障能挡住豌豆，但挡不住爆炸和啃食之外的直接伤害。"
		"bucket":
			return "铁桶需要大量豌豆，寒冰射手能拖慢它的脚步。"
		"flag":
			return "旗手出现意味着这一波要来了。"
		"newspaper":
			return "报纸被打掉之后它会暴走，提前用坚果挡住。"
		"football":
			return "橄榄球头盔极硬，用樱桃炸弹或大嘴花处理。"
		"pole":
			return "撑杆僵尸会跳过第一株植物，别把坚果放在最前面。"
		"screendoor":
			return "铁门抵挡正面攻击，三线射手和大嘴花更可靠。"
		"balloon":
			return "气球僵尸飞过植物，只有三叶草或高射植物能拦下来。"
		"dancer":
			return "舞王会召唤伴舞，范围伤害是最好答案。"
		"gargantuar":
			return "巨人僵尸会砸碎一整格，用小推车或大量输出对付它。"
		_:
			return "最普通的僵尸，一只豌豆射手就能解决。"


func set_live(on: bool) -> void:
	if _icon == null:
		return
	_icon.set_live(on and root.visible)
