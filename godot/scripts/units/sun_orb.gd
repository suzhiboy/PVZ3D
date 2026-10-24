class_name SunOrb
extends Node3D

## A collectable sun. Falls from the sky or pops out of a sunflower, then drifts
## toward the gardener when he gets close.

var value := 25
var vy := 1.4
var landed := false
var life := 13.0
var collected := false
var _t := 0.0
var _halo: MeshInstance3D
var _core: MeshInstance3D


func setup(pos: Vector3, from_plant := false, p_value := 25) -> void:
	value = p_value
	position = pos
	vy = 0.9 if from_plant else 1.7
	var model := Art.sun_model()
	add_child(model)
	_halo = model.get_meta("halo")
	_core = model.get_node_or_null("Core")
	_t = randf() * TAU
	scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if collected:
		return
	_t += delta
	rotation.y += delta * 0.8
	if _halo:
		_halo.rotation.y = -rotation.y
	var pulse := 1.0 + sin(_t * 3.0) * 0.06
	if _core:
		_core.scale = Vector3.ONE * pulse * 0.85
	if _halo:
		_halo.scale = Vector3(0.5, 0.5, 0.5) * (1.0 + sin(_t * 3.0) * 0.12)
	if not landed:
		position.y -= vy * delta
		if position.y <= 0.34:
			position.y = 0.34
			landed = true


## Returns true when this orb should be consumed.
func advance(delta: float, player_pos: Vector3, magnet: bool) -> bool:
	if collected:
		return false
	if landed:
		life -= delta
		if life <= 0.0:
			return true
	var to_player := player_pos - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if magnet and dist < 2.4 and global_position.y < 2.2:
		var pull := (2.4 - dist) * 3.4
		global_position += to_player.normalized() * pull * delta
		global_position.y = move_toward(global_position.y, player_pos.y - 0.35, delta * 2.6)
		if dist < 0.55:
			return true
	if landed:
		position.y = 0.34 + sin(_t * 2.2) * 0.04
	return false


func pop() -> void:
	collected = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.8, 0.12)
	tw.parallel().tween_property(self, "position:y", position.y + 0.5, 0.16)
	tw.tween_callback(queue_free)
