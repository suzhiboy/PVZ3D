class_name MainGame
extends Node

## Boots the game: menu camera, level loading, input routing, pausing, results.

## 注意：新增 class_name 后其他脚本需要 preload，因为 godot 的全局类缓存还没刷新
## 用 preload 拿脚本，变量声明成无类型 Node 可以避开解析期类型检查
const ALMANAC_SCRIPT := preload("res://scripts/ui/almanac.gd")
const STORE_SCRIPT := preload("res://scripts/ui/store.gd")
const TOMB_SCRIPT := preload("res://scripts/ui/menu_tomb.gd")

var hud: Hud
var menu: MenuScreen
var tomb: Node
var chooser: SeedChooser
var almanac: Node
var store: Node
var world: WorldBuilder
var player: PlayerController
var match_ref: Match
var menu_cam: Camera3D
var mode := "menu"
var current_id := ""
var start_doors_open := false
var _menu_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_scene_grade()

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.resume_pressed.connect(_resume)
	hud.restart_pressed.connect(_restart)
	hud.menu_pressed.connect(_open_menu)
	hud.next_pressed.connect(_next_level)
	hud.settings_changed.connect(_apply_settings)

	menu = MenuScreen.new()
	menu.name = "Menu"
	add_child(menu)
	menu.level_chosen.connect(_choose_level)
	menu.continue_pressed.connect(_continue)
	menu.endless_chosen.connect(func() -> void: _choose_level("endless"))
	menu.settings_changed.connect(_apply_settings)
	menu.quit_pressed.connect(func() -> void: get_tree().quit())
	menu.almanac_pressed.connect(_open_almanac)
	menu.store_pressed.connect(_open_store)
	# the cards are gone: the menu is the gravestone now, but the settings
	# overlay still belongs to this layer
	menu.show_cards(false)

	tomb = TOMB_SCRIPT.new()
	tomb.name = "MenuTomb"
	add_child(tomb)
	tomb.level_chosen.connect(_choose_level)
	tomb.continue_pressed.connect(_continue)
	tomb.endless_chosen.connect(func() -> void: _choose_level("endless"))
	tomb.settings_pressed.connect(_on_menu_settings)
	tomb.quit_pressed.connect(func() -> void: get_tree().quit())
	tomb.almanac_pressed.connect(_open_almanac)
	tomb.store_pressed.connect(_open_store)

	almanac = ALMANAC_SCRIPT.new()
	almanac.name = "Almanac"
	add_child(almanac)
	almanac.closed.connect(_on_almanac_closed)

	store = STORE_SCRIPT.new()
	store.name = "Store"
	add_child(store)
	store.closed.connect(_on_store_closed)
	store.purse_changed.connect(func(_v: int) -> void:
		if menu != null:
			menu.refresh()
	)

	chooser = SeedChooser.new()
	chooser.name = "SeedChooser"
	add_child(chooser)
	chooser.confirmed.connect(_on_loadout_confirmed)
	chooser.cancelled.connect(_on_loadout_cancelled)

	var args := OS.get_cmdline_user_args()
	var shot := ""
	var lvl := ""
	var out := ""
	var warp := 0.0
	var cam := ""
	var pre := ""
	var sim := 0.0
	var sel := ""
	var walk := ""
	var loadout := ""
	var test := ""
	var hide_ui := false
	for a in args:
		var arg: String = a.trim_prefix("--")
		if arg.begins_with("shot="):
			shot = arg.trim_prefix("shot=")
		elif arg.begins_with("level="):
			lvl = arg.trim_prefix("level=")
		elif arg.begins_with("out="):
			out = arg.trim_prefix("out=")
		elif arg.begins_with("warp="):
			warp = float(arg.trim_prefix("warp="))
		elif arg.begins_with("cam="):
			cam = arg.trim_prefix("cam=")
		elif arg.begins_with("plants="):
			pre = arg.trim_prefix("plants=")
		elif arg.begins_with("sim="):
			sim = float(arg.trim_prefix("sim="))
		elif arg.begins_with("sel="):
			sel = arg.trim_prefix("sel=")
		elif arg.begins_with("walk="):
			walk = arg.trim_prefix("walk=")
		elif arg == "hud=off":
			hide_ui = true
		elif arg.begins_with("loadout="):
			loadout = arg.trim_prefix("loadout=")
		elif arg.begins_with("test="):
			test = arg.trim_prefix("test=")
		elif arg.begins_with("doors="):
			start_doors_open = arg.trim_prefix("doors=") == "open"
	if test != "":
		_run_test(test)
		return
	if walk != "":
		_walk_test(walk)
		return
	if sim > 0.0:
		_sim(str(lvl if lvl != "" else "front-1"), sim, pre)
		return
	if shot != "":
		_shot(shot, lvl, out, warp, cam, pre, sel, loadout, hide_ui)
	else:
		_open_menu()


func open_all_doors() -> void:
	if world == null:
		return
	for d in world.doors:
		if is_instance_valid(d):
			d.set_open(true, false)


## A whisper of split-toning, edge falloff and paper grain. It sits below the
## HUD and menu layers, so only the 3D miniature is graded.
func _build_scene_grade() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SceneGrade"
	layer.layer = 2
	add_child(layer)
	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/grade.gdshader")
	wash.material = mat
	layer.add_child(wash)


