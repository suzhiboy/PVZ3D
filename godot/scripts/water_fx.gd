class_name WaterFX
extends Node3D

## Lightweight, stylised water feedback. Every splash is made from three cues:
## a vertical spray, a low crown and expanding foam rings. No realistic shader
## or external texture is needed, so the effect stays inside the game's toon art.

var surface_y := -0.16
var _drop_mesh: SphereMesh
var _drop_colors: Gradient
var _ring_mesh: TorusMesh


func splash(at: Vector3, strength := 1.0, moving := false) -> void:
	var s := clampf(strength, 0.2, 1.8)
	var pos := Vector3(at.x, surface_y + 0.025, at.z)
	_spray(pos, s, moving)
	_ring(pos, s, 0.0)
	if not moving:
		_ring(pos, s * 1.15, 0.13)
		_crown(pos, s)


func _spray(pos: Vector3, strength: float, moving: bool) -> void:
	var p := CPUParticles3D.new()
	p.name = "WaterSpray"
	p.position = pos
	p.amount = int(7.0 + strength * (5.0 if moving else 13.0))
	p.lifetime = 0.38 + strength * 0.16
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 42.0 if moving else 58.0
	p.gravity = Vector3(0, -8.5, 0)
	p.initial_velocity_min = 0.65 + strength * 0.45
	p.initial_velocity_max = 1.15 + strength * 0.9
	p.scale_amount_min = 0.32
	p.scale_amount_max = 0.85
	if _drop_mesh == null:
		_drop_mesh = SphereMesh.new()
		_drop_mesh.radius = 0.062
		_drop_mesh.height = 0.15
		_drop_mesh.radial_segments = 7
		_drop_mesh.rings = 4
		_drop_mesh.material = Art.unshaded(Color(0.68, 0.91, 0.96, 0.92))
		_drop_colors = Gradient.new()
		_drop_colors.set_color(0, Color(0.88, 0.98, 1.0, 0.95))
		_drop_colors.set_color(1, Color(0.36, 0.72, 0.86, 0.0))
	p.mesh = _drop_mesh
	p.color_ramp = _drop_colors
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.15).timeout.connect(p.queue_free)


func _ring(pos: Vector3, strength: float, delay: float) -> void:
	var mat := Art.unshaded(Color(0.77, 0.95, 0.98, 0.68))
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.43
		_ring_mesh.outer_radius = 0.465
		_ring_mesh.rings = 20
		_ring_mesh.ring_segments = 6
	var ring := Art.put(self, _ring_mesh, mat, pos + Vector3(0, delay * 0.025, 0), Vector3.ZERO,
		Vector3.ONE, "WaterRipple")
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(0.3, 0.1, 0.3)
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(ring, "scale", Vector3(1.65 * strength, 0.05, 1.65 * strength), 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "transparency", 1.0, 0.85).set_ease(Tween.EASE_IN)
	tw.tween_callback(ring.queue_free)


func _crown(pos: Vector3, strength: float) -> void:
	var crown := Node3D.new()
	crown.name = "SplashCrown"
	crown.position = pos
	add_child(crown)
	var mat := Art.unshaded(Color(0.7, 0.93, 0.98, 0.78))
	for i in range(10):
		var a := TAU * float(i) / 10.0
		var petal := Art.ball(crown, 0.055,
			Vector3(cos(a) * 0.22, 0.06, sin(a) * 0.22), mat,
			Vector3(0.7, 1.8 + strength * 0.5, 0.7), 7, 4)
		petal.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
		petal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tw := create_tween()
	tw.tween_property(crown, "scale", Vector3(1.8 * strength, 0.15, 1.8 * strength), 0.42).set_ease(Tween.EASE_OUT)
	for drop in crown.get_children():
		if drop is GeometryInstance3D:
			tw.parallel().tween_property(drop, "transparency", 1.0, 0.42)
	tw.tween_callback(crown.queue_free)
