class_name Match
extends Node3D

## The match simulation: lawn grid, planting, zombies, peas, sun, mowers, waves.

signal sun_changed(value: int)
signal wave_banner(text: String, big: bool)
signal state_changed(state: String)
signal seed_used(index: int)
signal spare_dropped(lane: int, left: int)

var level: Dictionary
var yard: Dictionary
var yard_name := "front"
var rows := 5
var cols := 9
var dir := -1.0
var goal_x := 0.0

var sun := 150
var selected := ""
var state := "playing"
var time := 0.0
var wave_index := 0
var wave_label := ""
## 无尽模式：波次由 `_endless_tick()` 现算，`level["waves"]` 是空的
var endless := false
var endless_wave := 0
var next_wave_t := 0.0
var wave_interval := 24.0

var plants: Dictionary = {}
var pads: Dictionary = {}
var shells: Dictionary = {}
var craters: Dictionary = {}
var _crater_nodes: Dictionary = {}
var lobs: Array = []
var escape_x := 0.0
var _summoning := false
var zombies: Array = []
var peas: Array = []
var suns: Array = []
var coins: Array = []
var mowers: Array = []

var cooldowns: Dictionary = {}
var spawn_queue: Array = []
var sky_timer := 6.0
var shove_cd := 0.0
var shove_kills := 0

var stat_kills := 0
var stat_sun := 0
var stat_coins := 0
var stat_plants := 0
var mowers_used := 0
var spares_left := 0

var player: PlayerController
var world: WorldBuilder
var seeds: Array = []

var _ghost: Node3D
var _ghost_kind := ""
var _highlight: MeshInstance3D
var _grid: MeshInstance3D
var _aim := Vector2i(-1, -1)
var _aim_ok := false
var _shake_cb: Callable


func setup(p_level: Dictionary, p_player: PlayerController, p_world: WorldBuilder,
		shake_cb: Callable = Callable(), p_seeds: Array = []) -> void:
	level = p_level
	seeds = _normalise_seeds(level, p_seeds)
	yard = Data.yard(str(level["yard"]))
	yard_name = str(yard["id"])
	rows = int(yard["rows"])
	cols = int(yard["cols"])
	dir = float(Data.zombie_dir(yard))
	goal_x = float(yard["goal_x"])
	escape_x = float(yard["x1"]) + 5.0 if dir < 0.0 else float(yard["x0"]) - 5.0
	sun = int(level["sun"]) + App.starting_sun_bonus()
	player = p_player
	world = p_world
	_shake_cb = shake_cb

	endless = bool(level.get("endless", false))
	_build_mowers()
	_build_queue()
	_build_helpers()

	var water_rows: Array = yard["water_rows"]
	var pool := Rect2()
	if water_rows.size() > 0:
		var wz0: float = Data.row_z(yard, int(water_rows[0])) - Data.TILE * 0.5
		var wz1: float = Data.row_z(yard, int(water_rows[water_rows.size() - 1])) + Data.TILE * 0.5
		pool = Rect2(Vector2(float(yard["x0"]), wz0), Vector2(float(yard["x1"]) - float(yard["x0"]), wz1 - wz0))
	player.set_water_bounds(pool)

	sun_changed.emit(sun)


func _normalise_seeds(p_level: Dictionary, requested: Array) -> Array:
	var slot_cap := clampi(int(p_level.get("slots", 9)), 1, 9)
	var source: Array = requested if requested.size() > 0 else Array(p_level.get("seeds", []))
	var out: Array = []
	for kind in source:
		var key := str(kind)
		if Data.PLANTS.has(key) and not out.has(key) and out.size() < slot_cap:
			out.append(key)
	if out.is_empty():
		for kind in Array(p_level.get("seeds", [])):
			var key := str(kind)
			if Data.PLANTS.has(key) and not out.has(key) and out.size() < slot_cap:
				out.append(key)
	return out.slice(0, slot_cap)


# --- setup -----------------------------------------------------------------

func _build_mowers() -> void:
	for r in range(rows):
		if Data.is_water(yard, r):
			continue
		var m := LawnMower.new()
		m.setup(r, Vector3(float(yard["mower_x"]), 0.02, Data.row_z(yard, r)), -dir)
		add_child(m)
		mowers.append(m)
	# spare mowers bought in the store are held back, then spent on the first
	# lane that would otherwise be overrun
	spares_left = App.spare_mowers()


func _build_queue() -> void:
	if endless:
		# no scripted queue — waves are generated while the match runs
		spawn_queue = []
		next_wave_t = float(level.get("first_wave", 18.0))
		wave_interval = 12.0
		return
	var q: Array = []
	for wi in range(level["waves"].size()):
		var w: Dictionary = level["waves"][wi]
		var slot := 0
		for sp in w["spawns"]:
			var count := int(sp.get("count", 1))
			var gap := float(sp.get("gap", 2.5))
			for i in range(count):
				var lane := int(sp.get("lane", -1))
				if lane < 0:
					lane = randi() % rows
					slot += 1
				q.append({
					"t": float(w["at"]) + i * gap + (0.0 if sp.has("lane") else slot * 0.35),
					"kind": str(sp["kind"]),
					"lane": lane,
					"wave": wi,
				})
	q.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	spawn_queue = q


func _build_helpers() -> void:
	var hl_mat := ShaderMaterial.new()
	hl_mat.shader = preload("res://shaders/highlight.gdshader")
	_highlight = Art.quad(self, Vector2(Data.TILE * 0.94, Data.TILE * 0.94), hl_mat,
		Vector3(0, 0.055, 0), Vector3(-PI * 0.5, 0, 0))
	_highlight.visible = false

	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/grid.gdshader")
	gm.set_shader_parameter("grid_origin", Vector2(float(yard["x0"]), float(yard["z0"])))
	gm.set_shader_parameter("cell_size", Data.TILE)
	gm.set_shader_parameter("cell_count", Vector2(cols, rows))
	_grid = Art.quad(self, Vector2(cols * Data.TILE, rows * Data.TILE), gm,
		Vector3((float(yard["x0"]) + float(yard["x1"])) * 0.5, 0.045,
			(float(yard["z0"]) + float(yard["z1"])) * 0.5), Vector3(-PI * 0.5, 0, 0))
	_grid.visible = false