func _walk_test(mode: String) -> void:
	_start_level("front-1")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if mode == "door" or mode == "doorclosed":
		if mode == "door":
			open_all_doors()
		player.spawn(Vector3(-7.6, 0.5, -0.55), PI * 0.5)
	elif mode == "backyard":
		open_all_doors()
		player.spawn(Vector3(-16.9, 0.5, 3.35), PI * 0.5)
	elif mode == "gateclosed":
		player.spawn(Vector3(-17.6, 0.5, 3.35), PI * 0.5)
		for d in world.doors:
			if is_instance_valid(d) and d.label == "后院栅栏门":
				d.set_open(false, false)
		for d in world.doors:
			if is_instance_valid(d) and d.label == "后门":
				d.set_open(true, false)
	elif mode == "chimney":
		player.spawn(Vector3(-13.1, 3.45, -3.55), 0.0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		print("[climb] start=", player.global_position, " look=", world.chimney_look(player.eye_position(), player.look_dir()))
		player.climb_to(world.chimney_path(1), 2.7)
		for i in range(260):
			await get_tree().physics_frame
		print("[climb] final=", player.global_position, " on_floor=", player.is_on_floor(), " climbing=", player.climbing)
		get_tree().quit()
		return
	else:
		player.spawn(Vector3(-16.85, 0.5, -3.30), PI)
	player.active = true
	await get_tree().physics_frame
	Input.action_press("move_forward")
	for i in range(240):
		await get_tree().physics_frame
		if i % 60 == 59:
			print("[walk] t=%d pos=%s" % [i + 1, str(player.global_position)])
	Input.action_release("move_forward")
	print("[walk] final pos=", player.global_position, " on_floor=", player.is_on_floor())
	get_tree().quit()


## Logic check for the loadout screen: every card can be removed, overfilling is
## refused, and the selected belt is persisted exactly as picked.
func _run_test(which: String) -> void:
	match which:
		"choice":
			_choice_test()
		"flow":
			_flow_test()
		"campaign":
			_campaign_expansion_test()
		"plants":
			_plants_test()
		"zombies":
			_zombies_test()
		"coins":
			_coins_test()
		"store":
			_store_test()
		"art":
			_art_test()
		"water":
			_water_test()
		"audio":
			_audio_test()
		_:
			print("[test] unknown: ", which)
			get_tree().quit()


## 每个入口：关卡卡片、继续游戏、下一关都必须落在选卡界面。
func _flow_test() -> void:
	hud.visible = false
	for lv in Data.LEVELS:
		var id := str(lv["id"])
		_choose_level(id)
		print("[flow] ", id, " chooser=", chooser.root.visible, " opened=", chooser.level_id,
			" slots=", chooser.slots, " picks=", chooser.picks.size(), " mode=", mode)
		chooser.close()
	current_id = "front-1"
	_next_level()
	print("[flow] next-level -> chooser=", chooser.root.visible, " level=", chooser.level_id)
	chooser.close()
	current_id = "front-1"
	_continue()
	print("[flow] continue -> chooser=", chooser.root.visible, " level=", chooser.level_id)
	chooser.close()
	_choose_level("front-2")
	chooser._on_tile_tapped("kernelpult")
	var picked: int = chooser.picks.size()
	chooser._confirm()
	print("[flow] confirm -> mode=", mode, " belt=", match_ref.seeds, " cards=", hud._cards.size(), " picked=", picked)

	# endless has more default cards than slots — the belt must be capped
	_choose_level("endless")
	print("[flow] endless chooser=", chooser.root.visible, " slots=", chooser.slots,
		" picks=", chooser.picks.size())
	chooser._confirm()
	print("[flow] endless belt=", match_ref.seeds.size(), " cards=", hud._cards.size(),
		" endless=", match_ref.endless, " waves=", match_ref.level["waves"].size())
	get_tree().quit()


## Campaign contract for the expanded campaign. Keep this test data-driven so
## adding a level updates the sequential flow automatically while the count,
## uniqueness, and menu pagination requirements remain explicit.
func _campaign_expansion_test() -> void:
	var catalog: Array = Data.LEVELS
	var validation := Data.validate_levels(catalog)
	assert(bool(validation["ok"]), "campaign catalog validation failed: %s" % "; ".join(validation["errors"]))
	assert(catalog.size() == 12, "campaign catalog must contain exactly 12 levels")
	var malformed: Array = [catalog[0].duplicate(true)]
	malformed[0]["id"] = ""
	malformed[0]["yard"] = "moon"
	malformed[0]["waves"] = [{"at": 4.0, "spawns": []}, {"at": 3.0, "spawns": [{"kind": "not-a-zombie"}]}]
	var malformed_result := Data.validate_levels(malformed)
	assert(not bool(malformed_result["ok"]), "validator must reject malformed catalog")

	var ids := {}
	for entry in catalog:
		var id := str(entry.get("id", ""))
		assert(id != "", "campaign level IDs must not be empty")
		assert(not ids.has(id), "campaign level IDs must be unique: %s" % id)
		ids[id] = true
		assert(Data.level_exists(id), "campaign catalog ID must resolve in Data.level_exists: %s" % id)

	# The stone menu owns the page boundaries. Keep this test coupled to that
	# shared API so a four-entry hardcoded menu cannot pass by accident.
	var page_size := TOMB_SCRIPT.LEVEL_PAGE_SIZE
	var page_count := TOMB_SCRIPT.level_page_count(catalog.size())
	assert(page_count == 3, "campaign menu must expose exactly three pages")
	for page in range(page_count):
		var bounds := TOMB_SCRIPT.level_page_bounds(page, catalog.size())
		var first := bounds.x
		var last := bounds.y
		var entries: Array = catalog.slice(first, last)
		assert(entries.size() <= page_size, "campaign menu page exceeds four entries")

	# The legacy 2-D menu keeps the full catalog but only presents one page of
	# cards at a time. Verify all three pages directly when the menu is available.
	if menu != null and is_instance_valid(menu):
		for page in range(page_count):
			menu._set_page(page)
			var visible_cards := 0
			for card in menu.cards:
				if card.visible:
					visible_cards += 1
			assert(visible_cards <= 4, "2D menu page exceeds four visible cards")

	# Exercise the complete ordered flow from the first catalog entry to the
	# final one.  Each selection must land on the corresponding chooser card.
	for entry in catalog:
		var id := str(entry["id"])
		_choose_level(id)
		assert(mode == "chooser", "campaign selection must open chooser: %s" % id)
		assert(chooser.level_id == id, "chooser must open selected campaign level: %s" % id)
		chooser.close()

	# The next-level transition must advance every adjacent pair and leave the
	# menu after the final campaign level.
	for i in range(catalog.size() - 1):
		current_id = str(catalog[i]["id"])
		_next_level()
		assert(mode == "chooser", "next-level must open chooser after %s" % current_id)
		assert(chooser.level_id == str(catalog[i + 1]["id"]),
			"next-level must advance to catalog successor")
		chooser.close()
	current_id = str(catalog[catalog.size() - 1]["id"])
	_next_level()
	assert(mode == "menu", "next-level after final campaign level must return to menu")
	print("[campaign] catalog=", catalog.size(), " pages=", page_count, " flow=ok")
	get_tree().quit()


func _test_zombie(m: Match, kind: String, lane: int) -> ZombieUnit:
	m.spawn_zombie(kind, lane)
	return m.zombies[m.zombies.size() - 1]


## Behaviour check for the original plants plus the PVZ2 newcomers.
func _plants_test() -> void:
	var belt := ["sunflower", "peashooter", "pumpkin", "kernelpult", "melonpult", "puffshroom",
		"sunshroom", "fumeshroom", "hypnoshroom", "iceshroom", "doomshroom", "magnetshroom"]
	_start_level("front-2", belt)
	var m := match_ref
	m.sun = 9000
	m.cooldowns.clear()
	m.spawn_queue = [{"t": 9999.0, "kind": "basic", "lane": 0, "wave": 0}]

	# 1) pumpkin wraps a plant in the same cell and eats the damage first
	var ok_p := m.plant_at(Vector2i(1, 0), "peashooter")
	var ok_s := m.plant_at(Vector2i(1, 0), "pumpkin")
	var inner: PlantUnit = m.plants.get(Vector2i(1, 0))
	var shell: PlantUnit = m.shells.get(Vector2i(1, 0))
	print("[plants] shell: plant=", ok_p, " wrap=", ok_s, " inner=", inner != null, " shell=", shell != null)
	m.cooldowns.clear()
	m.sun = 9000
	var biter := _test_zombie(m, "basic", 0)
	biter.body_x = inner.global_position.x + 0.62
	biter.global_position.x = biter.body_x
	for i in range(100):
		m.update(1.0 / 60.0)
	print("[plants] shell bite -> shell_hp=", int(shell.hp), "/", int(shell.max_hp),
		" inner_hp=", int(inner.hp), "/", int(inner.max_hp), " eating=", biter.eating)

	# 2) magnet-shroom strips a bucket
	m.cooldowns.clear()
	m.sun = 9000
	var bucket := _test_zombie(m, "bucket", 2)
	bucket.body_x = m.cell_center(Vector2i(6, 2)).x + 0.8
	bucket.global_position.x = bucket.body_x
	m.plant_at(Vector2i(4, 2), "magnetshroom")
	for i in range(220):
		m.update(1.0 / 60.0)
	print("[plants] magnet -> armor=", int(bucket.armor), "/", int(bucket.max_armor))

	# 3) doom-shroom blasts and leaves a crater that refuses seeds
	m.cooldowns.clear()
	m.sun = 9000
	var doomed := _test_zombie(m, "bucket", 3)
	var blast_cell := Vector2i(5, 3)
	doomed.body_x = m.cell_center(blast_cell).x + 0.7
	doomed.global_position.x = doomed.body_x
	m.plant_at(blast_cell, "doomshroom")
	for i in range(140):
		m.update(1.0 / 60.0)
	print("[plants] doom -> dead=", doomed.dead or doomed.dying > 0.0, " crater=", m.craters.has(blast_cell),
		" blocked=", not m.can_plant(blast_cell, "peashooter"))

	# 4) hypno-shroom flips the zombie that eats it
	m.cooldowns.clear()
	m.sun = 9000
	var hz := _test_zombie(m, "basic", 4)
	var hcell := Vector2i(4, 4)
	hz.body_x = m.cell_center(hcell).x + 0.62
	hz.global_position.x = hz.body_x
	m.plant_at(hcell, "hypnoshroom")
	for i in range(420):
		m.update(1.0 / 60.0)
	print("[plants] hypno -> charmed=", hz.charmed, " plant_gone=", not m.plants.has(hcell),
		" life=", snappedf(hz.charm_life, 0.1))

	# 5) puff + fume damage from the right distances
	m.cooldowns.clear()
	m.sun = 9000
	var fr := _test_zombie(m, "basic", 5)
	fr.body_x = m.cell_center(Vector2i(7, 5)).x
	fr.global_position.x = fr.body_x
	m.plant_at(Vector2i(5, 5), "fumeshroom")
	m.plant_at(Vector2i(6, 5), "puffshroom")
	for i in range(200):
		m.update(1.0 / 60.0)
	print("[plants] puff+fume hp=", int(fr.hp), "/", int(fr.max_hp))

	# 6) sun-shroom pays out
	m.cooldowns.clear()
	m.sun = 9000
	m.plant_at(Vector2i(0, 5), "sunshroom")
	var sun0: int = m.sun
	for i in range(520):
		m.update(1.0 / 60.0)
	print("[plants] sunshroom -> sun+=", m.sun - sun0, " orbs_on_lawn=", m.suns.size())

	# 7) ice-shroom freezes the whole lawn
	m.cooldowns.clear()
	m.sun = 9000
	var icicle := _test_zombie(m, "cone", 3)
	icicle.body_x = m.cell_center(Vector2i(7, 3)).x + 0.4
	icicle.global_position.x = icicle.body_x
	m.plant_at(Vector2i(7, 1), "iceshroom")
	for i in range(110):
		m.update(1.0 / 60.0)
	var chilled := 0
	for zz in m.zombies:
		if is_instance_valid(zz) and zz.stun > 0.0 and not zz.charmed:
			chilled += 1
	print("[plants] iceshroom -> chilled=", chilled, "/", m.zombies.size())

	# 8) both pults land their payload
	m.cooldowns.clear()
	m.sun = 9000
	var lob_target := _test_zombie(m, "bucket", 1)
	lob_target.body_x = m.cell_center(Vector2i(7, 1)).x + 1.2
	lob_target.global_position.x = lob_target.body_x
	m.plant_at(Vector2i(2, 1), "kernelpult")
	m.plant_at(Vector2i(1, 1), "melonpult")
	for i in range(260):
		m.update(1.0 / 60.0)
	print("[plants] pults -> hp=", int(lob_target.hp), "/", int(lob_target.max_hp),
		" armor=", int(lob_target.armor), " lobs_alive=", m.lobs.size())

	# 9) PVZ2 newcomers: melee, three-lane flame, piercing beam and balloon counter
	m.cooldowns.clear()
	m.sun = 9000
	var bonk_z := _test_zombie(m, "basic", 0)
	bonk_z.body_x = m.cell_center(Vector2i(4, 0)).x + 0.62
	bonk_z.global_position.x = bonk_z.body_x
	m.plant_at(Vector2i(4, 0), "bonkchoy")
	var bonk_hp := bonk_z.hp
	for i in range(90):
		m.update(1.0 / 60.0)
	print("[plants] bonkchoy -> damage=", int(bonk_hp - bonk_z.hp))

	m.cooldowns.clear()
	var flame_z := _test_zombie(m, "basic", 1)
	flame_z.body_x = m.cell_center(Vector2i(6, 1)).x
	flame_z.global_position.x = flame_z.body_x
	var flame_adj := _test_zombie(m, "basic", 2)
	flame_adj.body_x = m.cell_center(Vector2i(6, 2)).x
	flame_adj.global_position.x = flame_adj.body_x
	m.plant_at(Vector2i(4, 1), "snapdragon")
	var flame_hp := flame_z.hp + flame_adj.hp
	for i in range(120):
		m.update(1.0 / 60.0)
	print("[plants] snapdragon -> damage=", int(flame_hp - flame_z.hp - flame_adj.hp))

	m.cooldowns.clear()
	var beam_a := _test_zombie(m, "basic", 3)
	beam_a.body_x = m.cell_center(Vector2i(7, 3)).x
	beam_a.global_position.x = beam_a.body_x
	var beam_b := _test_zombie(m, "basic", 3)
	beam_b.body_x = m.cell_center(Vector2i(5, 3)).x
	beam_b.global_position.x = beam_b.body_x
	m.plant_at(Vector2i(2, 3), "laserbean")
	var beam_hp := beam_a.hp + beam_b.hp
	for i in range(180):
		m.update(1.0 / 60.0)
	print("[plants] laserbean -> piercing_damage=", int(beam_hp - beam_a.hp - beam_b.hp))

	m.cooldowns.clear()
	var balloon := _test_zombie(m, "balloon", 4)
	balloon.body_x = m.cell_center(Vector2i(7, 4)).x
	balloon.global_position.x = balloon.body_x
	m.plant_at(Vector2i(2, 4), "blover")
	for i in range(70):
		m.update(1.0 / 60.0)
	print("[plants] blover -> balloon_removed=", balloon.dead or balloon.dying > 0.0)

	# 10) digging a hypno-shroom must not charm anything
	m.cooldowns.clear()
	m.sun = 9000
	var dcell := Vector2i(2, 3)
	var dig_z := _test_zombie(m, "basic", 3)
	dig_z.body_x = m.cell_center(dcell).x + 0.72
	dig_z.global_position.x = dig_z.body_x
	m.plant_at(dcell, "hypnoshroom")
	m._aim = dcell
	var dug: bool = m.dig_here()
	for i in range(18):
		m.update(1.0 / 60.0)
	print("[plants] dig hypno -> dug=", dug, " still_there=", m.plants.has(dcell),
		" charmed=", dig_z.charmed, "  (charmed must be false)")
	get_tree().quit()


## Behaviour check for the five newcomers: vault, screen door, balloon,
## dancer summon, gargantuar smash.
func _zombies_test() -> void:
	var belt := ["sunflower", "peashooter", "wallnut", "melonpult", "kernelpult", "snowpea"]
	_start_level("front-2", belt)
	var m := match_ref
	m.sun = 9000
	m.cooldowns.clear()
	m.spawn_queue = [{"t": 9999.0, "kind": "basic", "lane": 0, "wave": 0}]

	# 1) pole vaulter clears one plant instead of eating it
	m.cooldowns.clear()
	m.sun = 9000
	var vcell := Vector2i(4, 0)
	m.plant_at(vcell, "wallnut")
	var nut: PlantUnit = m.plants.get(vcell)
	var vaulter := _test_zombie(m, "pole", 0)
	vaulter.body_x = m.cell_center(vcell).x + 1.4
	vaulter.global_position.x = vaulter.body_x
	for i in range(150):
		m.update(1.0 / 60.0)
	print("[zombies] pole -> passed=", vaulter.body_x < nut.global_position.x,
		" nut_hp=", int(nut.hp), "/", int(nut.max_hp), " vault_left=", vaulter.vault_left)

	# 2) screen door eats peas, but a lobbed shot goes over it
	m.cooldowns.clear()
	m.sun = 9000
	var door_z := _test_zombie(m, "screendoor", 1)
	door_z.body_x = m.cell_center(Vector2i(6, 1)).x + 0.4
	door_z.global_position.x = door_z.body_x
	var hp_before := door_z.hp
	m.fire_pea(Vector3(m.cell_center(Vector2i(1, 1)).x, 0.86, 0.0), 1, 25.0, false, 0.0)
	for i in range(90):
		m.update(1.0 / 60.0)
	var armor_mid := door_z.armor
	var hp_mid := door_z.hp
	m.lob_at(Vector3(m.cell_center(Vector2i(1, 1)).x, 0.9, 0.0), 1, door_z.body_x, 80.0, "melonpult", false)
	for i in range(120):
		m.update(1.0 / 60.0)
	print("[zombies] screendoor -> peas_hit_armor=", int(armor_mid) < int(door_z.max_armor),
		" hp_untouched=", is_equal_approx(hp_mid, hp_before), " hp_after_lob=", int(door_z.hp))

	# 3) balloon flies over the whole lane without eating
	m.cooldowns.clear()
	m.sun = 9000
	var lane := 2
	var guards: Array = []
	for c in range(0, 7):
		var cell2 := Vector2i(c, lane)
		m.cooldowns.clear()
		m.sun = 9000
		m.plant_at(cell2, "wallnut")
		guards.append(m.plants.get(cell2))
	var balloon_z := _test_zombie(m, "balloon", lane)
	balloon_z.body_x = m.cell_center(Vector2i(8, lane)).x
	balloon_z.global_position.x = balloon_z.body_x
	for i in range(240):
		m.update(1.0 / 60.0)
	var intact := 0
	for g in guards:
		if is_instance_valid(g) and not g.dead and g.hp >= g.max_hp - 0.5:
			intact += 1
	print("[zombies] balloon -> intact_nuts=", intact, "/", guards.size(),
		" x=", snappedf(balloon_z.body_x, 0.1), " flying=", balloon_z.flying)

	# 4) dancer drags four backups in with him
	m.cooldowns.clear()
	m.sun = 9000
	var before := m.zombies.size()
	_test_zombie(m, "dancer", 3)
	var backups := 0
	for zz in m.zombies:
		if is_instance_valid(zz) and zz.kind == "backup":
			backups += 1
	print("[zombies] dancer -> spawned=", m.zombies.size() - before, " backups=", backups)

	# 5) gargantuar flattens a wallnut in one swing
	m.cooldowns.clear()
	m.sun = 9000
	var gcell := Vector2i(4, 4)
	m.plant_at(gcell, "tallnut")
	var big_nut: PlantUnit = m.plants.get(gcell)
	var giant := _test_zombie(m, "gargantuar", 4)
	giant.body_x = m.cell_center(gcell).x + 1.0
	giant.global_position.x = giant.body_x
	for i in range(120):
		m.update(1.0 / 60.0)
	print("[zombies] gargantuar -> plant_gone=", not m.plants.has(gcell),
		" nut_dead=", (not is_instance_valid(big_nut)) or big_nut.dead,
		" hp=", int(giant.hp), "/", int(giant.max_hp))
	get_tree().quit()


## Pool feedback regression: enter, wade and jump in water all emit effects,
## and the controller remains inside the pool collision instead of falling through.
func _water_test() -> void:
	_start_level("back-1")
	match_ref.spawn_queue = []
	var splashes := [0]
	var moving_splashes := [0]
	player.water_feedback.connect(func(_p: Vector3, _s: float, moving: bool) -> void:
		splashes[0] += 1
		if moving:
			moving_splashes[0] += 1
	)
	var z := Data.row_z(Data.BACK, 2)
	player.spawn(Vector3(-29.0, 0.15, z), PI * 0.5)
	for i in range(24):
		await get_tree().physics_frame
	Input.action_press("move_forward")
	for i in range(75):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in range(20):
		await get_tree().physics_frame
	print("[water] in_water=", player.in_water, " y=", snappedf(player.global_position.y, 0.01),
		" splashes=", splashes[0], " while_moving=", moving_splashes[0],
		" on_floor=", player.is_on_floor(), " fx_nodes=", world.water_fx.get_child_count())
	get_tree().quit()


## Music must load, loop, and switch without restarting the stream.
func _audio_test() -> void:
	var st = App._music.stream
	var mp3 := st as AudioStreamMP3
	print("[audio] loaded=", st != null, " mp3=", mp3 != null,
		" loop=", mp3.loop if mp3 != null else false,
		" length=", snappedf(st.get_length(), 0.1) if st != null else -1.0)
	App.play_music("day")
	await get_tree().create_timer(0.35).timeout
	var pk1 := App._music.pitch_scale
	var db1 := App._music.volume_db
	var pos1 := App._music.get_playback_position()
	App.play_music("day")
	await get_tree().create_timer(0.25).timeout
	print("[audio] same-track repeat -> restarted=", App._music.get_playback_position() < pos1)
	App.play_music("night")
	await get_tree().create_timer(0.35).timeout
	print("[audio] switch day->night pitch ", snappedf(pk1, 0.01), " -> ", snappedf(App._music.pitch_scale, 0.01),
		" db ", snappedf(db1, 0.1), " -> ", snappedf(App._music.volume_db, 0.1))
	App.settings["music"] = 0.0
	App.refresh_music_volume()
	await get_tree().create_timer(0.1).timeout
	print("[audio] muted db=", snappedf(App._music.volume_db, 0.1))
	App.settings["music"] = 0.55
	App.refresh_music_volume()
	print("[audio] restored db=", snappedf(App._music.volume_db, 0.1), " playing=", App._music.playing)
	get_tree().quit()


## Store check: every upgrade bought with coins must change the next match,
func _art_test() -> void:
	# Model guards: every plant/zombie must build, keep the rig contract that
	# gameplay animates by node name, and keep roughly the card silhouette.
	var fails := 0
	var cards := {}
	var f := FileAccess.open("res://tools/model-ref/out/cards.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			for group in ["plants", "zombies"]:
				for item in parsed.get(group, []):
					if item is Dictionary and item.has("kind"):
						cards[String(item["kind"])] = float(item.get("aspect", 0.0))
	print("[art] card aspects loaded: ", cards.size())

	var plant_extra := {"chomper": 2, "potatomine": 1, "wallnut": 1, "tallnut": 1,
		"kernelpult": 1, "melonpult": 1, "threepeater": 3}
	var plant_extra_name := {"potatomine": "Led", "wallnut": "Cracks", "tallnut": "Cracks",
		"kernelpult": "Arm", "melonpult": "Arm"}
	# A measuring holder keeps every model inside the tree, so _model_aabb can
	# use global transforms without spamming "!is_inside_tree()" errors.
	var holder := Node3D.new()
	holder.name = "ArtTestHolder"
	add_child(holder)
	for kind in Data.PLANTS.keys():
		var rig = Art.plant_model(kind)
		if rig == null or rig.head == null:
			print("[art] plant ", kind, " -> FAIL rig/head")
			fails += 1
			continue
		var meshes: int = rig.root.find_children("*", "MeshInstance3D", true, false).size()
		if meshes < 4:
			print("[art] plant ", kind, " -> FAIL meshes=", meshes)
			fails += 1
		var want: int = plant_extra.get(kind, 0)
		if rig.extra.size() != want:
			print("[art] plant ", kind, " -> FAIL extra=", rig.extra.size(), " want=", want)
			fails += 1
		elif want == 1 and plant_extra_name.has(kind):
			var nm: String = String(rig.extra[0].name)
			if nm != plant_extra_name[kind]:
				print("[art] plant ", kind, " -> FAIL extra name=", nm)
				fails += 1
		holder.add_child(rig.root)
		var mb: AABB = _model_aabb(rig.root)
		holder.remove_child(rig.root)
		var aspect: float = mb.size.x / maxf(mb.size.y, 0.001)
		if cards.has(kind) and float(cards[kind]) > 0.05:
			var want_aspect: float = float(cards[kind])
			var dev: float = absf(aspect - want_aspect) / want_aspect
			if dev > 0.45:
				print("[art] plant ", kind, " aspect=", String.num(aspect, 2),
					" card=", String.num(want_aspect, 2), " dev=", String.num(dev, 2), " (warn)")
		print("[art] plant ", kind, " ok meshes=", meshes, " aspect=", String.num(aspect, 2))

	for kind in Data.zombie_kinds():
		var zr = Art.zombie_model(kind)
		if zr == null or zr.head == null:
			print("[art] zombie ", kind, " -> FAIL rig/head")
			fails += 1
			continue
		var zm: int = zr.root.find_children("*", "MeshInstance3D", true, false).size()
		if zm < 12:
			print("[art] zombie ", kind, " -> FAIL meshes=", zm)
			fails += 1
		print("[art] zombie ", kind, " ok meshes=", zm)
	holder.queue_free()
	print("[art] fails=", fails)
	get_tree().quit()


## and the shop must never let the wallet go negative.
func _store_test() -> void:
	var wallet0 := App.wallet()
	var ups0: Dictionary = App.save.get("upgrades", {}).duplicate()
	var fails := 0

	# 1) buying spends exactly the listed price and raises the level
	App.save["coins"] = 1000
	App.save["upgrades"] = {}
	var lv0 := App.upgrade_level("sun_bank")
	var cost0 := App.upgrade_cost("sun_bank")
	var ok_buy := App.buy_upgrade("sun_bank")
	var spent: int = 1000 - App.wallet()
	print("[store] buy sun_bank -> ok=", ok_buy, " spent=", spent, " cost=", cost0,
		" lv=", App.upgrade_level("sun_bank"))
	if not (ok_buy and spent == cost0 and App.upgrade_level("sun_bank") == lv0 + 1):
		fails += 1

	# 2) cannot buy what the purse cannot cover, and max level is respected
	App.save["coins"] = 10
	var broke := App.buy_upgrade("spare_mower")
	print("[store] broke buy -> ", broke, " (expect false), coins=", App.wallet())
	if broke or App.wallet() != 10:
		fails += 1
	App.save["coins"] = 5000
	while App.upgrade_cost("shovel") >= 0:
		App.buy_upgrade("shovel")
	var capped := App.upgrade_cost("shovel")
	print("[store] shovel maxed -> cost=", capped, " lv=", App.upgrade_level("shovel"))
	if capped != -1:
		fails += 1

	# 3) upgrades reach the match: sun bonus, spares, refund, coin multiplier
	App.save["upgrades"] = {"sun_bank": 2, "spare_mower": 1, "shovel": 1, "purse": 1}
	_start_level("front-1", [])
	var m := match_ref
	var base_sun := int(Data.level("front-1")["sun"])
	print("[store] start sun=", m.sun, " base=", base_sun, " bonus=", App.starting_sun_bonus())
	if m.sun != base_sun + 50:
		fails += 1
	print("[store] spares=", m.spares_left, " mowers=", m.mowers.size())
	if m.spares_left != 1:
		fails += 1

	# 4) shovel refund returns a quarter of the plant's cost
	m.sun = 500
	m.spawn_queue = [{"t": 9999.0, "kind": "basic", "lane": 0, "wave": 0}]
	var cell := Vector2i(1, 1)
	m._aim = cell
	var planted := m.plant_at(cell, "wallnut")
	var before_dig: int = m.sun
	m.dig_here()
	var refund: int = m.sun - before_dig
	print("[store] planted=", planted, " dig refund=", refund,
		" expect=", int(round(50.0 * App.shovel_refund())))
	if not planted or refund != int(round(50.0 * App.shovel_refund())):
		fails += 1

	# 5) spare mower takes the breach instead of ending the run
	var z := _test_zombie(m, "basic", 0)
	m.spares_left = 1
	m.mowers.clear()
	m.breach(z)
	print("[store] breach with spare -> state=", m.state, " spares=", m.spares_left,
		" mowers=", m.mowers.size())
	if m.state == "lost" or m.spares_left != 0:
		fails += 1

	# 6) coin multiplier pays out extra per pickup
	App.save["upgrades"] = {"purse": 2}
	print("[store] coin multiplier lv2 =", App.coin_multiplier())
	if not is_equal_approx(App.coin_multiplier(), 1.5):
		fails += 1

	# restore the real save so a test run never edits the profile
	App.save["coins"] = wallet0
	App.save["upgrades"] = ups0
	App.persist()
	print("[store] fails=", fails)
	get_tree().quit()


## Economy check: the drop table pays out in range, coins magnet to the
## player, and the wallet banks across matches.
func _coins_test() -> void:
	_start_level("front-2")
	var m := match_ref
	m.sun = 9000
	m.cooldowns.clear()
	m.spawn_queue = [{"t": 9999.0, "kind": "basic", "lane": 0, "wave": 0}]
	for c in m.coins:
		c.queue_free()
	m.coins.clear()

	# 1) a gargantuar always pays 5
	var g := _test_zombie(m, "gargantuar", 0)
	g.damage(99999.0)
	for i in range(8):
		m.update(1.0 / 60.0)
	print("[coins] gargantuar guaranteed -> dropped=", m.coins.size(), " (expect 5)")
	for c in m.coins:
		c.queue_free()
	m.coins.clear()

	# 2) drop rate: 120 basics at 32% -> expect 26..52 (95%+ window)
	for i in range(120):
		var z := _test_zombie(m, "basic", i % 5)
		z.damage(99999.0)
	for i in range(30):
		m.update(1.0 / 60.0)
	var dropped: int = m.coins.size()
	var in_range: bool = dropped >= 26 and dropped <= 52
	print("[coins] 120 basics -> dropped=", dropped, " in_range=", in_range)

	# 3) magnet: stand a coin next to the player, it should fly in
	if m.coins.is_empty():
		print("[coins] no coins on field, magnet test skipped")
	else:
		var c0: CoinOrb = m.coins[0]
		player.global_position = Vector3(c0.global_position.x + 1.4, 0.02, c0.global_position.z)
		var before: int = m.stat_coins
		for i in range(240):
			m.update(1.0 / 60.0)
			if m.stat_coins > before:
				break
		print("[coins] magnet -> collected=", m.stat_coins - before, " hud_shown=", hud._coin.shown)

	# 4) wallet banks and reads back (then restore, so the test leaves no trace)
	var wallet0 := App.wallet()
	App.add_coins(m.stat_coins)
	var after_bank := App.wallet()
	print("[coins] bank ", wallet0, " + ", m.stat_coins, " -> ", after_bank,
		" ok=", after_bank == wallet0 + m.stat_coins)
	App.save["coins"] = wallet0
	App.persist()
	print("[coins] restored=", App.wallet())

	# 5) HUD badge exists and reads the live total
	print("[coins] badge=", hud._coin != null, " shown=", hud._coin.shown)
	get_tree().quit()


func _choice_test() -> void:
	menu.show_menu(true)
	chooser.open("front-1")
	print("[choice] open picks=", chooser.picks, " slots=", chooser.slots)
	chooser._on_tile_tapped("sunflower")
	print("[choice] remove sunflower -> ", chooser.picks, " removed=", not chooser.picks.has("sunflower"))
	chooser._on_tile_tapped("lilypad")
	print("[choice] tap lilypad -> ", chooser.picks)
	chooser._on_tile_tapped("lilypad")
	print("[choice] tap lilypad again -> ", chooser.picks)
	chooser._on_tile_tapped("wallnut")
	chooser._on_tile_tapped("cherrybomb")
	chooser._on_tile_tapped("snowpea")
	chooser._on_tile_tapped("squash")
	print("[choice] fill -> ", chooser.picks)
	chooser._on_tile_tapped("jalapeno")
	print("[choice] overfill attempt -> ", chooser.picks)
	chooser._on_slot_tapped(0)
	print("[choice] remove slot 0 -> ", chooser.picks)
	chooser._on_slot_tapped(2)
	print("[choice] remove slot 2 -> ", chooser.picks)
	chooser._randomise()
	print("[choice] random -> ", chooser.picks, " (", chooser.picks.size(), "/", chooser.slots, ")")
	chooser._reset_default()
	print("[choice] reset -> ", chooser.picks)
	chooser._confirm()
	print("[choice] saved=", App.picks_for("front-1"))
	print("[choice] level belt=", match_ref.seeds if match_ref != null else "none",
		" cards=", hud._cards.size() if hud != null else -1,
		" chooser_visible=", chooser.root.visible)
	var saved_loadout: Array = App.picks_for("front-1")
	chooser.open("front-1")
	chooser.picks = ["wallnut"]
	chooser._refresh()
	chooser._confirm()
	print("[choice] custom belt=", match_ref.seeds, " forced_sunflower=", match_ref.seeds.has("sunflower"))
	App.set_picks("front-1", saved_loadout)
	App.persist()
	get_tree().quit()


func _sim(id: String, seconds: float, pre: String) -> void:
	_start_level(id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if pre != "":
		for entry in pre.split(";"):
			var bits := entry.split(",")
			if bits.size() >= 3:
				match_ref.plant_at(Vector2i(int(bits[0]), int(bits[1])), str(bits[2]))
				match_ref.cooldowns.clear()
				match_ref.sun += 999
	var dt := 1.0 / 60.0
	var steps := int(seconds * 60.0)
	for i in range(steps):
		match_ref.update(dt)
	print("[sim] ", match_ref.snapshot(), " kills=", match_ref.stat_kills, " mowers_used=", match_ref.mowers_used)
	get_tree().quit()


func _shot(shot: String, lvl: String, out: String, warp: float, cam: String, pre: String, sel: String,
		loadout := "", hide_ui := false) -> void:
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if shot == "menu":
		_open_menu()
	elif shot == "almanac":
		_open_menu()
		# the shot needs a populated page, but this must not touch the real save
		App.save["seen"] = ["sunflower", "peashooter", "wallnut", "snowpea",
			"cherrybomb", "potatomine", "repeater", "chomper", "basic", "cone", "bucket"]
		await get_tree().process_frame
		_open_almanac()
		if sel != "":
			almanac._switch("zombies" if sel.begins_with("z:") else "plants")
			almanac._select(sel.trim_prefix("z:"))
	elif shot == "store":
		_open_menu()
		App.save["coins"] = maxi(App.wallet(), 900)
		await get_tree().process_frame
		_open_store()
	elif shot == "lineup":
		# art review: one model, neutral stage, card-like framing (`cam=` = view)
		_build_lineup(sel, cam)
	elif shot == "choose":
		_open_menu()
		await get_tree().process_frame
		chooser.open(lvl if lvl != "" else "front-2")
	elif shot == "zombie":
		_start_level(lvl if lvl != "" else "front-2")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		match_ref.spawn_zombie(loadout if loadout != "" else "basic", 2)
		var z: ZombieUnit = match_ref.zombies[0]
		z.body_x = 2.6
		z.global_position.x = z.body_x
		z.stun = 999.0
		z.set_physics_process(false)
		match_ref.spawn_queue = []
		if cam != "" and player != null:
			var b := cam.split(",")
			if b.size() >= 5:
				var eye := Vector3(float(b[0]), float(b[1]), float(b[2]))
				player.spawn(eye - Vector3(0, PlayerController.EYE, 0), deg_to_rad(float(b[3])))
				player.pitch = deg_to_rad(float(b[4]))
				player.camera.rotation.x = player.pitch
		if player:
			player.active = false
	elif shot == "coins":
		_start_level(lvl if lvl != "" else "front-1")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		for i in range(7):
			match_ref.spawn_coin(Vector3(-3.4 + i * 0.85, 0.4, -1.2 + (i % 3) * 0.75), 1)
# 内部用的 UI 提示：HUD 的文案与按钮状态
		if cam != "":
			var cb := cam.split(",")
			if cb.size() >= 3:
				var at := Vector3(float(cb[0]), 0.4, float(cb[2]))
				for k in range(3):
					match_ref.spawn_coin(at + Vector3(0.3 + k * 0.45, 0.0, 0.5 - k * 0.35), 1)
		match_ref.spawn_queue = []
		if cam != "" and player != null:
			var b := cam.split(",")
			if b.size() >= 5:
				var eye := Vector3(float(b[0]), float(b[1]), float(b[2]))
				player.spawn(eye - Vector3(0, PlayerController.EYE, 0), deg_to_rad(float(b[3])))
				player.pitch = deg_to_rad(float(b[4]))
				player.camera.rotation.x = player.pitch
		if player:
			player.active = false
	elif shot == "zombies":
		_start_level(lvl if lvl != "" else "front-2")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var kinds := ["pole", "screendoor", "balloon", "dancer", "gargantuar"]
		for i in range(kinds.size()):
			match_ref.spawn_zombie(str(kinds[i]), i)
			var z: ZombieUnit = match_ref.zombies[match_ref.zombies.size() - 1]
			z.body_x = 2.6 + (i % 2) * 0.9
			z.global_position.x = z.body_x
			z.stun = 999.0
		match_ref.spawn_queue = []
		if cam != "" and player != null:
			var b := cam.split(",")
			if b.size() >= 5:
				var eye := Vector3(float(b[0]), float(b[1]), float(b[2]))
				player.spawn(eye - Vector3(0, PlayerController.EYE, 0), deg_to_rad(float(b[3])))
				player.pitch = deg_to_rad(float(b[4]))
				player.camera.rotation.x = player.pitch
		if player:
			player.active = false
	elif shot == "water":
		_start_level(lvl if lvl != "" else "back-1")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await get_tree().physics_frame
		if cam != "" and player != null:
			var wb := cam.split(",")
			if wb.size() >= 5:
				var eye := Vector3(float(wb[0]), float(wb[1]), float(wb[2]))
				player.spawn(eye - Vector3(0, PlayerController.EYE, 0), deg_to_rad(float(wb[3])))
				player.pitch = deg_to_rad(float(wb[4]))
				player.camera.rotation.x = player.pitch
		if player:
			player.active = false
	elif shot == "pause":
		_start_level(lvl if lvl != "" else "front-2")
		await get_tree().create_timer(0.5).timeout
		_pause()
	elif shot == "end":
		_start_level(lvl if lvl != "" else "front-1")
		await get_tree().create_timer(0.4).timeout
		if lvl == "endless":
			hud.show_end(false, {"endless": true, "wave": 17, "best": 17, "new_record": true,
				"time": 642.0, "kills": 121, "plants": 46, "sun": 3125, "coins": 486, "has_next": false})
		else:
			hud.show_end(true, {"stars": 3, "time": 148.0, "kills": 18, "plants": 14, "mowers": 5,
				"sun": 975, "coins": 342, "has_next": true})
		mode = "end"
	else:
		var id := lvl if lvl != "" else "front-1"
		_start_level(id, loadout.split(",", false) if loadout != "" else [])
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if pre != "":
			for entry in pre.split(";"):
				var bits := entry.split(",")
				if bits.size() >= 3:
					match_ref.plant_at(Vector2i(int(bits[0]), int(bits[1])), str(bits[2]))
					match_ref.cooldowns.clear()
					match_ref.sun += 999
		if warp > 0.0:
			var steps := int(warp * 60.0)
			for i in range(steps):
				match_ref.update(1.0 / 60.0)
			# a sun orb that drifted into the lens ruins the shot
			for orb in match_ref.suns:
				if is_instance_valid(orb):
					orb.queue_free()
			match_ref.suns.clear()
		if cam != "" and player != null:
			var b := cam.split(",")
			if b.size() >= 5:
				var eye := Vector3(float(b[0]), float(b[1]), float(b[2]))
				player.spawn(eye - Vector3(0, PlayerController.EYE, 0), deg_to_rad(float(b[3])))
				player.pitch = deg_to_rad(float(b[4]))
				player.camera.rotation.x = player.pitch
		if sel != "":
			match_ref.select_seed(sel)
		if player:
			player.active = false
		if match_ref:
			print("[sim] ", match_ref.snapshot(), " kills=", match_ref.stat_kills, " mowers=", match_ref.mowers_used)
	if hide_ui:
		if hud != null:
			hud.visible = false
		if player != null:
			var hand := player.get("_view") as Node3D
			if hand != null:
				hand.visible = false
	var settle_frames := 6 if shot == "water" else 40
	for i in range(settle_frames):
		await get_tree().process_frame
	if shot == "water" and world != null and world.water_fx != null:
		world.water_fx.splash(Vector3(-26.2, 0.0, Data.row_z(Data.BACK, 2) + 0.55), 1.45, false)
		for i in range(6):
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	print("[shot] image ", img.get_width(), "x", img.get_height())
	var err := ERR_UNAVAILABLE
	if out != "":
		err = img.save_png(out)
	print("[shot] save ", out, " -> ", err)
	get_tree().quit()
	await get_tree().process_frame
	OS.kill(OS.get_process_id())


## Art-review stage: one model, neutral backdrop, orthographic card-like framing.
## Driven by --shot=lineup --sel=<kind> --cam=front|threeq|side --out=<png>, or in
## bulk by start_art_sweep() (the shot flag needs cmdline args, which a live
## instance does not have).
func _build_lineup(sel_kind: String, view: String) -> void:
	# Hold a direct reference: renaming a parked node is not reliable enough to
	# free it by name, and a leftover stage would stack two models in one frame.
	if _lineup_stage != null and is_instance_valid(_lineup_stage):
		_lineup_stage.free()
	_lineup_stage = null
	if hud != null:
		hud.visible = false
	if world != null and is_instance_valid(world):
		world.visible = false
	if menu != null:
		menu.show_cards(false)
	if tomb != null and is_instance_valid(tomb):
		tomb.show_menu(false)
	if almanac != null:
		almanac.force_hide()
	if store != null:
		store.force_hide()

	var stage := Node3D.new()
	stage.name = "Lineup"
	# park the stage far above the yard so no fence/bush leaks into the frame
	stage.position = Vector3(0, 300.0, 0)
	add_child(stage)
	_lineup_stage = stage

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#e9e3d3")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#cfd8e6")
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, 42, 0)
	key.light_color = Color("#fff3d8")
	key.light_energy = 1.5
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-16, -120, 0)
	rim.light_color = Color("#a9c8e8")
	rim.light_energy = 0.7
	stage.add_child(rim)

	var kind := sel_kind if sel_kind != "" else "peashooter"
	var is_zombie := kind.begins_with("z:")
	var node: Node3D
	if is_zombie:
		node = Art.zombie_model(kind.trim_prefix("z:")).root
	else:
		node = Art.plant_model(kind).root
	stage.add_child(node)

	match view:
		"side":
			node.rotation.y = 0.0
		"threeq":
			node.rotation.y = -PI * 0.5 + 0.42
		_:
			node.rotation.y = -PI * 0.5

	var box := _model_aabb(node, stage.global_transform.affine_inverse())
	var center := box.get_center()
	var aspect := 16.0 / 9.0
	var flat := box.size.y < 0.3
	var span := maxf(box.size.y, box.size.x / aspect) * 1.12
	if flat:
		span = maxf(box.size.x, box.size.z) * 1.18
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(span, 0.2)
	cam.near = 0.05
	cam.far = 80.0
	stage.add_child(cam)
	# look_at takes GLOBAL coordinates, but the box above is in stage space
	cam.position = Vector3(center.x, center.y, center.z + 20.0)
	cam.look_at(stage.global_transform * Vector3(center.x, center.y, center.z))
	if flat:
		# a lily pad seen edge-on is a sliver — tilt down so the shape reads
		cam.position = Vector3(center.x, center.y + 12.0, center.z + 15.0)
		cam.look_at(stage.global_transform * Vector3(center.x, center.y, center.z))
	cam.current = true
	print("[lineup] kind=", kind, " view=", view, " aabb=", box, " ortho=", cam.size)


## Merge every mesh AABB of a built model into one box, expressed in the space of
## `to_space` (so a stage parked far from the origin still frames correctly).
static func _model_aabb(root: Node3D, to_space := Transform3D.IDENTITY) -> AABB:
	var box := AABB()
	var first := true
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var local: AABB = m.mesh.get_aabb()
		var xf := to_space * m.global_transform
		for i in range(8):
			var corner := local.get_endpoint(i)
			var p := xf * corner
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
	if first:
		box = AABB(Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 0.9, 0.6))
	return box


