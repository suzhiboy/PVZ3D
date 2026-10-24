class_name Art
extends RefCounted

## Every visual in the game is built here at runtime: toon materials, outline
## shells, and low-poly plant / zombie / prop models. No external art assets.

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const TOON_ALPHA := preload("res://shaders/toon_alpha.gdshader")

static var _mat_cache: Dictionary = {}
static var _outline: StandardMaterial3D
static var _outline_thick: StandardMaterial3D

# --- palette ---------------------------------------------------------------
const INK := Color("#2a2420")
const STEM := Color("#4c8f38")
const STEM_DARK := Color("#3d7530")
const LEAF := Color("#69b94b")
const LEAF_DARK := Color("#4f9c3a")
const PEA := Color("#86cc4f")
const NUT := Color("#b3803f")
const NUT_LIGHT := Color("#c9964f")
const PETAL := Color("#f6c744")
const PETAL_DARK := Color("#e0a72c")
const NUT_CENTER := Color("#8a5622")
const WHITE := Color("#f6f1e2")
const EYE := Color("#241f1c")
const ICE := Color("#9ed9ea")
const ICE_DEEP := Color("#6fb8d4")
const CHERRY := Color("#c93a31")
const CHILI := Color("#d23b2b")
const SQUASH := Color("#8fae45")
const CHOMPER := Color("#8b57b3")
const CHOMPER_DARK := Color("#6f3f96")
const DIRT := Color("#6d5236")
const SKIN := Color("#a3b884")
const SKIN_DARK := Color("#8ba06c")
const SHIRT := Color("#5b4b6b")
const PANTS := Color("#4b4137")
const METAL := Color("#9aa3a8")
const WOOD := Color("#8d6440")


# --- materials -------------------------------------------------------------

static func toon(color: Color, opts := {}) -> ShaderMaterial:
	var transparent: bool = float(opts.get("alpha", 1.0)) < 1.0
	var key := "%s|%s|%s|%s|%s|%s" % [
		color.to_html(true),
		str(opts.get("bands", 3.0)),
		str(opts.get("rim", 0.22)),
		str(opts.get("glow", 0.0)),
		str(opts.get("alpha", 1.0)),
		str(opts.get("outline", true)),
	]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON_ALPHA if transparent else TOON_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("bands", float(opts.get("bands", 3.0)))
	m.set_shader_parameter("rim_amount", float(opts.get("rim", 0.22)))
	m.set_shader_parameter("rim_color", opts.get("rim_color", Color(1.0, 0.98, 0.9)))
	m.set_shader_parameter("glow", float(opts.get("glow", 0.0)))
	if transparent:
		m.set_shader_parameter("alpha", float(opts.get("alpha", 1.0)))
		m.render_priority = 1
	if opts.get("outline", true):
		m.next_pass = outline_mat()
	_mat_cache[key] = m
	return m


static func outline_mat() -> StandardMaterial3D:
	if _outline == null:
		_outline = StandardMaterial3D.new()
		_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline.albedo_color = Color(0.10, 0.08, 0.07)
		_outline.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline.grow = true
		_outline.grow_amount = 0.016
		_outline.disable_ambient_light = true
	return _outline


static func outline_thick() -> StandardMaterial3D:
	if _outline_thick == null:
		_outline_thick = StandardMaterial3D.new()
		_outline_thick.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_thick.albedo_color = Color(0.08, 0.06, 0.06)
		_outline_thick.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline_thick.grow = true
		_outline_thick.grow_amount = 0.045
		_outline_thick.disable_ambient_light = true
	return _outline_thick


