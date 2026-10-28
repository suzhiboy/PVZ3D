## 3-D start menu: a carved tombstone standing in the front lawn.
##
## The whole menu is geometry: level names are chiselled plaques, the coin bank
## is a stack on the plinth, and the secondary entries (图鉴 / 商店 / 设置 / 退出)
## are small stones set into the step in front. Everything is picked with a
## physics ray, so the menu is pointed at with the mouse instead of clicked on a
## flat card — that is what removes the "plastic UI" feel.
class_name MenuTomb
extends Node3D

signal level_chosen(id: String)
signal endless_chosen
signal continue_pressed
signal settings_pressed
signal quit_pressed
signal almanac_pressed
signal store_pressed

const STONE := Color("#8c9186")
const STONE_DARK := Color("#666a61")
const STONE_LIP := Color("#a8ada0")
const CARVE := Color("#25261f")
const MOSS := Color("#5f8746")
const MOSS_DARK := Color("#40632f")
const GOLD := Color("#e8c96c")
const DIM := Color("#6d7060")

const LAYER := 2

var _root: Node3D
var _items: Array = []
var _levels: Array = []
var _endless: Dictionary = {}
var _continues: Dictionary = {}
var _coin_label: MeshInstance3D
var _seen_label: MeshInstance3D
var _hover: Dictionary = {}
var _on := false
var _built := false
var _t := 0.0

# materials are shared so a state change never allocates during refresh()
var _stone: StandardMaterial3D
var _stone_dark: StandardMaterial3D
var _plate_off: StandardMaterial3D
var _plate_on: Material
var _ink: Material
var _ink_dim: Material
var _ink_gold: Material
var _ink_dark: Material


func _ready() -> void:
	if not _built:
		_build()
	set_process(true)
	visible = false


func _process(delta: float) -> void:
	if not _on:
		return
	_t += delta
	# a slow breathing drift keeps the stone from looking like a photograph
	if _root != null:
		_root.position.y = sin(_t * 0.7) * 0.006


# --- public API ------------------------------------------------------------

func show_menu(on: bool) -> void:
	_on = on
	visible = on
	if on:
		refresh()


func is_open() -> bool:
	return _on


## Park a camera in front of the face so the stone fills the frame the same way
## the old card layout used to. Called by MainGame after placing the tombstone.
func frame_camera(cam: Camera3D) -> void:
	cam.position = cam_point(Vector3.ZERO)
	cam.look_at(look_point())


## Camera eye for the menu: a fixed vantage with an optional sway offset, so the
## live camera can drift very slightly without ever leaving the stone's framing.
func cam_point(offset := Vector3.ZERO) -> Vector3:
	return to_global(Vector3(0.46, 1.78, 4.85) + offset)


func look_point() -> Vector3:
	return to_global(Vector3(0.0, 1.02, 0.14))


func refresh() -> void:
	var prev_ok := true
	for i in range(_levels.size()):
		var row: Dictionary = _levels[i]
		var id := str(row["id"])
		var stars := App.stars_for(id)
		var locked := not prev_ok
		prev_ok = stars > 0
		var plate: MeshInstance3D = row["plate"]
		var label: MeshInstance3D = row["label"]
		var tm := label.mesh as TextMesh
		var lvl := Data.level(id)
		var mark := "★★★".substr(0, stars) + "☆☆☆".substr(0, 3 - stars)
		if locked:
			tm.text = "%02d  %s   🔒" % [i + 1, str(lvl["name"])]
			label.material_override = _ink_dim
			plate.material_override = _plate_off
		else:
			tm.text = "%02d  %s   %s" % [i + 1, str(lvl["name"]), mark]
			label.material_override = _ink_dark if stars > 0 else _ink
			plate.material_override = _plate_on if stars > 0 else _plate_off
		row["locked"] = locked
	if not _endless.is_empty():
		var best := App.endless_best()
		var elabel: MeshInstance3D = _endless["label"]
		var etm := elabel.mesh as TextMesh
		etm.text = "无尽模式   最佳 %d 波" % best if best > 0 else "无尽模式   没有终点"
	_refresh_continue()
	if _coin_label != null:
		(_coin_label.mesh as TextMesh).text = "钱袋 %d" % App.wallet()
	if _seen_label != null:
		(_seen_label.mesh as TextMesh).text = "图鉴 %d/%d" % [App.seen_count(), App.species_total()]


func _refresh_continue() -> void:
	if _continues.is_empty():
		return
	var any := false
	for i in range(Data.LEVELS.size()):
		if App.stars_for(str(Data.LEVELS[i]["id"])) > 0:
			any = true
	var body: StaticBody3D = _continues["body"]
	var plate: MeshInstance3D = _continues["plate"]
	var label: MeshInstance3D = _continues["label"]
	body.visible = any
	plate.visible = any
	label.visible = any


