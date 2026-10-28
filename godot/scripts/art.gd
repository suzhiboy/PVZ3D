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
const SHIRT := Color("#625548")
const PANTS := Color("#49423b")
const METAL := Color("#9aa3a8")
const WOOD := Color("#8d6440")


# --- materials -------------------------------------------------------------

static func toon(color: Color, opts := {}) -> ShaderMaterial:
	var transparent: bool = float(opts.get("alpha", 1.0)) < 1.0
	var key := "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		color.to_html(true),
		str(opts.get("bands", 3.0)),
		str(opts.get("rim", 0.22)),
		str(opts.get("glow", 0.0)),
		str(opts.get("alpha", 1.0)),
		str(opts.get("outline", true)),
		str(opts.get("roughness", 0.88)),
		str(opts.get("gloss", 0.05)),
		str(opts.get("pigment", 0.035)),
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
	m.set_shader_parameter("roughness", float(opts.get("roughness", 0.88)))
	m.set_shader_parameter("gloss", float(opts.get("gloss", 0.05)))
	m.set_shader_parameter("pigment", float(opts.get("pigment", 0.035)))
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
		_outline.albedo_color = Color(0.095, 0.072, 0.055)
		_outline.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline.grow = true
		_outline.grow_amount = 0.014
		_outline.disable_ambient_light = true
	return _outline


static func outline_thick() -> StandardMaterial3D:
	if _outline_thick == null:
		_outline_thick = StandardMaterial3D.new()
		_outline_thick.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_thick.albedo_color = Color(0.075, 0.056, 0.045)
		_outline_thick.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline_thick.grow = true
		_outline_thick.grow_amount = 0.04
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


## Tapered tube with individually sized ends. Local +Y is the wide end, which
## makes it useful for a flared pea-shooter muzzle without extra cone segments.
static func tube(parent: Node3D, bottom_r: float, top_r: float, height: float, pos: Vector3,
		mat: Material, rot := Vector3.ZERO, segments := 14, nm := "") -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bottom_r
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


## High-resolution rounded limb/segment. Used by the detailed zombie rebuild
## where faceted silhouettes are no longer acceptable.
static func capsule(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material,
		rot := Vector3.ZERO, segments := 28, rings := 10, nm := "") -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.02)
	m.radial_segments = segments
	m.rings = rings
	return put(parent, m, mat, pos, rot, Vector3.ONE, nm)


## A smooth capsule stretched between two local points. Quaternion alignment is
## exact, avoiding the stepped elbows/fingers of the old primitive build.
static func streak(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material,
		segments := 14, nm := "") -> MeshInstance3D:
	var d := b - a
	var length := d.length()
	if length < 0.0001:
		length = 0.0001
	var mi := capsule(parent, radius, length, (a + b) * 0.5, mat, Vector3.ZERO, segments, 6, nm)
	mi.quaternion = Quaternion(Vector3.UP, d / length)
	return mi


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
	var mat := toon(LEAF, {"bands": 3.0, "rim": 0.24})
	var leaf_root := pivot(parent, Vector3(0.012, y, 0))
	leaf_root.rotation.y = ang
	# Two overlapping lobes form a broad leaf with a visible upward curl, rather
	# than the flat green pancake the old single ellipsoid produced.
	var l := ball(leaf_root, 0.115 * size, Vector3(0.105 * size, 0.012 * size, 0),
		mat, Vector3(2.05, 0.42, 0.98), 14, 7)
	l.rotation.z = 0.3
	var lobe := ball(leaf_root, 0.09 * size, Vector3(0.11 * size, 0.025 * size, 0.045 * size),
		toon(LEAF_DARK, {"bands": 2.0}), Vector3(1.55, 0.34, 0.72), 10, 6)
	lobe.rotation.z = 0.52
	lobe.rotation.y = 0.28
	# Raised midrib follows the curl and catches the toon highlight.
	cyl(leaf_root, 0.008 * size, 0.26 * size, Vector3(0.125 * size, 0.047 * size, 0),
		toon(LEAF_DARK, {"outline": false}), Vector3(0, 0, -PI * 0.5 + 0.3), 6)



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
	# scatter the spots around the front of the cap instead of one straight row,
	# otherwise the cap reads as a plain balloon (cards all show spotted caps)
	for i in range(count):
		var a := -1.3 + 2.6 * (float(i) + 0.5) / maxf(1.0, float(count))
		var rr := r * (0.6 + 0.16 * absf(sin(float(i) * 1.9)))
		# sit the spot ON the cap ellipsoid: 0.7r out needs ~0.4r of height,
		# otherwise it ends up buried inside the cap and never shows
		ball(head, r * 0.19, Vector3(cos(a) * rr, y + r * (0.36 + 0.1 * absf(cos(float(i) * 1.3))),
			sin(a) * rr), toon(col, {"outline": false}), Vector3(1.0, 0.4, 1.0), 7, 5)