# --- art sweep -------------------------------------------------------------
# The bridge cannot pass cmdline args to a live instance, so batch art shots are
# driven from _process: build one stage, let it render, save, next.

var _sweep: Array = []
var _sweep_wait := 0
var _sweep_total := 0
var _lineup_stage: Node3D = null


func start_art_sweep(kinds: Array, views: Array, outdir: String) -> String:
	# Image.save_png does not create directories, so do it up front
	DirAccess.make_dir_recursive_absolute(outdir)
	_sweep.clear()
	for k in kinds:
		for v in views:
			var name := str(k).replace(":", "-")
			_sweep.append({
				"kind": str(k), "view": str(v),
				"out": "%s/%s-%s.png" % [outdir, name, str(v)],
				"built": false,
			})
	_sweep_total = _sweep.size()
	_sweep_wait = 2
	print("[sweep] queued ", _sweep_total, " shots -> ", outdir)
	return "%d shots" % _sweep_total


func _sweep_tick() -> void:
	if _sweep.is_empty():
		return
	if _sweep_wait > 0:
		_sweep_wait -= 1
		return
	var job: Dictionary = _sweep[0]
	if not bool(job["built"]):
		_build_lineup(str(job["kind"]), str(job["view"]))
		job["built"] = true
		_sweep_wait = 3
		return
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(str(job["out"]))
	print("[sweep] ", _sweep_total - _sweep.size() + 1, "/", _sweep_total,
		" ", job["kind"], " ", job["view"], " -> ", err)
	_sweep.pop_front()
	_sweep_wait = 2
	if _sweep.is_empty():
		print("[sweep] done")


