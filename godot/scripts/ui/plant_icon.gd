class_name PlantIcon
extends SubViewportContainer

## Renders a plant or zombie model into a tiny viewport so seed packets and
## menus can show the real 3D art instead of flat icons.

var kind := "sunflower"
var zombie := false
var spin := 0.45
var viewport: SubViewport
var model: Node3D
var _cam: Camera3D
var _t := 0.0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	_cam = Camera3D.new()
	_cam.fov = 34.0
	_cam.near = 0.1
	_cam.far = 20.0
	viewport.add_child(_cam)

	var key := DirectionalLight3D.new()
	key.light_energy = 1.5
	key.light_color = Color("#fff3d8")
	key.rotation_degrees = Vector3(-32, 42, 0)
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.7
	rim.light_color = Color("#a9c8e8")
	rim.rotation_degrees = Vector3(-16, -120, 0)
	viewport.add_child(rim)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#cfd8e6")
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)

	_build_model()


## Swap the model without rebuilding the whole viewport — the seed chooser
## reuses a fixed set of icons instead of spawning one per card.
func set_kind(k: String) -> void:
	if k == kind and model != null:
		return
	kind = k
	if is_inside_tree() and viewport != null:
		_build_model()


func _build_model() -> void:
	if model != null and is_instance_valid(model):
		model.queue_free()
		model = null
	if kind == "":
		return
	var node: Node3D
	if zombie:
		node = Art.zombie_model(kind).root
	else:
		node = Art.plant_model(kind).root
	model = Node3D.new()
	model.add_child(node)
	viewport.add_child(model)

	# frame the model roughly by its top
	var top := 0.6
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh is PrimitiveMesh:
			var h: float = (m.mesh as PrimitiveMesh).get_aabb().size.y
			top = max(top, m.position.y + h * 0.5)
	top = clamp(top, 0.4, 1.6)
	var dist := 1.45 + top * 1.35
	_cam.position = Vector3(0, top * 0.62 + 0.08, dist)
	_cam.look_at(Vector3(0, top * 0.5, 0))

	node.rotation.y = -PI * 0.5 + 0.42
	model.rotation.y = 0.0
	if kind == "lilypad":
		model.scale = Vector3(1.0, 1.0, 1.0)


## Pausing the tiny render when the panel is hidden keeps a screen full of
## icons from rendering 20 viewports behind a menu.
func set_live(on: bool) -> void:
	if viewport == null:
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	set_process(on)


func _process(delta: float) -> void:
	_t += delta
	if model and is_instance_valid(model):
		model.rotation.y = sin(_t * spin) * 0.45