# --- aiming ----------------------------------------------------------------

func aim_cell() -> Vector2i:
	var cam := player.camera
	var origin := cam.global_position
	var forward := -cam.global_transform.basis.z
	if forward.y > -0.06:
		return Vector2i(-1, -1)
	var t := (0.02 - origin.y) / forward.y
	if t <= 0.0 or t > 18.0:
		return Vector2i(-1, -1)
	var p := origin + forward * t
	if not Data.inside(yard, p.x, p.z, -0.02):
		return Vector2i(-1, -1)
	var c := Data.col_at(yard, p.x)
	var r := Data.row_at(yard, p.z)
	if c < 0 or c >= cols or r < 0 or r >= rows:
		return Vector2i(-1, -1)
	return Vector2i(c, r)


func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(Data.col_x(yard, cell.x), 0.0, Data.row_z(yard, cell.y))


func is_water_cell(cell: Vector2i) -> bool:
	return Data.is_water(yard, cell.y)


func plant_y(cell: Vector2i) -> float:
	if not is_water_cell(cell):
		return Data.PLANT_Y
	var base := float(Data.POOL["surface_y"])
	return base + (0.07 if pads.has(cell) else 0.02)


func can_plant(cell: Vector2i, kind: String) -> bool:
	if cell.x < 0 or cell.x >= cols or cell.y < 0 or cell.y >= rows:
		return false
	if kind == "" or not Data.PLANTS.has(kind):
		return false
	if craters.has(cell):
		return false
	var def := Data.plant(kind)
	var water := is_water_cell(cell)
	if kind == "pumpkin":
		# the shell sits in the same cell as the plant it protects
		if water or shells.has(cell):
			return false
	elif bool(def.get("water", false)):
		if not water or plants.has(cell) or pads.has(cell) or shells.has(cell):
			return false
	elif water and not pads.has(cell):
		return false
	elif plants.has(cell):
		return false
	if sun < int(def["cost"]):
		return false
	if float(cooldowns.get(kind, 0.0)) > 0.01:
		return false
	return true


func select_seed(kind: String) -> void:
	if kind != "" and not seeds.has(kind):
		return
	if kind == "":
		selected = ""
		_clear_ghost()
		App.sfx("click", -6.0)
		return
	var def := Data.plant(kind)
	if float(cooldowns.get(kind, 0.0)) > 0.01 or sun < int(def["cost"]):
		App.sfx("deny", -8.0)
		return
	if selected == kind:
		selected = ""
		_clear_ghost()
		App.sfx("click", -6.0)
		return
	selected = kind
	_make_ghost(kind)
	App.sfx("select", -6.0)


func _make_ghost(kind: String) -> void:
	_clear_ghost()
	var rig := Art.plant_model(kind)
	_ghost = rig.root
	_ghost_kind = kind
	for mi in rig.parts:
		if mi.material_override:
			var dup: Material = mi.material_override.duplicate()
			if dup is ShaderMaterial:
				(dup as ShaderMaterial).shader = Art.TOON_ALPHA
				(dup as ShaderMaterial).set_shader_parameter("alpha", 0.55)
			mi.material_override = dup
	_ghost.scale = Vector3.ONE * PlantUnit.PLANT_SCALE
	_ghost.visible = false
	add_child(_ghost)


func _clear_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_ghost_kind = ""


# --- planting --------------------------------------------------------------

func plant_here() -> bool:
	if selected == "" or _aim.x < 0:
		return false
	return plant_at(_aim, selected)


func plant_at(cell: Vector2i, kind: String) -> bool:
	if not can_plant(cell, kind):
		App.sfx("deny", -8.0)
		return false
	var def := Data.plant(kind)
	sun -= int(def["cost"])
	cooldowns[kind] = float(def["recharge"])
	stat_plants += 1
	sun_changed.emit(sun)

	var pos := cell_center(cell)
	pos.y = plant_y(cell)
	var unit := PlantUnit.new()
	unit.setup(kind, cell.x, cell.y, pos, -dir, is_water_cell(cell))
	add_child(unit)
	if kind == "pumpkin":
		shells[cell] = unit
	elif bool(def.get("water", false)):
		pads[cell] = unit
	else:
		plants[cell] = unit

	_burst(pos + Vector3(0, 0.08, 0), Color("#7a5c3c"), 14, 2.2, 0.09)
	App.sfx_at("plant", pos, -3.0, randf_range(0.92, 1.06))
	player.play_trowel(false)
	App.mark_seen(kind)
	if kind == "cherrybomb" or kind == "jalapeno":
		App.sfx_at("groan3", pos, -10.0, 0.7)
	return true


func dig_here() -> bool:
	if _aim.x < 0:
		return false
	var p = plants.get(_aim)
	if p != null and is_instance_valid(p):
		plants.erase(_aim)
		var back := int(round(float(Data.plant(p.kind)["cost"]) * App.shovel_refund()))
		if back > 0:
			sun += back
			stat_sun += back
			sun_changed.emit(sun)
		p.die("dug")
		App.sfx_at("dig", p.global_position, -3.0)
		player.play_trowel(false)
		_burst(p.global_position + Vector3(0, 0.2, 0), Color("#8a6a44"), 10, 1.8, 0.08)
		return true
	var sh = shells.get(_aim)
	if sh != null and is_instance_valid(sh):
		shells.erase(_aim)
		sh.die("dug")
		App.sfx_at("dig", sh.global_position, -3.0)
		player.play_trowel(false)
		_burst(sh.global_position + Vector3(0, 0.2, 0), Color("#c98a44"), 10, 1.8, 0.08)
		return true
	var pad = pads.get(_aim)
	if pad != null and is_instance_valid(pad):
		pads.erase(_aim)
		pad.die()
		App.sfx_at("dig", pad.global_position, -3.0)
		player.play_trowel(false)
		return true
	App.sfx("deny", -10.0)
	return false


