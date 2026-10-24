class_name ZombieUnit
extends AnimatableBody3D

## A zombie. Match drives tick(); this node owns the walk/eat/die animation.

const GRAVITY := 12.0

signal died

var kind := "basic"
var def: Dictionary
var lane := 0
var hp := 200.0
var max_hp := 200.0
var armor := 0.0
var max_armor := 0.0
var speed := 0.44
var dps := 60.0
var dir := -1.0
var frozen := 0.0
var stun := 0.0
var dying := 0.0
var dead := false
var phase := 0.0
var eating := false
var eat_target: PlantUnit
var body_x := 0.0
var charmed := false
var charm_life := 0.0
## 撑杆跳：剩余可跳次数，跳过去以后就不再吃眼前这株
var vault_left := 0
## 气球：离地高度（0 表示正常走路）
var flying := 0.0
## 巨人：不啃，直接一棒砸掉
var smashing := false

var rig: Art.ZombieRig
var _flash := 0.0
var _chomp_t := 0.0
var _gear_lost := false
var _death_t := 0.0
var _vault_t := -1.0
var _vault_from := 0.0
var _vault_to := 0.0
var _smash_cd := 0.0
var _scale := 1.0


func setup(p_kind: String, p_lane: int, pos: Vector3, p_dir: float) -> void:
	kind = p_kind
	def = Data.zombie(kind)
	lane = p_lane
	max_hp = float(def["hp"])
	hp = max_hp
	max_armor = float(def.get("armor", 0.0))
	armor = max_armor
	speed = float(def["speed"]) * randf_range(0.94, 1.07)
	dps = float(def["dps"])
	dir = p_dir
	body_x = pos.x
	sync_to_physics = false
	position = pos
	rotation.y = 0.0 if dir > 0.0 else PI
	phase = randf() * TAU

	collision_layer = 4
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.55
	cs.shape = cap
	cs.position = Vector3(0, 0.78, 0)
	add_child(cs)

	rig = Art.zombie_model(kind)
	add_child(rig.root)

	vault_left = int(def.get("vault", 0))
	flying = float(def.get("fly", 0.0))
	smashing = bool(def.get("smash", false))
	_scale = float(def.get("scale", 1.0))
	if _scale != 1.0:
		rig.root.scale = rig.root.scale * _scale
		cap.radius *= _scale
		cap.height *= _scale
		cs.position = Vector3(0, 0.78 * _scale, 0)
	if flying > 0.0:
		rig.root.position.y = flying
		# a balloon zombie never eats: it sails over the whole lawn
		dps = 0.0


func _process(delta: float) -> void:
	if rig == null:
		return
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_clear_flash()

	if dead:
		return

	var speed_now := 0.0
	if dying <= 0.0 and stun <= 0.0:
		speed_now = speed * (0.42 if frozen > 0.0 else 1.0)
	var swing := sin(phase) * (0.5 if speed_now > 0.0 else 0.16)
	if rig.hip_l:
		rig.hip_l.rotation.x = swing
		rig.hip_r.rotation.x = -swing
	if rig.arm_l:
		rig.arm_l.rotation.x = sin(phase + 0.4) * 0.12
	if rig.arm_r:
		rig.arm_r.rotation.x = -sin(phase + 0.4) * 0.12
	if flying > 0.0 and dying <= 0.0:
		rig.root.position.y = flying + sin(phase * 2.4) * 0.09
	if rig.head and dying <= 0.0:
		rig.head.rotation.z = sin(phase * 0.5) * 0.08
		rig.head.rotation.x = -0.12 if eating else 0.0

	if charmed and dying <= 0.0:
		_apply_charm()
	elif freezing() and dying <= 0.0:
		_apply_freeze()
	elif _flash <= 0.0:
		_clear_flash()


func freezing() -> bool:
	return frozen > 0.0


