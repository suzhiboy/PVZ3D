class_name PeaShot
extends Node3D

## A single pea. Pure kinematic movement so the simulation stays deterministic.

var lane := 0
var damage := 25.0
var freeze := false
var dir := -1.0
var dead := false
var max_dist := 99.0
var _life := 0.0


func setup(pos: Vector3, lane_i: int, dmg: float, is_freeze: bool, direction: float, dist := 99.0) -> void:
	max_dist = dist
	position = pos
	lane = lane_i
	damage = dmg
	freeze = is_freeze
	dir = direction
	add_child(Art.pea_model(freeze))


func advance(delta: float) -> bool:
	if dead:
		return false
	_life += delta
	position.x += dir * 9.5 * delta
	position.y = 0.86 + sin(_life * 20.0) * 0.015
	if _life > 1.9 or _life * 9.5 > max_dist:
		dead = true
		queue_free()
		return false
	return true


func hit() -> void:
	if dead:
		return
	dead = true
	queue_free()