func collect_nearby() -> bool:
	var eye := player.eye_position()
	var best: SunOrb = null
	var best_d := 99.0
	for s in suns:
		if not is_instance_valid(s) or s.collected:
			continue
		var d: float = s.global_position.distance_to(eye)
		if d > 9.0:
			continue
		var to: Vector3 = (s.global_position - eye).normalized()
		if to.dot(player.look_dir()) < 0.86:
			continue
		if d < best_d:
			best_d = d
			best = s
	if best == null:
		return _collect_coin_in_view()
	_collect(best)
	return true


func _collect(s: SunOrb) -> void:
	if s.collected:
		return
	s.collected = true
	sun += s.value
	stat_sun += s.value
	sun_changed.emit(sun)
	App.sfx("sun", -5.0, randf_range(0.96, 1.06))
	_burst(s.global_position, Color("#ffd94a"), 10, 1.8, 0.07)
	s.pop()


# --- combat ----------------------------------------------------------------

func lane_has_zombie(row: int, from_x: float, reach := 99.0) -> bool:
	var attack := -dir
	for z in zombies:
		if not is_instance_valid(z) or z.dead or z.charmed or z.lane != row:
			continue
		var ahead: float = (z.global_position.x - from_x) * attack
		if ahead > -0.25 and ahead <= reach:
			return true
	return false


## Closest zombie ahead of `origin_x` in `lane`, ignoring charmed ones.
func frontmost_zombie(lane_i: int, origin_x: float, max_range := 99.0) -> ZombieUnit:
	var attack := -dir
	var best: ZombieUnit = null
	var best_d := max_range
	for z in zombies:
		if not is_instance_valid(z) or z.dead or z.dying > 0.0 or z.charmed or z.lane != lane_i:
			continue
		var ahead: float = (z.global_position.x - origin_x) * attack
		if ahead < -0.25:
			continue
		if ahead < best_d:
			best_d = ahead
			best = z
	return best


## A hostile zombie right next to a charmed one — used by hypno-shroom thralls.
func zombie_foe_near(z: ZombieUnit, radius: float) -> ZombieUnit:
	var best: ZombieUnit = null
	var best_d := radius
	for o in zombies:
		if o == z or not is_instance_valid(o) or o.dead or o.dying > 0.0 or o.charmed:
			continue
		if o.lane != z.lane:
			continue
		var d: float = absf(o.global_position.x - z.global_position.x)
		if d <= best_d:
			best_d = d
			best = o
	return best


func plant_in_front(z: ZombieUnit) -> PlantUnit:
	var best: PlantUnit = null
	var best_d := 999.0
	for key in plants.keys():
		var p: PlantUnit = plants[key]
		if p == null or not is_instance_valid(p) or p.dead or p.row != z.lane:
			continue
		var ahead := (p.global_position.x - z.global_position.x) * dir
		if ahead < -0.05 or ahead > 0.8:
			continue
		# a pumpkin shell takes the bite before the plant inside it
		var sh = shells.get(key)
		if sh != null and is_instance_valid(sh) and not sh.dead:
			p = sh
		if ahead < best_d:
			best_d = ahead
			best = p
	# pumpkins standing on their own cell
	for key in shells.keys():
		if plants.has(key):
			continue
		var sh2: PlantUnit = shells[key]
		if sh2 == null or not is_instance_valid(sh2) or sh2.dead or sh2.row != z.lane:
			continue
		var ahead2 := (sh2.global_position.x - z.global_position.x) * dir
		if ahead2 < -0.05 or ahead2 > 0.8:
			continue
		if ahead2 < best_d:
			best_d = ahead2
			best = sh2
	return best


func zombie_near(pos: Vector3, radius: float) -> ZombieUnit:
	var best: ZombieUnit = null
	var best_d := radius
	for z in zombies:
		if not is_instance_valid(z) or z.dead or z.dying > 0.0 or z.charmed:
			continue
		if abs(z.global_position.z - pos.z) > 0.95:
			continue
		var d: float = abs(z.global_position.x - pos.x)
		if d <= best_d:
			best_d = d
			best = z
	return best


func zombies_in_radius(pos: Vector3, radius: float) -> Array:
	var out: Array = []
	for z in zombies:
		if not is_instance_valid(z) or z.dead or z.dying > 0.0:
			continue
		if Vector2(z.global_position.x - pos.x, z.global_position.z - pos.z).length() <= radius:
			out.append(z)
	return out


func fire_pea(pos: Vector3, lane: int, dmg: float, freeze: bool, delay: float, dist := 99.0) -> void:
	var p := PeaShot.new()
	p.setup(Vector3(pos.x, 0.86, Data.row_z(yard, lane)), lane, dmg, freeze, -dir, dist)
	add_child(p)
	if delay > 0.0:
		p.scale = Vector3.ONE * 0.2
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func() -> void:
			if is_instance_valid(p):
				p.scale = Vector3.ONE
		)
	peas.append(p)


# --- lobbed shots ----------------------------------------------------------

func lob_at(pos: Vector3, lane: int, target_x: float, dmg: float, kind: String, butter := false) -> void:
	var target := Vector3(target_x, 0.9, Data.row_z(yard, lane) + randf_range(-0.08, 0.08))
	var p := LobShot.new()
	p.setup(pos, lane, target, dmg, kind, butter)
	p.landed.connect(_on_lob_landed)
	add_child(p)
	lobs.append(p)


func _update_lobs(delta: float) -> void:
	var alive: Array = []
	for p in lobs:
		if not is_instance_valid(p):
			continue
		if p.done:
			continue
		p.advance(delta)
		alive.append(p)
	lobs = alive