func tick(delta: float, m) -> void:
	if dead:
		return

	if dying > 0.0:
		dying -= delta
		_death_t += delta
		if rig.root:
			rig.root.rotation.z = -1.55 * clamp(_death_t / 0.55, 0.0, 1.0)
			rig.root.position.y = -0.35 * clamp((_death_t - 0.4) / 0.5, 0.0, 1.0)
		if dying <= 0.0:
			_finish()
		return

	if stun > 0.0:
		stun -= delta
		phase += delta * 1.0
		return

	if frozen > 0.0:
		frozen -= delta

	var slow := 0.42 if frozen > 0.0 else 1.0

	if charmed:
		charm_life -= delta
		if charm_life <= 0.0:
			start_dying(true)
			return
		var foe = m.zombie_foe_near(self, 0.95)
		if foe != null:
			phase += delta * 11.0
			foe.damage(180.0 * delta)
			_chomp_t -= delta
			if _chomp_t <= 0.0:
				_chomp_t = 0.5
				App.sfx_at("chomp", global_position + Vector3(0, 1.2, 0), -11.0, 0.9)
			return
		var back := speed * 0.9 * delta
		body_x -= dir * back
		global_position.x = body_x
		phase += back * 7.5
		if (dir < 0.0 and body_x > m.escape_x) or (dir > 0.0 and body_x < m.escape_x):
			start_dying(true)
		return

	# --- 撑杆跳：落到第一株植物后面，之后照常啃
	if _vault_t >= 0.0:
		_vault_t += delta
		var vk: float = clampf(_vault_t / 0.62, 0.0, 1.0)
		body_x = lerpf(_vault_from, _vault_to, vk)
		global_position.x = body_x
		rig.root.position.y = sin(vk * PI) * 1.15 * _scale
		phase += delta * 6.0
		if vk >= 1.0:
			_vault_t = -1.0
			rig.root.position.y = 0.0
		return

	var target = m.plant_in_front(self)
	_smash_cd = maxf(0.0, _smash_cd - delta)

	if target != null and vault_left > 0 and not flying > 0.0:
		# plant the pole and hop clean over it
		var gap: float = ((target.global_position.x - body_x) * dir) + 0.95
		vault_left -= 1
		_vault_t = 0.0
		_vault_from = body_x
		_vault_to = body_x + dir * maxf(gap, 1.1)
		eating = false
		App.sfx_at("shove", global_position + Vector3(0, 1.0, 0), -6.0, 1.35)
		return

	if target != null and smashing and _smash_cd <= 0.0:
		# one swing flattens whatever is in front, then he keeps walking
		_smash_cd = 1.15
		eating = true
		eat_target = target
		phase += 1.2
		var tw := create_tween()
		tw.tween_property(rig.root, "rotation:z", -0.55, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(rig.root, "rotation:z", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
		App.sfx_at("explode", global_position + Vector3(0, 0.6, 0), -8.0, 1.5)
		target.take_damage(99999.0)
		m.smash_fx(target.global_position)
		return

	if flying > 0.0:
		eating = false
		eat_target = null
		var air_step := speed * slow * delta
		body_x += dir * air_step
		global_position.x = body_x
		phase += air_step * 7.5
		if (dir < 0.0 and body_x < m.goal_x) or (dir > 0.0 and body_x > m.goal_x):
			m.breach(self)
		return

	if target != null:
		eating = true
		eat_target = target
		phase += delta * 11.0
		target.take_damage(dps * delta)
		_chomp_t -= delta
		if _chomp_t <= 0.0:
			_chomp_t = 0.55
			App.sfx_at("chomp", global_position + Vector3(0, 1.2, 0), -8.0, randf_range(0.85, 1.15))
		return

	eating = false
	eat_target = null
	var step := speed * slow * delta
	body_x += dir * step
	global_position.x = body_x
	phase += step * 7.5

	if (dir < 0.0 and body_x < m.goal_x) or (dir > 0.0 and body_x > m.goal_x):
		m.breach(self)


## Hypno-shroom flipped this one: it now walks back up the lane, biting its
## former friends, and collapses once the spell runs out.
func charm(duration := 14.0) -> void:
	if dead or dying > 0.0 or charmed:
		return
	charmed = true
	charm_life = duration
	eating = false
	eat_target = null
	rotation.y = 0.0 if -dir > 0.0 else PI
	App.sfx_at("groan2", global_position + Vector3(0, 1.3, 0), -4.0, 1.35)
	_flash = 0.2
	_apply_charm()


## Butter from a kernel-pult: a long stun with a pale crust, no damage over time.
func butter(duration := 4.0) -> void:
	if dead or dying > 0.0:
		return
	stun = max(stun, duration)
	frozen = 0.0
	_flash = 0.22
	_apply_flash()


## Ice-shroom's flash freeze.
func chill(duration := 5.0) -> void:
	if dead or dying > 0.0:
		return
	stun = max(stun, duration)
	frozen = max(frozen, duration + 0.8)
	_apply_freeze()


## Magnet-shroom pulls the bucket or helmet off. Returns false when there is
## nothing metal left to take.
func strip_metal() -> bool:
	if dead or dying > 0.0 or armor <= 0.0:
		return false
	if not (kind in ["bucket", "football", "screendoor"]):
		return false
	armor = 0.0
	_gear_lost = true
	if rig.gear and is_instance_valid(rig.gear):
		var tw := create_tween()
		tw.tween_property(rig.gear, "position", rig.gear.position + Vector3(0.9, 1.5, 0.2), 0.5)
		tw.parallel().tween_property(rig.gear, "rotation", Vector3(4.0, 2.0, 1.0), 0.5)
		tw.parallel().tween_property(rig.gear, "scale", Vector3(0.06, 0.06, 0.06), 0.5)
		tw.tween_callback(_hide_gear)
	return true


func _apply_charm() -> void:
	var m := Art.unshaded(Color(0.72, 0.42, 0.95, 0.42))
	for p in rig.parts:
		if is_instance_valid(p):
			p.material_overlay = m


func damage(amount: float, crit := false, ignore_armor := false) -> void:
	if dead or dying > 0.0:
		return
	if armor > 0.0 and not ignore_armor:
		var absorbed: float = min(armor, amount)
		armor -= absorbed
		amount -= absorbed
		if armor <= 0.0:
			_break_armor()
	if amount > 0.0:
		hp -= amount
	_update_gear()
	_flash = 0.09
	if dying <= 0.0:
		_apply_flash()
	if hp <= 0.0:
		start_dying(crit)


func _break_armor() -> void:
	if kind == "newspaper":
		speed = float(def.get("rage_speed", 1.15))
		App.sfx_at("groan2", global_position + Vector3(0, 1.4, 0), -4.0, 1.25)


func _update_gear() -> void:
	if _gear_lost:
		return
	var drop := hp < max_hp * 0.5
	if max_armor > 0.0 and armor <= 0.0:
		drop = true
	if drop and kind in ["cone", "bucket", "football", "screendoor"]:
		_gear_lost = true
		if rig.gear:
			var tw := create_tween()
			tw.tween_property(rig.gear, "position:y", 0.9, 0.3)
			tw.parallel().tween_property(rig.gear, "rotation:x", 2.4, 0.3)
			tw.parallel().tween_property(rig.gear, "scale", Vector3(0.1, 0.1, 0.1), 0.3)
			tw.tween_callback(_hide_gear)


func _hide_gear() -> void:
	if is_instance_valid(rig) and is_instance_valid(rig.gear):
		rig.gear.visible = false


func _apply_flash() -> void:
	var m := Art.unshaded(Color(1.0, 0.9, 0.8, 0.45))
	for p in rig.parts:
		if is_instance_valid(p):
			p.material_overlay = m


func _apply_freeze() -> void:
	var m := Art.unshaded(Color(0.55, 0.85, 1.0, 0.4))
	for p in rig.parts:
		if is_instance_valid(p):
			p.material_overlay = m


func _clear_flash() -> void:
	if rig == null:
		return
	for p in rig.parts:
		if is_instance_valid(p):
			p.material_overlay = null


func start_dying(instant := false) -> void:
	if dying > 0.0 or dead:
		return
	dying = 0.6 if not instant else 0.001
	_death_t = 0.0
	eating = false
	collision_layer = 0
	died.emit()
	App.sfx_at("groan3", global_position + Vector3(0, 1.2, 0), -6.0, randf_range(0.8, 1.0))


func _finish() -> void:
	if dead:
		return
	dead = true
	queue_free()


func shove(push: float) -> void:
	if dead or dying > 0.0:
		return
	body_x -= dir * push
	global_position.x = body_x
	stun = 0.85
	frozen = max(frozen, 1.2)
	_flash = 0.12
	_apply_flash()
