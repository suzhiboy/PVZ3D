class_name CoinOrb
extends Node3D

## 击杀僵尸掉落的金币：弹出后落地打转，靠近自动吸进钱袋。
## 目前只累计数量（HUD 钱袋 + 跨局存档），用途待定——商店/解锁已在计划里。

var value := 1
var collected := false
var landed := false
var life := 24.0
var _vel := Vector3.ZERO
var _bounces := 0
var _pulled := false
var _t := 0.0
var _spark: MeshInstance3D


func setup(pos: Vector3, worth := 1) -> void:
	value = worth
	global_position = pos
	var model := Art.coin_model()
	add_child(model)
	_spark = model.get_meta("spark")
	_t = randf() * TAU
	_vel = Vector3(randf_range(-1.3, 1.3), randf_range(2.4, 3.4), randf_range(-1.3, 1.3))
	scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if collected:
		return
	_t += delta
	rotation.y += delta * (2.4 if landed else 7.0)
	if _spark:
		# 反向转，让十字光斑固定朝向镜头，读起来是“在发光”而不是“在翻滚”
		_spark.rotation.y = -rotation.y
	if _pulled:
		return
	if not landed:
		_vel.y -= 9.4 * delta
		global_position += _vel * delta
		if global_position.y <= 0.18:
			global_position.y = 0.18
			if _bounces < 2 and absf(_vel.y) > 0.8:
				_vel.y = -_vel.y * 0.42
				_vel.x *= 0.55
				_vel.z *= 0.55
				_bounces += 1
			else:
				landed = true
				_vel = Vector3.ZERO
	else:
		position.y = 0.18 + sin(_t * 2.6) * 0.02
		# 快消失时闪烁提醒
		if life < 3.0:
			visible = fmod(life, 0.22) > 0.08


## 返回 true 表示应该移除（被吸走或超时消失）。
func advance(delta: float, player_pos: Vector3) -> bool:
	if collected:
		return false
	if landed:
		life -= delta
		if life <= 0.0:
			return true
	var to := player_pos - global_position
	to.y = 0.0
	var d := to.length()
	if d < 2.1 and global_position.y < 2.4:
		_pulled = true
		var pull := (2.1 - d) * 4.2
		global_position += to.normalized() * pull * delta
		global_position.y = move_toward(global_position.y, player_pos.y + 0.55, delta * 3.0)
		if d < 0.6:
			return true
	return false


func pop() -> void:
	collected = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.6, 0.1)
	tw.parallel().tween_property(self, "position:y", position.y + 0.4, 0.14)
	tw.tween_callback(queue_free)