func _on_lob_landed(pos: Vector3, lane: int, dmg: float, kind: String, butter: bool) -> void:
	_burst(pos, Color("#f6dd8a") if kind == "kernelpult" else Color("#7fc45a"), 12, 2.4, 0.08)
	App.sfx_at("hit", pos, -6.0, 0.8 if kind == "melonpult" else 1.2)
	if kind == "melonpult":
		var def := Data.plant("melonpult")
		var radius := float(def.get("splash_radius", 1.5))
		var splash := float(def.get("splash", 40))
		var direct: ZombieUnit = null
		var best := 0.8
		for z in zombies:
			if not is_instance_valid(z) or z.dead or z.dying > 0.0 or z.lane != lane:
				continue
			var d: float = absf(z.global_position.x - pos.x)
			if d <= best:
				best = d
				direct = z
		if direct != null:
			# the melon comes down from above, so the door does not stop it
			direct.damage(dmg, false, true)
		for z in zombies_in_radius(pos, radius):
			if z == direct:
				continue
			z.damage(splash)
		player.add_shake(0.12)
		return
	var hit: ZombieUnit = null
	for z in zombies:
		if not is_instance_valid(z) or z.dead or z.dying > 0.0 or z.lane != lane:
			continue
		if absf(z.global_position.x - pos.x) <= 0.8:
			hit = z
			break
	if hit != null:
		# 抛射物走的是抛物线，会越过铁门直接砸到头
		hit.damage(dmg, false, true)
		if butter:
			hit.butter(4.5)
			_burst(hit.global_position + Vector3(0, 1.1, 0), Color("#fff3b0"), 14, 2.2, 0.09)
			App.sfx_at("freeze", hit.global_position + Vector3(0, 1.1, 0), -8.0, 0.7)


# --- mushroom tricks -------------------------------------------------------

## Fume-shroom: a short cone that damages every zombie in reach at once.
func fume_cone(pos: Vector3, lane: int, radius: float, damage: float) -> void:
	var attack := -dir
	var hit := 0
	for z in zombies:
		if not is_instance_valid(z) or z.dead or z.dying > 0.0 or z.charmed or z.lane != lane:
			continue
		var ahead: float = (z.global_position.x - pos.x) * attack
		if ahead < 0.0 or ahead > radius:
			continue
		z.damage(damage)
		_burst(z.global_position + Vector3(0, 0.9, 0), Color("#b9a8d0"), 6, 1.4, 0.05)
		hit += 1
	# a puff drifting down the lane, so the hit reads on screen
	for i in range(3):
		var p := Art.puff(Color(0.78, 0.72, 0.88))
		var at := pos + Vector3(attack * (0.35 + i * radius * 0.34), 0.62 + i * 0.08, 0)
		p.position = at
		p.scale = Vector3.ONE * 0.35
		add_child(p)
		var tw := create_tween()
		tw.tween_property(p, "scale", Vector3.ONE * (1.05 + i * 0.15), 0.42)
		tw.parallel().tween_property(p, "scale", Vector3.ZERO, 0.5)
		tw.tween_callback(p.queue_free)
	if hit > 0:
		App.sfx_at("hit", pos, -14.0, 0.7)


## 火龙草：短距离扇形火焰，同时覆盖本行和相邻两行。
func flame_cone(pos: Vector3, lane: int, radius: float, damage: float) -> int:
	var attack := -dir
	var hit := 0
	for rr in range(maxi(0, lane - 1), mini(rows, lane + 2)):
		for z in zombies:
			if not is_instance_valid(z) or z.dead or z.dying > 0.0 or z.charmed or z.lane != rr:
				continue
			var ahead: float = (z.global_position.x - pos.x) * attack
			if ahead < 0.0 or ahead > radius:
				continue
			z.damage(damage)
			_burst(z.global_position + Vector3(0, 0.85, 0), Color("#ffab54"), 7, 1.8, 0.06)
			hit += 1
	for rr in range(maxi(0, lane - 1), mini(rows, lane + 2)):
		var puff := Art.puff(Color(1.0, 0.45, 0.18, 0.82))
		puff.position = pos + Vector3(attack * (0.35 + radius * 0.22), 0.72, (rr - lane) * Data.TILE * 0.42)
		puff.scale = Vector3(0.22, 0.22, 0.22)
		add_child(puff)
		var tw := create_tween()
		tw.tween_property(puff, "scale", Vector3.ONE * 0.68, 0.28)
		tw.parallel().tween_property(puff, "scale", Vector3.ZERO, 0.34)
		tw.tween_callback(puff.queue_free)
	if hit > 0:
		App.sfx_at("hit", pos, -10.0, 1.15)
		if player != null:
			player.add_shake(0.08)
	return hit


## 激光豆：整行贯穿，直接命中所有前方僵尸。
func laser_row(pos: Vector3, lane: int, damage: float) -> int:
	var attack := -dir
	var hit := 0
	for z in zombies:
		if not is_instance_valid(z) or z.dead or z.dying > 0.0 or z.charmed or z.lane != lane:
			continue
		var ahead: float = (z.global_position.x - pos.x) * attack
		if ahead < -0.2:
			continue
		z.damage(damage)
		_burst(z.global_position + Vector3(0, 0.85, 0), Color("#b7f4e5"), 5, 1.2, 0.04)
		hit += 1
	var edge_x := float(yard["x1"]) if attack > 0.0 else float(yard["x0"])
	var beam_len: float = maxf(absf(edge_x - pos.x), Data.TILE)
	var beam_x: float = pos.x + (edge_x - pos.x) * 0.5
	var beam := Art.box(self, Vector3(beam_len, 0.09, 0.09),
		Vector3(beam_x, 0.9, Data.row_z(yard, lane)),
		Art.additive(Color(0.35, 1.0, 0.82, 0.9)))
	var tw := create_tween()
	tw.tween_property(beam, "scale", Vector3(1.0, 2.5, 2.5), 0.12)
	tw.parallel().tween_property(beam, "transparency", 1.0, 0.22)
	tw.tween_callback(beam.queue_free)
	if hit > 0:
		App.sfx_at("shoot", pos, -7.0, 1.35)
		if player != null:
			player.add_shake(0.12)
	return hit


## 三叶草：一次性把所有飞行僵尸吹走。
func blow_away() -> int:
	var hit := 0
	for z in zombies:
		if not is_instance_valid(z) or z.dead or z.dying > 0.0 or z.flying <= 0.0:
			continue
		z.start_dying(true)
		_burst(z.global_position + Vector3(0, z.flying + 0.65, 0), Color("#b9ecb7"), 14, 3.4, 0.09)
		hit += 1
	var wind := Art.quad(self, Vector2(float(yard["x1"]) - float(yard["x0"]), Data.TILE * 0.72),
		Art.additive(Color(0.55, 1.0, 0.68, 0.26)),
		Vector3((float(yard["x0"]) + float(yard["x1"])) * 0.5, 0.78, float(yard["z0"]) + Data.TILE * 0.5),
		Vector3(-PI * 0.5, 0, 0))
	var tw := create_tween()
	tw.tween_property(wind, "scale", Vector3(1.0, 1.0, 1.8), 0.4)
	tw.parallel().tween_property(wind, "transparency", 1.0, 0.48)
	tw.tween_callback(wind.queue_free)
	App.sfx_at("wind", player.eye_position() if player != null else global_position, -2.0, 1.2)
	if player != null:
		player.add_shake(0.16 if hit > 0 else 0.05)
	return hit