# --- input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _on:
		return
	if event is InputEventMouseMotion:
		_set_hover(_pick((event as InputEventMouseMotion).position))
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hit := _pick(mb.position)
			if not hit.is_empty():
				_activate(hit)
				get_viewport().set_input_as_handled()


func _set_hover(hit: Dictionary) -> void:
	if hit.get("id", "") == _hover.get("id", ""):
		return
	if not _hover.is_empty():
		_lift(_hover, false)
	_hover = hit
	if not _hover.is_empty():
		_lift(_hover, true)


func _lift(item: Dictionary, on: bool) -> void:
	var plate: MeshInstance3D = item["plate"]
	var label: MeshInstance3D = item["label"]
	var glow: MeshInstance3D = item["glow"]
	var base: Vector3 = item["base"]
	glow.visible = on
	var dz := 0.035 if on else 0.0
	plate.position = base + Vector3(0, 0, dz)
	label.position = base + Vector3(0, 0, dz + 0.019)
	if on:
		App.sfx("click", -14.0)


func _activate(item: Dictionary) -> void:
	App.sfx("click", -3.0)
	if bool(item.get("locked", false)):
		App.sfx("deny", -3.0)
		return
	match str(item["kind"]):
		"level":
			level_chosen.emit(str(item["id"]))
		"endless":
			endless_chosen.emit()
		"continue":
			continue_pressed.emit()
		"almanac":
			almanac_pressed.emit()
		"store":
			store_pressed.emit()
		"settings":
			settings_pressed.emit()
		"quit":
			quit_pressed.emit()


func _pick(screen: Vector2) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var from := cam.project_ray_origin(screen)
	var to := from + cam.project_ray_normal(screen) * 30.0
	var q := PhysicsRayQueryParameters3D.create(from, to, LAYER)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	var body: Object = hit.get("collider")
	for i in range(_items.size()):
		var it: Dictionary = _items[i]
		if it["body"] == body:
			return it
	return {}


# --- geometry --------------------------------------------------------------

