class_name MainGame
extends Node

## Boots the game: menu camera, level loading, input routing, pausing, results.

var hud: Hud
var menu: MenuScreen
var chooser: SeedChooser
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
		_shot(shot, lvl, out, warp, cam, pre, sel, loadout)
	else:
		_open_menu()


func open_all_doors() -> void:
	if world == null:
		return
	for d in world.doors:
		if is_instance_valid(d):
			d.set_open(true, false)


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


## Logic check for the loadout screen: it must refuse to drop a required seed,
## refuse to overfill, and persist exactly what was picked.
func _run_test(which: String) -> void:
	match which:
		"choice":
			_choice_test()
		"flow":
			_flow_test()
		"plants":
			_plants_test()
		"zombies":
			_zombies_test()
		"audio":
			_audio_test()
		_:
			print("[test] unknown: ", which)
			get_tree().quit()


## Every entry point — level card, 继续游戏, 下一关 — must land on the chooser.
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

	# endless has a 12-seed default but only 9 slots — the belt must be capped
	_choose_level("endless")
	print("[flow] endless chooser=", chooser.root.visible, " slots=", chooser.slots,
		" picks=", chooser.picks.size())
	chooser._confirm()
	print("[flow] endless belt=", match_ref.seeds.size(), " cards=", hud._cards.size(),
		" endless=", match_ref.endless, " waves=", match_ref.level["waves"].size())
	get_tree().quit()


func _test_zombie(m: Match, kind: String, lane: int) -> ZombieUnit:
	m.spawn_zombie(kind, lane)
	return m.zombies[m.zombies.size() - 1]


## Behaviour check for the seven non-shooter newcomers + the two pults.
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

	# 9) digging a hypno-shroom must not charm anything
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


func _choice_test() -> void:
	menu.show_menu(true)
	chooser.open("front-1")
	print("[choice] open picks=", chooser.picks, " slots=", chooser.slots, " must=", chooser.must)
	chooser._on_tile_tapped("sunflower")
	print("[choice] tap required sunflower -> ", chooser.picks)
	chooser._on_tile_tapped("lilypad")
	print("[choice] tap lilypad -> ", chooser.picks)
	chooser._on_tile_tapped("lilypad")
	print("[choice] tap lilypad again -> ", chooser.picks)
	chooser._on_tile_tapped("wallnut")
	chooser._on_tile_tapped("snowpea")
	chooser._on_tile_tapped("squash")
	print("[choice] fill -> ", chooser.picks)
	chooser._on_tile_tapped("jalapeno")
	print("[choice] overfill attempt -> ", chooser.picks)
	chooser._on_slot_tapped(0)
	print("[choice] remove required slot 0 -> ", chooser.picks)
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
		loadout := "") -> void:
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if shot == "menu":
		_open_menu()
	elif shot == "choose":
		_open_menu()
		await get_tree().process_frame
		chooser.open(lvl if lvl != "" else "front-2")
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
	elif shot == "pause":
		_start_level(lvl if lvl != "" else "front-2")
		await get_tree().create_timer(0.5).timeout
		_pause()
	elif shot == "end":
		_start_level(lvl if lvl != "" else "front-1")
		await get_tree().create_timer(0.4).timeout
		if lvl == "endless":
			hud.show_end(false, {"endless": true, "wave": 17, "best": 17, "new_record": true,
				"time": 642.0, "kills": 121, "plants": 46, "sun": 3125, "has_next": false})
		else:
			hud.show_end(true, {"stars": 3, "time": 148.0, "kills": 18, "plants": 14, "mowers": 5, "sun": 975, "has_next": true})
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
	for i in range(40):
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


func _process(delta: float) -> void:
	if mode == "playing" and match_ref != null and is_instance_valid(match_ref):
		match_ref.update(delta)
		_update_prompt()
	elif mode == "menu" and menu_cam != null and is_instance_valid(menu_cam):
		_menu_t += delta
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
		hud.set_prompt("[E] 爬进烟囱")
	elif c < 0:
		hud.set_prompt("[E] 顺着烟囱下到二楼")
	else:
		hud.set_prompt("")


# --- flow ------------------------------------------------------------------

func _choose_level(id: String) -> void:
	# every entry point goes through here: level card, 继续游戏, 下一关
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
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	hud.hide_end()
	_teardown()
	_build_world("dawn")
	_decorate_menu_garden()
	_build_menu_camera()
	menu.show_menu(true)
	App.play_music("menu")


func _decorate_menu_garden() -> void:
	var spots := [
		[1, 0, "sunflower"], [1, 2, "sunflower"], [1, 4, "sunflower"],
		[2, 1, "peashooter"], [2, 3, "peashooter"], [3, 4, "snowpea"],
		[3, 0, "repeater"], [3, 2, "wallnut"], [4, 1, "threepeater"],
		[4, 3, "tallnut"], [5, 2, "chomper"], [2, 4, "potatomine"],
	]
	for s in spots:
		var u := PlantUnit.new()
		var pos := Vector3(Data.col_x(Data.FRONT, int(s[0])), 0.03, Data.row_z(Data.FRONT, int(s[1])))
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
	current_id = id
	var level := Data.level(id)
	var loadout: Array = picks.duplicate() if picks.size() > 0 else App.picks_for(id)
	if loadout.is_empty():
		loadout = Array(level["seeds"])
	get_tree().paused = false
	mode = "playing"
	menu.show_menu(false)
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
	menu_cam.fov = 56.0
	add_child(menu_cam)
	menu_cam.current = true


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
		"has_next": won and idx + 1 < Data.LEVELS.size(),
	})