func melee_fx(pos: Vector3, color: Color) -> void:
	_burst(pos + Vector3(0, 0.78, 0), color, 8, 1.7, 0.05)
	if player != null:
		player.add_shake(0.07)


func freeze_all(duration: float) -> void:
	for z in zombies:
		if is_instance_valid(z) and not z.dead and z.dying <= 0.0:
			z.chill(duration)
			_burst(z.global_position + Vector3(0, 0.9, 0), Color("#bfe9f5"), 8, 2.0, 0.07)
	player.add_shake(0.2)
	App.sfx_at("freeze", player.eye_position(), 0.0, 0.7)


func charm_near(pos: Vector3, radius: float) -> void:
	var z := zombie_near(pos, radius)
	if z != null and not z.charmed:
		z.charm(14.0)
		_burst(z.global_position + Vector3(0, 1.0, 0), Color("#d98ad6"), 16, 2.6, 0.1)


func strip_metal_near(pos: Vector3, radius: float) -> int:
	var hit := 0
	for z in zombies:
		if not is_instance_valid(z) or z.dead or z.dying > 0.0 or z.charmed:
			continue
		if absf(z.global_position.z - pos.z) > 1.0:
			continue
		if absf(z.global_position.x - pos.x) > radius:
			continue
		if z.strip_metal():
			hit += 1
			_burst(z.global_position + Vector3(0, 1.6, 0), Color("#cfd6da"), 10, 2.6, 0.07)
			App.sfx_at("hit", z.global_position + Vector3(0, 1.5, 0), -5.0, 1.5)
	return hit


## Doom-shroom: a huge blast that also poisons the cell for a minute.
func doom(pos: Vector3, cell: Vector2i) -> void:
	explode(pos, float(Data.plant("doomshroom").get("blast", 5.2)), 3000.0)
	player.add_shake(1.4)
	craters[cell] = 60.0
	var c := cell_center(cell)
	if _crater_nodes.has(cell) and is_instance_valid(_crater_nodes[cell]):
		_crater_nodes[cell].queue_free()
	var dark := Art.cyl(self, Data.TILE * 0.44, 0.02, Vector3(c.x, 0.035, c.z),
		Art.toon(Color("#2c241d"), {"bands": 1.0, "outline": false}), Vector3.ZERO, 18)
	var rim := Art.torus(self, Data.TILE * 0.34, Data.TILE * 0.46, Vector3(c.x, 0.04, c.z),
		Art.toon(Color("#4a3a2a"), {"bands": 1.0}))
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var group := Node3D.new()
	add_child(group)
	dark.reparent(group)
	rim.reparent(group)
	_crater_nodes[cell] = group
	group.scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(group, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_craters(delta: float) -> void:
	for key in craters.keys():
		var t: float = float(craters[key]) - delta
		if t > 0.0:
			craters[key] = t
			continue
		craters.erase(key)
		if _crater_nodes.has(key) and is_instance_valid(_crater_nodes[key]):
			_crater_nodes[key].queue_free()
		_crater_nodes.erase(key)


func explode(pos: Vector3, radius: float, damage: float) -> void:
	App.sfx_at("explode", pos, 0.0, randf_range(0.94, 1.05))
	player.add_shake(0.85)
	var hit := zombies_in_radius(pos, radius)
	for z in hit:
		z.damage(damage)
	# flash sphere
	var ring := Art.ball(self, radius * 0.75, pos + Vector3(0, 0.55, 0),
		Art.toon(Color("#ffca55"), {"bands": 1.0, "glow": 2.2, "alpha": 0.55, "rim": 0.0, "outline": false}), Vector3.ONE, 12, 8)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3.ONE * 1.7, 0.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "transparency", 1.0, 0.32)
	tw.tween_callback(ring.queue_free)
	_burst(pos + Vector3(0, 0.4, 0), Color("#ffb347"), 26, 5.5, 0.13)


func burn_row(row: int) -> void:
	var z_fire: float = Data.row_z(yard, row)
	var cx: float = (float(yard["x0"]) + float(yard["x1"])) * 0.5
	var w: float = float(yard["x1"]) - float(yard["x0"])
	for z in zombies:
		if is_instance_valid(z) and not z.dead and z.lane == row:
			z.damage(3000.0)
	App.sfx_at("explode", Vector3(cx, 0.4, z_fire), -2.0, 1.15)
	player.add_shake(0.7)
	var fire := Art.quad(self, Vector2(w, Data.TILE * 0.95),
		Art.additive(Color(1.0, 0.45, 0.15, 0.85)), Vector3(cx, 0.35, z_fire), Vector3(-PI * 0.5, 0, 0))
	var tw := create_tween()
	tw.tween_property(fire, "scale", Vector3(1.0, 1.0, 2.0), 0.55)
	tw.parallel().tween_property(fire, "transparency", 1.0, 0.7)
	tw.tween_callback(fire.queue_free)
	_burst(Vector3(cx, 0.4, z_fire), Color("#ff8a3d"), 40, 4.0, 0.16)


## 巨人一棒子把植物砸成木屑
func smash_fx(pos: Vector3) -> void:
	_burst(pos + Vector3(0, 0.4, 0), Color("#b08a52"), 20, 3.4, 0.11)
	player.add_shake(0.45)


func devour(z: ZombieUnit) -> void:
	if not is_instance_valid(z):
		return
	_burst(z.global_position + Vector3(0, 0.8, 0), Color("#a06fd0"), 18, 3.0, 0.11)
	z.start_dying(true)


