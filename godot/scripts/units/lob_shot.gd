class_name LobShot
extends Node3D

## A lobbed projectile — a corn kernel or a whole melon. It flies on a parabola
## and only resolves damage when it lands, so it clears whatever stands between
## the pult and its target.

signal landed(pos: Vector3, lane: int, dmg: float, kind: String, butter: bool)

var lane := 0
var damage := 20.0
var kind := "kernelpult"
var butter := false
var done := false

var _start := Vector3.ZERO
var _end := Vector3.ZERO
var _t := 0.0
var _dur := 0.9
var _arc := 1.1
var _model: Node3D


func setup(pos: Vector3, lane_i: int, target: Vector3, dmg: float, p_kind: String, is_butter: bool) -> void:
	position = pos
	_start = pos
	_end = target
	lane = lane_i
	damage = dmg
	kind = p_kind
	butter = is_butter
	var dist := _start.distance_to(_end)
	_dur = clampf(dist / 8.0, 0.34, 1.1)
	_arc = 0.55 + dist * 0.1
	_model = Art.lob_model(kind, butter)
	add_child(_model)
	scale = Vector3.ONE * 0.55


func advance(delta: float) -> bool:
	if done:
		return false
	_t += delta
	var k: float = clampf(_t / _dur, 0.0, 1.0)
	global_position = _start.lerp(_end, k) + Vector3(0, sin(k * PI) * _arc, 0)
	if _model and is_instance_valid(_model):
		_model.rotation.x += delta * 8.0
		_model.rotation.z += delta * 5.0
	scale = scale.lerp(Vector3.ONE, delta * 7.0)
	if k >= 1.0:
		done = true
		landed.emit(global_position, lane, damage, kind, butter)
		queue_free()
		return false
	return true