static func _lily_disc(parent: Node3D, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 32
	for i in range(segments):
		var a0 := TAU * float(i) / segments
		var a1 := TAU * float(i + 1) / segments
		# Leave a real open notch on +X rather than painting one on a cylinder.
		if a0 < 0.34 or a0 > TAU - 0.34:
			continue
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(Vector3.ZERO)
		st.set_uv(Vector2(cos(a0), sin(a0)) * 0.5 + Vector2.ONE * 0.5)
		st.add_vertex(Vector3(cos(a0) * 0.66, 0, sin(a0) * 0.58))
		st.set_uv(Vector2(cos(a1), sin(a1)) * 0.5 + Vector2.ONE * 0.5)
		st.add_vertex(Vector3(cos(a1) * 0.66, 0, sin(a1) * 0.58))
	return put(parent, st.commit(), mat, Vector3(0, 0.035, 0))


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
			_leaf(sway, 0.26, 0.4, 1.15)
			_leaf(sway, 0.4, -0.5, 1.05)
			var head := pivot(sway, Vector3(0, 0.78, 0), "Head")
			rig.head = head
			var petal := toon(PETAL, {"bands": 3.0, "rim": 0.3})
			var petal2 := toon(PETAL_DARK, {"bands": 3.0, "rim": 0.2})
			var disc := toon(Color("#c4762f"), {"bands": 3.0, "rim": 0.26})
			# Plants face +X. The card puts a big seed disc in front and a short
			# ring of rounded petals behind it, so the face must sit at +X and be
			# the widest single element of the head.
			for i in range(15):
				var a := TAU * float(i) / 15.0
				var pm := petal if i % 3 != 0 else petal2
				var p := ball(head, 0.118, Vector3(-0.02, cos(a) * 0.425, sin(a) * 0.425), pm,
					Vector3(0.30, 1.10, 0.86), 10, 7)
				p.rotation = Vector3(a, 0, 0)
			# Small green calyx peeking out behind the petals, not in front of them.
			ball(head, 0.30, Vector3(-0.075, 0, 0), toon(LEAF_DARK), Vector3(0.22, 1.0, 1.0), 16, 10)
			var face := ball(head, 0.345, Vector3(0.035, 0, 0), disc, Vector3(0.40, 1.0, 1.0), 20, 13)
			face.name = "Face"
			for s in [-1, 1]:
				ball(head, 0.062, Vector3(0.163, 0.085, 0.118 * s), toon(EYE, {"outline": false}),
					Vector3(0.42, 1.22, 0.82), 10, 7)
				ball(head, 0.014, Vector3(0.184, 0.104, 0.110 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 6, 4)
			# A wide upward-curving smile, drawn as overlapping beads on the disc.
			for i in range(7):
				var z := (float(i) - 3.0) * 0.030
				var dip := (1.0 - absf(float(i) - 3.0) / 3.0) * 0.032
				ball(head, 0.015, Vector3(0.170, -0.055 - dip, z),
					toon(Color("#3c2415"), {"outline": false}), Vector3(0.45, 0.75, 1.0), 6, 4)
			# Seed dots around the rim of the disc read as the classic sunflower face.
			for i in range(10):
				var a := TAU * float(i) / 10.0 + 0.3
				ball(head, 0.011, Vector3(0.152, cos(a) * 0.265, sin(a) * 0.265),
					toon(Color("#96601f"), {"outline": false}), Vector3.ONE, 6, 4)

		"peashooter", "snowpea", "repeater":
			_mound(root)
			var icy := kind == "snowpea"
			var stem_col := ICE_DEEP if icy else STEM
			var stem_mat := toon(stem_col, {"bands": 2.0, "rim": 0.15})
			# Two short stalk segments lean the head forward like the reference.
			cyl(sway, 0.048, 0.3, Vector3(0, 0.14, 0), stem_mat, Vector3.ZERO, 9)
			cyl(sway, 0.04, 0.3, Vector3(0.035, 0.37, 0), stem_mat, Vector3(0, 0, -0.12), 9)
			# Three broad leaves fill the silhouette at the base.
			_leaf(sway, 0.08, 0.82, 1.2)
			_leaf(sway, 0.11, -0.76, 1.12)
			_leaf(sway, 0.15, PI + 0.18, 1.0)
			var head := pivot(sway, Vector3(0.06, 0.72, 0), "Head")
			rig.head = head
			var body_mat := toon(ICE if icy else PEA, {"bands": 3.0, "rim": 0.3, "glow": 0.06 if icy else 0.0})
			# A long bean-shaped head, heavier at the back and narrower at the muzzle.
			# The card head is clearly wider than it is tall, so the x stretch is
			# generous and the verticall bulge stays modest.
			ball(head, 0.245, Vector3(-0.05, 0.02, 0), body_mat, Vector3(1.46, 0.98, 0.94), 20, 13)
			ball(head, 0.17, Vector3(-0.19, -0.015, 0), body_mat, Vector3(1.18, 0.86, 0.84), 12, 8)
			var snouts := 2 if kind == "repeater" else 1
			var snout_len := 0.31
			var muzzle := toon(ICE_DEEP if icy else LEAF_DARK, {"bands": 2.0})
			var mouth_hole := toon(Color("#143424") if not icy else Color("#173c4c"), {"outline": false})
			var flare := 0.145 if snouts == 1 else 0.112
			for s in range(snouts):
				var snout_y := (0.145 if s == 0 else -0.005) if snouts > 1 else 0.07
				var tilt := -PI * 0.5 + 0.1
				var cx := 0.25
				var cy := snout_y + 0.018
				tube(head, flare * 0.66, flare, snout_len, Vector3(cx, cy, 0),
					body_mat, Vector3(0, 0, tilt), 18)
				var ex := cx + cos(0.1) * snout_len * 0.5
				var ey := cy + sin(0.1) * snout_len * 0.5
				torus(head, flare * 0.69, flare * 1.04, Vector3(ex, ey, 0), muzzle, Vector3(0, 0, tilt))
				cyl(head, flare * 0.70, 0.012, Vector3(ex + 0.006, ey + 0.001, 0),
					mouth_hole, Vector3(0, 0, tilt), 18)
			for s in [-1, 1]:
				# Black oval eyes sit on the sides so they remain readable at any angle.
				ball(head, 0.05, Vector3(0.072, 0.12, 0.19 * s), toon(EYE, {"outline": false}),
					Vector3(0.62, 1.28, 0.76), 10, 7)
				ball(head, 0.012, Vector3(0.088, 0.14, 0.225 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 6, 4)
				var brow := ball(head, 0.05, Vector3(0.055, 0.177, 0.155 * s),
					toon(LEAF_DARK, {"outline": false}), Vector3(1.45, 0.22, 0.5), 8, 5)
				brow.rotation.z = -0.18
			# The little crease above the barrel is a signature detail of the original.
			ball(head, 0.022, Vector3(0.15, 0.172, 0), toon(LEAF_DARK, {"outline": false}),
				Vector3(0.6, 1.3, 0.55), 8, 5)
			# A backward leaf sprout replaces the old flat crown slab.
			var sprout := pivot(head, Vector3(-0.235, 0.07, 0), "Sprout")
			for s in [-1, 1]:
				var rear := ball(sprout, 0.07, Vector3(-0.07, 0.04 + 0.025 * s, 0.035 * s),
					toon(LEAF_DARK), Vector3(1.8, 0.28, 0.58), 8, 5)
				rear.rotation = Vector3(0, 0.3 * s, 0.36 + 0.12 * s)
			if icy:
				for i in range(4):
					var a := TAU * float(i) / 4.0 + 0.4
					cone(head, 0.034, 0.13, Vector3(-0.09, cos(a) * 0.17, sin(a) * 0.17),
						toon(ICE, {"glow": 0.25, "rim": 0.4}), Vector3(-a, 0, -0.7), 5)

		"threepeater":
			_mound(root)
			_stalk(sway, 0.42)
			_leaf(sway, 0.2, 0.4, 1.2)
			for i in range(3):
				var h := pivot(sway, Vector3(0, 0.6 + (0.13 if i == 1 else 0.0), (i - 1) * 0.26), "Head%d" % i)
				rig.extra.append(h)
				var mat := toon(PEA, {"bands": 3.0, "rim": 0.25})
				ball(h, 0.15, Vector3.ZERO, mat)
				cyl(h, 0.085, 0.22, Vector3(0.15, 0, 0), mat, Vector3(0, 0, PI * 0.5), 9)
				# dark muzzle so the snout reads from the front, like the card
				ball(h, 0.075, Vector3(0.265, 0, 0), toon(Color("#2f4a1c"), {"outline": false}),
					Vector3(0.42, 1.02, 1.02), 8, 6)
				for s in [-1, 1]:
					ball(h, 0.028, Vector3(0.1, 0.045, 0.058 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 6, 4)
					ball(h, 0.015, Vector3(0.118, 0.045, 0.058 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)
			# the middle head is the rig's head; the other two stay in extra[]
			rig.head = rig.extra[1]

		"wallnut", "tallnut":
			var tall := kind == "tallnut"
			var sy := 0.72 if tall else 0.55
			var cy := sy * 0.68
			var body := pivot(sway, Vector3(0, 0.0, 0), "Head")
			rig.head = body
			var mat := toon(NUT, {"bands": 3.0, "rim": 0.25})
			var shell_light := toon(NUT_LIGHT, {"bands": 2.0, "rim": 0.12, "outline": false})
			ball(body, 0.37 if tall else 0.36, Vector3(0, sy * 0.62, 0), mat,
				Vector3(0.94, sy / 0.55, 0.96), 18, 13)
			# The lighter front is only a shallow colour patch, not a second ball.
			ball(body, 0.335, Vector3(0.026, sy * 0.64, 0), shell_light,
				Vector3(0.86, sy / 0.57, 0.82), 16, 11)
			for s in [-1, 1]:
				var eye_x := 0.292
				var eye_z := 0.115 * float(s)
				ball(body, 0.098, Vector3(eye_x, cy + 0.035, eye_z),
					toon(NUT_CENTER.darkened(0.35), {"outline": false}), Vector3(0.28, 1.02, 0.94), 12, 8)
				ball(body, 0.088, Vector3(eye_x + 0.014, cy + 0.035, eye_z), toon(WHITE, {"outline": false}),
					Vector3(0.26, 1.02, 0.94), 14, 10)
				ball(body, 0.038, Vector3(eye_x + 0.038, cy + 0.028, 0.108 * float(s)),
					toon(EYE, {"outline": false}), Vector3(0.4, 1.0, 0.94), 10, 7)
				ball(body, 0.010, Vector3(eye_x + 0.052, cy + 0.044, 0.098 * float(s)),
					toon(WHITE, {"outline": false}), Vector3.ONE, 6, 4)
				# Worried brow, the expression that sells the wall-nut.
				var brow := ball(body, 0.062, Vector3(eye_x - 0.01, cy + 0.145, eye_z),
					toon(NUT_CENTER.darkened(0.5), {"outline": false}), Vector3(0.22, 0.20, 0.72), 8, 5)
				brow.rotation.x = 0.22 * float(s)
			box(body, Vector3(0.016, 0.020, 0.095), Vector3(0.337, cy - 0.11, 0),
				toon(NUT_CENTER.darkened(0.52), {"outline": false}), Vector3.ZERO, "Mouth")
			# Sparse pores keep the shell organic without turning into polka dots.
			for i in range(7):
				var a := TAU * float(i) / 7.0 + 0.5
				ball(body, 0.016, Vector3(0.13, cy + cos(a) * sy * 0.38, sin(a) * 0.26),
					toon(NUT_CENTER.darkened(0.12), {"outline": false}), Vector3(0.35, 0.62, 0.62), 6, 4)
			if tall:
				# Tall-nut's messy brown tuft, built from overlapping soft blades.
				for i in range(7):
					var a := -0.78 + float(i) * 0.26
					var tuft := ball(body, 0.055,
						Vector3(cos(a) * 0.16, sy * 0.62 + 0.52 + 0.022 * (i % 2), sin(a) * 0.12),
						toon(Color("#4a3824"), {"bands": 2.0}), Vector3(0.55, 2.5, 0.65), 8, 6)
					tuft.rotation.z = -a * 0.85
					tuft.rotation.x = a * 0.25
				for s in [-1, 1]:
					var side_tuft := ball(body, 0.045,
						Vector3(-0.16, sy * 0.62 + 0.31, 0.28 * s),
						toon(Color("#4a3824"), {"outline": false}), Vector3(0.58, 1.8, 0.6), 7, 5)
					side_tuft.rotation.x = 0.55 * s
			else:
				cyl(body, 0.025, 0.075, Vector3(0.02, sy * 0.62 + 0.355, 0),
					toon(Color("#6f7a3f"), {"bands": 2.0}), Vector3(0, 0, 0.5), 6)
				var top_leaf := ball(body, 0.06, Vector3(-0.03, sy * 0.62 + 0.4, 0.02),
					toon(LEAF_DARK), Vector3(1.45, 0.25, 0.55), 8, 5)
				top_leaf.rotation.z = 0.5
			var cracks := Node3D.new()
			cracks.name = "Cracks"
			body.add_child(cracks)
			rig.extra.append(cracks)
			for i in range(4):
				var cm := toon(Color("#6b4520"), {"outline": false})
				var c1 := box(cracks, Vector3(0.02, 0.11, 0.02), Vector3(-0.22 - i * 0.02, 0.42 + i * 0.09, -0.16 + i * 0.1), cm)
				c1.rotation = Vector3(0.3 * i, 0.4, 0.5)
			cracks.visible = false

		"cherrybomb":
			var h := pivot(sway, Vector3(0, 0, 0), "Head")
			rig.head = h
			var mat := toon(CHERRY, {"bands": 3.0, "rim": 0.35, "glow": 0.05})
			var shine := toon(CHERRY.lightened(0.28), {"outline": false})
			for s in [-1, 1]:
				ball(h, 0.205, Vector3(0.02, 0.26, 0.155 * s), mat, Vector3(1.0, 0.96, 0.94), 16, 11)
				# a small specular blob keeps the fruit reading as glossy, not plastic
				ball(h, 0.05, Vector3(0.20, 0.38, 0.075 * s), shine, Vector3(0.45, 1.0, 0.8), 8, 6)
				# Angry face on the +X side, the direction every plant faces. The
				# cherries are 0.205 deep, so features have to sit near x=0.21 or
				# they end up buried inside the fruit.
				var eye_y := 0.27
				ball(h, 0.052, Vector3(0.205, eye_y, 0.095 * s), toon(WHITE, {"outline": false}),
					Vector3(0.4, 1.0, 1.0), 10, 7)
				ball(h, 0.026, Vector3(0.228, eye_y - 0.004, 0.098 * s), toon(EYE, {"outline": false}),
					Vector3(0.4, 1.0, 1.0), 8, 6)
				var brow := box(h, Vector3(0.03, 0.028, 0.09), Vector3(0.222, eye_y + 0.075, 0.095 * s),
					toon(EYE, {"outline": false}), Vector3.ZERO)
				brow.rotation.x = 0.46 * float(s)
				var mouth := box(h, Vector3(0.03, 0.018, 0.06), Vector3(0.232, 0.165, 0.058 * s),
					toon(Color("#5a1210"), {"outline": false}), Vector3.ZERO)
				mouth.rotation.x = -0.3 * float(s)
				# Stem rises from the top of each cherry and leans toward the pair.
				cyl(h, 0.017, 0.30, Vector3(0.01, 0.40, 0.13 * s), toon(STEM_DARK, {"outline": false}),
					Vector3(0, 0, -0.34 * s), 6)
			cyl(h, 0.024, 0.30, Vector3(0, 0.50, 0), toon(STEM, {"outline": false}), Vector3.ZERO, 6)
			for i in range(2):
				var lf := ball(h, 0.10, Vector3(-0.01 + (i - 0.5) * 0.14, 0.80, (i - 0.5) * 0.10),
					toon(LEAF, {"bands": 2.0}), Vector3(1.5, 0.24, 0.66), 8, 5)
				lf.rotation.y = (i - 0.5) * 0.9
				lf.rotation.z = 0.1 * float(i) - 0.05

		"potatomine":
			_mound(root)
			var h := pivot(sway, Vector3(0, 0, 0), "Head")
			rig.head = h
			var mat := toon(Color("#b98a52"), {"bands": 2.0, "rim": 0.2})
			# the card potato is a low lumpy mound, not a dome
			ball(h, 0.24, Vector3(-0.02, 0.1, 0), mat, Vector3(1.2, 0.62, 1.05), 16, 11)
			for i in range(7):
				var a2 := TAU * float(i) / 7.0 + 0.2
				ball(root, 0.055, Vector3(cos(a2) * 0.29, 0.035, sin(a2) * 0.27),
					toon(Color("#6d5236"), {"bands": 2.0}), Vector3(1.3, 0.7, 1.1), 7, 5)
			for i in range(5):
				var a := TAU * float(i) / 5.0 + 0.35
				ball(h, 0.018, Vector3(-0.14, 0.12 + cos(a) * 0.14, sin(a) * 0.17),
					toon(Color("#805a32"), {"outline": false}), Vector3(0.5, 0.8, 0.8), 6, 4)
			for s in [-1, 1]:
				ball(h, 0.035, Vector3(0.225, 0.17, 0.075 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
				ball(h, 0.019, Vector3(0.252, 0.17, 0.075 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)
			box(h, Vector3(0.02, 0.022, 0.12), Vector3(0.238, 0.11, 0), toon(Color("#5d3f1f"), {"outline": false}))
			for s in [-1, 1]:
				box(h, Vector3(0.018, 0.028, 0.03), Vector3(0.24, 0.135, 0.062 * s),
					toon(Color("#f4ead6"), {"outline": false}))
			var led := ball(h, 0.045, Vector3(0.0, 0.34, 0), toon(Color("#8a2a20"), {"glow": 0.0}), Vector3.ONE, 8, 6, "Led")
			rig.extra.append(led)

		"chomper":
			_mound(root)
			# A curved purple neck, three broad leaves and a head that is almost
			# entirely mouth: this is the original chomper silhouette.
			_stalk(sway, 0.16, STEM_DARK)
			cyl(sway, 0.045, 0.34, Vector3(0.055, 0.3, 0), toon(CHOMPER_DARK, {"bands": 2.0}),
				Vector3(0, 0, -0.23), 9)
			_leaf(sway, 0.09, 0.75, 1.25)
			_leaf(sway, 0.12, -0.8, 1.18)
			_leaf(sway, 0.16, PI + 0.1, 1.0)
			var h := pivot(sway, Vector3(0.085, 0.56, 0), "Head")
			h.scale = Vector3.ONE * 1.1
			rig.head = h
			var mat := toon(CHOMPER, {"bands": 3.0, "rim": 0.32})
			var dark := toon(CHOMPER_DARK, {"bands": 2.0})
			var lip := toon(Color("#a9c588"), {"bands": 2.2, "rim": 0.16})
			var maw := toon(Color("#342040"), {"bands": 1.0, "outline": false})
			var tongue := toon(Color("#9e4d76"), {"bands": 2.0, "outline": false})
			ball(h, 0.25, Vector3(-0.01, 0.16, 0), mat, Vector3(1.02, 1.12, 0.9), 18, 12)
			# Open throat and tongue sit behind the two jaw shells.
			ball(h, 0.225, Vector3(0.14, 0.17, 0), maw, Vector3(0.62, 0.82, 0.82), 14, 10)
			ball(h, 0.17, Vector3(0.135, 0.125, 0), tongue, Vector3(0.62, 0.32, 0.58), 12, 8)
			var lower := pivot(h, Vector3(-0.03, -0.02, 0), "Jaw")
			ball(lower, 0.23, Vector3(0.12, 0.0, 0), dark, Vector3(1.06, 0.48, 0.94), 16, 9)
			var lower_lip := ball(lower, 0.17, Vector3(0.235, 0.115, 0), lip,
				Vector3(0.78, 0.19, 0.92), 12, 6)
			lower_lip.rotation.z = 0.04
			var upper := pivot(h, Vector3(-0.03, 0.36, 0), "UpperJaw")
			ball(upper, 0.23, Vector3(0.12, 0.02, 0), mat, Vector3(1.06, 0.55, 0.94), 16, 9)
			var upper_lip := ball(upper, 0.17, Vector3(0.235, -0.10, 0), lip,
				Vector3(0.8, 0.19, 0.92), 12, 6)
			upper_lip.rotation.z = -0.04
			# Two pale lip bands frame a wide open bite; no closed ring, so the
			# teeth and dark throat stay visible in profile.
			for i in range(7):
				var z := (float(i) - 3.0) * 0.041
				var big := 1.0 + 0.12 * (1.0 - absf(float(i) - 3.0) / 3.0)
				cone(upper, 0.03 * big, 0.086 * big, Vector3(0.366, -0.105, z),
					toon(WHITE, {"outline": false}), Vector3(0, 0, PI), 6)
				cone(lower, 0.028 * big, 0.08 * big, Vector3(0.366, 0.13, z + 0.021),
					toon(WHITE, {"outline": false}), Vector3.ZERO, 6)
			# Green thorn fringe around the back and top of the purple head.
			var thorn := toon(Color("#86b34b"), {"bands": 2.0, "rim": 0.2})
			for i in range(5):
				var a := 0.55 + float(i) * 0.48
				var tx := cos(a) * 0.275
				var ty := 0.16 + sin(a) * 0.295
				cone(h, 0.047, 0.205, Vector3(tx, ty, 0),
					thorn, Vector3(0, 0, a - PI * 0.5), 5)
			for s in [-1, 1]:
				for i in range(2):
					var a := 1.2 + float(i) * 0.65
					cone(h, 0.034, 0.13,
						Vector3(cos(a) * 0.23, 0.16 + sin(a) * 0.23, 0.2 * s),
						thorn, Vector3(0.65 * s, 0, a - PI * 0.5), 5)
			# Purple leaf veins on the outer cheek.
			for i in range(3):
				var vein := ball(h, 0.13, Vector3(-0.19, 0.2 + i * 0.065, -0.11 + i * 0.11),
					toon(Color("#5e367a"), {"outline": false}), Vector3(0.45, 0.08, 0.9), 7, 5)
				vein.rotation.x = -0.4 + i * 0.4
			rig.extra.append(lower)
			rig.extra.append(upper)

		"lilypad":
			var pad := toon(Color("#62ad4f"), {"bands": 3.0, "rim": 0.24})
			_lily_disc(root, pad)
			# A pad is flat, but the rig still needs a head pivot for gameplay
			# squash/stretch, so hang one at the pad centre.
			var pad_head := pivot(root, Vector3(0, 0.02, 0), "Head")
			rig.head = pad_head
			for i in range(7):
				var a := 0.55 + float(i) * (TAU - 1.1) / 6.0
				var vein := cyl(root, 0.008, 0.43,
					Vector3(cos(a) * 0.22, 0.044, sin(a) * 0.20), toon(Color("#438c3d"), {"outline": false}),
					Vector3(0, 0, PI * 0.5), 5)
				vein.rotation.y = -a
			for s in [-1, 1]:
				ball(root, 0.035, Vector3(-0.19, 0.065, 0.11 * s), toon(EYE, {"outline": false}),
					Vector3(0.85, 0.32, 0.72), 8, 5)
				ball(root, 0.007, Vector3(-0.20, 0.077, 0.102 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 6, 4)
			for i in range(6):
				var a := TAU * float(i) / 6.0
				ball(root, 0.065, Vector3(-0.34 + cos(a) * 0.065, 0.09, 0.26 + sin(a) * 0.065),
					toon(Color("#f3e6f5"), {"bands": 2.0}), Vector3(1.0, 0.38, 0.68), 8, 5)
			ball(root, 0.045, Vector3(-0.34, 0.11, 0.26), toon(PETAL), Vector3(1.0, 0.55, 1.0), 8, 5, "Flower")

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
			box(h, Vector3(0.02, 0.025, 0.08), Vector3(0.17, 0.47, 0), toon(EYE, {"outline": false}), Vector3(0, 0, 0.3))
			box(h, Vector3(0.02, 0.02, 0.1), Vector3(0.172, 0.355, 0), toon(Color("#6d1410"), {"outline": false}))

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
				box(h, Vector3(0.02, 0.03, 0.12), Vector3(0.278, 0.40, 0.11 * s), toon(EYE, {"outline": false}),
					Vector3(0, 0, -0.34 * s))
			box(h, Vector3(0.02, 0.04, 0.22), Vector3(0.29, 0.17, 0), toon(EYE, {"outline": false}), Vector3(0, 0, -0.1))

		"pumpkin":
			# a ring of lobes reads as a real gourd, and leaves the middle hollow
			var shell := pivot(root, Vector3(0, 0.0, 0), "Head")
			rig.head = shell
			var body := toon(Color("#e8912f"), {"bands": 3.0, "rim": 0.3})
			var body2 := toon(Color("#d97d22"), {"bands": 3.0, "rim": 0.28})
			for i in range(8):
				var a := TAU * float(i) / 8.0
				ball(shell, 0.2, Vector3(cos(a) * 0.34, 0.3, sin(a) * 0.34),
					body if i % 2 == 0 else body2, Vector3(0.95, 1.55, 0.95), 10, 7)
			cyl(shell, 0.4, 0.03, Vector3(0, 0.07, 0), toon(Color("#3f2611"), {"outline": false}), Vector3.ZERO, 16)
			torus(shell, 0.34, 0.53, Vector3(0, 0.585, 0), toon(Color("#c66f18"), {"bands": 2.0}))
			cyl(shell, 0.055, 0.2, Vector3(-0.34, 0.62, -0.3), toon(Color("#6d7a3a")), Vector3(0.42, 0, 0.42), 6)
			# the carved face turns toward the zombies, i.e. the model's +X side
			for s in [-1, 1]:
				ball(shell, 0.09, Vector3(0.53, 0.42, 0.16 * s),
					toon(Color("#2a1a0c"), {"outline": false}), Vector3(0.5, 1.0, 0.85), 8, 6)
			box(shell, Vector3(0.04, 0.11, 0.26), Vector3(0.55, 0.25, 0), toon(Color("#2a1a0c"), {"outline": false}))
			for i in range(3):
				box(shell, Vector3(0.04, 0.06, 0.055), Vector3(0.56, 0.31, -0.075 + i * 0.075),
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
				ball(hk, 0.04, Vector3(0.2, 0.32, 0.075 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
				ball(hk, 0.021, Vector3(0.232, 0.32, 0.075 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)
			box(hk, Vector3(0.02, 0.018, 0.12), Vector3(0.216, 0.245, 0), toon(EYE, {"outline": false}))
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
				ball(hm, 0.045, Vector3(0.24, 0.33, 0.09 * s), toon(WHITE, {"outline": false}), Vector3.ONE, 8, 6)
				ball(hm, 0.023, Vector3(0.275, 0.33, 0.09 * s), toon(EYE, {"outline": false}), Vector3.ONE, 6, 4)
			box(hm, Vector3(0.02, 0.02, 0.1), Vector3(0.262, 0.245, 0), toon(EYE, {"outline": false}))
			var marm := pivot(hm, Vector3(0.0, 0.5, 0), "Arm")
			box(marm, Vector3(0.46, 0.06, 0.06), Vector3(0.16, 0.04, 0), toon(WOOD, {"bands": 2.0}), Vector3(0, 0, 0.28))
			cyl(marm, 0.15, 0.1, Vector3(0.38, 0.14, 0), toon(Color("#a8763f"), {"bands": 2.0}), Vector3.ZERO, 10)
			ball(marm, 0.13, Vector3(0.38, 0.24, 0), rind, Vector3(1.0, 0.88, 1.0), 12, 8)
			rig.extra.append(marm)

		"puffshroom":
			_mound(root)
			var hp := _shroom(sway, Color("#a389c8"), 0.2, 0.78, 0.16)
			rig.head = hp
			_mushroom_spots(hp, 0.188, 0.2, 6, Color("#6b4a86"))
			_shroom_eyes(hp, 0.13, 0.12, 0.05, 0.03)
			box(hp, Vector3(0.02, 0.02, 0.07), Vector3(0.155, 0.07, 0), toon(EYE, {"outline": false}))

		"sunshroom":
			_mound(root)
			var hs := _shroom(sway, Color("#f2c033"), 0.25, 0.72, 0.22, 0.1)
			rig.head = hs
			_mushroom_spots(hs, 0.255, 0.25, 6, Color("#d98b28"))
			_shroom_eyes(hs, 0.17, 0.17, 0.06, 0.036)
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
			# wide muzzle on the front (+X, toward the zombies)
			cyl(hf, 0.17, 0.16, Vector3(0.2, 0.24, 0), toon(Color("#b6a8c8"), {"bands": 2.0}), Vector3(0, 0, PI * 0.5), 12)
			torus(hf, 0.1, 0.17, Vector3(0.28, 0.24, 0), toon(Color("#6f6484"), {"bands": 2.0}), Vector3(0, 0, PI * 0.5))
			cyl(hf, 0.12, 0.03, Vector3(0.26, 0.24, 0), toon(Color("#3b3348"), {"outline": false}), Vector3(0, 0, PI * 0.5), 12)
			_mushroom_spots(hf, 0.322, 0.3, 6, Color("#5b4a72"))
			# eyes sit on the cap above the muzzle, not floating over the crown
			_shroom_eyes(hf, 0.2, 0.34, 0.1, 0.042)

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
			_mushroom_spots(hh, 0.258, 0.27, 5, Color("#a9538c"))
			_shroom_eyes(hh, 0.19, 0.16, 0.06, 0.038, Color("#7a3a86"))
			box(hh, Vector3(0.02, 0.022, 0.08), Vector3(-0.2, 0.11, 0), toon(Color("#7a3a86"), {"outline": false}))

		"iceshroom":
			_mound(root)
			var hi := _shroom(sway, Color("#9fd8ea"), 0.26, 0.68, 0.2, 0.22)
			rig.head = hi
			for i in range(6):
				var a := TAU * float(i) / 6.0 + 0.3
				cone(hi, 0.045, 0.16, Vector3(cos(a) * 0.22, 0.14, sin(a) * 0.22),
					toon(ICE, {"glow": 0.3, "rim": 0.5}), Vector3(PI, 0, 0), 5)
			_shroom_eyes(hi, 0.17, 0.19, 0.055, 0.034, Color("#2b5f7a"))
			box(hi, Vector3(0.02, 0.025, 0.075), Vector3(-0.19, 0.13, 0), toon(Color("#2b5f7a"), {"outline": false}))

		"doomshroom":
			_mound(root)
			var hd := _shroom(sway, Color("#4a2e5c"), 0.33, 0.66, 0.24, 0.06)
			rig.head = hd
			for i in range(6):
				var a := TAU * float(i) / 6.0
				box(hd, Vector3(0.03, 0.09, 0.03), Vector3(cos(a) * 0.3, 0.3, sin(a) * 0.3),
					toon(Color("#6b4a80"), {"outline": false}), Vector3(0.4, -a, 0))
			# the red glare sits on the +X side where the player can see it
			for s in [-1, 1]:
				ball(hd, 0.05, Vector3(0.28, 0.3, 0.08 * s),
					toon(Color("#ff5a3c"), {"glow": 1.8, "bands": 1.0, "outline": false}), Vector3(1.4, 0.6, 1.0), 8, 5)
				box(hd, Vector3(0.03, 0.03, 0.1), Vector3(0.29, 0.34, 0.09 * s),
					toon(Color("#3a0f18"), {"outline": false}), Vector3(0, 0, -0.5 * s))
			box(hd, Vector3(0.02, 0.045, 0.17), Vector3(0.3, 0.18, 0), toon(Color("#2a1a2e"), {"outline": false}))

		"magnetshroom":
			_mound(root)
			var hm2 := _shroom(sway, Color("#9aa3a8"), 0.28, 0.62, 0.24, 0.05)
			rig.head = hm2
			# the horseshoe magnet is the cap's crown, not a floating prop
			torus(hm2, 0.12, 0.2, Vector3(0.0, 0.34, 0), toon(Color("#c0392b"), {"bands": 2.0}), Vector3(0, 0, PI * 0.5))
			for s in [-1, 1]:
				box(hm2, Vector3(0.07, 0.14, 0.07), Vector3(0.11, 0.42, 0.12 * s), toon(Color("#3d6fb0"), {"bands": 2.0}))
				box(hm2, Vector3(0.075, 0.05, 0.075), Vector3(0.11, 0.51, 0.12 * s), toon(Color("#d8dde0"), {"bands": 1.0}))
			_shroom_eyes(hm2, 0.2, 0.16, 0.06, 0.036, Color("#33404a"))

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

	# Smooth, high-resolution character materials. Zombies intentionally drop
	# the ink outline and faceted look: shading, silhouette and material response
	# carry the form instead. Plants keep their hand-drawn outline language.
	var skin := toon(Color("#9caf82"), {"bands": 5.0, "rim": 0.16, "outline": false,
		"roughness": 0.66, "gloss": 0.08, "pigment": 0.018})
	var skin_hi := toon(Color("#aebf93"), {"bands": 4.0, "outline": false,
		"roughness": 0.62, "gloss": 0.1, "pigment": 0.014})
	var skin_d := toon(Color("#7f9369"), {"bands": 4.0, "outline": false,
		"roughness": 0.7, "gloss": 0.05, "pigment": 0.02})
	var skin_deep := toon(Color("#67795c"), {"bands": 3.0, "outline": false, "pigment": 0.0})
	var lip := toon(Color("#5f4b42"), {"bands": 4.0, "outline": false,
		"roughness": 0.7, "gloss": 0.06})
	var cloth := toon(Color("#535446"), {"bands": 4.0, "outline": false,
		"roughness": 0.92, "gloss": 0.02, "pigment": 0.04})
	var cloth_hi := toon(Color("#626352"), {"bands": 4.0, "outline": false,
		"roughness": 0.9, "gloss": 0.025, "pigment": 0.038})
	var cloth_d := toon(Color("#424439"), {"bands": 3.0, "outline": false,
		"roughness": 0.94, "gloss": 0.015, "pigment": 0.045})
	var pants := toon(Color("#3d4239"), {"bands": 4.0, "outline": false,
		"roughness": 0.94, "gloss": 0.015, "pigment": 0.045})
	var shirt := toon(Color("#d1c6ad"), {"bands": 4.0, "outline": false,
		"roughness": 0.88, "gloss": 0.03, "pigment": 0.035})
	var tie := toon(Color("#87352f"), {"bands": 4.0, "outline": false,
		"roughness": 0.78, "gloss": 0.06, "pigment": 0.025})
	var hair := toon(Color("#352e27"), {"bands": 3.0, "outline": false,
		"roughness": 0.84, "gloss": 0.035})
	var maw := toon(Color("#321b18"), {"bands": 2.0, "outline": false})
	var tooth := toon(Color("#e5dabb"), {"bands": 3.0, "outline": false,
		"roughness": 0.5, "gloss": 0.13, "pigment": 0.01})
	var sclera := toon(Color("#e9e1cb"), {"bands": 3.0, "outline": false,
		"roughness": 0.34, "gloss": 0.16, "pigment": 0.008})
	var iris := toon(Color("#77704b"), {"bands": 3.0, "outline": false, "roughness": 0.4})
	var pupil := toon(Color("#161512"), {"bands": 1.0, "outline": false, "roughness": 0.22, "gloss": 0.2})
	var shoe := toon(Color("#29241f"), {"bands": 4.0, "outline": false,
		"roughness": 0.58, "gloss": 0.13, "pigment": 0.03})
	var sole := toon(Color("#171614"), {"bands": 2.0, "outline": false, "roughness": 0.92})
	var dark := toon(EYE, {"outline": false})

	# Narrow trousers, exaggerated shoes and a stooped jacket: the silhouette is
	# unchanged, only the surface quality and anatomical detail increase.
	rig.hip_l = pivot(root, Vector3(0, 0.74, -0.14), "HipL")
	rig.hip_r = pivot(root, Vector3(0, 0.74, 0.14), "HipR")
	for hip in [rig.hip_l, rig.hip_r]:
		ball(hip, 0.135, Vector3(-0.015, -0.045, 0), pants, Vector3(1.0, 0.68, 0.9), 32, 20)
		capsule(hip, 0.099, 0.42, Vector3(-0.005, -0.2, 0), pants, Vector3.ZERO, 32, 12)
		ball(hip, 0.088, Vector3(0.008, -0.39, 0), pants, Vector3(1.06, 0.8, 1.0), 28, 18)
		# Two subtle knee creases replace the old blocky joint.
		for c in range(2):
			streak(hip, Vector3(0.0, -0.345 - c * 0.032, -0.073), Vector3(0.0, -0.345 - c * 0.032, 0.073),
				0.004, cloth_d, 10)
		capsule(hip, 0.075, 0.29, Vector3(-0.008, -0.51, 0), pants, Vector3.ZERO, 32, 12)
		ball(hip, 0.089, Vector3(-0.008, -0.585, 0), pants, Vector3(1.06, 0.34, 1.03), 28, 16)
		# Rounded, soft leather shoe with a separate sole, toe cap and laces.
		ball(hip, 0.104, Vector3(0.06, -0.635, 0), shoe, Vector3(1.72, 0.76, 1.02), 36, 22)
		ball(hip, 0.092, Vector3(0.155, -0.63, 0), shoe, Vector3(1.12, 0.7, 0.9), 30, 18)
		ball(hip, 0.11, Vector3(0.055, -0.69, 0), sole, Vector3(1.76, 0.24, 1.0), 36, 20)
		ball(hip, 0.072, Vector3(-0.02, -0.635, 0), shoe, Vector3(0.82, 0.95, 0.78), 24, 14)
		streak(hip, Vector3(0.155, -0.59, -0.082), Vector3(0.155, -0.59, 0.082), 0.0045,
			toon(Color("#6f5a47"), {"outline": false}), 10)
		for l in range(3):
			streak(hip, Vector3(0.02 + l * 0.034, -0.565, -0.062), Vector3(0.02 + l * 0.034, -0.565, 0.062),
				0.0035, toon(Color("#806950"), {"outline": false}), 8)

	rig.torso = pivot(root, Vector3(-0.025, 0.79, 0), "Torso")
	rig.torso.rotation.z = -0.08
	# One continuous jacket volume with a soft chest and tapered waist.
	ball(rig.torso, 0.295, Vector3(0, 0.26, 0), cloth, Vector3(0.78, 0.95, 0.99), 48, 30)
	ball(rig.torso, 0.25, Vector3(0.005, 0.09, 0), cloth_d, Vector3(0.82, 0.62, 0.97), 36, 22)
	# Ragged coat tails break the perfect oval hem and cover the top of the trousers.
	for i in range(5):
		var a := -0.8 + float(i) * 0.4
		var tail := ball(rig.torso, 0.13, Vector3(-0.035 + 0.012 * (i % 2), -0.075 - 0.02 * (i % 2),
			sin(a) * 0.19), cloth_d if i % 2 == 0 else cloth,
			Vector3(0.62, 1.32, 0.56), 24, 14)
		tail.rotation.z = 0.2 * sin(a)
	# Shirt panel, collar and lapels sit proud of the jacket but stay smooth.
	ball(rig.torso, 0.2, Vector3(0.216, 0.315, 0), shirt, Vector3(0.095, 0.76, 0.4), 36, 24)
	tube(rig.torso, 0.126, 0.168, 0.105, Vector3(0, 0.465, 0), cloth_hi, Vector3.ZERO, 36)
	cyl(rig.torso, 0.116, 0.02, Vector3(0, 0.515, 0),
		toon(Color("#25281f"), {"outline": false}), Vector3.ZERO, 32)
	for s in [-1, 1]:
		var lapel := ball(rig.torso, 0.13, Vector3(0.21, 0.295, 0.104 * s),
			cloth_hi, Vector3(0.16, 1.2, 0.44), 28, 18)
		lapel.rotation.x = 0.18 * s
		lapel.rotation.z = -0.1
		# shirt collar wedge
		streak(rig.torso, Vector3(0.222, 0.43, 0.03 * s), Vector3(0.226, 0.31, 0.085 * s),
			0.017, shirt, 12)
		ball(rig.torso, 0.018, Vector3(0.224, 0.35, 0.07 * s), toon(Color("#9d8b70"), {"outline": false}),
			Vector3.ONE, 16, 10)
		for b in range(2):
			ball(rig.torso, 0.014, Vector3(0.232, 0.29 - b * 0.075, 0.04),
				toon(Color("#272920"), {"outline": false}), Vector3(1.0, 0.85, 0.7), 16, 10)
	# tie with a soft knot and a slightly bent blade
	ball(rig.torso, 0.041, Vector3(0.229, 0.41, 0.012), tie, Vector3(1.0, 0.9, 0.72), 28, 18)
	var blade := ball(rig.torso, 0.062, Vector3(0.234, 0.285, 0.012), tie,
		Vector3(0.17, 1.55, 0.56), 28, 20)
	blade.rotation.z = 0.06
	# pocket seams and cloth wrinkles
	for s in [-1, 1]:
		streak(rig.torso, Vector3(0.205, 0.12, 0.13 * s), Vector3(0.212, 0.02, 0.1 * s),
			0.004, cloth_d, 10)
	streak(rig.torso, Vector3(0.208, 0.07, -0.07), Vector3(0.213, 0.16, 0.06), 0.0035, cloth_d, 10)
	streak(rig.torso, Vector3(0.2, 0.2, -0.12), Vector3(0.207, 0.13, -0.04), 0.003, cloth_d, 10)
	# neck and shirt collar close the gap to the head
	capsule(rig.torso, 0.075, 0.26, Vector3(0, 0.48, 0), skin, Vector3.ZERO, 32, 10)
	torus(rig.torso, 0.092, 0.132, Vector3(0, 0.5, 0), shirt, Vector3.ZERO, "Collar")

	rig.arm_l = pivot(root, Vector3(-0.015, 1.13, -0.27), "ArmL")
	rig.arm_r = pivot(root, Vector3(-0.015, 1.13, 0.27), "ArmR")
	for arm in [rig.arm_l, rig.arm_r]:
		arm.rotation.z = 1.35
		# dropped shoulder, elbow and bare forearm
		ball(arm, 0.105, Vector3(0.002, -0.02, 0), cloth, Vector3(0.82, 1.1, 1.0), 32, 20)
		capsule(arm, 0.082, 0.27, Vector3(0, -0.15, 0), cloth, Vector3.ZERO, 32, 12)
		ball(arm, 0.076, Vector3(0, -0.295, 0), cloth_d, Vector3(1.02, 0.58, 1.0), 28, 16)
		# cuff, wrist and hand
		ball(arm, 0.064, Vector3(0, -0.322, 0), shirt, Vector3(0.96, 0.35, 1.0), 28, 16)
		capsule(arm, 0.05, 0.22, Vector3(0, -0.42, 0), skin, Vector3.ZERO, 28, 10)
		ball(arm, 0.058, Vector3(0.002, -0.525, 0), skin, Vector3(1.0, 0.82, 1.0), 28, 16)
		var hand := pivot(arm, Vector3(0.002, -0.55, 0), "Hand")
		ball(hand, 0.061, Vector3(0.008, -0.035, 0), skin, Vector3(1.22, 1.2, 0.72), 32, 20)
		# four articulated fingers plus a thumb, two phalanges each
		for f in range(4):
			var fz := (float(f) - 1.5) * 0.033
			var a := Vector3(0.01, -0.075, fz)
			var b := Vector3(-0.004, -0.122, fz * 1.04)
			var c := Vector3(-0.028, -0.16 + 0.004 * absf(float(f) - 1.5), fz * 0.98)
			streak(hand, a, b, 0.0135, skin, 12)
			streak(hand, b, c, 0.0105, skin_hi, 12)
			ball(hand, 0.014, b, skin, Vector3.ONE, 16, 10)
			ball(hand, 0.0075, c + Vector3(-0.006, -0.003, 0), tooth, Vector3(0.8, 0.35, 0.72), 12, 8)
		var thumb_a := Vector3(0.038, -0.035, 0.062)
		var thumb_b := Vector3(0.018, -0.075, 0.086)
		var thumb_c := Vector3(-0.008, -0.11, 0.084)
		streak(hand, thumb_a, thumb_b, 0.015, skin, 12)
		streak(hand, thumb_b, thumb_c, 0.012, skin_hi, 12)
		ball(hand, 0.007, thumb_c + Vector3(-0.006, -0.002, 0), tooth, Vector3(0.8, 0.35, 0.7), 12, 8)

	# ---- head -------------------------------------------------------------
	rig.head = pivot(root, Vector3(0.035, 1.39, 0), "Head")
	rig.head.rotation.z = -0.08
	# A continuous cranium, cheek planes and jaw are layered with smooth normals.
	ball(rig.head, 0.215, Vector3(-0.015, 0.045, 0), skin, Vector3(1.0, 1.12, 0.95), 48, 32)
	ball(rig.head, 0.16, Vector3(0.035, 0.145, 0), skin_hi, Vector3(1.0, 0.66, 0.92), 40, 26)
	for s in [-1, 1]:
		ball(rig.head, 0.08, Vector3(0.075, 0.015, 0.115 * s), skin,
			Vector3(1.1, 0.72, 0.75), 32, 20)
		# hollow under the cheekbone makes the face feel gaunt without a hard line
		ball(rig.head, 0.065, Vector3(0.166, -0.036, 0.12 * s), skin_d,
			Vector3(0.18, 0.62, 0.58), 28, 18)
	ball(rig.head, 0.145, Vector3(0.055, -0.095, 0), skin, Vector3(1.05, 0.7, 0.94), 40, 26)
	ball(rig.head, 0.068, Vector3(0.135, -0.17, 0), skin_hi, Vector3(1.1, 0.72, 0.84), 28, 18)
	# ears and inner folds
	for s in [-1, 1]:
		ball(rig.head, 0.052, Vector3(-0.005, 0.01, 0.205 * s), skin,
			Vector3(0.42, 1.25, 0.34), 24, 16)
		ball(rig.head, 0.025, Vector3(0.003, 0.012, 0.218 * s), skin_d,
			Vector3(0.38, 1.2, 0.28), 20, 12)
	# nose bridge, bulb and alae
	ball(rig.head, 0.05, Vector3(0.174, 0.03, 0), skin, Vector3(0.58, 1.3, 0.58), 28, 18)
	ball(rig.head, 0.045, Vector3(0.207, -0.025, 0), skin_hi, Vector3(0.86, 0.72, 0.96), 28, 18)
	for s in [-1, 1]:
		ball(rig.head, 0.025, Vector3(0.198, -0.045, 0.032 * s), skin,
			Vector3(0.9, 0.66, 0.72), 20, 12)
		ball(rig.head, 0.009, Vector3(0.223, -0.053, 0.02 * s), skin_deep,
			Vector3(0.62, 0.4, 0.75), 14, 9)
	# eye sockets, drooping lids, sclera/iris/pupil/highlight
	for s in [-1, 1]:
		var eye_y := 0.073 - (0.007 if s < 0 else 0.0)
		ball(rig.head, 0.061, Vector3(0.172, eye_y, 0.083 * s), skin_deep,
			Vector3(0.48, 1.1, 0.96), 28, 18)
		ball(rig.head, 0.036, Vector3(0.193, eye_y, 0.082 * s), sclera,
			Vector3(0.48, 1.0, 0.84), 32, 22)
		ball(rig.head, 0.016, Vector3(0.209, eye_y - 0.002, 0.081 * s), iris,
			Vector3(0.3, 1.0, 1.0), 20, 12)
		ball(rig.head, 0.0105, Vector3(0.214, eye_y - 0.002, 0.079 * s), pupil,
			Vector3.ONE, 16, 10)
		ball(rig.head, 0.0042, Vector3(0.218, eye_y + 0.01, 0.089 * s),
			toon(WHITE, {"outline": false}), Vector3.ONE, 10, 7)
		# heavy upper lid and a narrow lower lid create the tired PvZ stare
		var lid := ball(rig.head, 0.05, Vector3(0.186, eye_y + 0.026, 0.083 * s), skin_d,
			Vector3(0.5, 0.48, 0.96), 28, 18)
		lid.rotation.x = -0.1 * s
		ball(rig.head, 0.038, Vector3(0.189, eye_y - 0.027, 0.083 * s), skin,
			Vector3(0.46, 0.2, 0.93), 24, 14)
		ball(rig.head, 0.042, Vector3(0.184, eye_y - 0.01, 0.083 * s), skin_d,
			Vector3(0.38, 0.24, 0.9), 24, 14)
		# eyebrow made of two smooth tapered strokes
		streak(rig.head, Vector3(0.185, 0.14 + (0.006 if s < 0 else 0.0), 0.035 * s),
			Vector3(0.192, 0.15 + (0.006 if s < 0 else 0.0), 0.078 * s), 0.0075, hair, 12)
		streak(rig.head, Vector3(0.192, 0.15 + (0.006 if s < 0 else 0.0), 0.078 * s),
			Vector3(0.183, 0.145 + (0.006 if s < 0 else 0.0), 0.124 * s), 0.0062, hair, 12)
		# crow's feet and under-eye crease
		streak(rig.head, Vector3(0.2, 0.035, 0.125 * s), Vector3(0.192, 0.02, 0.16 * s),
			0.0022, skin_d, 8)
		streak(rig.head, Vector3(0.2, 0.038, 0.1 * s), Vector3(0.199, 0.013, 0.145 * s),
			0.002, skin_d, 8)
	# forehead and nasolabial creases keep the face from reading as a smooth doll.
	streak(rig.head, Vector3(0.192, 0.165, -0.055), Vector3(0.196, 0.17, 0.055),
		0.0022, skin_d, 8)
	streak(rig.head, Vector3(0.192, 0.142, -0.07), Vector3(0.196, 0.146, 0.07),
		0.0018, skin_d, 8)
	for s in [-1, 1]:
		streak(rig.head, Vector3(0.201, -0.04, 0.03 * s), Vector3(0.205, -0.085, 0.044 * s),
			0.0022, skin_d, 8)
	# mouth cavity, lips, irregular rounded teeth and tongue
	ball(rig.head, 0.095, Vector3(0.214, -0.112, 0), maw, Vector3(0.06, 0.44, 0.94), 36, 22)
	ball(rig.head, 0.093, Vector3(0.2, -0.049, 0), lip, Vector3(0.24, 0.17, 0.96), 28, 18)
	ball(rig.head, 0.094, Vector3(0.2, -0.176, 0), lip, Vector3(0.27, 0.19, 0.92), 28, 18)
	ball(rig.head, 0.04, Vector3(0.19, -0.13, 0), toon(Color("#72454b"), {"outline": false}),
		Vector3(0.35, 0.38, 0.86), 20, 12)
	# three upper and two lower teeth with a clear dark gap between the rows
	for i in range(3):
		var tz := (float(i) - 1.0) * 0.054
		capsule(rig.head, 0.0105, 0.03 - 0.002 * absf(float(i) - 1.0),
			Vector3(0.222, -0.085, tz), tooth, Vector3(0.12 * (i - 1.0), 0, 0.04), 18, 8)
	for i in range(2):
		capsule(rig.head, 0.0095, 0.026,
			Vector3(0.221, -0.151, (float(i) - 0.5) * 0.052), tooth,
			Vector3(0.1 * (i - 0.5), 0, -0.03), 18, 8)
	# a little dried blood at one lip corner
	ball(rig.head, 0.012, Vector3(0.207, -0.179, -0.078), toon(Color("#65464a"), {"outline": false}),
		Vector3(1.0, 0.35, 0.7), 14, 9)
	# sparse strands at the crown and temple sideburns
	for i in range(6):
		var z := -0.105 + float(i) * 0.042
		var a := Vector3(-0.115 + 0.02 * absf(z) / 0.1, 0.21 - 0.1 * absf(z), z)
		var b := Vector3(-0.18, 0.17 - 0.04 * absf(z), z * 1.12)
		streak(rig.head, a, b, 0.0065, hair, 10)
		var c := Vector3(-0.225, 0.13 - 0.05 * absf(z), z * 1.18)
		streak(rig.head, b, c, 0.0045, hair, 8)
	for i in range(4):
		var z := (float(i) - 1.5) * 0.052
		var tuft := ball(rig.head, 0.055, Vector3(-0.095 - 0.03 * absf(float(i) - 1.5),
			0.282 - 0.009 * absf(float(i) - 1.5), z), hair,
			Vector3(0.65, 0.72, 0.5), 24, 16)
		tuft.rotation.z = 0.38
	for s in [-1, 1]:
		streak(rig.head, Vector3(-0.01, 0.075, 0.19 * s), Vector3(-0.03, -0.02, 0.19 * s),
			0.007, hair, 8)

	rig.gear = pivot(rig.head, Vector3(0, 0.06, 0), "Gear")

	match kind:
		"cone":
			var hat_mat := toon(Color("#d97a2b"), {"bands": 4.0, "outline": false,
				"roughness": 0.68, "gloss": 0.11, "pigment": 0.03})
			var hat_dark := toon(Color("#b96220"), {"bands": 3.0, "outline": false,
				"roughness": 0.78, "gloss": 0.06})
			cone(rig.gear, 0.19, 0.36, Vector3(0, 0.2, 0), hat_mat, Vector3.ZERO, 40)
			cyl(rig.gear, 0.2, 0.036, Vector3(0, 0.03, 0), hat_dark, Vector3.ZERO, 40)
			cyl(rig.gear, 0.145, 0.055, Vector3(0, 0.158, 0),
				toon(Color("#e1d3b0"), {"outline": false, "roughness": 0.8}), Vector3.ZERO, 40)
			for i in range(3):
				var a := 0.7 + float(i) * 2.1
				ball(rig.gear, 0.027, Vector3(cos(a) * 0.145, 0.08 + i * 0.035, sin(a) * 0.14),
					hat_dark, Vector3(0.7, 0.38, 0.55), 16, 10)
		"bucket":
			var bucket_mat := toon(Color("#8b979b"), {"bands": 4.0, "outline": false,
				"roughness": 0.42, "gloss": 0.22, "pigment": 0.02})
			var bucket_dark := toon(Color("#677377"), {"bands": 3.0, "outline": false,
				"roughness": 0.55, "gloss": 0.12})
			cyl(rig.gear, 0.19, 0.28, Vector3(0, 0.14, 0), bucket_mat, Vector3.ZERO, 40)
			cyl(rig.gear, 0.205, 0.032, Vector3(0, 0.292, 0), bucket_dark, Vector3.ZERO, 40)
			for i in range(2):
				cyl(rig.gear, 0.194, 0.017, Vector3(0, 0.085 + i * 0.1, 0), bucket_dark, Vector3.ZERO, 40)
			# Three smooth capsules form a dented handle arch over the rim.
			var left := Vector3(-0.17, 0.29, 0)
			var mid := Vector3(0, 0.52, 0)
			var right := Vector3(0.17, 0.29, 0)
			streak(rig.gear, left, mid, 0.012, bucket_dark, 12)
			streak(rig.gear, mid, right, 0.012, bucket_dark, 12)
			for i in range(3):
				var a := 0.6 + float(i) * 2.0
				ball(rig.gear, 0.024, Vector3(cos(a) * 0.175, 0.07 + i * 0.05, sin(a) * 0.17),
					toon(Color("#9a6d43"), {"outline": false}), Vector3(0.65, 0.4, 0.3), 16, 10)
		"football":
			rig.gear.position = Vector3(0.02, 0.04, 0)
			var helmet := toon(Color("#9c2b2b"), {"bands": 4.0, "outline": false,
				"roughness": 0.4, "gloss": 0.22, "pigment": 0.018})
			var pad := toon(Color("#788583"), {"bands": 3.0, "outline": false,
				"roughness": 0.35, "gloss": 0.2})
			var jersey := toon(Color("#8e2727"), {"bands": 4.0, "outline": false,
				"roughness": 0.9, "gloss": 0.03, "pigment": 0.04})
			var dome_mesh := SphereMesh.new()
			dome_mesh.radius = 0.22
			dome_mesh.height = 0.44
			dome_mesh.is_hemisphere = true
			dome_mesh.radial_segments = 40
			dome_mesh.rings = 26
			# crown + rear shell leave a real face opening instead of shrinking
			# the helmet to a skullcap when the head turns.
			put(rig.gear, dome_mesh, helmet, Vector3(-0.015, 0.04, 0), Vector3.ZERO)
			put(rig.gear, dome_mesh, helmet, Vector3(-0.025, 0.025, 0), Vector3(0, 0, PI * 0.5))
			streak(rig.gear, Vector3(-0.15, 0.255, 0), Vector3(0.11, 0.255, 0), 0.017,
				toon(Color("#d8d4c7"), {"outline": false, "roughness": 0.5}), 16)
			for s in [-1, 1]:
				ball(rig.gear, 0.062, Vector3(0.005, -0.02, 0.212 * s), pad,
					Vector3(0.62, 1.0, 0.3), 24, 16)
				streak(rig.gear, Vector3(0.11, 0.015, 0.175 * s), Vector3(0.205, -0.055, 0.115 * s),
					0.011, pad, 12)
				streak(rig.gear, Vector3(0.195, -0.065, 0.11 * s), Vector3(0.272, -0.032, 0.025 * s),
					0.01, pad, 12)
			streak(rig.gear, Vector3(0.272, -0.032, -0.09), Vector3(0.272, -0.032, 0.09),
				0.01, pad, 12)
			streak(rig.gear, Vector3(0.25, -0.09, -0.07), Vector3(0.25, -0.09, 0.07),
				0.009, pad, 12)
			# full jersey covers the suit, with soft shoulder pads and a centre stripe
			ball(rig.torso, 0.312, Vector3(0, 0.26, 0), jersey, Vector3(0.83, 0.92, 0.99), 40, 26)
			tube(rig.torso, 0.13, 0.17, 0.09, Vector3(0, 0.46, 0),
				toon(Color("#d8d4c7"), {"outline": false}), Vector3.ZERO, 32)
			for s in [-1, 1]:
				var shoulder_pad := ball(rig.torso, 0.145, Vector3(0, 0.4, 0.23 * s), jersey,
					Vector3(0.74, 0.38, 0.78), 30, 18)
				shoulder_pad.rotation.x = 0.12 * s
			streak(rig.torso, Vector3(0.252, 0.39, 0), Vector3(0.262, 0.12, 0), 0.012,
				toon(Color("#d8d4c7"), {"outline": false}), 14)
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
			var band_mesh := TorusMesh.new()
			band_mesh.inner_radius = 0.186
			band_mesh.outer_radius = 0.218
			band_mesh.rings = 44
			band_mesh.ring_segments = 8
			put(rig.head, band_mesh, toon(Color("#b23a32"), {"outline": false, "roughness": 0.8}),
				Vector3(0, 0.108, 0))
			rig.arm_l.rotation.z = 1.05
			var staff := pivot(root, Vector3(0.26, 0.05, -0.34), "Pole")
			staff.rotation.z = -0.34
			staff.rotation.x = 0.22
			cyl(staff, 0.026, 2.05, Vector3(0, 0.95, 0), toon(Color("#c9a86a"), {"bands": 3.0, "outline": false}), Vector3.ZERO, 24)
			cyl(staff, 0.034, 0.1, Vector3(0, -0.02, 0), toon(Color("#8a7048"), {"bands": 2.0, "outline": false}), Vector3.ZERO, 24)

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
			# purple suit, wide collar and a sculpted afro
			var suit := toon(Color("#6b4a8f"), {"bands": 4.0, "outline": false,
				"roughness": 0.88, "gloss": 0.03, "pigment": 0.035})
			ball(rig.torso, 0.312, Vector3(0, 0.23, 0), suit, Vector3(0.82, 0.94, 0.97), 40, 26)
			tube(rig.torso, 0.13, 0.18, 0.11, Vector3(0, 0.45, 0), suit, Vector3.ZERO, 36)
			ball(rig.torso, 0.305, Vector3(0, 0.46, 0), toon(Color("#e8e2d0"), {"outline": false}),
				Vector3(0.58, 0.12, 0.9), 32, 18)
			ball(rig.torso, 0.045, Vector3(0.2, 0.39, 0), toon(Color("#c9a55a"), {"outline": false}),
				Vector3(0.5, 0.7, 0.7), 20, 12)
			var afro := toon(Color("#2c2228"), {"bands": 4.0, "outline": false,
				"roughness": 0.82, "gloss": 0.04})
			if kind == "dancer":
				ball(rig.head, 0.235, Vector3(-0.038, 0.145, 0), afro, Vector3(1.12, 0.86, 1.12), 40, 26)
				for i in range(4):
					var a := float(i) * TAU / 4.0 + 0.4
					ball(rig.head, 0.105, Vector3(-0.04 + cos(a) * 0.17, 0.11 + 0.045 * (i % 2),
						sin(a) * 0.17), afro, Vector3(1.0, 0.9, 1.0), 28, 18)
				rig.arm_l.rotation.z = 2.0
				rig.arm_r.rotation.z = 2.0
			else:
				# the backup dancer is the punk twin: mohawk + red headband
				rig.root.scale = Vector3.ONE * 0.94
				var hawk := toon(Color("#d9c04e"), {"bands": 3.0, "outline": false,
					"roughness": 0.8, "gloss": 0.05})
				for i in range(5):
					var t := float(i) / 4.0
					cone(rig.head, 0.042, 0.21 - 0.07 * absf(t - 0.5) * 2.0,
						Vector3(-0.12 + 0.24 * t, 0.28, 0), hawk,
						Vector3(0, 0, 0.62 - 1.24 * t), 6)
				torus(rig.head, 0.188, 0.238, Vector3(-0.02, 0.175, 0),
					toon(Color("#c0392b"), {"bands": 2.0, "outline": false}))

		"gargantuar":
			# he is scaled up whole; the telephone pole is the weapon
			var brute := toon(Color("#6d2f2a"), {"bands": 4.0, "outline": false,
				"roughness": 0.95, "gloss": 0.015, "pigment": 0.045})
			ball(rig.torso, 0.375, Vector3(0, 0.22, 0), brute, Vector3(0.88, 1.0, 1.0), 40, 26)
			capsule(rig.torso, 0.3, 0.13, Vector3(0, 0.1, 0), brute, Vector3.ZERO, 36, 10)
			ball(rig.head, 0.13, Vector3(0.1, -0.11, 0), skin_d, Vector3(1.2, 0.85, 1.05), 32, 20)
			for s2 in [-1, 1]:
				ball(rig.head, 0.052, Vector3(0.218, 0.073, 0.081 * s2),
					toon(Color("#ff7a3c"), {"glow": 2.2, "bands": 1.0, "outline": false}),
					Vector3(1.05, 0.78, 0.96), 20, 12)
			rig.arm_l.rotation.z = 0.6
			rig.arm_r.rotation.z = 0.6
			var club := pivot(root, Vector3(0.34, 0.62, -0.3), "Club")
			club.rotation.z = -0.95
			cyl(club, 0.085, 2.0, Vector3(0, 0.85, 0), toon(Color("#8a6a48"), {"bands": 3.0, "outline": false, "roughness": 0.9}), Vector3.ZERO, 28)
			for i in range(2):
				box(club, Vector3(0.06, 0.05, 0.5), Vector3(0, 1.62 + i * 0.2, 0), toon(Color("#6b5038"), {"outline": false}))
			cyl(club, 0.11, 0.1, Vector3(0, 0.02, 0), toon(Color("#5a4430"), {"outline": false}), Vector3.ZERO, 20)
			# the whole brute is 1.55x the basic zombie � that is his whole point
			root.scale = Vector3.ONE * 1.55

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


## 金币模型：一枚立起来的扁金片（圆柱绕 X 转 90°），正反两面各压一道暗色
## 边环和一枚高光球，让旋转时能看出厚度与金属反光；最后挂一张附加发光贴片
## 作为闪光，取用方通过 meta "spark" 拿到它并自行做旋转/脉冲。
static func coin_model() -> Node3D:
	var root := Node3D.new()
	var gold := toon(Color("#f0c24a"), {"bands": 2.0, "rim": 0.42, "glow": 0.3})
	var rim_d := toon(Color("#c89436"), {"bands": 2.0, "outline": false})
	var shine := toon(Color("#ffe08a"), {"glow": 0.45, "outline": false})
	cyl(root, 0.16, 0.05, Vector3.ZERO, gold, Vector3(PI * 0.5, 0, 0), 16)
	# 正反两面各一道凹进去的暗色边环，侧面看过去才有硬币的厚边
	cyl(root, 0.118, 0.014, Vector3(0, 0, 0.026), rim_d, Vector3(PI * 0.5, 0, 0), 12)
	cyl(root, 0.118, 0.014, Vector3(0, 0, -0.026), rim_d, Vector3(PI * 0.5, 0, 0), 12)
	ball(root, 0.042, Vector3(0, 0, 0.034), shine, Vector3.ONE, 8, 6)
	ball(root, 0.042, Vector3(0, 0, -0.034), shine, Vector3.ONE, 8, 6)
	var spark := quad(root, Vector2(0.42, 0.42), additive(Color(1.0, 0.85, 0.4, 0.16)), Vector3.ZERO, Vector3.ZERO, "Spark")
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("spark", spark)
	return root