func shove() -> bool:
	if shove_cd > 0.0 or state != "playing":
		return false
	shove_cd = 2.6
	player.play_trowel(true)
	App.sfx("shove", -3.0, randf_range(0.95, 1.05))
	player.add_shake(0.2)
	var eye := player.eye_position()
	var fwd := player.look_dir()
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	var hit := 0
	for z in zombies:
		if not is_instance_valid(z) or z.dead:
			continue
		var to: Vector3 = z.global_position + Vector3(0, 0.9, 0) - eye
		var dist := to.length()
		if dist > 2.6:
			continue
		var flat_to := Vector3(to.x, 0, to.z).normalized()
		if flat_to.dot(flat) < 0.55:
			continue
		z.shove(0.62)
		z.damage(35.0)
		hit += 1
		_burst(z.global_position + Vector3(0, 1.0, 0), Color("#cfe08a"), 8, 2.0, 0.07)
	if hit > 0:
		player.add_shake(0.35)
	return hit > 0


func spawn_sun(pos: Vector3, from_plant: bool, value := 25) -> void:
	var orb := SunOrb.new()
	add_child(orb)
	orb.setup(pos, from_plant, value)
	suns.append(orb)


# --- coins ------------------------------------------------------------------

func spawn_coin(pos: Vector3, n := 1) -> void:
	for i in range(n):
		var c := CoinOrb.new()
		# add first: setup() writes a global transform, which needs the node
		# in the tree or Godot reports "!is_inside_tree()" and drops it at origin
		add_child(c)
		c.setup(pos + Vector3(randf_range(-0.12, 0.12), i * 0.14, randf_range(-0.12, 0.12)), 1)
		coins.append(c)


## 击杀掉落：按 Data.COIN_TABLE 掷骰子；死在小推车或魅惑倒计时手里一样给钱。
func _drop_coins(z: ZombieUnit) -> void:
	if not is_instance_valid(z):
		return
	var drop := Data.coin_drop(z.kind)
	if randf() >= float(drop["chance"]):
		return
	spawn_coin(z.global_position + Vector3(0, 0.9, 0), int(drop["n"]))


func _update_coins(delta: float) -> void:
	var feet: Vector3 = player.global_position
	for c in coins:
		if not is_instance_valid(c) or c.collected:
			continue
		if c.advance(delta, feet):
			_collect_coin(c)


func _collect_coin(c: CoinOrb) -> void:
	if c.collected:
		return
	# the store's coin purse upgrade pays out a little extra per pickup
	stat_coins += int(round(float(c.value) * App.coin_multiplier()))
	App.sfx_at("coin", c.global_position, -7.0, randf_range(0.92, 1.14))
	_burst(c.global_position, Color("#ffdf7a"), 6, 1.4, 0.06)
	c.pop()


## E 键的第二优先目标：准星前方的金币（没有阳光才轮到它）。
func _collect_coin_in_view() -> bool:
	var eye := player.eye_position()
	var best: CoinOrb = null
	var best_d := 99.0
	for c in coins:
		if not is_instance_valid(c) or c.collected:
			continue
		var d: float = c.global_position.distance_to(eye)
		if d > 9.0:
			continue
		var to: Vector3 = (c.global_position - eye).normalized()
		if to.dot(player.look_dir()) < 0.86:
			continue
		if d < best_d:
			best_d = d
			best = c
	if best == null:
		return false
	_collect_coin(best)
	return true


func breach(z: ZombieUnit) -> void:
	var m := _mower_for(z.lane)
	if m != null and not m.spent:
		if not m.active:
			m.launch()
			mowers_used += 1
		# the mower is right here — it takes the zombie out before it can pass
		z.start_dying(true)
		_burst(z.global_position + Vector3(0, 0.8, 0), Color("#c9d6a0"), 14, 3.2, 0.1)
		return
	if spares_left > 0:
		# a store-bought spare drops in on this lane and clears it
		spares_left -= 1
		var spare := LawnMower.new()
		spare.setup(z.lane, Vector3(float(yard["mower_x"]), 0.02, Data.row_z(yard, z.lane)), -dir)
		add_child(spare)
		mowers.append(spare)
		spare.launch()
		mowers_used += 1
		spare_dropped.emit(z.lane, spares_left)
		z.start_dying(true)
		_burst(z.global_position + Vector3(0, 0.8, 0), Color("#f2d38a"), 18, 3.6, 0.11)
		return
	if state == "playing":
		state = "lost"
		App.sfx("lose", -1.0)
		state_changed.emit(state)


func _mower_for(lane: int) -> LawnMower:
	for m in mowers:
		if is_instance_valid(m) and m.lane == lane:
			return m
	return null


# --- wave spawning ---------------------------------------------------------

func spawn_zombie(kind: String, lane: int) -> void:
	var z := ZombieUnit.new()
	var sub_lane: int = clampi(lane, 0, rows - 1)
	var jitter := randf_range(-0.18, 0.18)
	z.setup(kind, sub_lane, Vector3(float(yard["spawn_x"]), 0.02, Data.row_z(yard, sub_lane) + jitter), dir)
	App.mark_seen(kind)
	add_child(z)
	z.died.connect(func() -> void:
		stat_kills += 1
		_drop_coins(z))
	zombies.append(z)
	var summon := int(Data.zombie(kind).get("summon", 0))
	if summon > 0 and not _summoning:
		_summoning = true
		for i in range(summon):
			var off := (i - (summon - 1) * 0.5)
			var l2: int = clampi(lane + int(signf(off)) * (1 if absf(off) > 0.6 else 0), 0, rows - 1)
			spawn_zombie("backup", l2)
		_summoning = false
		App.sfx_at("groan2", z.global_position + Vector3(0, 1.3, 0), -3.0, 0.85)
	App.sfx_at("groan1", z.global_position + Vector3(0, 1.2, 0), -6.0, randf_range(0.85, 1.1))


func _spawn_waves() -> void:
	while spawn_queue.size() > 0 and float(spawn_queue[0]["t"]) <= time:
		var s: Dictionary = spawn_queue.pop_front()
		spawn_zombie(str(s["kind"]), int(s["lane"]))
		if endless:
			continue
		var wi := int(s["wave"])
		if wi >= wave_index:
			wave_index = wi + 1
			var w: Dictionary = level["waves"][wi]
			wave_label = str(w["label"])
			var big := bool(w.get("big", false))
			wave_banner.emit(wave_label, big)
			if big:
				App.sfx("wave", -2.0)
			else:
				App.sfx("select", -12.0, 0.8)