func _process(delta: float) -> void:
	if not _sweep.is_empty():
		_sweep_tick()
	if mode == "playing" and match_ref != null and is_instance_valid(match_ref):
		match_ref.update(delta)
		_update_prompt()
	elif mode == "menu" and menu_cam != null and is_instance_valid(menu_cam):
		_menu_t += delta
		if tomb != null and is_instance_valid(tomb) and tomb.is_open():
			# a few centimetres of drift is enough: the stone stays framed
			var sway := Vector3(sin(_menu_t * 0.24) * 0.15, sin(_menu_t * 0.33) * 0.04, 0.0)
			menu_cam.position = tomb.cam_point(sway)
			menu_cam.look_at(tomb.look_point())
		else:
			var base := Vector3(10.4, 4.3, 5.4)
			var aim := Vector3(-13.8, 1.9, -0.8)
			menu_cam.position = base + Vector3(sin(_menu_t * 0.16) * 0.6, sin(_menu_t * 0.24) * 0.14, cos(_menu_t * 0.14) * 0.5)
			menu_cam.look_at(aim)


func _update_prompt() -> void:
	if world == null or player == null:
		return
	if player.climbing:
		hud.set_prompt("")
		return
	var d = world.door_in_view(player.eye_position(), player.look_dir())
	if d != null:
		hud.set_prompt("[E] " + ("关门" if d.open else "开门") + " · " + d.label)
		return
	var c := world.chimney_look(player.eye_position(), player.look_dir())
	if c > 0:
			hud.set_prompt("[E] 爬烟囱")
	elif c < 0:
		hud.set_prompt("[E] 打开舱门")
	else:
		hud.set_prompt("")