static func unshaded(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var key := "u|%s|%s" % [color.to_html(true), str(alpha)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 1.0:
		m.render_priority = 2
	_mat_cache[key] = m
	return m


static func additive(color: Color) -> StandardMaterial3D:
	var key := "a|%s" % color.to_html(true)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.no_depth_test = false
	m.render_priority = 3
	_mat_cache[key] = m
	return m


static func tex_mat(tex: Texture2D, color := Color.WHITE, opts := {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = color
	m.roughness = 0.95
	m.uv1_scale = opts.get("uv", Vector3.ONE)
	m.uv1_triplanar = opts.get("triplanar", false)
	if opts.get("triplanar", false):
		m.uv1_triplanar_sharpness = 4.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


# --- mesh helpers ----------------------------------------------------------

static func put(parent: Node3D, m: Mesh, mat: Material, pos := Vector3.ZERO,
		rot := Vector3.ZERO, scl := Vector3.ONE, nm := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	if nm != "":
		mi.name = nm
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		rot := Vector3.ZERO, nm := "") -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return put(parent, m, mat, pos, rot, Vector3.ONE, nm)


static func cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material,
		rot := Vector3.ZERO, segments := 12, nm := "") -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return put(parent, m, mat, pos, rot, Vector3.ONE, nm)


static func cone(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material,
		rot := Vector3.ZERO, segments := 10, nm := "") -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.02
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return put(parent, m, mat, pos, rot, Vector3.ONE, nm)


static func ball(parent: Node3D, radius: float, pos: Vector3, mat: Material,
		scl := Vector3.ONE, segments := 12, rings := 8, nm := "") -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = rings
	return put(parent, m, mat, pos, Vector3.ZERO, scl, nm)


static func quad(parent: Node3D, size: Vector2, mat: Material, pos := Vector3.ZERO,
		rot := Vector3.ZERO, nm := "") -> MeshInstance3D:
	var m := QuadMesh.new()
	m.size = size
	return put(parent, m, mat, pos, rot, Vector3.ONE, nm)


static func pivot(parent: Node3D, pos: Vector3, nm := "") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	if nm != "":
		n.name = nm
	parent.add_child(n)
	return n


# --- plant models ----------------------------------------------------------

class PlantRig extends RefCounted:
	var root: Node3D
	var sway: Node3D
	var head: Node3D
	var extra: Array[Node3D] = []
	var parts: Array[MeshInstance3D] = []


static func _mound(parent: Node3D) -> void:
	var dirt := toon(DIRT, {"bands": 2.0, "rim": 0.1})
	cyl(parent, 0.26, 0.07, Vector3(0, 0.02, 0), dirt, Vector3.ZERO, 12)


static func _leaf(parent: Node3D, y: float, ang: float, size := 1.0) -> void:
	var mat := toon(LEAF, {"bands": 2.0})
	var l := ball(parent, 0.13 * size, Vector3(0.02, y, 0), mat, Vector3(1.6, 0.22, 0.7), 8, 5)
	l.rotation = Vector3(0, ang, 0.32)
	l.position += Vector3(0, 0, 0)



static func torus(parent: Node3D, inner: float, outer: float, pos: Vector3, mat: Material,
		rot := Vector3.ZERO, nm := "") -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 18
	m.ring_segments = 8
	return put(parent, m, mat, pos, rot, Vector3.ONE, nm)


static func hemisphere(parent: Node3D, radius: float, pos: Vector3, mat: Material,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.is_hemisphere = true
	m.radial_segments = 16
	m.rings = 8
	return put(parent, m, mat, pos, rot, Vector3.ONE)


## Shared mushroom build: stem, cap, gills and a ring of pale spots.
static func _shroom(sway: Node3D, cap: Color, cap_r: float, cap_flat: float, stem_h: float,
		glow := 0.0) -> Node3D:
	var head := pivot(sway, Vector3(0, 0.04, 0), "Head")
	var stem_mat := toon(Color("#e9dec6"), {"bands": 2.0, "rim": 0.2})
	var cap_mat := toon(cap, {"bands": 3.0, "rim": 0.32, "glow": glow})
	cyl(head, cap_r * 0.44, stem_h, Vector3(0, stem_h * 0.5, 0), stem_mat, Vector3.ZERO, 10)
	ball(head, cap_r, Vector3(0, stem_h + cap_r * 0.14, 0), cap_mat, Vector3(1.0, cap_flat, 1.0), 14, 9)
	cyl(head, cap_r * 0.92, 0.03, Vector3(0, stem_h - 0.02, 0),
		toon(cap.darkened(0.4), {"outline": false}), Vector3.ZERO, 14)
	for i in range(5):
		var a := TAU * float(i) / 5.0 + 0.4
		ball(head, cap_r * 0.15,
			Vector3(cos(a) * cap_r * 0.6, stem_h + cap_r * (0.14 + cap_flat * 0.62), sin(a) * cap_r * 0.55),
			toon(Color("#f4ead6"), {"outline": false}), Vector3(1.0, 0.42, 1.0), 8, 5)
	return head


static func _shroom_eyes(head: Node3D, x: float, y: float, gap: float, r: float, iris := EYE) -> void:
	for s in [-1, 1]:
		ball(head, r, Vector3(x, y, gap * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
		ball(head, r * 0.52, Vector3(x + signf(x) * r * 0.66, y, gap * s), toon(iris, {"outline": false}), Vector3.ONE, 6, 4)


static func _mushroom_spots(head: Node3D, y: float, r: float, count: int, col: Color) -> void:
	for i in range(count):
		ball(head, r, Vector3(0.06, y + 0.02 * i, -0.1 + i * (0.2 / max(1, count - 1))),
			toon(col, {"outline": false}), Vector3(0.8, 0.5, 0.8), 6, 4)


static func plant_model(kind: String) -> PlantRig:
	var rig := PlantRig.new()
	var root := Node3D.new()
	rig.root = root
	var sway := Node3D.new()
	root.add_child(sway)
	rig.sway = sway

	match kind:
		"sunflower":
			_mound(root)
			_stalk(sway, 0.62)
			_leaf(sway, 0.26, 0.4)
			_leaf(sway, 0.4, -0.5)
			var head := pivot(sway, Vector3(0, 0.78, 0), "Head")
			rig.head = head
			var petal := toon(PETAL, {"bands": 3.0, "rim": 0.3})
			var petal2 := toon(PETAL_DARK, {"bands": 3.0, "rim": 0.2})
			var disc := toon(NUT_CENTER, {"bands": 2.0})
			var c := cyl(head, 0.185, 0.09, Vector3(0, 0, 0), disc, Vector3(0, 0, PI * 0.5), 16)
			c.name = "Face"
			for i in range(12):
				var a := TAU * float(i) / 12.0
				var pm := petal if i % 2 == 0 else petal2
				var p := box(head, Vector3(0.028, 0.24, 0.1), Vector3(0.0, cos(a) * 0.24, sin(a) * 0.24), pm)
				p.rotation = Vector3(a, 0, 0)
			# the sunflower looks back at the gardener — much friendlier from behind
			for s in [-1, 1]:
				ball(head, 0.035, Vector3(-0.075, 0.045, 0.062 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
				ball(head, 0.019, Vector3(-0.098, 0.045, 0.062 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)
			box(head, Vector3(0.02, 0.022, 0.075), Vector3(-0.095, -0.045, 0), toon(NUT_CENTER.darkened(0.35), {"outline": false}))

		"peashooter", "snowpea", "repeater":
			_mound(root)
			var icy := kind == "snowpea"
			_stalk(sway, 0.5, ICE_DEEP if icy else STEM)
			_leaf(sway, 0.22, 0.4)
			_leaf(sway, 0.33, -0.6)
			var head := pivot(sway, Vector3(0, 0.7, 0), "Head")
			rig.head = head
			var body_mat := toon(ICE if icy else PEA, {"bands": 3.0, "rim": 0.3, "glow": 0.06 if icy else 0.0})
			ball(head, 0.185, Vector3.ZERO, body_mat)
			var snout_len := 0.26
			var snout_y := 0.0
			var snouts := 1
			if kind == "repeater":
				snouts = 2
			for s in range(snouts):
				snout_y = 0.0 if s == 0 else -0.085
				cyl(head, 0.085, snout_len, Vector3(0.2, snout_y, 0), body_mat, Vector3(0, 0, PI * 0.5), 10)
				cyl(head, 0.092, 0.04, Vector3(0.32, snout_y, 0), toon(ICE_DEEP if icy else LEAF_DARK, {"outline": false}), Vector3(0, 0, PI * 0.5), 10)
			for s in [-1, 1]:
				ball(head, 0.036, Vector3(0.12, 0.06, 0.075 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
				ball(head, 0.02, Vector3(0.145, 0.06, 0.075 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)
			if icy:
				for i in range(4):
					var a := TAU * float(i) / 4.0 + 0.4
					cone(head, 0.04, 0.14, Vector3(-0.06, cos(a) * 0.16, sin(a) * 0.16), toon(ICE, {"glow": 0.25, "rim": 0.4}), Vector3(-a, 0, -0.7), 5)
			box(head, Vector3(0.16, 0.03, 0.06), Vector3(-0.02, 0.17, 0), toon(LEAF_DARK, {"outline": false}))

		"threepeater":
			_mound(root)
			_stalk(sway, 0.42)
			_leaf(sway, 0.2, 0.4, 1.2)
			for i in range(3):
				var h := pivot(sway, Vector3(0, 0.6 + (0.13 if i == 1 else 0.0), (i - 1) * 0.26), "Head%d" % i)
				rig.extra.append(h)
				var mat := toon(PEA, {"bands": 3.0, "rim": 0.25})
				ball(h, 0.15, Vector3.ZERO, mat)
				cyl(h, 0.07, 0.2, Vector3(0.16, 0, 0), mat, Vector3(0, 0, PI * 0.5), 9)
				for s in [-1, 1]:
					ball(h, 0.028, Vector3(0.1, 0.045, 0.058 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 6, 4)
					ball(h, 0.015, Vector3(0.118, 0.045, 0.058 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)

		"wallnut", "tallnut":
			var tall := kind == "tallnut"
			var sy := 0.72 if tall else 0.55
			var body := pivot(sway, Vector3(0, 0.0, 0), "Head")
			rig.head = body
			var mat := toon(NUT, {"bands": 3.0, "rim": 0.25})
			ball(body, 0.38 if tall else 0.36, Vector3(0, sy * 0.62, 0), mat, Vector3(1.0, sy / 0.55, 0.95), 14, 10)
			var light := toon(NUT_LIGHT, {"outline": false})
			ball(body, 0.3, Vector3(0.03, sy * 0.68, 0), light, Vector3(0.9, sy / 0.62, 0.82), 12, 8)
			for s in [-1, 1]:
				ball(body, 0.05, Vector3(0.3, sy * 0.68 + 0.06, 0.085 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
				ball(body, 0.026, Vector3(0.335, sy * 0.68 + 0.06, 0.085 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)
			var mouth := box(body, Vector3(0.03, 0.035, 0.13), Vector3(0.33, sy * 0.68 - 0.09, 0), toon(NUT_CENTER.darkened(0.4), {"outline": false}), Vector3.ZERO, "Mouth")
			mouth.visible = true
			var cracks := Node3D.new()
			cracks.name = "Cracks"
			body.add_child(cracks)
			rig.extra.append(cracks)
			for i in range(4):
				var cm := toon(Color("#6b4520"), {"outline": false})
				var c1 := box(cracks, Vector3(0.02, 0.11, 0.02), Vector3(0.22 + i * 0.02, 0.42 + i * 0.09, -0.16 + i * 0.1), cm)
				c1.rotation = Vector3(0.3 * i, 0.4, 0.5)
			cracks.visible = false

		"cherrybomb":
			var h := pivot(sway, Vector3(0, 0, 0), "Head")
			rig.head = h
			var mat := toon(CHERRY, {"bands": 3.0, "rim": 0.35, "glow": 0.05})
			for s in [-1, 1]:
				ball(h, 0.23, Vector3(0, 0.3, 0.17 * s), mat, Vector3(1.0, 0.95, 0.95))
				var eye_y := 0.38
				ball(h, 0.045, Vector3(0.19, eye_y, 0.12 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
				ball(h, 0.022, Vector3(0.225, eye_y, 0.12 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)
				box(h, Vector3(0.02, 0.03, 0.1), Vector3(0.21, eye_y + 0.09, 0.12 * s), toon(EYE, {"outline": false}), Vector3(0.4, 0, 0))
				cyl(h, 0.018, 0.2, Vector3(0, 0.56, 0.13 * s), toon(STEM_DARK, {"outline": false}), Vector3(0, 0, 0.3 * s), 6)
			cyl(h, 0.03, 0.09, Vector3(0, 0.62, 0), toon(STEM, {"outline": false}), Vector3.ZERO, 6)

		"potatomine":
			_mound(root)
			var h := pivot(sway, Vector3(0, 0, 0), "Head")
			rig.head = h
			var mat := toon(Color("#b98a52"), {"bands": 2.0, "rim": 0.2})
			ball(h, 0.24, Vector3(0.02, 0.12, 0), mat, Vector3(1.15, 0.85, 1.0), 12, 8)
			for s in [-1, 1]:
				ball(h, 0.035, Vector3(0.19, 0.2, 0.075 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
				ball(h, 0.019, Vector3(0.218, 0.2, 0.075 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)
			var led := ball(h, 0.045, Vector3(0.06, 0.34, 0), toon(Color("#8a2a20"), {"glow": 0.0}), Vector3.ONE, 8, 6, "Led")
			rig.extra.append(led)

		"chomper":
			_mound(root)
			_stalk(sway, 0.38, CHOMPER_DARK)
			_leaf(sway, 0.18, 0.5, 1.2)
			var h := pivot(sway, Vector3(0, 0.52, 0), "Head")
			rig.head = h
			var mat := toon(CHOMPER, {"bands": 3.0, "rim": 0.3})
			var dark := toon(CHOMPER_DARK, {"bands": 2.0})
			ball(h, 0.25, Vector3(0, 0.1, 0), mat, Vector3(1.0, 1.05, 0.95), 12, 9)
			var lower := pivot(h, Vector3(0.1, 0.06, 0), "Jaw")
			box(lower, Vector3(0.26, 0.09, 0.3), Vector3(0.14, -0.04, 0), dark, Vector3(0, 0, 0.12))
			var upper := pivot(h, Vector3(0.08, 0.2, 0), "UpperJaw")
			box(upper, Vector3(0.3, 0.1, 0.32), Vector3(0.14, 0.06, 0), mat, Vector3(0, 0, -0.16))
			for i in range(5):
				var z := -0.12 + i * 0.06
				cone(lower, 0.022, 0.06, Vector3(0.24, 0.01, z), toon(WHITE, {"outline": false}), Vector3(0, 0, -PI * 0.5), 5)
				cone(upper, 0.022, 0.06, Vector3(0.26, -0.01, z), toon(WHITE, {"outline": false}), Vector3(0, 0, PI * 0.5), 5)
			for s in [-1, 1]:
				ball(h, 0.04, Vector3(0.12, 0.3, 0.09 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
				ball(h, 0.021, Vector3(0.148, 0.3, 0.09 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)
			rig.extra.append(lower)
			rig.extra.append(upper)

		"lilypad":
			var pad := toon(Color("#5aa84a"), {"bands": 2.0, "rim": 0.2})
			var p := cyl(root, 0.66, 0.05, Vector3(0, 0.01, 0), pad, Vector3.ZERO, 20)
			p.scale = Vector3(1.0, 1.0, 0.88)
			var notch := box(root, Vector3(0.3, 0.06, 0.3), Vector3(0.3, 0.02, 0), toon(Color("#3f7f3a"), {"outline": false}))
			notch.visible = false
			var flower := ball(root, 0.09, Vector3(-0.16, 0.1, 0.14), toon(Color("#f3e6f5"), {"bands": 2.0}), Vector3(1.0, 0.6, 1.0), 8, 6)
			flower.name = "Flower"

		"jalapeno":
			_mound(root)
			var h := pivot(sway, Vector3(0, 0.05, 0), "Head")
			rig.head = h
			var mat := toon(CHILI, {"bands": 3.0, "rim": 0.35, "glow": 0.08})
			ball(h, 0.16, Vector3(0.02, 0.3, 0), mat, Vector3(1.0, 1.9, 1.0), 12, 9)
			cone(h, 0.12, 0.2, Vector3(0.02, 0.05, 0), mat, Vector3(0, 0, 0), 10)
			cyl(h, 0.03, 0.12, Vector3(0, 0.62, 0), toon(STEM, {"outline": false}), Vector3(0, 0, 0.2), 6)
			for s in [-1, 1]:
				ball(h, 0.035, Vector3(0.15, 0.42, 0.06 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
				ball(h, 0.019, Vector3(0.178, 0.42, 0.06 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)
			box(h, Vector3(0.02, 0.025, 0.08), Vector3(0.17, 0.47, 0), toon(EYE, {"outline": false}), Vector3(0, 0, -0.3))

		"squash":
			_mound(root)
			var h := pivot(sway, Vector3(0, 0.14, 0), "Head")
			rig.head = h
			var mat := toon(SQUASH, {"bands": 3.0, "rim": 0.25})
			ball(h, 0.32, Vector3(0, 0.26, 0), mat, Vector3(1.0, 0.95, 0.95), 14, 10)
			ball(h, 0.1, Vector3(0, 0.56, 0), toon(STEM_DARK, {"outline": false}), Vector3(1.6, 0.5, 1.6), 8, 6)
			for s in [-1, 1]:
				ball(h, 0.045, Vector3(0.26, 0.34, 0.1 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
				ball(h, 0.022, Vector3(0.295, 0.34, 0.1 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)
			box(h, Vector3(0.02, 0.04, 0.22), Vector3(0.29, 0.17, 0), toon(EYE, {"outline": false}), Vector3(0, 0, 0.1))

		"pumpkin":
			# a ring of lobes reads as a real gourd, and leaves the middle hollow
			var body := toon(Color("#e8912f"), {"bands": 3.0, "rim": 0.3})
			var body2 := toon(Color("#d97d22"), {"bands": 3.0, "rim": 0.28})
			for i in range(8):
				var a := TAU * float(i) / 8.0
				ball(root, 0.2, Vector3(cos(a) * 0.34, 0.3, sin(a) * 0.34),
					body if i % 2 == 0 else body2, Vector3(0.95, 1.55, 0.95), 10, 7)
			cyl(root, 0.4, 0.03, Vector3(0, 0.07, 0), toon(Color("#3f2611"), {"outline": false}), Vector3.ZERO, 16)
			torus(root, 0.34, 0.53, Vector3(0, 0.585, 0), toon(Color("#c66f18"), {"bands": 2.0}))
			cyl(root, 0.055, 0.2, Vector3(-0.34, 0.62, -0.3), toon(Color("#6d7a3a")), Vector3(0.42, 0, 0.42), 6)
			# the carved face looks back at the gardener — in both yards that is
			# the model's -X side, which is where the player actually stands
			for s in [-1, 1]:
				ball(root, 0.09, Vector3(-0.53, 0.42, 0.16 * s),
					toon(Color("#2a1a0c"), {"outline": false}), Vector3(0.5, 1.0, 0.85), 8, 6)
			box(root, Vector3(0.04, 0.11, 0.26), Vector3(-0.55, 0.25, 0), toon(Color("#2a1a0c"), {"outline": false}))
			for i in range(3):
				box(root, Vector3(0.04, 0.06, 0.055), Vector3(-0.56, 0.31, -0.075 + i * 0.075),
					toon(Color("#2a1a0c"), {"outline": false}))

		"kernelpult":
			_mound(root)
			_leaf(sway, 0.12, 0.4, 1.3)
			var hk := pivot(sway, Vector3(0, 0.32, 0), "Head")
			rig.head = hk
			var corn := toon(Color("#f0c34a"), {"bands": 3.0, "rim": 0.3})
			var husk := toon(Color("#7fae45"), {"bands": 2.0})
			ball(hk, 0.23, Vector3(0, 0.24, 0), corn, Vector3(0.82, 1.35, 0.82), 12, 9)
			for s in [-1, 1]:
				for i in range(2):
					var lf := ball(hk, 0.1, Vector3(-0.08 - i * 0.02, 0.14 + i * 0.13, 0.14 * s), husk,
						Vector3(1.0, 2.2, 0.42), 8, 6)
					lf.rotation = Vector3(0.26 * s, 0, 0.1 + i * 0.12)
			for i in range(9):
				var aa := float(i) * 2.1
				ball(hk, 0.027, Vector3(cos(aa) * 0.155, 0.1 + i * 0.052, sin(aa) * 0.155),
					toon(Color("#f8dd7a"), {"outline": false}), Vector3.ONE, 6, 4)
			for s in [-1, 1]:
				ball(hk, 0.04, Vector3(-0.2, 0.32, 0.075 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
				ball(hk, 0.021, Vector3(-0.232, 0.32, 0.075 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)
			var arm := pivot(hk, Vector3(0.0, 0.58, 0), "Arm")
			box(arm, Vector3(0.5, 0.055, 0.055), Vector3(0.18, 0.04, 0), toon(WOOD, {"bands": 2.0}), Vector3(0, 0, 0.26))
			box(arm, Vector3(0.15, 0.06, 0.14), Vector3(0.4, 0.16, 0), toon(Color("#f7e6a8"), {"bands": 2.0}))
			rig.extra.append(arm)

		"melonpult":
			_mound(root)
			_stalk(sway, 0.26, STEM_DARK)
			var hm := pivot(sway, Vector3(0, 0.28, 0), "Head")
			rig.head = hm
			var rind := toon(Color("#4f8f36"), {"bands": 3.0, "rim": 0.28})
			ball(hm, 0.28, Vector3(0, 0.24, 0), rind, Vector3(1.0, 0.94, 1.0), 14, 10)
			for i in range(5):
				var am := TAU * float(i) / 5.0
				ball(hm, 0.028, Vector3(cos(am) * 0.255, 0.25, sin(am) * 0.255),
					toon(Color("#2f5c22"), {"outline": false}), Vector3(0.45, 2.8, 0.45), 6, 4)
			for s in [-1, 1]:
				ball(hm, 0.045, Vector3(-0.24, 0.33, 0.09 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
				ball(hm, 0.023, Vector3(-0.275, 0.33, 0.09 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)
			var marm := pivot(hm, Vector3(0.0, 0.5, 0), "Arm")
			box(marm, Vector3(0.46, 0.06, 0.06), Vector3(0.16, 0.04, 0), toon(WOOD, {"bands": 2.0}), Vector3(0, 0, 0.28))
			cyl(marm, 0.15, 0.1, Vector3(0.38, 0.14, 0), toon(Color("#a8763f"), {"bands": 2.0}), Vector3.ZERO, 10)
			ball(marm, 0.13, Vector3(0.38, 0.24, 0), rind, Vector3(1.0, 0.88, 1.0), 12, 8)
			rig.extra.append(marm)

		"puffshroom":
			_mound(root)
			var hp := _shroom(sway, Color("#a389c8"), 0.2, 0.78, 0.16)
			rig.head = hp
			_shroom_eyes(hp, -0.13, 0.12, 0.05, 0.03)
			box(hp, Vector3(0.02, 0.02, 0.07), Vector3(-0.155, 0.07, 0), toon(EYE, {"outline": false}))

		"sunshroom":
			_mound(root)
			var hs := _shroom(sway, Color("#f2c033"), 0.25, 0.72, 0.22, 0.1)
			rig.head = hs
			_shroom_eyes(hs, -0.17, 0.17, 0.06, 0.036)
			for i in range(8):
				var a := TAU * float(i) / 8.0
				var ray := box(hs, Vector3(0.02, 0.13, 0.05),
					Vector3(cos(a) * 0.3, 0.3 + sin(a) * 0.26, sin(a) * 0.06), toon(Color("#f8dd7a"), {"outline": false}))
				ray.rotation.z = -a
			box(hs, Vector3(0.02, 0.025, 0.09), Vector3(-0.19, 0.12, 0), toon(EYE, {"outline": false}))

		"fumeshroom":
			_mound(root)
			var hf := _shroom(sway, Color("#8d7fa8"), 0.3, 0.6, 0.28)
			rig.head = hf
			# wide muzzle on the front
			cyl(hf, 0.17, 0.16, Vector3(-0.2, 0.24, 0), toon(Color("#b6a8c8"), {"bands": 2.0}), Vector3(0, 0, PI * 0.5), 12)
			torus(hf, 0.1, 0.17, Vector3(-0.28, 0.24, 0), toon(Color("#6f6484"), {"bands": 2.0}), Vector3(0, 0, PI * 0.5))
			cyl(hf, 0.12, 0.03, Vector3(-0.26, 0.24, 0), toon(Color("#3b3348"), {"outline": false}), Vector3(0, 0, PI * 0.5), 12)
			_shroom_eyes(hf, -0.06, 0.46, 0.16, 0.048)

		"hypnoshroom":
			_mound(root)
			var hh := _shroom(sway, Color("#d977b8"), 0.27, 0.66, 0.22, 0.08)
			rig.head = hh
			for i in range(7):
				var t := float(i) / 6.0
				var ang := t * TAU * 1.05
				var rad := 0.05 + t * 0.19
				ball(hh, 0.032, Vector3(cos(ang) * rad, 0.37 + t * 0.13, sin(ang) * rad),
					toon(Color("#f6d6ea"), {"outline": false}), Vector3(1.0, 0.4, 1.0), 6, 4)
			_shroom_eyes(hh, -0.19, 0.16, 0.06, 0.038, Color("#7a3a86"))
			box(hh, Vector3(0.02, 0.022, 0.08), Vector3(-0.2, 0.11, 0), toon(Color("#7a3a86"), {"outline": false}))

		"iceshroom":
			_mound(root)
			var hi := _shroom(sway, Color("#9fd8ea"), 0.26, 0.68, 0.2, 0.22)
			rig.head = hi
			for i in range(6):
				var a := TAU * float(i) / 6.0 + 0.3
				cone(hi, 0.045, 0.16, Vector3(cos(a) * 0.22, 0.14, sin(a) * 0.22),
					toon(ICE, {"glow": 0.3, "rim": 0.5}), Vector3(PI, 0, 0), 5)
			_shroom_eyes(hi, -0.17, 0.19, 0.055, 0.034, Color("#2b5f7a"))
			box(hi, Vector3(0.02, 0.025, 0.075), Vector3(-0.19, 0.13, 0), toon(Color("#2b5f7a"), {"outline": false}))

		"doomshroom":
			_mound(root)
			var hd := _shroom(sway, Color("#4a2e5c"), 0.33, 0.66, 0.24, 0.06)
			rig.head = hd
			for i in range(6):
				var a := TAU * float(i) / 6.0
				box(hd, Vector3(0.03, 0.09, 0.03), Vector3(cos(a) * 0.3, 0.3, sin(a) * 0.3),
					toon(Color("#6b4a80"), {"outline": false}), Vector3(0.4, -a, 0))
			for s in [-1, 1]:
				ball(hd, 0.05, Vector3(-0.22, 0.3, 0.08 * s),
					toon(Color("#ff5a3c"), {"glow": 1.8, "bands": 1.0, "outline": false}), Vector3(1.2, 0.7, 1.0), 8, 5)
			box(hd, Vector3(0.02, 0.035, 0.16), Vector3(-0.25, 0.16, 0), toon(Color("#2a1a2e"), {"outline": false}))

		"magnetshroom":
			_mound(root)
			var hm2 := _shroom(sway, Color("#9aa3a8"), 0.28, 0.62, 0.24, 0.05)
			rig.head = hm2
			torus(hm2, 0.1, 0.17, Vector3(0.0, 0.42, 0), toon(Color("#c0392b"), {"bands": 2.0}), Vector3(0, 0, PI * 0.5))
			for s in [-1, 1]:
				box(hm2, Vector3(0.06, 0.16, 0.06), Vector3(0.09, 0.5, 0.12 * s), toon(Color("#3d6fb0"), {"bands": 2.0}))
				box(hm2, Vector3(0.06, 0.05, 0.06), Vector3(0.09, 0.6, 0.12 * s), toon(Color("#d8dde0"), {"bands": 1.0}))
			_shroom_eyes(hm2, -0.2, 0.16, 0.06, 0.036, Color("#33404a"))

		_:
			_mound(root)
			_stalk(sway, 0.4)
			ball(sway, 0.2, Vector3(0, 0.55, 0), toon(PEA))

	# collect every mesh instance for tinting / transparency
	_collect(root, rig.parts)
	return rig


static func _stalk(parent: Node3D, h: float, col := STEM) -> void:
	var mat := toon(col, {"bands": 2.0, "rim": 0.15})
	cyl(parent, 0.045, h, Vector3(0, h * 0.5, 0), mat, Vector3.ZERO, 8)


static func _collect(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			out.append(c)
		_collect(c, out)


# --- zombie models ---------------------------------------------------------

class ZombieRig extends RefCounted:
	var root: Node3D
	var hip_l: Node3D
	var hip_r: Node3D
	var arm_l: Node3D
	var arm_r: Node3D
	var head: Node3D
	var torso: Node3D
	var gear: Node3D
	var paper: Node3D
	var parts: Array[MeshInstance3D] = []


static func zombie_model(kind: String) -> ZombieRig:
	var rig := ZombieRig.new()
	var root := Node3D.new()
	rig.root = root

	var skin := toon(SKIN, {"bands": 3.0, "rim": 0.2})
	var skin_d := toon(SKIN_DARK, {"bands": 2.0})
	var cloth := toon(SHIRT, {"bands": 2.5})
	var pants := toon(PANTS, {"bands": 2.5})
	var dark := toon(EYE, {"outline": false})

	# hips + legs
	rig.hip_l = pivot(root, Vector3(0, 0.72, -0.13), "HipL")
	rig.hip_r = pivot(root, Vector3(0, 0.72, 0.13), "HipR")
	for hip in [rig.hip_l, rig.hip_r]:
		box(hip, Vector3(0.15, 0.56, 0.16), Vector3(0, -0.28, 0), pants)
		box(hip, Vector3(0.19, 0.13, 0.2), Vector3(0.04, -0.58, 0), toon(Color("#2e2a26")))

	# torso
	rig.torso = pivot(root, Vector3(0, 0.78, 0), "Torso")
	box(rig.torso, Vector3(0.34, 0.52, 0.46), Vector3(0, 0.22, 0), cloth)
	box(rig.torso, Vector3(0.3, 0.12, 0.4), Vector3(0, -0.04, 0), pants)
	# tattered hem
	for i in range(3):
		box(rig.torso, Vector3(0.1, 0.09, 0.1), Vector3(-0.06 + i * 0.06, -0.06, -0.18 + i * 0.18), cloth, Vector3(0.2 * i, 0.3, 0))
	# tie
	box(rig.torso, Vector3(0.1, 0.2, 0.03), Vector3(0.16, 0.28, 0), toon(Color("#a3403a")))

	# arms reaching forward
	rig.arm_l = pivot(root, Vector3(0, 1.12, -0.26), "ArmL")
	rig.arm_r = pivot(root, Vector3(0, 1.12, 0.26), "ArmR")
	for arm in [rig.arm_l, rig.arm_r]:
		arm.rotation.z = 1.35
		box(arm, Vector3(0.13, 0.42, 0.13), Vector3(0, -0.2, 0), skin)
		box(arm, Vector3(0.15, 0.1, 0.15), Vector3(0, -0.42, 0), skin_d)

	# head
	rig.head = pivot(root, Vector3(0, 1.34, 0), "Head")
	ball(rig.head, 0.168, Vector3(0, 0.02, 0), skin, Vector3(1.0, 1.08, 0.96), 12, 9)
	box(rig.head, Vector3(0.14, 0.05, 0.2), Vector3(0.1, -0.09, 0), dark)
	for s in [-1, 1]:
		ball(rig.head, 0.04, Vector3(0.13, 0.06, 0.062 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
		ball(rig.head, 0.02, Vector3(0.158, 0.055, 0.062 * s), dark, Vector3.ONE, 6, 4)
	box(rig.head, Vector3(0.16, 0.035, 0.24), Vector3(0.0, 0.15, 0), toon(Color("#4d4038"), {"outline": false}))
	# hair tufts
	for i in range(3):
		box(rig.head, Vector3(0.03, 0.08, 0.03), Vector3(-0.04 + i * 0.03, 0.19, -0.05 + i * 0.05), toon(Color("#3b322c"), {"outline": false}), Vector3(0.2, 0, 0.3))

	rig.gear = pivot(rig.head, Vector3(0, 0.06, 0), "Gear")

	match kind:
		"cone":
			cone(rig.gear, 0.19, 0.36, Vector3(0, 0.2, 0), toon(Color("#d97a2b"), {"bands": 3.0}), Vector3.ZERO, 12)
			cyl(rig.gear, 0.2, 0.04, Vector3(0, 0.03, 0), toon(Color("#c46a20")), Vector3.ZERO, 12)
			cyl(rig.gear, 0.13, 0.05, Vector3(0, 0.16, 0), toon(WHITE, {"outline": false}), Vector3.ZERO, 12)
		"bucket":
			cyl(rig.gear, 0.19, 0.28, Vector3(0, 0.14, 0), toon(METAL, {"bands": 2.0, "rim": 0.4}), Vector3.ZERO, 14)
			cyl(rig.gear, 0.205, 0.04, Vector3(0, 0.3, 0), toon(Color("#7d868b")), Vector3.ZERO, 14)
			for i in range(2):
				cyl(rig.gear, 0.196, 0.02, Vector3(0, 0.08 + i * 0.1, 0), toon(Color("#6f787d"), {"outline": false}), Vector3.ZERO, 14)
		"football":
			rig.gear.position = Vector3(0.02, 0.04, 0)
			ball(rig.gear, 0.21, Vector3(0, 0.03, 0), toon(Color("#9c2b2b"), {"bands": 3.0, "rim": 0.4}), Vector3(1.1, 1.0, 1.05), 14, 10)
			box(rig.gear, Vector3(0.02, 0.05, 0.26), Vector3(0.2, 0.0, 0), toon(Color("#d8d8d8"), {"outline": false}))
			for i in range(3):
				box(rig.gear, Vector3(0.03, 0.02, 0.05), Vector3(0.22, -0.03 + i * 0.035, 0), toon(Color("#d8d8d8"), {"outline": false}))
			for s in [-1, 1]:
				box(rig.torso, Vector3(0.14, 0.12, 0.16), Vector3(0, 0.32, 0.3 * s), toon(Color("#8e2626")), Vector3(0, 0, 0.1))
			box(rig.torso, Vector3(0.36, 0.1, 0.48), Vector3(0, 0.34, 0), toon(Color("#8e2626")))
		"newspaper":
			rig.arm_l.rotation.z = 1.5
			rig.arm_r.rotation.z = 1.5
			rig.paper = pivot(root, Vector3(0.42, 0.98, 0), "Paper")
			box(rig.paper, Vector3(0.02, 0.42, 0.5), Vector3(0, 0, 0), toon(Color("#e8e2d2"), {"bands": 2.0}))
			box(rig.paper, Vector3(0.008, 0.3, 0.4), Vector3(0.02, 0.02, 0), toon(Color("#b9b2a0"), {"outline": false}))
			for i in range(4):
				box(rig.paper, Vector3(0.01, 0.012, 0.34), Vector3(0.025, 0.1 - i * 0.06, 0), toon(Color("#8d8778"), {"outline": false}))
			for s in [-1, 1]:
				cyl(rig.head, 0.05, 0.01, Vector3(0.15, 0.06, 0.062 * s), toon(Color("#2c2c2c"), {"outline": false}), Vector3(0, 0, PI * 0.5), 8)
		"flag":
			var pole := pivot(root, Vector3(0.3, 1.0, -0.35), "Pole")
			cyl(pole, 0.02, 1.2, Vector3(0, 0.3, 0), toon(Color("#7a5a3a"), {"outline": false}), Vector3.ZERO, 6)
			box(pole, Vector3(0.02, 0.3, 0.5), Vector3(0, 0.75, -0.26), toon(Color("#c0392b"), {"bands": 2.0}))
			rig.arm_l.rotation.z = 0.5

		"pole":
			# tracksuit stripes + the pole he plants before the first hop
			box(rig.torso, Vector3(0.36, 0.05, 0.05), Vector3(0, 0.34, 0.16), toon(Color("#e8e2d0"), {"outline": false}))
			box(rig.torso, Vector3(0.36, 0.05, 0.05), Vector3(0, 0.34, -0.16), toon(Color("#e8e2d0"), {"outline": false}))
			for hip in [rig.hip_l, rig.hip_r]:
				box(hip, Vector3(0.17, 0.05, 0.05), Vector3(0, -0.34, 0.09), toon(Color("#e8e2d0"), {"outline": false}))
				box(hip, Vector3(0.17, 0.05, 0.05), Vector3(0, -0.34, -0.09), toon(Color("#e8e2d0"), {"outline": false}))
			box(rig.head, Vector3(0.2, 0.045, 0.36), Vector3(0, 0.11, 0), toon(Color("#c0392b"), {"outline": false}))
			rig.arm_l.rotation.z = 1.05
			var staff := pivot(root, Vector3(0.26, 0.05, -0.34), "Pole")
			staff.rotation.z = -0.34
			staff.rotation.x = 0.22
			cyl(staff, 0.026, 2.05, Vector3(0, 0.95, 0), toon(Color("#c9a86a"), {"bands": 2.0}), Vector3.ZERO, 6)
			cyl(staff, 0.034, 0.1, Vector3(0, -0.02, 0), toon(Color("#8a7048"), {"bands": 2.0}), Vector3.ZERO, 6)

		"screendoor":
			# the door hangs off his front arm and takes every pea
			rig.arm_l.rotation.z = 1.15
			rig.arm_r.rotation.z = 1.15
			var door := pivot(root, Vector3(0.44, 0.0, -0.09), "Door")
			var door_frame := toon(Color("#7d8c84"), {"bands": 2.0, "rim": 0.3})
			var door_mesh := toon(Color("#a9b6ae"), {"bands": 2.0, "rim": 0.2})
			box(door, Vector3(0.05, 1.2, 0.78), Vector3(0, 0.63, 0), door_frame)
			box(door, Vector3(0.03, 1.02, 0.6), Vector3(0.03, 0.63, 0), door_mesh)
			for i in range(3):
				box(door, Vector3(0.035, 0.03, 0.62), Vector3(0.05, 0.33 + i * 0.32, 0), door_frame)
			for i in range(3):
				box(door, Vector3(0.035, 1.04, 0.03), Vector3(0.05, 0.63, -0.2 + i * 0.2), door_frame)
			ball(door, 0.05, Vector3(0.08, 0.62, 0.26), toon(Color("#d8b25a"), {"rim": 0.6}), Vector3.ONE, 8, 6)

		"balloon":
			# he floats: legs hang, the balloon rides above the head
			for hip in [rig.hip_l, rig.hip_r]:
				hip.rotation.x = 0.34
			rig.arm_l.rotation.z = 0.55
			rig.arm_r.rotation.z = 0.55
			var balloon := pivot(root, Vector3(0, 1.5, 0), "Balloon")
			cyl(balloon, 0.012, 1.1, Vector3(0, 0.5, 0), toon(Color("#e8e2d0"), {"outline": false}), Vector3.ZERO, 4)
			ball(balloon, 0.4, Vector3(0, 1.32, 0), toon(Color("#c8503f"), {"bands": 3.0, "rim": 0.45, "glow": 0.1}),
				Vector3(1.0, 1.16, 1.0), 14, 10)
			ball(balloon, 0.09, Vector3(0, 0.98, 0), toon(Color("#a83c30"), {"outline": false}), Vector3(1.0, 0.7, 1.0), 8, 6)
			for i in range(3):
				box(balloon, Vector3(0.02, 0.34, 0.02), Vector3(-0.14 + i * 0.14, 0.86, 0.02),
					toon(Color("#8e6a4a"), {"outline": false}), Vector3(0, 0, -0.3 + i * 0.3))

		"dancer", "backup":
			# purple suit, wide collar and an afro
			var suit := toon(Color("#6b4a8f"), {"bands": 2.5, "rim": 0.25})
			box(rig.torso, Vector3(0.38, 0.54, 0.5), Vector3(0, 0.22, 0), suit)
			box(rig.torso, Vector3(0.3, 0.06, 0.44), Vector3(0, 0.46, 0), toon(Color("#e8e2d0"), {"outline": false}))
			box(rig.torso, Vector3(0.14, 0.12, 0.06), Vector3(0.18, 0.4, 0), toon(Color("#d8b25a"), {"outline": false}))
			ball(rig.head, 0.23, Vector3(-0.02, 0.13, 0), toon(Color("#2c2228"), {"bands": 2.0, "rim": 0.3}),
				Vector3(1.12, 0.85, 1.12), 14, 9)
			for s2 in [-1, 1]:
				ball(rig.head, 0.05, Vector3(0.13, 0.06, 0.062 * s2), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
				ball(rig.head, 0.025, Vector3(0.16, 0.055, 0.062 * s2), dark, Vector3.ONE, 6, 4)
			if kind == "dancer":
				rig.arm_l.rotation.z = 2.0
				rig.arm_r.rotation.z = 2.0
			else:
				rig.root.scale = Vector3.ONE * 0.94

		"gargantuar":
			# he is scaled up whole; the telephone pole is the weapon
			box(rig.torso, Vector3(0.4, 0.34, 0.5), Vector3(0, 0.3, 0), toon(Color("#4a5a48"), {"bands": 2.0}))
			box(rig.torso, Vector3(0.44, 0.1, 0.54), Vector3(0, 0.12, 0), toon(Color("#3a2f2a"), {"outline": false}))
			for s2 in [-1, 1]:
				ball(rig.head, 0.048, Vector3(0.13, 0.06, 0.062 * s2),
					toon(Color("#ff7a3c"), {"glow": 1.6, "bands": 1.0, "outline": false}), Vector3(1.1, 0.8, 1.0), 8, 6)
			rig.arm_l.rotation.z = 0.6
			rig.arm_r.rotation.z = 0.6
			var club := pivot(root, Vector3(0.3, 0.2, -0.34), "Club")
			club.rotation.z = -0.42
			cyl(club, 0.085, 2.0, Vector3(0, 0.85, 0), toon(Color("#8a6a48"), {"bands": 2.5}), Vector3.ZERO, 8)
			for i in range(2):
				box(club, Vector3(0.06, 0.05, 0.5), Vector3(0, 1.62 + i * 0.2, 0), toon(Color("#6b5038"), {"bands": 2.0}))
			cyl(club, 0.11, 0.1, Vector3(0, 0.02, 0), toon(Color("#5a4430"), {"bands": 2.0}), Vector3.ZERO, 8)

	_collect(root, rig.parts)
	return rig


# --- props -----------------------------------------------------------------

static func mower_model() -> Node3D:
	var root := Node3D.new()
	var red := toon(Color("#bf3a2f"), {"bands": 3.0, "rim": 0.3})
	var dark := toon(Color("#2f3338"), {"bands": 2.0})
	var grey := toon(Color("#8b9398"), {"bands": 2.0})
	box(root, Vector3(0.72, 0.26, 0.5), Vector3(0, 0.3, 0), red)
	box(root, Vector3(0.46, 0.16, 0.4), Vector3(-0.06, 0.5, 0), red)
	box(root, Vector3(0.06, 0.06, 0.52), Vector3(0.37, 0.56, 0), dark)
	cyl(root, 0.06, 0.3, Vector3(-0.3, 0.62, 0), grey, Vector3(0, 0, 0.3), 8)
	for dz in [-0.22, 0.22]:
		for dx in [-0.23, 0.23]:
			cyl(root, 0.15, 0.09, Vector3(dx, 0.15, dz), dark, Vector3(PI * 0.5, 0, 0), 10)
	cyl(root, 0.13, 0.03, Vector3(0.3, 0.2, 0), grey, Vector3(0, 0, PI * 0.5), 10)
	return root


static func sun_model() -> Node3D:
	var root := Node3D.new()
	var core := ball(root, 0.185, Vector3.ZERO, toon(Color("#ffd63a"), {"bands": 2.0, "rim": 0.5, "glow": 0.7}), Vector3.ONE, 12, 8)
	core.name = "Core"
	var halo := quad(root, Vector2(0.5, 0.5), additive(Color(1.0, 0.82, 0.35, 0.2)), Vector3.ZERO, Vector3.ZERO, "Halo")
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("halo", halo)
	return root


static func pea_model(frozen: bool) -> Node3D:
	var root := Node3D.new()
	var c := Color("#a9e0f2") if frozen else Color("#8bd452")
	ball(root, 0.105, Vector3.ZERO, toon(c, {"bands": 2.0, "rim": 0.3, "glow": 0.15}), Vector3.ONE, 8, 6)
	if frozen:
		ball(root, 0.14, Vector3.ZERO, additive(Color(0.6, 0.9, 1.0, 0.35)), Vector3.ONE, 8, 6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


static func puff(color: Color) -> Node3D:
	var root := Node3D.new()
	var m := toon(color, {"bands": 2.0, "outline": false, "alpha": 0.85})
	var b := ball(root, 0.5, Vector3.ZERO, m, Vector3.ONE, 8, 6)
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


static func lob_model(kind: String, butter: bool) -> Node3D:
	var root := Node3D.new()
	if butter:
		box(root, Vector3(0.22, 0.15, 0.18), Vector3.ZERO,
			toon(Color("#f7e6a8"), {"bands": 2.0, "rim": 0.3}))
		box(root, Vector3(0.23, 0.035, 0.19), Vector3(0, 0.04, 0),
			toon(Color("#fff6d0"), {"outline": false}))
		return root
	if kind == "melonpult":
		var rind := toon(Color("#4f8f36"), {"bands": 3.0, "rim": 0.3})
		ball(root, 0.2, Vector3.ZERO, rind, Vector3(1.0, 0.94, 1.0), 12, 8)
		for i in range(4):
			var a := TAU * float(i) / 4.0
			ball(root, 0.022, Vector3(cos(a) * 0.185, 0, sin(a) * 0.185),
				toon(Color("#2f5c22"), {"outline": false}), Vector3(0.45, 2.6, 0.45), 6, 4)
		return root
	ball(root, 0.085, Vector3.ZERO, toon(Color("#f2cf5a"), {"bands": 2.0, "rim": 0.3}),
		Vector3(1.3, 1.0, 1.0), 8, 6)
	return root