func _build() -> void:
	_built = true
	_root = Node3D.new()
	_root.name = "Stone"
	add_child(_root)

	# A triplanar noise grain is what stops the slab from reading as plastic:
	# flat vertex colours pick up the sun as one smooth gradient.
	var noise := FastNoiseLite.new()
	noise.frequency = 0.055
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = false
	_stone = Art.tex_mat(tex, STONE, {"triplanar": true, "uv": Vector3(3.2, 3.2, 3.2)})
	_stone_dark = Art.tex_mat(tex, STONE_DARK, {"triplanar": true, "uv": Vector3(3.2, 3.2, 3.2)})
	_plate_off = Art.tex_mat(tex, Color("#4a4d45"), {"triplanar": true, "uv": Vector3(6.0, 6.0, 6.0)})
	_plate_on = Art.toon(Color("#d8bd76"))
	_ink = Art.unshaded(Color("#f2e9d2"))
	_ink_dim = Art.unshaded(Color("#8a8b80"))
	_ink_gold = Art.unshaded(Color("#f2e9d2"))
	_ink_dark = Art.unshaded(Color("#2b2d24"))

	var stone := _stone
	var stone_dark := Art.toon(STONE_DARK)
	var lip := Art.toon(STONE_LIP)
	var moss := Art.toon(MOSS)
	var moss_dark := Art.toon(MOSS_DARK)
	var gold := Art.toon(GOLD, {"glow": 0.4})

	# grass mound the stone is planted in (kept low so the step stays readable)
	Art.ball(_root, 1.30, Vector3(0, -0.05, 0.02), moss, Vector3(1.0, 0.16, 0.66), 20, 10)
	Art.ball(_root, 0.92, Vector3(-0.42, -0.06, 0.32), moss_dark, Vector3(1.0, 0.13, 0.6), 16, 8)

	# step, plinth, slab, arched cap
	Art.box(_root, Vector3(2.60, 0.14, 1.10), Vector3(0, 0.09, 0.10), stone_dark)
	Art.box(_root, Vector3(1.90, 0.26, 0.78), Vector3(0, 0.29, 0), stone)
	Art.box(_root, Vector3(1.36, 1.26, 0.28), Vector3(0, 1.05, 0), stone)
	Art.cyl(_root, 0.68, 0.28, Vector3(0, 1.68, 0), stone, Vector3(PI * 0.5, 0, 0), 26)
	# carved rim so the face reads as recessed stone rather than a slab
	Art.box(_root, Vector3(1.22, 1.12, 0.03), Vector3(0, 1.05, 0.15), stone_dark)
	Art.box(_root, Vector3(1.16, 1.06, 0.02), Vector3(0, 1.05, 0.163), _plate_off)

	_text(_root, "花 园 防 线", 0.20, Vector3(0, 1.46, 0.21), CARVE.lightened(0.78), true)
	_text(_root, "G A R D E N   D E F E N S E", 0.05, Vector3(0, 1.355, 0.21), STONE_LIP.darkened(0.15))
	_text(_root, "第一人称 · 亲手走过庭院种下每一株", 0.052, Vector3(0, 1.285, 0.21), STONE_LIP.darkened(0.05))

	# level plaques stand a little proud of the lip so they read as tablets
	var rows := 4
	for i in range(rows):
		var id := str(Data.LEVELS[i]["id"]) if i < Data.LEVELS.size() else ""
		_plate("level", id, Vector3(0, 1.12 - i * 0.155, 0.169), Vector3(1.10, 0.128, 0.04))
		_levels.append(_items[-1])
	_endless = _plate("endless", "endless", Vector3(0, 1.12 - rows * 0.155, 0.169), Vector3(1.10, 0.128, 0.04))

	# coin bank on the plinth ledge
	var coin := Art.cyl(_root, 0.075, 0.026, Vector3(-0.72, 0.44, 0.34), gold,
		Vector3(PI * 0.5, 0, 0), 18)
	coin.name = "Coin"
	_coin_label = _text(_root, "钱袋 0", 0.062, Vector3(-0.36, 0.44, 0.35), GOLD, true)
	_seen_label = _text(_root, "图鉴 0/34", 0.05, Vector3(0.52, 0.44, 0.35), STONE_LIP.darkened(0.3))

	# the secondary row sits on its own little plinths on the step
	var row := [
		["continue", -0.94, 0.42, "继续"], ["almanac", -0.50, 0.38, "图鉴"],
		["store", -0.06, 0.38, "商店"], ["settings", 0.36, 0.34, "设置"],
		["quit", 0.76, 0.26, "退出"],
	]
	for r in row:
		var kind := str(r[0])
		var rx := float(r[1])
		var rw := float(r[2])
		Art.box(_root, Vector3(rw + 0.07, 0.12, 0.22), Vector3(rx, 0.215, 0.60), stone_dark)
		var item := _plate(kind, kind, Vector3(rx, 0.315, 0.68), Vector3(rw, 0.10, 0.14), 0.0)
		var lbl: TextMesh = (item["label"] as MeshInstance3D).mesh as TextMesh
		lbl.text = str(r[3])
		if kind == "continue":
			_continues = item

	# a few props: two candle stubs and a leaning shovel feel like a garden grave
	Art.cyl(_root, 0.035, 0.14, Vector3(-1.32, 0.22, 0.42), Art.toon(Color("#d9d6c4")), Vector3.ZERO, 10)
	Art.cyl(_root, 0.035, 0.10, Vector3(-1.14, 0.20, 0.50), Art.toon(Color("#cfccb8")), Vector3.ZERO, 10)
	Art.ball(_root, 0.028, Vector3(-1.32, 0.30, 0.42), Art.toon(Color("#ffb43c"), {"glow": 2.2}), Vector3.ONE, 8, 6)
	Art.ball(_root, 0.024, Vector3(-1.14, 0.26, 0.50), Art.toon(Color("#ffb43c"), {"glow": 2.0}), Vector3.ONE, 8, 6)


## Chisel a plate into the face. `depth_offset` keeps the secondary stones proud
## of the step so their front faces stay pickable.
func _plate(kind: String, id: String, pos: Vector3, size: Vector3, depth_offset := 0.0) -> Dictionary:
	var plate := Art.box(_root, size, pos, _plate_off)
	var glow := Art.box(_root, size + Vector3(0.022, 0.022, 0.0), pos + Vector3(0, 0, -0.006),
		Art.unshaded(GOLD, 0.18))
	glow.visible = false
	var label := _text(_root, "", _text_size(kind), pos + Vector3(0, 0, size.z * 0.5 + 0.003),
		Color("#f2e9d2"), true)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER
	body.collision_mask = 0
	body.position = pos + Vector3(0, 0, depth_offset)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x + 0.04, size.y + 0.05, size.z + 0.10)
	shape.shape = box
	body.add_child(shape)
	_root.add_child(body)

	var item := {
		"kind": kind, "id": id, "body": body, "plate": plate, "label": label,
		"glow": glow, "base": pos, "locked": false,
	}
	_items.append(item)
	return item


static func _text_size(kind: String) -> float:
	match kind:
		"level", "endless":
			return 0.062
		"continue":
			return 0.05
		_:
			return 0.052


func _text(parent: Node3D, s: String, size: float, pos: Vector3, col: Color,
		bold := false) -> MeshInstance3D:
	var tm := TextMesh.new()
	tm.text = s
	tm.font = App.font_bold if bold else App.font_body
	tm.font_size = 64
	tm.pixel_size = size / 64.0
	tm.depth = 0.006
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.material_override = Art.unshaded(col)
	mi.position = pos
	parent.add_child(mi)
	return mi
