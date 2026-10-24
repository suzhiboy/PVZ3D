class_name LawnMower
extends Node3D

## Last line of defence. Sits at the house end of a lane until a zombie slips
## past, then charges across the lawn clearing the row.

var lane := 0
var active := false
var spent := false
var dir := -1.0
var _t := 0.0
var _wheels: Array[Node3D] = []
var _body: Node3D


func setup(lane_i: int, pos: Vector3, direction: float) -> void:
	lane = lane_i
	dir = direction
	position = pos
	_body = Art.mower_model()
	add_child(_body)
	rotation.y = 0.0 if dir < 0.0 else PI
	scale = Vector3.ONE * 1.15


func _process(delta: float) -> void:
	_t += delta
	if active:
		_body.position.y = abs(sin(_t * 30.0)) * 0.025
		rotation.z = sin(_t * 22.0) * 0.012
	else:
		_body.position.y = sin(_t * 1.6) * 0.005


func launch() -> void:
	if active or spent:
		return
	active = true
	App.sfx("mower", -2.0, randf_range(0.95, 1.06))


func advance(delta: float) -> void:
	if not active or spent:
		return
	position.x += dir * 12.5 * delta
