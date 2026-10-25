class_name PlayerController
extends CharacterBody3D

## First-person gardener: walk, sprint (stamina), jump, wade, and swing a trowel.

signal footstep(surface: String)
signal water_feedback(pos: Vector3, strength: float, moving: bool)
signal sprint_changed(ratio: float)

const WALK := 2.85
const SPRINT := 4.85
const ACCEL := 15.0
const AIR_ACCEL := 4.5
const GRAVITY := 17.0
const JUMP := 5.0
const EYE := 1.58
const STAMINA_MAX := 100.0

var active := false
var yaw := 0.0
var pitch := 0.0
var stamina := STAMINA_MAX
var in_water := false
var sprinting := false
var climbing := false

var camera: Camera3D
var water_rect := Rect2()
var base_fov := 80.0
var mouse_sens := 0.0022
var invert_y := false

var _bob := 0.0
var _bob_amp := 0.0
var _step_dist := 0.0
var _land_dip := 0.0
var _regen_delay := 0.0
var _shake := 0.0
var _shake_t := 0.0
var _view: Node3D
var _view_home := Vector3(0.33, -0.33, -0.50)
var _tween: Tween
var _climb_tween: Tween
var _water_step := 0.0
var _last_wet_pos := Vector3.ZERO


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(52)
	floor_snap_length = 0.35
	slide_on_ceiling = true

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.72
	shape.shape = cap
	shape.position = Vector3(0, 0.86, 0)
	add_child(shape)

	camera = Camera3D.new()
	camera.position = Vector3(0, EYE, 0)
	camera.fov = base_fov
	camera.near = 0.04
	camera.far = 260.0
	add_child(camera)
	camera.current = true
	_build_view_model()


func _build_view_model() -> void:
	_view = Node3D.new()
	_view.position = _view_home
	_view.rotation_degrees = Vector3(-8, 16, -6)
	_view.scale = Vector3.ONE * 0.5
	camera.add_child(_view)

	var glove := Art.toon(Color("#5f8a52"), {"bands": 3.0, "rim": 0.22})
	var cuff := Art.toon(Color("#e8dcc0"), {"bands": 2.0})
	var steel := Art.toon(Color("#b9c4c9"), {"bands": 3.0, "rim": 0.5})
	var handle := Art.toon(Color("#8a5a3a"), {"bands": 2.0})

	# forearm coming in from the bottom-right
	var arm := Art.box(_view, Vector3(0.10, 0.30, 0.10), Vector3(0.03, -0.16, 0.1), glove)
	arm.rotation = Vector3(0.35, 0, 0.12)
	Art.box(_view, Vector3(0.12, 0.08, 0.12), Vector3(0.02, -0.30, 0.16), cuff)
	# fist
	Art.ball(_view, 0.062, Vector3(0.0, 0.02, 0.0), glove, Vector3(1.0, 0.9, 1.0), 8, 6)
	# trowel
	var trowel := Node3D.new()
	trowel.position = Vector3(0.0, 0.06, -0.06)
	trowel.rotation_degrees = Vector3(24, 0, 0)
	_view.add_child(trowel)
	Art.cyl(trowel, 0.028, 0.18, Vector3(0, 0.06, 0.05), handle, Vector3(1.4, 0, 0), 8)
	var blade := Art.box(trowel, Vector3(0.1, 0.02, 0.2), Vector3(0, 0.05, -0.14), steel)
	blade.rotation = Vector3(0.28, 0, 0)
	Art.cone(trowel, 0.05, 0.08, Vector3(0, 0.02, -0.24), steel, Vector3(-PI * 0.62, 0, 0), 6)


func set_water_bounds(r: Rect2) -> void:
	water_rect = r


func spawn(pos: Vector3, new_yaw: float) -> void:
	climbing = false
	if _climb_tween and _climb_tween.is_running():
		_climb_tween.kill()
	if _view:
		_view.visible = true
	global_position = pos
	yaw = new_yaw
	pitch = 0.0
	velocity = Vector3.ZERO
	in_water = false
	_water_step = 0.0
	_last_wet_pos = pos
	rotation = Vector3(0, yaw, 0)
	camera.rotation = Vector3.ZERO
	active = true


func look_at_yaw(y: float) -> void:
	yaw = y
	rotation.y = y


func _unhandled_input(event: InputEvent) -> void:
	if not active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		yaw -= m.relative.x * mouse_sens
		pitch -= m.relative.y * mouse_sens * (-1.0 if invert_y else 1.0)
		pitch = clamp(pitch, -1.45, 1.45)
		rotation.y = yaw
		camera.rotation.x = pitch


