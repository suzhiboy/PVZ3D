class_name PlantUnit
extends Node3D

## One planted unit. Match drives tick(); the node handles its own look.

var kind := "sunflower"
var def: Dictionary
var col := 0
var row := 0
var hp := 300.0
var max_hp := 300.0
var timer := 0.0
var age := 0.0
var armed := true
var chewing := 0.0
var dead := false
var on_water := false
var facing := 1.0

var rig: Art.PlantRig
var _phase := 0.0
var _flash := 0.0
var _damage_stage := 0
var _squash_state := 0
var _squash_t := 0.0
var _squash_target := Vector3.ZERO
var _burn := 0.0
var _last_chomp := 0.0
var _match = null
const PLANT_SCALE := 1.18


func setup(p_kind: String, p_col: int, p_row: int, pos: Vector3, p_facing: float, water := false) -> void:
	kind = p_kind
	def = Data.plant(kind)
	col = p_col
	row = p_row
	hp = float(def["hp"])
	max_hp = hp
	on_water = water
	facing = p_facing
	position = pos
	rotation.y = 0.0 if p_facing > 0.0 else PI
	_phase = randf() * TAU
	rig = Art.plant_model(kind)
	add_child(rig.root)
	rig.root.scale = Vector3(0.05, 0.05, 0.05)
	var big := Vector3.ONE * PLANT_SCALE
	var tw := create_tween()
	tw.tween_property(rig.root, "scale", big, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if kind == "sunflower":
		timer = 6.0
	elif kind == "sunshroom":
		timer = 7.0
	elif kind in ["peashooter", "snowpea", "repeater", "threepeater", "puffshroom"]:
		timer = 0.5
	elif kind in ["kernelpult", "melonpult"]:
		timer = 2.2
	elif kind == "fumeshroom":
		timer = 0.8
	elif kind == "magnetshroom":
		timer = 2.5
	elif kind == "potatomine":
		armed = false
		timer = 0.0
	else:
		timer = 0.0


func _process(delta: float) -> void:
	if dead:
		return
	_phase += delta
	if rig == null:
		return
	var sway := sin(_phase * 1.7) * 0.045
	if rig.sway:
		rig.sway.rotation.z = sway
	if rig.head:
		rig.head.rotation.z = sin(_phase * 2.2 + 0.6) * 0.06

	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_clear_flash()

	match kind:
		"sunflower":
			if rig.head:
				rig.head.rotation.y = sin(_phase * 0.8) * 0.35
		"chomper":
			if rig.extra.size() >= 2:
				var jaw: Node3D = rig.extra[0]
				var upper: Node3D = rig.extra[1]
				if chewing > 0.0:
					jaw.rotation.z = -0.5 + sin(_phase * 16.0) * 0.12
					upper.rotation.z = 0.5 - sin(_phase * 16.0) * 0.1
				else:
					jaw.rotation.z = lerp(jaw.rotation.z, sin(_phase * 3.0) * 0.14, delta * 6.0)
					upper.rotation.z = lerp(upper.rotation.z, -sin(_phase * 3.0) * 0.12, delta * 6.0)
		"potatomine":
			if rig.extra.size() > 0:
				var led: MeshInstance3D = rig.extra[0]
				var on: bool = armed and fmod(_phase, 1.0) < 0.5
				led.material_override = Art.toon(Color("#ff5a3c") if on else Color("#8a2a20"), {"glow": 1.6 if on else 0.0, "outline": false})
		"cherrybomb":
			var k: float = clamp(age / 1.1, 0.0, 1.0)
			if rig.head:
				rig.head.scale = Vector3.ONE * (1.0 + k * 0.28 + sin(age * 26.0) * 0.03 * k)
		"jalapeno":
			if _burn > 0.0:
				if rig.head:
					rig.head.scale = Vector3.ONE * (1.0 + sin(_phase * 40.0) * 0.06)
		"sunshroom":
			if rig.head:
				var grow: float = 1.0 if age < 36.0 else 1.28
				rig.head.scale = rig.head.scale.lerp(Vector3.ONE * grow, delta * 2.4)
		"doomshroom":
			var dk: float = clamp(age / 1.9, 0.0, 1.0)
			if rig.head:
				rig.head.scale = Vector3.ONE * (1.0 + dk * 0.3 + sin(age * 30.0) * 0.04 * dk)
		"iceshroom":
			var ik: float = clamp(age / 1.3, 0.0, 1.0)
			if rig.head:
				rig.head.scale = Vector3.ONE * (1.0 + ik * 0.18)
		"kernelpult", "melonpult":
			if rig.extra.size() > 0:
				var pa: Node3D = rig.extra[0]
				pa.rotation.z = sin(_phase * 1.6) * 0.04


func tick(delta: float, m) -> void:
	if dead:
		return
	_match = m
	age += delta
	if chewing > 0.0:
		chewing -= delta

	match kind:
		"sunflower":
			timer -= delta
			if timer <= 0.0:
				timer = 9.2
				m.spawn_sun(global_position + Vector3(randf_range(-0.2, 0.2), 0.5, randf_range(-0.2, 0.2)), true)
		"sunshroom":
			timer -= delta
			if timer <= 0.0:
				var grown: bool = age > 36.0
				timer = 11.0 if grown else 8.0
				m.spawn_sun(global_position + Vector3(randf_range(-0.16, 0.16), 0.46, randf_range(-0.16, 0.16)),
					true, 25 if grown else 15)
		"kernelpult", "melonpult":
			var tz = m.frontmost_zombie(row, global_position.x, 12.0)
			if tz == null:
				timer = min(timer, 0.3)
				return
			timer -= delta
			if timer <= 0.0:
				timer = float(def.get("cadence", 3.0))
				var butter := kind == "kernelpult" and randf() < float(def.get("butter", 0.0))
				m.lob_at(global_position + Vector3(0.16 * facing, 0.6, 0), row, tz.global_position.x,
					float(def["lob"]), kind, butter)
				_swing_arm()
				App.sfx_at("shoot", global_position, -9.0, 0.78 if kind == "melonpult" else 1.15)
		"fumeshroom":
			var fr: float = float(def.get("range", 3.8))
			if m.lane_has_zombie(row, global_position.x, fr):
				timer -= delta
				if timer <= 0.0:
					timer = float(def.get("cadence", 1.6))
					m.fume_cone(global_position, row, fr, float(def.get("fume", 20)))
					App.sfx_at("shoot", global_position, -12.0, 0.62)
			else:
				timer = min(timer, 0.2)
		"hypnoshroom":
			pass
		"iceshroom":
			if age > 1.3:
				m.freeze_all(float(def.get("freeze_all", 5.0)))
				die()
		"doomshroom":
			if age > 1.9:
				m.doom(global_position, Vector2i(col, row))
				die()
		"magnetshroom":
			timer -= delta
			if timer <= 0.0:
				if m.strip_metal_near(global_position, float(def.get("magnet", 4.6))) > 0:
					timer = 8.0
				else:
					timer = 1.2
		"peashooter", "snowpea", "repeater", "threepeater", "puffshroom":
			var rows: Array = [row]
			if kind == "threepeater":
				rows = [row - 1, row, row + 1]
			var reach: float = float(def.get("range", 99.0))
			var has_target := false
			for rr in rows:
				if rr < 0 or rr >= m.rows:
					continue
				if m.lane_has_zombie(rr, global_position.x, reach):
					has_target = true
					break
			if not has_target:
				timer = min(timer, 0.25)
				return
			timer -= delta
			if timer <= 0.0:
				timer = float(def.get("cadence", 1.4))
				var shots := int(def.get("shots", 1))
				for s in range(shots):
					for rr in rows:
						if rr < 0 or rr >= m.rows:
							continue
						m.fire_pea(global_position + Vector3(0.42 * facing, 0.86, 0), rr,
							float(def.get("shot", 25)), kind == "snowpea", s * 0.09, reach)
				_recoil()
				App.sfx_at("shoot", global_position, -10.0, randf_range(0.94, 1.08))
		"potatomine":
			if not armed and age > 8.0:
				armed = true
				App.sfx_at("select", global_position, -6.0, 1.4)
			if armed:
				var z = m.zombie_near(global_position, 0.95)
				if z != null:
					m.explode(global_position, 1.45, 2000.0)
					die()
		"cherrybomb":
			if age > 1.1:
				m.explode(global_position, 2.5, 2000.0)
				die()
		"jalapeno":
			_burn += delta
			if age > 1.0:
				m.burn_row(row)
				die()
		"chomper":
			if chewing > 0.0:
				return
			var z2 = m.zombie_near(global_position, 1.25)
			if z2 != null:
				m.devour(z2)
				chewing = 16.0
				App.sfx_at("chomp", global_position, -3.0, 1.0)
		"squash":
			if _squash_state == 0:
				var z3 = m.zombie_near(global_position, 1.7)
				if z3 != null:
					_squash_state = 1
					_squash_t = 0.0
					_squash_target = z3.global_position
			elif _squash_state == 1:
				_squash_t += delta
				var k: float = clamp(_squash_t / 0.38, 0.0, 1.0)
				if rig.head:
					var flat: float = 1.0 + k * 0.25
					rig.root.position.y = sin(k * PI) * 1.1
					rig.root.position.x = (_squash_target.x - global_position.x) * 0.55
					rig.root.scale = Vector3(flat, 1.0 - k * 0.2, flat)
				if k >= 1.0:
					m.explode(_squash_target, 1.5, 2000.0)
					die()


func _swing_arm() -> void:
	if rig == null or rig.extra.size() == 0:
		return
	var arm: Node3D = rig.extra[0]
	var tw := create_tween()
	tw.tween_property(arm, "rotation:z", -0.55, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(arm, "rotation:z", 0.0, 0.34).set_trans(Tween.TRANS_SINE)


func _recoil() -> void:
	if rig.head == null:
		return
	var tw := create_tween()
	tw.tween_property(rig.head, "position:x", -0.07, 0.05)
	tw.tween_property(rig.head, "position:x", 0.0, 0.14)


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.1
	_apply_flash()
	_update_damage_look()
	if hp <= 0.0:
		die()


func _update_damage_look() -> void:
	if kind in ["wallnut", "tallnut"] and rig.extra.size() > 0:
		var stage := 0
		if hp < max_hp * 0.66:
			stage = 1
		if hp < max_hp * 0.33:
			stage = 2
		if stage != _damage_stage:
			_damage_stage = stage
			var cracks: Node3D = rig.extra[0]
			cracks.visible = stage > 0


func _apply_flash() -> void:
	var m := Art.unshaded(Color(1.0, 0.35, 0.25, 0.5))
	for p in rig.parts:
		if is_instance_valid(p):
			p.material_overlay = m


func _clear_flash() -> void:
	for p in rig.parts:
		if is_instance_valid(p):
			p.material_overlay = null


## `reason` matters for hypno-shroom: it only flips a zombie when something
## actually ate it. Digging it up (reason "dug") must not charm anything.
func die(reason := "killed") -> void:
	if dead:
		return
	dead = true
	if kind == "hypnoshroom" and _match != null and reason != "dug":
		_match.charm_near(global_position, 1.6)
	_clear_flash()
	var tw := create_tween()
	tw.tween_property(rig.root, "scale", Vector3(PLANT_SCALE * 1.15, 0.1, PLANT_SCALE * 1.15), 0.16).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(rig.root, "position:y", -0.12, 0.16)
	tw.tween_callback(queue_free)