# --- endless waves ---------------------------------------------------------



func _endless_step() -> void:
	if not endless or state != "playing":
		return
	if time < next_wave_t:
		return
	_spawn_endless_wave()


## One wave: turn a growing budget into zombies, then schedule the next one.
func _spawn_endless_wave() -> void:
	endless_wave += 1
	wave_index = endless_wave
	var w := endless_wave
	var roster := Data.endless_roster(w)
	# soft ramp: a solid static wall should hold past wave 20, a lazy one should not
	var budget := 2.5 + w * 1.15 + pow(w, 1.32) * 0.25
	var at := time + 0.15
	var placed := 0
	while budget > 0.6 and placed < 44:
		var entry: Dictionary = _pick_endless_kind(roster)
		budget -= float(entry["cost"])
		# keep one gargantuar per wave until the roster gets thick
		if str(entry["kind"]) == "gargantuar" and placed > 0 and w < 18:
			continue
		spawn_queue.append({
			"t": at,
			"kind": str(entry["kind"]),
			"lane": randi() % rows,
			"wave": w - 1,
		})
		placed += 1
		at += randf_range(0.4, 1.15)
	wave_interval = maxf(8.5, 24.0 - w * 0.46)
	next_wave_t = time + wave_interval
	wave_label = "第 %d 波" % w
	var big := w % 5 == 0
	wave_banner.emit(wave_label, big)
	App.sfx("wave" if big else "select", -2.0 if big else -12.0, 1.0 if big else 0.8)


func _pick_endless_kind(roster: Array) -> Dictionary:
	var total := 0.0
	for e in roster:
		total += float(e["weight"])
	var r := randf() * total
	for e in roster:
		r -= float(e["weight"])
		if r <= 0.0:
			return e
	return roster[roster.size() - 1]


# --- tick ------------------------------------------------------------------

func update(delta: float) -> void:
	shove_cd = max(0.0, shove_cd - delta)
	if state != "playing":
		return
	time += delta

	for k in cooldowns.keys():
		var v: float = cooldowns[k] - delta
		if v <= 0.0:
			cooldowns.erase(k)
		else:
			cooldowns[k] = v

	_spawn_waves()
	_endless_step()

	for key in plants.keys():
		var p = plants[key]
		if is_instance_valid(p) and not p.dead:
			p.tick(delta, self)
	for key in pads.keys():
		var p = pads[key]
		if is_instance_valid(p) and not p.dead:
			p.tick(delta, self)
	for key in shells.keys():
		var p = shells[key]
		if is_instance_valid(p) and not p.dead:
			p.tick(delta, self)

	for z in zombies:
		if is_instance_valid(z) and not z.dead:
			z.tick(delta, self)
	_update_zombie_wading(delta)

	_update_peas(delta)
	_update_lobs(delta)
	_update_craters(delta)
	_update_mowers(delta)
	_update_suns(delta)
	_update_coins(delta)
	_update_aim()
	_cleanup()
	_check_end()


## Zombies entering the pool push real water too. Keep the cadence lower than
## the player's so a full wave does not drown the mix or the frame budget.
func _update_zombie_wading(delta: float) -> void:
	if world == null or not is_instance_valid(world) or world.water_fx == null:
		return
	for z in zombies:
		if not is_instance_valid(z) or z.dead or z.dying > 0.0 or z.flying > 0.0:
			continue
		if not Data.is_water(yard, z.lane):
			continue
		var in_pool: bool = z.global_position.x >= float(yard["x0"]) and z.global_position.x <= float(yard["x1"])
		var was_wet: bool = bool(z.get_meta("water_wet", false))
		if in_pool and not was_wet:
			z.set_meta("water_wet", true)
			z.set_meta("water_step", 0.52)
			world.water_fx.splash(z.global_position, 0.62, false)
			App.sfx_at("step_water", z.global_position, -9.0, randf_range(0.68, 0.82))
		elif in_pool:
			var water_step := float(z.get_meta("water_step", 0.0)) - delta
			if water_step <= 0.0:
				water_step = 0.62
				world.water_fx.splash(z.global_position, 0.25, true)
				if randf() < 0.32:
					App.sfx_at("step_water", z.global_position, -17.0, randf_range(0.64, 0.78))
			z.set_meta("water_step", water_step)
		elif was_wet:
			z.set_meta("water_wet", false)
			world.water_fx.splash(z.global_position, 0.34, false)


func _update_peas(delta: float) -> void:
	for p in peas:
		if not is_instance_valid(p) or p.dead:
			continue
		if not p.advance(delta):
			continue
		if not Data.inside(yard, p.global_position.x, p.global_position.z, 0.4):
			p.hit()
			continue
		for z in zombies:
			if not is_instance_valid(z) or z.dead or z.charmed or z.lane != p.lane:
				continue
			if abs(z.global_position.x - p.global_position.x) > 0.42:
				continue
			z.damage(p.damage)
			if p.freeze:
				z.frozen = max(z.frozen, float(Data.plant("snowpea").get("freeze", 3.2)))
				App.sfx_at("freeze", z.global_position + Vector3(0, 1.0, 0), -10.0, randf_range(1.0, 1.2))
			else:
				App.sfx_at("hit", z.global_position + Vector3(0, 1.0, 0), -12.0, randf_range(0.9, 1.15))
			p.hit()
			_burst(p.global_position, Color("#a8e070") if not p.freeze else Color("#bfe9f5"), 5, 1.6, 0.05)
			break


func _update_mowers(delta: float) -> void:
	for m in mowers:
		if not is_instance_valid(m) or not m.active or m.spent:
			continue
		m.advance(delta)
		for z in zombies:
			if not is_instance_valid(z) or z.dead or z.dying > 0.0:
				continue
			if z.lane != m.lane:
				continue
			if abs(z.global_position.x - m.global_position.x) < 0.95:
				z.start_dying(true)
				_burst(z.global_position + Vector3(0, 0.8, 0), Color("#c9d6a0"), 16, 3.4, 0.1)
		if m.global_position.x > float(yard["x1"]) + 3.0 or m.global_position.x < float(yard["x0"]) - 3.0:
			m.spent = true
			m.visible = false


