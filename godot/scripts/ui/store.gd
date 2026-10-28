class_name StoreScreen
extends CanvasLayer

## 疯狂戴夫的商店：用对局里捡到的金币买永久升级。
## 每一项都在 match 开局时生效（见 App.UPGRADES 与 App.buy_upgrade），
## 所以买东西真的会改变下一局的玩法，而不是只加一个数字。

signal closed
signal purse_changed(value: int)


## A single spinning coin, so the shop shows real art instead of a flat number.
class CoinPreview extends SubViewportContainer:
	var viewport: SubViewport
	var model: Node3D
	var _t := 0.0

	func _ready() -> void:
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		viewport = SubViewport.new()
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var cam := Camera3D.new()
		cam.fov = 34.0
		cam.position = Vector3(0, 0, 1.35)
		viewport.add_child(cam)
		var key := DirectionalLight3D.new()
		key.light_energy = 1.6
		key.rotation_degrees = Vector3(-28, 36, 0)
		viewport.add_child(key)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#cfd8e6")
		env.ambient_light_energy = 1.0
		var we := WorldEnvironment.new()
		we.environment = env
		viewport.add_child(we)
		model = Art.coin_model()
		viewport.add_child(model)

	func _process(delta: float) -> void:
		_t += delta
		if model != null and is_instance_valid(model):
			model.rotation.y = _t * 1.4

var root: Control
var _panel: Panel
var _list: VBoxContainer
var _purse: Label
var _rows: Dictionary = {}


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
	_panel.position = Vector2(-470, -300)
	_panel.size = Vector2(940, 600)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.11, 0.08, 0.99)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.85, 0.72, 0.4, 0.35)
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)

	var title := App.title("戴夫的商店", 40)
	title.position = Vector2(36, 26)
	_panel.add_child(title)

	var sub := Label.new()
	sub.text = "金币来自对局掉落 · 升级永久生效"
	sub.position = Vector2(38, 78)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	_panel.add_child(sub)

	_purse = Label.new()
	_purse.position = Vector2(96, 100)
	_purse.add_theme_font_size_override("font_size", 16)
	_purse.add_theme_color_override("font_color", App.C["gold_hi"])
	_panel.add_child(_purse)

	var coin := CoinPreview.new()
	coin.position = Vector2(28, 92)
	coin.size = Vector2(58, 58)
	_panel.add_child(coin)

	var close := Button.new()
	close.text = "关闭"
	close.position = Vector2(786, 30)
	close.size = Vector2(116, 44)
	close.pressed.connect(_close)
	_panel.add_child(close)

	_list = VBoxContainer.new()
	_list.position = Vector2(34, 146)
	_list.size = Vector2(872, 420)
	_list.add_theme_constant_override("separation", 12)
	_panel.add_child(_list)

	for id in App.UPGRADES.keys():
		_list.add_child(_build_row(str(id)))

	root.visible = false


func _build_row(id: String) -> Control:
	var def: Dictionary = App.UPGRADES[id]
	var row := Panel.new()
	row.custom_minimum_size = Vector2(872, 96)
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.1, 0.16, 0.12, 0.95)
	rs.set_corner_radius_all(14)
	rs.set_border_width_all(1)
	rs.border_color = Color(0.8, 0.85, 0.6, 0.16)
	row.add_theme_stylebox_override("panel", rs)

	var name_lbl := Label.new()
	name_lbl.text = str(def["name"])
	name_lbl.position = Vector2(20, 14)
	name_lbl.add_theme_font_size_override("font_size", 21)
	name_lbl.add_theme_color_override("font_color", App.C["cream"])
	row.add_child(name_lbl)

	var desc := Label.new()
	desc.text = str(def["desc"])
	desc.position = Vector2(20, 48)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	row.add_child(desc)

	var lvl := Label.new()
	lvl.position = Vector2(560, 20)
	lvl.size = Vector2(120, 26)
	lvl.add_theme_font_size_override("font_size", 15)
	lvl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.6, 0.9))
	row.add_child(lvl)

	var buy := Button.new()
	buy.position = Vector2(684, 22)
	buy.size = Vector2(168, 52)
	buy.pressed.connect(_buy.bind(id))
	row.add_child(buy)

	_rows[id] = {"lvl": lvl, "buy": buy}
	return row


func open() -> void:
	root.visible = true
	refresh()


func close() -> void:
	root.visible = false
	closed.emit()


## Hides without telling the caller — used when the whole menu is reset.
func force_hide() -> void:
	root.visible = false


func _close() -> void:
	App.sfx("click", -4.0)
	close()


func refresh() -> void:
	_purse.text = "钱袋：%d 金币" % App.wallet()
	for id in App.UPGRADES.keys():
		var refs: Dictionary = _rows.get(id, {})
		if refs.is_empty():
			continue
		var lv := App.upgrade_level(id)
		var cap := App.upgrade_max(id)
		var unit := str((App.UPGRADES[id] as Dictionary).get("unit", "级"))
		(refs["lvl"] as Label).text = "已拥有 %d / %d %s" % [lv, cap, unit]
		var buy := refs["buy"] as Button
		var cost := App.upgrade_cost(id)
		if cost < 0:
			buy.text = "已满级"
			buy.disabled = true
		else:
			buy.text = "%d 金币" % cost
			buy.disabled = App.wallet() < cost


func _buy(id: String) -> void:
	if App.buy_upgrade(id):
		App.sfx("plant", -3.0)
		_purse_changed()
		refresh()
		var refs: Dictionary = _rows.get(id, {})
		var buy := refs.get("buy") as Button
		if buy != null:
			# a short pop so the purchase lands instead of just changing text
			buy.pivot_offset = buy.size * 0.5
			buy.scale = Vector2(0.92, 0.92)
			var tw := create_tween()
			tw.tween_property(buy, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		App.sfx("deny", -6.0)


func _purse_changed() -> void:
	purse_changed.emit(App.wallet())