# --- flow ------------------------------------------------------------------

func _choose_level(id: String) -> void:
# 所有入口都会走到这里：关卡卡片、继续游戏、下一关
	mode = "chooser"
	get_tree().paused = false
	hud.hide_end()
	hud.set_prompt("")
	chooser.open(id)


func _on_loadout_confirmed(id: String, kinds: Array) -> void:
	chooser.close()
	_start_level(id, kinds)


func _on_loadout_cancelled() -> void:
	chooser.close()
	_open_menu()


func _open_menu() -> void:
	mode = "menu"
	if chooser != null:
		chooser.close()
	if almanac != null:
		almanac.force_hide()
	if store != null:
		store.force_hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	hud.hide_end()
	_teardown()
	_build_world("dawn")
	_place_tomb()
	_decorate_menu_garden()
	_build_menu_camera()
	tomb.show_menu(true)
	App.play_music("menu")


## The stone stands where the old card menu used to be: on the lawn in front of
## the porch, face turned east so the camera looks past it at the house.
func _place_tomb() -> void:
	if tomb == null or not is_instance_valid(tomb):
		return
	tomb.position = Vector3(-5.55, 0.0, 1.15)
	tomb.rotation.y = PI * 0.5


## Settings stays a card panel, floating over the 3-D menu (it dims the whole
## screen, so the stone showing through is exactly what we want).
func _on_menu_settings() -> void:
	if menu != null:
		menu.show_cards(false)
		menu._open_settings()