## Scripted climb (the chimney). The path is walked at constant speed, so a
## shaft of five metres takes the same time whether it is one straight leg or
## five short ones.
func climb_to(path: Array, duration: float) -> void:
	if climbing or not active:
		return
	climbing = true
	velocity = Vector3.ZERO
	if _view:
		_view.visible = false
	if _climb_tween and _climb_tween.is_running():
		_climb_tween.kill()
	var pts: Array[Vector3] = [global_position]
	for p in path:
		pts.append(p)
	_climb_tween = create_tween()
	_climb_tween.tween_method(func(t: float) -> void: global_position = _path_at(pts, t),
		0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_climb_tween.tween_callback(_end_climb)


func _path_at(pts: Array[Vector3], t: float) -> Vector3:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var d: float = clampf(t, 0.0, 1.0) * total
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if d <= seg or i == pts.size() - 1:
			return pts[i - 1].lerp(pts[i], clampf(d / maxf(seg, 0.001), 0.0, 1.0))
		d -= seg
	return pts[pts.size() - 1]


func _end_climb() -> void:
	climbing = false
	velocity = Vector3.ZERO
	if _view:
		_view.visible = true


func _physics_process(delta: float) -> void:
	if not active:
		return
	if climbing:
		_shake = max(0.0, _shake - delta * 2.6)
		camera.rotation.z = lerp(camera.rotation.z, sin(_shake_t * 0.6) * 0.012, delta * 4.0)
		_shake_t += delta * 20.0
		return

	var was_in_water := in_water
	var impact_speed := maxf(0.0, -velocity.y)
	in_water = water_rect.has_point(Vector2(global_position.x, global_position.z)) and global_position.y < 0.5
	if in_water:
		_last_wet_pos = global_position
		if not was_in_water:
			var impact := clampf(0.7 + impact_speed * 0.12, 0.7, 1.6)
			water_feedback.emit(global_position, impact, false)
			_land_dip = -0.055 * impact
			_water_step = 0.18
	elif was_in_water:
		water_feedback.emit(_last_wet_pos, 0.55, false)
		_water_step = 0.0

	# movement is gated by `active` + the paused tree, not by mouse capture
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
	if dir.length() > 1.0:
		dir = dir.normalized()

	var want_sprint := Input.is_action_pressed("sprint") and input.length() > 0.2 and stamina > 1.0
	sprinting = want_sprint
	if want_sprint:
		stamina = max(0.0, stamina - 21.0 * delta)
		_regen_delay = 0.9
		if stamina <= 0.0:
			sprinting = false
	else:
		_regen_delay = max(0.0, _regen_delay - delta)
		if _regen_delay <= 0.0:
			stamina = min(STAMINA_MAX, stamina + 15.0 * delta)
	sprint_changed.emit(stamina / STAMINA_MAX)

	var target_speed := (SPRINT if sprinting else WALK)
	if in_water:
		target_speed *= 0.62
	var target := dir * target_speed
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	if in_water:
		# Water drag makes the gardener feel slower to start and stop; the
		# movement stays responsive instead of turning into a boat.
		accel *= 0.58
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP * (0.78 if in_water else 1.0)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta * (0.7 if in_water else 1.0)
	elif velocity.y < 0.0:
		velocity.y = -0.5

	move_and_slide()
	if in_water:
		var wading := Vector2(velocity.x, velocity.z).length()
		if wading > 0.35 and is_on_floor():
			_water_step -= delta * (1.4 if sprinting else 1.0)
			if _water_step <= 0.0:
				_water_step = 0.34 if sprinting else 0.46
				water_feedback.emit(global_position, 0.42 if sprinting else 0.3, true)

	# --- camera feel -------------------------------------------------------
	var horizontal := Vector2(velocity.x, velocity.z).length()
	_bob_amp = lerp(_bob_amp, 1.0 if is_on_floor() and horizontal > 0.4 else 0.0, delta * 8.0)
	_bob += horizontal * delta * (1.5 if in_water else 2.35)
	_land_dip = lerp(_land_dip, 0.0, delta * 9.0)
	if is_on_floor() and velocity.y < -6.0:
		_land_dip = -0.07
	_shake = max(0.0, _shake - delta * 2.6)
	_shake_t += delta * 34.0

	var bob_y := sin(_bob * 2.0) * 0.032 * _bob_amp
	var bob_x := cos(_bob) * 0.026 * _bob_amp
	camera.position = Vector3(bob_x, EYE + bob_y + _land_dip, 0)
	if _shake > 0.0:
		camera.position += Vector3(sin(_shake_t) * 0.02, cos(_shake_t * 1.7) * 0.02, 0) * _shake
	camera.rotation.z = lerp(camera.rotation.z, -input.x * 0.018, delta * 6.0)
	camera.fov = lerp(camera.fov, base_fov + (4.0 if sprinting else 0.0), delta * 5.0)

	# view model sway
	if _view:
		var sway := Vector3(-input.x * 0.05, -abs(bob_y) * 0.7 - 0.01, 0)
		_view.position = _view.position.lerp(_view_home + sway, delta * 9.0)
		_view.rotation.z = lerp(_view.rotation.z, -input.x * 0.09 - 0.1, delta * 8.0)

	# --- footsteps ---------------------------------------------------------
	if is_on_floor() and horizontal > 0.4:
		_step_dist += horizontal * delta
		var stride := 1.15 if sprinting else 0.95
		if in_water:
			stride = 0.8
		if _step_dist >= stride:
			_step_dist = 0.0
			footstep.emit(surface_now())
	else:
		_step_dist = min(_step_dist, 0.6)


func surface_now() -> String:
	if in_water:
		return "water"
	if global_position.y > 0.35:
		return "wood"
	return "grass"


func add_shake(amount: float) -> void:
	if App.settings["shake"]:
		_shake = max(_shake, amount)


func play_trowel(swing := false) -> void:
	if _view == null:
		return
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	if swing:
		_tween.tween_property(_view, "rotation:x", _view.rotation.x - 1.1, 0.09).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_view, "rotation:x", 0.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	else:
		_tween.tween_property(_view, "position:y", _view_home.y - 0.16, 0.08).set_ease(Tween.EASE_IN)
		_tween.tween_property(_view, "position:y", _view_home.y, 0.24).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func eye_position() -> Vector3:
	return global_position + Vector3(0, EYE, 0)


func look_dir() -> Vector3:
	return -camera.global_transform.basis.z