func _update_suns(delta: float) -> void:
	sky_timer -= delta
	if sky_timer <= 0.0:
		sky_timer = float(level["sky_sun"]) + randf_range(0.0, 4.0)
		var c := randi() % cols
		var dry_rows: Array = []
		for candidate in range(rows):
			if not Data.is_water(yard, candidate):
				dry_rows.append(candidate)
		if dry_rows.is_empty():
			return
		var r: int = int(dry_rows[randi() % dry_rows.size()])
		spawn_sun(Vector3(Data.col_x(yard, c), 9.0, Data.row_z(yard, r)), false)

	var eye := player.eye_position()
	for s in suns:
		if not is_instance_valid(s) or s.collected:
			continue
		if s.advance(delta, eye, true):
			_collect(s)


func _update_aim() -> void:
	_aim = aim_cell()
	_aim_ok = false
	if is_instance_valid(_grid):
		_grid.visible = selected != ""
	if selected != "" and _aim.x >= 0:
		_aim_ok = can_plant(_aim, selected)
		var pos := cell_center(_aim)
		_highlight.visible = true
		_highlight.position = Vector3(pos.x, 0.06, pos.z)
		var col := Color("#8dff6a") if _aim_ok else Color("#ff6a5a")
		(_highlight.material_override as ShaderMaterial).set_shader_parameter("fill_color", Color(col.r, col.g, col.b, 0.3))
		(_highlight.material_override as ShaderMaterial).set_shader_parameter("rim_color", Color(col.r, col.g, col.b, 0.95))
		if is_instance_valid(_ghost):
			_ghost.visible = true
			_ghost.position = Vector3(pos.x, plant_y(_aim) + (0.0 if _aim_ok else 0.03), pos.z)
	else:
		_highlight.visible = false
		if is_instance_valid(_ghost):
			_ghost.visible = false


func _cleanup() -> void:
	var alive_z: Array = []
	for z in zombies:
		if is_instance_valid(z) and not z.dead:
			alive_z.append(z)
		elif is_instance_valid(z) and z.dead:
			pass
	zombies = alive_z
	var alive_p: Array = []
	for p in peas:
		if is_instance_valid(p) and not p.dead:
			alive_p.append(p)
	peas = alive_p
	var alive_s: Array = []
	for s in suns:
		if is_instance_valid(s) and not s.collected:
			alive_s.append(s)
	suns = alive_s
	var alive_c: Array = []
	for c in coins:
		if is_instance_valid(c) and not c.collected:
			alive_c.append(c)
	coins = alive_c
	for key in plants.keys():
		var p = plants[key]
		if not is_instance_valid(p) or p.dead:
			plants.erase(key)
	for key in pads.keys():
		var p = pads[key]
		if not is_instance_valid(p) or p.dead:
			pads.erase(key)
	for key in shells.keys():
		var p = shells[key]
		if not is_instance_valid(p) or p.dead:
			shells.erase(key)


func _check_end() -> void:
	if state != "playing":
		return
	if endless:
		return
	var live := zombies.filter(func(z): return is_instance_valid(z) and not z.dead and not z.charmed)
	if spawn_queue.size() == 0 and live.size() == 0 and time > 5.0:
		state = "won"
		App.sfx("win", -1.0)
		state_changed.emit(state)


# --- fx --------------------------------------------------------------------

func _burst(pos: Vector3, color: Color, amount: int, speed: float, size: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.75
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 75.0
	pm.initial_velocity_min = speed * 0.45
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -8.5, 0)
	pm.scale_min = size
	pm.scale_max = size * 1.7
	pm.color = color
	pm.damping_min = 1.0
	pm.damping_max = 3.0
	p.process_material = pm
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 5
	mesh.rings = 3
	p.draw_pass_1 = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	p.material_override = mat
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.4).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)


# --- hud -------------------------------------------------------------------

func progress() -> float:
	if endless:
		# in endless the bar becomes a "next wave incoming" gauge
		var left := next_wave_t - time
		return 1.0 - clampf(left / maxf(wave_interval, 0.001), 0.0, 1.0)
	var total: int = level["waves"].size()
	if total == 0:
		return 0.0
	return clamp(float(wave_index) / float(total), 0.0, 1.0)


func seed_slots() -> Array:
	var out: Array = []
	for kind in seeds:
		var def := Data.plant(kind)
		var cd := float(cooldowns.get(kind, 0.0))
		out.append({
			"kind": kind,
			"name": str(def["name"]),
			"cost": int(def["cost"]),
			"ready": cd <= 0.01,
			"cooldown01": clamp(cd / max(0.01, float(def["recharge"])), 0.0, 1.0),
			"affordable": sun >= int(def["cost"]),
			"selected": selected == kind,
			"hint": str(def["hint"]),
			"tags": str(def.get("tags", "")),
		})
	return out


func hint_text() -> String:
	if state == "won":
		return "草坪安全了"
	if state == "lost":
		return "僵尸进屋了……"
	if selected != "":
		if _aim.x < 0:
			return "看向草坪选一格"
		if not _aim_ok:
			if craters.has(_aim):
				return "这里刚被炸出坑，暂时种不了"
			if is_water_cell(_aim) and not pads.has(_aim) and not bool(Data.plant(selected).get("water", false)):
				return "水面上需要先种睡莲"
			if selected == "pumpkin" and shells.has(_aim):
				return "这一格已经有南瓜头了"
			if plants.has(_aim):
				return "这一格已经有植物了"
			if sun < int(Data.plant(selected)["cost"]):
				return "阳光不够"
			return "这一格不能种"
		return "左键种下 · Q 铲除"
	return "1-9 选植物 · 走近阳光自动收取 · F 推开僵尸"


func snapshot() -> Dictionary:
	return {
		"state": state,
		"sun": sun,
		"plants": plants.size() + pads.size() + shells.size(),
		"coins": stat_coins,
		"zombies": zombies.size(),
		"queued": spawn_queue.size(),
		"time": snappedf(time, 0.1),
		"wave": wave_index,
		"mowers": mowers.filter(func(m): return is_instance_valid(m) and not m.spent).size(),
		"level": level["id"],
		"endless": endless,
		"endless_wave": endless_wave,
	}