## 收尾：把状态改动写回存档并刷新界面
## 注意：UI 文案改动后要重新拍照验收
func _open_almanac() -> void:
	if mode != "menu":
		return
	tomb.show_menu(false)
	menu.show_cards(false)
	almanac.open("plants")


func _on_almanac_closed() -> void:
	if mode == "menu":
		tomb.show_menu(true)


func _open_store() -> void:
	if mode != "menu":
		return
	tomb.show_menu(false)
	menu.show_cards(false)
	store.open()


func _on_store_closed() -> void:
	if mode == "menu":
		tomb.show_menu(true)


func _decorate_menu_garden() -> void:
	var spots := [
		[1, 0, "sunflower"], [1, 2, "sunflower"], [1, 4, "sunflower"],
		[2, 1, "peashooter"], [2, 3, "peashooter"], [3, 4, "snowpea"],
		[3, 0, "repeater"], [3, 2, "wallnut"], [4, 1, "threepeater"],
		[4, 3, "tallnut"], [5, 2, "chomper"], [2, 4, "potatomine"],
		[5, 0, "bonkchoy"], [5, 4, "snapdragon"], [6, 1, "laserbean"], [6, 3, "blover"],
	]
	for s in spots:
		var pos := Vector3(Data.col_x(Data.FRONT, int(s[0])), 0.03, Data.row_z(Data.FRONT, int(s[1])))
		# keep the frame around the gravestone clear so the menu reads
		if tomb != null and is_instance_valid(tomb):
			var flat := Vector2(pos.x - tomb.position.x, pos.z - tomb.position.z)
			if flat.length() < 3.10:
				continue
		var u := PlantUnit.new()
		u.setup(str(s[2]), int(s[0]), int(s[1]), pos, 1.0, false)
		# sunflowers look at the gardener, but the menu camera is behind the
		# lawn — turn them round so the hero shot is not a field of seed heads
		if str(s[2]) == "sunflower":
			u.rotation.y = PI
		world.add_child(u)


