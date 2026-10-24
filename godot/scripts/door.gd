class_name HouseDoor
extends Node3D

## A hinged door. The panel swings on a pivot; the collider is switched off
## while open so the doorway is genuinely walkable.

var label := "门"
var open := false
var open_angle := -1.6
var width := 1.0
var pivot: Node3D
var body: StaticBody3D

var _tween: Tween


func toggle() -> void:
	set_open(not open, true)


func set_open(value: bool, animate := true) -> void:
	open = value
	# opening clears the collider at once; closing restores it when the swing ends
	if body:
		body.collision_layer = 0
	var target := open_angle if open else 0.0
	if _tween and _tween.is_running():
		_tween.kill()
	if animate and is_inside_tree() and pivot:
		_tween = create_tween()
		_tween.tween_property(pivot, "rotation:y", target, 0.48) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if not open:
			_tween.tween_callback(_enable_collision)
		App.sfx_at("door_open" if open else "door_close", global_position, -5.0, randf_range(0.96, 1.05))
	elif pivot:
		pivot.rotation.y = target
		if not open:
			_enable_collision()


func _enable_collision() -> void:
	if is_instance_valid(body):
		body.collision_layer = 1