func _continue() -> void:
	var target := str(Data.LEVELS[0]["id"])
	for lv in Data.LEVELS:
		if App.stars_for(str(lv["id"])) > 0:
			target = str(lv["id"])
	for i in range(Data.LEVELS.size() - 1):
		if App.stars_for(str(Data.LEVELS[i]["id"])) > 0 and App.stars_for(str(Data.LEVELS[i + 1]["id"])) == 0:
			target = str(Data.LEVELS[i + 1]["id"])
			break
	_choose_level(target)


func _start_level(id: String, picks: Array = []) -> void:
	if not Data.level_exists(id):
		push_warning("Unknown level '%s'; falling back to front-1" % id)
		id = "front-1"
	current_id = id
	var level := Data.level(id)
	var loadout: Array = picks.duplicate() if picks.size() > 0 else App.picks_for(id)
	if loadout.is_empty():
		loadout = Array(level["seeds"])
	get_tree().paused = false
	mode = "playing"
	menu.show_cards(false)
	if tomb != null and is_instance_valid(tomb):
		tomb.show_menu(false)
	chooser.close()
	hud.visible = true
	hud.hide_end()
	_teardown()
	var sky := str(level["sky"])
	_build_world(sky)
	App.play_music("endless" if bool(level.get("endless", false)) else ("night" if sky == "night" else "day"))

	player = PlayerController.new()
	player.name = "Player"
	add_child(player)
	var spawn := _spawn_for(str(level["yard"]))
	player.spawn(spawn[0], spawn[1])
	player.footstep.connect(_on_footstep)
	player.water_feedback.connect(_on_water_feedback)
	_apply_settings()

	match_ref = Match.new()
	match_ref.name = "Match"
	add_child(match_ref)
	match_ref.setup(level, player, world, player.add_shake, loadout)
	match_ref.state_changed.connect(_on_state)

	hud.bind(match_ref, player)
	if start_doors_open:
		open_all_doors()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var t := get_tree().create_timer(0.6)
	t.timeout.connect(func() -> void:
		if mode == "playing":
			hud.banner(str(level["name"]), false)
	)


func _spawn_for(yard_name: String) -> Array:
	if yard_name == "back":
		# start on the lawn just past the garden gate, not cooped up on the deck
		return [Vector3(-21.3, 0.05, 3.35), PI * 0.5]
	return [Vector3(-7.55, 0.55, -0.55), -PI * 0.5]


func _teardown() -> void:
	if match_ref != null and is_instance_valid(match_ref):
		match_ref.queue_free()
	match_ref = null
	if player != null and is_instance_valid(player):
		player.queue_free()
	player = null
	if world != null and is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null
	if menu_cam != null and is_instance_valid(menu_cam):
		menu_cam.queue_free()
	menu_cam = null


func _build_world(sky: String) -> void:
	world = WorldBuilder.new()
	world.name = "World"
	add_child(world)
	world.build(sky)


func _build_menu_camera() -> void:
	menu_cam = Camera3D.new()
	menu_cam.name = "MenuCam"
	menu_cam.fov = 52.0
	add_child(menu_cam)
	menu_cam.current = true
	if tomb != null and is_instance_valid(tomb):
		tomb.frame_camera(menu_cam)


func _apply_settings() -> void:
	App.persist()
	if player != null and is_instance_valid(player):
		player.mouse_sens = float(App.settings["sensitivity"])
		player.invert_y = bool(App.settings["invert_y"])


# --- input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if mode == "playing":
			_pause()
			get_viewport().set_input_as_handled()
		elif mode == "paused":
			_resume()
			get_viewport().set_input_as_handled()
		elif mode == "end":
			_open_menu()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# the almanac and the shop are modal: Esc backs out of them before anything else
	if mode == "menu":
		if event.is_action_pressed("ui_cancel"):
			if almanac != null and almanac.visible:
				almanac.close()
			elif store != null and store.visible:
				store.close()
		return
	if mode != "playing" or match_ref == null or not is_instance_valid(match_ref):
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if player != null and player.climbing:
		return

	if event.is_action_pressed("plant"):
		match_ref.plant_here()
	elif event.is_action_pressed("dig"):
		match_ref.dig_here()
	elif event.is_action_pressed("interact"):
		if player != null and player.climbing:
			return
		var door = world.door_in_view(player.eye_position(), player.look_dir()) if world != null else null
		if door != null:
			door.toggle()
			return
		var climb := world.chimney_look(player.eye_position(), player.look_dir()) if world != null else 0
		if climb != 0:
			player.climb_to(world.chimney_path(climb), 2.7 if climb > 0 else 2.4)
			App.sfx("chimney", -5.0, 1.0)
			hud.set_prompt("")
			return
		match_ref.collect_nearby()
	elif event.is_action_pressed("shove"):
		match_ref.shove()
	else:
		for i in range(9):
			if event.is_action_pressed("slot_%d" % (i + 1)):
				if i < match_ref.seeds.size():
					match_ref.select_seed(str(match_ref.seeds[i]))
				break


func _on_footstep(surface: String) -> void:
	var name := "step_grass"
	if surface == "water":
		name = "step_water"
	elif surface == "wood":
		name = "step_wood"
	App.sfx(name, -16.0, randf_range(0.9, 1.12))


func _on_water_feedback(pos: Vector3, strength: float, moving: bool) -> void:
	if world == null or not is_instance_valid(world):
		return
	if world.water_fx != null:
		world.water_fx.splash(pos, strength, moving)
	if not moving:
		App.sfx("step_water", -11.0, randf_range(0.72, 0.84))
		if player != null:
			player.add_shake(0.14 * strength)


func _pause() -> void:
	mode = "paused"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	hud.set_paused(true)
	hud.set_prompt("")


func _resume() -> void:
	get_tree().paused = false
	mode = "playing"
	hud.set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	match_ref.select_seed("")


func _restart() -> void:
	get_tree().paused = false
	_start_level(current_id)


func _next_level() -> void:
	if current_id == "endless":
		_open_menu()
		return
	for i in range(Data.LEVELS.size()):
		if str(Data.LEVELS[i]["id"]) == current_id:
			if i + 1 < Data.LEVELS.size():
				_choose_level(str(Data.LEVELS[i + 1]["id"]))
			else:
				_open_menu()
			return
	_open_menu()


func _on_state(s: String) -> void:
	if s != "won" and s != "lost":
		return
	mode = "end"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	var won := s == "won"
	var m := match_ref
	var earned := m.stat_coins
	if earned > 0:
		App.add_coins(earned)
	if m.endless:
		# endless cannot be won — always report it as a survival record
		var record := App.record_endless(m.endless_wave)
		hud.set_prompt("")
		hud.show_end(false, {
			"endless": true,
			"wave": m.endless_wave,
			"best": App.endless_best(),
			"new_record": record,
			"time": m.time,
			"kills": m.stat_kills,
			"plants": m.stat_plants,
			"sun": m.stat_sun,
			"coins": earned,
			"has_next": false,
		})
		return
	var stars := 0
	if won:
		stars = 1
		if m.mowers_used == 0:
			stars += 1
		if m.time <= float(m.level.get("par", 9999.0)):
			stars += 1
		App.record_level(current_id, stars, m.time)
		App.sfx("win", -2.0)
	var idx := 0
	for i in range(Data.LEVELS.size()):
		if str(Data.LEVELS[i]["id"]) == current_id:
			idx = i
	hud.set_prompt("")
	hud.show_end(won, {
		"stars": stars,
		"time": m.time,
		"kills": m.stat_kills,
		"plants": m.stat_plants,
		"mowers": m.mowers.filter(func(x): return is_instance_valid(x) and not x.spent).size(),
		"sun": m.stat_sun,
		"coins": earned,
		"has_next": won and idx + 1 < Data.LEVELS.size(),
	})
