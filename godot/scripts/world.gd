class_name WorldBuilder
extends Node3D

## Builds the whole property — front lawn, house, pool, backyard, street — as
## one continuous space, plus the lighting for each time of day.

const TILE := Data.TILE
const FRONT := Data.FRONT
const BACK := Data.BACK
const HOUSE := Data.HOUSE
const WaterFeedback := preload("res://scripts/water_fx.gd")

var night := false
var water_fx: WaterFX
var _body: StaticBody3D
var _rng := RandomNumberGenerator.new()
var _rrng := RandomNumberGenerator.new()
var _lamps: Array[OmniLight3D] = []
var _picket_spots: Array[Transform3D] = []
var _fire: OmniLight3D
var doors: Array = []
var chimney := {}

const STREET := {
	"walk0": 8.4, "walk1": 9.8,
	"road0": 10.0, "road1": 16.4,
	"far0": 16.6, "far1": 18.0,
}


func build(sky: String) -> void:
	_rng.seed = 20261023
	_rrng.seed = 7
	night = sky == "night"
	_body = StaticBody3D.new()
	_body.name = "Collision"
	add_child(_body)
	_environment(sky)
	_ground()
	_lawns()
	_pool()
	_house()
	_street()
	_fences()
	_scenery()
	_props()
	if night:
		_stars()
	else:
		_clouds()


# --- helpers ---------------------------------------------------------------

func _mat(c: Color, opts := {}) -> ShaderMaterial:
	return Art.toon(c, opts)


func _box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, collide := false) -> MeshInstance3D:
	var mi := Art.box(self, size, pos, mat, rot)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if collide:
		_collide(size, pos, rot)
	return mi


func _cyl(radius: float, height: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, seg := 12, collide := false) -> MeshInstance3D:
	var mi := Art.cyl(self, radius, height, pos, mat, rot, seg)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		cs.shape = sh
		cs.position = pos
		cs.rotation = rot
		_body.add_child(cs)
	return mi


func _collide(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation = rot
	_body.add_child(cs)


func _ramp(size: Vector3, pos: Vector3, rot: Vector3) -> void:
	_collide(size, pos, rot)


# --- environment -----------------------------------------------------------

func _environment(sky: String) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	var sky_node := Sky.new()

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 64.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_fade_start = 0.78
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = 1.1
	sun.shadow_blur = 1.25
	sun.shadow_opacity = 0.92
	sun.light_angular_distance = 1.35

	match sky:
		"dawn":
			sky_mat.sky_top_color = Color("#355679")
			sky_mat.sky_horizon_color = Color("#f2b184")
			sky_mat.ground_horizon_color = Color("#c19573")
			sky_mat.ground_bottom_color = Color("#3d4933")
			sky_mat.sun_angle_max = 12.0
			sky_mat.sky_curve = 0.46
			sun.light_color = Color("#ffd5a6")
			sun.light_energy = 2.25
			sun.rotation_degrees = Vector3(-30, 145, 0)
			env.ambient_light_color = Color("#809ab4")
			env.ambient_light_energy = 0.33
			env.fog_light_color = Color("#e7c3a8")
			env.fog_density = 0.0021
		"noon":
			sky_mat.sky_top_color = Color("#2b5378")
			sky_mat.sky_horizon_color = Color("#b8d4d9")
			sky_mat.ground_horizon_color = Color("#a7b99a")
			sky_mat.ground_bottom_color = Color("#435035")
			sky_mat.sun_angle_max = 17.0
			sky_mat.sky_curve = 0.44
			sun.light_color = Color("#ffe2b0")
			sun.light_energy = 2.35
			sun.rotation_degrees = Vector3(-53, 34, 0)
			env.ambient_light_color = Color("#8ea9bd")
			env.ambient_light_energy = 0.32
			env.fog_light_color = Color("#bbcfd3")
			env.fog_density = 0.00165
		"pool":
			sky_mat.sky_top_color = Color("#35698f")
			sky_mat.sky_horizon_color = Color("#cbe2e5")
			sky_mat.ground_horizon_color = Color("#aec09d")
			sky_mat.ground_bottom_color = Color("#48593b")
			sky_mat.sun_angle_max = 16.0
			sky_mat.sky_curve = 0.43
			sun.light_color = Color("#ffe7bd")
			sun.light_energy = 2.32
			sun.rotation_degrees = Vector3(-40, 118, 0)
			env.ambient_light_color = Color("#98b8c8")
			env.ambient_light_energy = 0.35
			env.fog_light_color = Color("#bed7db")
			env.fog_density = 0.0015
		_:
			sky_mat.sky_top_color = Color("#07101e")
			sky_mat.sky_horizon_color = Color("#1d2d47")
			sky_mat.ground_horizon_color = Color("#202b3b")
			sky_mat.ground_bottom_color = Color("#090d14")
			sky_mat.sun_angle_max = 3.0
			sky_mat.sky_curve = 0.58
			sun.light_color = Color("#acc5ef")
			sun.light_energy = 0.72
			sun.rotation_degrees = Vector3(-42, -140, 0)
			env.ambient_light_color = Color("#35476b")
			env.ambient_light_energy = 0.4
			env.fog_light_color = Color("#111b2a")
			env.fog_density = 0.0062

	sky_node.sky_material = sky_mat
	env.sky = sky_node
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.background_energy_multiplier = 0.86
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95 if night else 0.86
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.24
	env.glow_strength = 0.95
	env.glow_bloom = 0.035
	env.glow_hdr_threshold = 1.02
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 1.45
	env.ssao_intensity = 1.85
	env.ssao_power = 1.55
	env.ssao_detail = 0.72
	env.ssao_light_affect = 0.16
	env.fog_enabled = true
	env.fog_aerial_perspective = 0.0 if sky == "night" else 0.18
	env.fog_sky_affect = 0.72
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.13
	env.adjustment_contrast = 1.09
	env.adjustment_brightness = 1.0

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	add_child(sun)

	# soft bounce from the opposite side so shadows never read as flat black
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_energy = 0.26 if night else 0.25
	fill.light_color = Color("#8eaed1") if not night else Color("#5a79b8")
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-28, -120, 0)
	add_child(fill)


# --- ground ----------------------------------------------------------------

func _ground() -> void:
	var grass_shader := preload("res://shaders/grass.gdshader")
	var gmat := ShaderMaterial.new()
	gmat.shader = grass_shader
	gmat.set_shader_parameter("color_a", Color("#4d7735"))
	gmat.set_shader_parameter("color_b", Color("#3c602b"))
	gmat.set_shader_parameter("color_deep", Color("#2b4722"))
	gmat.set_shader_parameter("dry", Color("#8b9360"))
	gmat.set_shader_parameter("dry_amount", 0.1)
	gmat.set_shader_parameter("cell_shade", 0.028 if night else 0.024)

	# ground is built as four slabs around a hole for the pool, so the water
	# basin can actually sit below grade
	var pz0: float = Data.row_z(BACK, 2) - TILE * 0.5 - 0.2
	var pz1: float = Data.row_z(BACK, 3) + TILE * 0.5 + 0.2
	var px0: float = BACK["x0"] + 0.0
	var px1: float = BACK["x1"] - 0.0
	var x_lo := -74.0
	var x_hi := 46.0
	var z_lo := -60.0
	var z_hi := 60.0
	_ground_slab(Rect2(x_lo, z_lo, x_hi - x_lo, pz0 - z_lo), gmat)
	_ground_slab(Rect2(x_lo, pz1, x_hi - x_lo, z_hi - pz1), gmat)
	_ground_slab(Rect2(x_lo, pz0, px0 - x_lo, pz1 - pz0), gmat)
	_ground_slab(Rect2(px1, pz0, x_hi - px1, pz1 - pz0), gmat)
	_collide(Vector3(160, 0.4, pz0 - z_lo), Vector3(-14, -0.22, (z_lo + pz0) * 0.5))
	_collide(Vector3(160, 0.4, z_hi - pz1), Vector3(-14, -0.22, (z_hi + pz1) * 0.5))
	_collide(Vector3(px0 - x_lo, 0.4, pz1 - pz0), Vector3((x_lo + px0) * 0.5, -0.22, (pz0 + pz1) * 0.5))
	_collide(Vector3(x_hi - px1, 0.4, pz1 - pz0), Vector3((x_hi + px1) * 0.5, -0.22, (pz0 + pz1) * 0.5))


func _ground_slab(r: Rect2, mat: Material) -> void:
	var q := Art.quad(self, r.size, mat, Vector3(r.position.x + r.size.x * 0.5, 0.0, r.position.y + r.size.y * 0.5), Vector3(-PI * 0.5, 0, 0))
	q.name = "Ground"
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# dirt strip under the house and behind the back fence
	_box(Vector3(10.4, 0.04, 13.4), Vector3(-13.1, 0.02, 0), _mat(Color("#8a7a5e")))


func _lawns() -> void:
	var grass_shader := preload("res://shaders/grass.gdshader")
	for side in [FRONT, BACK]:
		var m := ShaderMaterial.new()
		m.shader = grass_shader
		m.set_shader_parameter("color_a", Color("#557f3b") if not night else Color("#3f6633"))
		m.set_shader_parameter("color_b", Color("#40672f") if not night else Color("#33542b"))
		m.set_shader_parameter("color_deep", Color("#2d4e25") if not night else Color("#263f22"))
		m.set_shader_parameter("dry", Color("#929761"))
		m.set_shader_parameter("dry_amount", 0.1)
		m.set_shader_parameter("cell_shade", 0.032)
		var w: float = side["x1"] - side["x0"]
		var cx: float = (side["x0"] + side["x1"]) * 0.5
		var water_rows: Array = side["water_rows"]
		if water_rows.size() == 0:
			var d: float = side["z1"] - side["z0"]
			var cz: float = (side["z0"] + side["z1"]) * 0.5
			var q := Art.quad(self, Vector2(w, d), m, Vector3(cx, 0.012, cz), Vector3(-PI * 0.5, 0, 0))
			q.name = "Lawn_" + str(side["id"])
		else:
			var wz0: float = Data.row_z(side, int(water_rows[0])) - TILE * 0.5
			var wz1: float = Data.row_z(side, int(water_rows[water_rows.size() - 1])) + TILE * 0.5
			var qa := Art.quad(self, Vector2(w, wz0 - float(side["z0"])), m,
				Vector3(cx, 0.012, (float(side["z0"]) + wz0) * 0.5), Vector3(-PI * 0.5, 0, 0))
			qa.name = "Lawn_" + str(side["id"]) + "_a"
			var qb := Art.quad(self, Vector2(w, float(side["z1"]) - wz1), m,
				Vector3(cx, 0.012, (wz1 + float(side["z1"])) * 0.5), Vector3(-PI * 0.5, 0, 0))
			qb.name = "Lawn_" + str(side["id"]) + "_b"
		# thin stone border so the playable grid reads clearly
		var edge := _mat(Color("#b9ac92"))
		_box(Vector3(w + 0.3, 0.06, 0.16), Vector3(cx, 0.02, side["z0"] - 0.08), edge)
		_box(Vector3(w + 0.3, 0.06, 0.16), Vector3(cx, 0.02, side["z1"] + 0.08), edge)


# --- pool ------------------------------------------------------------------

func _pool() -> void:
	var pz0: float = Data.row_z(BACK, 2) - TILE * 0.5
	var pz1: float = Data.row_z(BACK, 3) + TILE * 0.5
	var px0: float = BACK["x0"] + 0.2
	var px1: float = BACK["x1"] - 0.2
	var cx := (px0 + px1) * 0.5
	var cz := (pz0 + pz1) * 0.5
	var w := px1 - px0
	var d := pz1 - pz0
	var surf: float = Data.POOL["surface_y"]

	var cope := _mat(Color("#d5cbb2"), {"roughness": 0.72, "gloss": 0.1})
	var tile := _mat(Color("#78acb9"), {"roughness": 0.5, "gloss": 0.16})
	var deep := _mat(Color("#28657a"), {"roughness": 0.82})

	# coping ring
	_box(Vector3(w + 0.5, 0.1, 0.28), Vector3(cx, 0.01, pz0 - 0.14), cope)
	_box(Vector3(w + 0.5, 0.1, 0.28), Vector3(cx, 0.01, pz1 + 0.14), cope)
	_box(Vector3(0.28, 0.1, d), Vector3(px0 - 0.14, 0.01, cz), cope)
	_box(Vector3(0.28, 0.1, d), Vector3(px1 + 0.14, 0.01, cz), cope)

	# basin
	_box(Vector3(w, 0.1, d), Vector3(cx, Data.POOL["floor_y"], cz), deep)
	_box(Vector3(0.1, 1.5, d), Vector3(px0 + 0.05, -0.72, cz), tile)
	_box(Vector3(0.1, 1.5, d), Vector3(px1 - 0.05, -0.72, cz), tile)
	_box(Vector3(w, 1.5, 0.1), Vector3(cx, -0.72, pz0 + 0.05), tile)
	_box(Vector3(w, 1.5, 0.1), Vector3(cx, -0.72, pz1 - 0.05), tile)
	# water is impassable below wading depth
	_collide(Vector3(w, 0.1, d), Vector3(cx, Data.POOL["wade_y"] - 0.05, cz))

	var wmat := ShaderMaterial.new()
	wmat.shader = preload("res://shaders/water.gdshader")
	wmat.set_shader_parameter("shallow", Color("#45a7b2") if not night else Color("#2f6a7e"))
	wmat.set_shader_parameter("deep", Color("#06475e") if not night else Color("#08283a"))
	wmat.set_shader_parameter("foam", Color("#d9eeee") if not night else Color("#6e95a2"))
	wmat.set_shader_parameter("alpha", 0.84)
	var plane := PlaneMesh.new()
	plane.size = Vector2(w, d)
	plane.subdivide_width = 28
	plane.subdivide_depth = 8
	var water := Art.put(self, plane, wmat, Vector3(cx, surf, cz))
	water.name = "Water"
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_fx = WaterFeedback.new()
	water_fx.name = "WaterFeedback"
	water_fx.surface_y = surf
	add_child(water_fx)

	# steps into the shallow end
	for i in range(3):
		_box(Vector3(1.1, 0.14, 1.2), Vector3(px0 + 0.75, surf - 0.16 - i * 0.28, cz), tile)
	_ramp(Vector3(1.75, 0.12, 1.3), Vector3(px0 + 0.9, -0.23, cz), Vector3(0, 0, 0.34))

	# ladder
	var chrome := _mat(Color("#cfd6da"))
	for side in [-1, 1]:
		_cyl(0.035, 1.1, Vector3(px1 - 0.35, -0.1, cz + side * 0.26), chrome, Vector3.ZERO, 8)
	for i in range(4):
		_cyl(0.03, 0.56, Vector3(px1 - 0.35, -0.5 + i * 0.26, cz), chrome, Vector3(PI * 0.5, 0, 0), 8)

	# diving board
	var board := _box(Vector3(2.2, 0.12, 0.62), Vector3(px0 - 1.5, 0.55, cz), _mat(Color("#e8eef0")))
	board.rotation.z = 0.05
	_box(Vector3(0.4, 0.55, 0.4), Vector3(px0 - 2.4, 0.28, cz), _mat(Color("#b9c2c6")), Vector3.ZERO, true)

	# floats
	var float_cols := [Color("#e0574f"), Color("#f2c14e"), Color("#4f9fd6")]
	for i in range(3):
		var ring := Art.cyl(self, 0.3, 0.1, Vector3(px0 + 1.5 + i * 1.6, surf + 0.02, cz + (-0.5 + i * 0.55)), _mat(float_cols[i], {"rim": 0.4}), Vector3.ZERO, 12)
		ring.scale = Vector3(1.0, 1.0, 0.8)

# --- house -----------------------------------------------------------------

func _house() -> void:
	var hx0: float = HOUSE["x0"]
	var hx1: float = HOUSE["x1"]
	var hz0: float = HOUSE["z0"]
	var hz1: float = HOUSE["z1"]
	var fy: float = HOUSE["floor_y"]
	var wt: float = HOUSE["wall"]
	var sh: float = HOUSE["storey"]
	var cx := (hx0 + hx1) * 0.5
	var cz := (hz0 + hz1) * 0.5
	var w := hx1 - hx0
	var d := hz1 - hz0
	var y2 := fy + sh

	var siding := _mat(Color("#cbb896"))
	var trim := _mat(Color("#f4eddb"))
	var roof := _mat(Color("#6d6070"), {"rim": 0.3})
	var wood := _mat(Color("#a9784c"))
	var glass := _mat(Color("#ffd9a0"), {"glow": 0.55, "rim": 0.6}) if night else _mat(Color("#9fc6d8"), {"rim": 0.5, "glow": 0.08})

	# foundation + ground floor
	_box(Vector3(w, fy, d), Vector3(cx, fy * 0.5, cz), _mat(Color("#b8b0a0")), Vector3.ZERO, true)

	var door_z: float = HOUSE["front_door_z"]
	var door_w := 1.15
	var door_h := 2.1
	var wall_y := fy + sh * 0.5
	# back wall: three pieces around the garden doorway
	var bz: float = HOUSE["back_door_z"]
	var bw := 1.12
	var bh := 2.08
	var bz0 := bz - bw * 0.5
	var bz1 := bz + bw * 0.5
	_box(Vector3(wt, sh, bz0 - hz0), Vector3(hx0 + wt * 0.5, wall_y, (hz0 + bz0) * 0.5), siding, Vector3.ZERO, true)
	_box(Vector3(wt, sh, hz1 - bz1), Vector3(hx0 + wt * 0.5, wall_y, (bz1 + hz1) * 0.5), siding, Vector3.ZERO, true)
	_box(Vector3(wt, sh - bh, bw), Vector3(hx0 + wt * 0.5, fy + bh + (sh - bh) * 0.5, bz), siding, Vector3.ZERO, true)
	# side walls
	_box(Vector3(w - wt * 2, sh, wt), Vector3(cx, wall_y, hz0 + wt * 0.5), siding, Vector3.ZERO, true)
	_box(Vector3(w - wt * 2, sh, wt), Vector3(cx, wall_y, hz1 - wt * 0.5), siding, Vector3.ZERO, true)
	# front wall: three pieces around the doorway
	var fz0: float = door_z - door_w * 0.5
	var fz1: float = door_z + door_w * 0.5
	_box(Vector3(wt, sh, fz0 - hz0), Vector3(hx1 - wt * 0.5, wall_y, (hz0 + fz0) * 0.5), siding, Vector3.ZERO, true)
	_box(Vector3(wt, sh, hz1 - fz1), Vector3(hx1 - wt * 0.5, wall_y, (fz1 + hz1) * 0.5), siding, Vector3.ZERO, true)
	_box(Vector3(wt, sh - door_h, door_w), Vector3(hx1 - wt * 0.5, fy + door_h + (sh - door_h) * 0.5, door_z), siding, Vector3.ZERO, true)

	# exterior belt lines — these were once full-footprint slabs, which buried
	# the plank floors; keep them as thin perimeter strips only
	_band(fy + 0.02, 0.16, cx, cz, w, d, hx0, hx1, hz0, hz1, trim)
	_band(fy + sh - 0.05, 0.18, cx, cz, w, d, hx0, hx1, hz0, hz1, trim)

	# --- second storey: hollow shell so it can actually be lived in --------
	var wy2 := y2 + sh * 0.5
	_box(Vector3(wt, sh, d), Vector3(hx0 + wt * 0.5, wy2, cz), siding, Vector3.ZERO, true)
	_box(Vector3(wt, sh, d), Vector3(hx1 - wt * 0.5, wy2, cz), siding, Vector3.ZERO, true)
	_box(Vector3(w - wt * 2, sh, wt), Vector3(cx, wy2, hz0 + wt * 0.5), siding, Vector3.ZERO, true)
	_box(Vector3(w - wt * 2, sh, wt), Vector3(cx, wy2, hz1 - wt * 0.5), siding, Vector3.ZERO, true)
	_band(y2 + sh - 0.1, 0.2, cx, cz, w, d, hx0, hx1, hz0, hz1, trim)
	for sx in [hx0, hx1]:
		for sz in [hz0, hz1]:
			_box(Vector3(0.22, sh * 2.4, 0.22), Vector3(sx, fy + sh * 1.05, sz), trim)

	_roof(roof, siding, trim)
	_chimney()

	# front door frame + a real, hinged door

	# windows -----------------------------------------------------------------
	for wall in ["front", "back", "left", "right"]:
		var count := 3 if wall in ["front", "back"] else 2
		for i in range(count):
			for floor_i in range(2):
				var wy := fy + 1.45 + floor_i * sh
				var off := (i - (count - 1) * 0.5) * 3.1
				if wall == "front":
					if floor_i == 0 and i == 1:
						continue
					_place_window(Vector3(hx1 + 0.02, wy, door_z + off), Vector3(0, PI * 0.5, 0), glass, trim)
				elif wall == "back":
					if floor_i == 0 and i == count - 1:
						continue
					_place_window(Vector3(hx0 - 0.02, wy, cz + off), Vector3(0, PI * 0.5, 0), glass, trim)
				elif wall == "left":
					_place_window(Vector3(cx + off, wy, hz0 - 0.02), Vector3.ZERO, glass, trim)
				else:
					_place_window(Vector3(cx + off, wy, hz1 + 0.02), Vector3.ZERO, glass, trim)

	# front door frame + a real, hinged door
	_box(Vector3(0.16, door_h + 0.12, 0.14), Vector3(hx1 + 0.04, fy + door_h * 0.5, fz0 - 0.05), trim)
	_box(Vector3(0.16, door_h + 0.12, 0.14), Vector3(hx1 + 0.04, fy + door_h * 0.5, fz1 + 0.05), trim)
	_box(Vector3(0.16, 0.14, door_w + 0.24), Vector3(hx1 + 0.02, fy + door_h + 0.06, door_z), trim)
	_make_door(Vector3(hx1 - 0.15, fy, fz0 + 0.02), door_w - 0.06, door_h - 0.04, "前门", -1.62)

	# garden door: frame + hinged leaf, opening inward against the east wall
	_box(Vector3(0.16, bh + 0.12, 0.14), Vector3(hx0 - 0.04, fy + bh * 0.5, bz0 - 0.05), trim)
	_box(Vector3(0.16, bh + 0.12, 0.14), Vector3(hx0 - 0.04, fy + bh * 0.5, bz1 + 0.05), trim)
	_box(Vector3(0.16, 0.14, bw + 0.24), Vector3(hx0 - 0.02, fy + bh + 0.06, bz), trim)
	# a pane of glass in the leaf so the pool is visible from the sofa
	_make_door(Vector3(hx0 + 0.15, fy, bz0 + 0.02), bw - 0.06, bh - 0.04, "后门", 1.52)

	_porch(trim, wood, siding)
	_deck(trim, wood, siding)
	_interior(wood, trim)
	_upstairs(wood, trim)


func _band(h: float, thick: float, cx: float, cz: float, w: float, d: float,
		hx0: float, hx1: float, hz0: float, hz1: float, mat: Material) -> void:
	_box(Vector3(w + 0.16, thick, 0.16), Vector3(cx, h, hz0 - 0.02), mat)
	_box(Vector3(w + 0.16, thick, 0.16), Vector3(cx, h, hz1 + 0.02), mat)
	_box(Vector3(0.16, thick, d + 0.16), Vector3(hx0 - 0.02, h, cz), mat)
	_box(Vector3(0.16, thick, d + 0.16), Vector3(hx1 + 0.02, h, cz), mat)


# --- roof -------------------------------------------------------------------

func _roof(mat: Material, siding: Material, trim: Material) -> void:
	var hz0: float = HOUSE["z0"]
	var hz1: float = HOUSE["z1"]
	var cx := (HOUSE["x0"] + HOUSE["x1"]) * 0.5
	var w: float = HOUSE["x1"] - HOUSE["x0"]
	var d: float = hz1 - hz0
	var cz := (hz0 + hz1) * 0.5
	var eave := HOUSE["floor_y"] + HOUSE["storey"] * 2.0
	# the chimney straddles the ridge, so each slope is laid in three bands:
	# north of it, the strip it pierces (stopping short of the ridge), south of it
	var cg0 := -6.22
	var cg1 := -4.72
	var gap := 0.92
	for side in [-1.0, 1.0]:
		_roof_band(side, 0.0, hz0 - 0.5, cg0, mat)
		_roof_band(side, gap, cg0, cg1, mat)
		_roof_band(side, 0.0, cg1, hz1 + 0.5, mat)
		_box(Vector3(0.16, 0.28, d + 1.0), Vector3(cx + side * (w * 0.5 + 0.2), eave + 0.02, cz), trim)
	# gable end walls
	for s in [-1, 1]:
		var prism := PrismMesh.new()
		prism.size = Vector3(w, 2.15, 0.24)
		Art.put(self, prism, siding, Vector3(cx, eave + 1.075, cz + s * (d * 0.5 - 0.12)))


func _roof_band(side: float, gap: float, z0: float, z1: float, mat: Material) -> void:
	var w: float = HOUSE["x1"] - HOUSE["x0"]
	var cx := (HOUSE["x0"] + HOUSE["x1"]) * 0.5
	var half := w * 0.5
	var rise := 2.15
	var eave: float = HOUSE["floor_y"] + HOUSE["storey"] * 2.0
	var a := gap
	var b := half + 0.25
	var mid := (a + b) * 0.5
	var run := b - a
	var drp := run / half * rise
	var length := sqrt(run * run + drp * drp)
	var ang := atan2(rise, half)
	var pos := Vector3(cx + side * mid, eave + (half - mid) / half * rise, (z0 + z1) * 0.5)
	var size := Vector3(length, 0.2, z1 - z0)
	var mi := _box(size, pos, mat)
	mi.rotation.z = -side * ang
	_collide(size, pos, Vector3(0, 0, -side * ang))


func _roof_y(x: float) -> float:
	var w: float = HOUSE["x1"] - HOUSE["x0"]
	var cx := (HOUSE["x0"] + HOUSE["x1"]) * 0.5
	var eave: float = HOUSE["floor_y"] + HOUSE["storey"] * 2.0
	var dx: float = abs(x - cx)
	return eave + clamp(1.0 - dx / (w * 0.5), 0.0, 1.0) * 2.15 + 0.11


# --- chimney ----------------------------------------------------------------

func _chimney() -> void:
	var fy: float = HOUSE["floor_y"]
	var y2 := fy + HOUSE["storey"]
	var brick := _mat(Color("#a06d55"))
	var brick_d := _mat(Color("#7a4c38"))
	var soot := _mat(Color("#4a3d36"), {"glow": 0.18})
	var stone := _mat(Color("#8d857a"))
	var x0 := -14.0
	var x1 := -12.2
	var z0 := -6.22
	var z1 := -4.72
	var ix0 := -13.7
	var ix1 := -12.5
	var iz0 := -6.0
	var iz1 := -4.95
	var top := 10.05
	var open_y := y2 + 2.1

	# back + cheeks of the firebox, carried all the way up as the flue walls
	_box(Vector3(x1 - x0, top - y2, iz0 - z0), Vector3((x0 + x1) * 0.5, (y2 + top) * 0.5, (z0 + iz0) * 0.5), brick, Vector3.ZERO, true)
	_box(Vector3(ix0 - x0, top - y2, z1 - iz0), Vector3((x0 + ix0) * 0.5, (y2 + top) * 0.5, (iz0 + z1) * 0.5), brick, Vector3.ZERO, true)
	_box(Vector3(x1 - ix1, top - y2, z1 - iz0), Vector3((ix1 + x1) * 0.5, (y2 + top) * 0.5, (iz0 + z1) * 0.5), brick, Vector3.ZERO, true)
	# breast above the hearth opening
	_box(Vector3(x1 - x0, top - open_y, z1 - iz1), Vector3((x0 + x1) * 0.5, (open_y + top) * 0.5, (iz1 + z1) * 0.5), brick, Vector3.ZERO, true)

	# sooty lining inside the flue, so the climb reads as brick on all sides
	_box(Vector3(x1 - x0 - 0.02, 0.04, iz0 - z0 - 0.02), Vector3((x0 + x1) * 0.5, y2 + 0.05, (z0 + iz0) * 0.5), soot)
	_box(Vector3(ix1 - ix0, open_y - y2 + 0.3, 0.03), Vector3((ix0 + ix1) * 0.5, (y2 + open_y) * 0.5, iz0 + 0.02), soot)
	_box(Vector3(0.03, top - y2, iz1 - iz0), Vector3(ix0 + 0.02, (y2 + top) * 0.5, (iz0 + iz1) * 0.5), soot)
	_box(Vector3(0.03, top - y2, iz1 - iz0), Vector3(ix1 - 0.02, (y2 + top) * 0.5, (iz0 + iz1) * 0.5), soot)

	# brick courses: a shallow band every 0.42 m breaks up the flat faces
	var y := y2 + 0.42
	while y < top - 0.1:
		if y > open_y + 0.2 or y < y2 + 0.05:
			_box(Vector3(x1 - x0 + 0.06, 0.06, z1 - z0 + 0.06), Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5), brick_d)
		y += 0.42

	# crown: a rim round an open flue, so the stack reads as a chimney and not a box
	_box(Vector3(x1 - x0 + 0.22, 0.18, 0.2), Vector3((x0 + x1) * 0.5, top, z0 - 0.01), brick_d)
	_box(Vector3(x1 - x0 + 0.22, 0.18, 0.2), Vector3((x0 + x1) * 0.5, top, z1 + 0.01), brick_d)
	_box(Vector3(0.2, 0.18, z1 - z0 + 0.22), Vector3(x0 - 0.01, top, (z0 + z1) * 0.5), brick_d)
	_box(Vector3(0.2, 0.18, z1 - z0 + 0.22), Vector3(x1 + 0.01, top, (z0 + z1) * 0.5), brick_d)

	# hearth slab + mantel
	_box(Vector3(x1 - x0 + 0.2, 0.07, 0.85), Vector3((x0 + x1) * 0.5, y2 + 0.035, z1 + 0.42), stone, Vector3.ZERO, true)
	_box(Vector3(x1 - x0 + 0.36, 0.14, 0.3), Vector3((x0 + x1) * 0.5, open_y + 0.1, z1 + 0.1), _mat(Color("#8a5f3e")), Vector3.ZERO, true)
	_box(Vector3(x1 - x0 + 0.2, 0.08, 0.16), Vector3((x0 + x1) * 0.5, open_y + 0.02, z1 + 0.02), brick_d)

	# andirons + logs
	for sx in [-13.95, -12.25]:
		_box(Vector3(0.06, 0.32, 0.06), Vector3(sx, y2 + 0.16, z1 - 0.34), _mat(Color("#3a3a3a")))
	var log_mat := _mat(Color("#5d3f28"))
	for i in range(2):
		var lay := Art.cyl(self, 0.075, 0.56, Vector3(-13.35 + i * 0.5, y2 + 0.15, z1 - 0.6), log_mat, Vector3(PI * 0.5, 0, 0), 7)
		lay.rotation.z = 0.04 * (1 - i)
	var top_log := Art.cyl(self, 0.07, 0.6, Vector3(-13.1, y2 + 0.28, z1 - 0.62), log_mat, Vector3(0, 0, PI * 0.5), 7)
	top_log.rotation.y = 0.12

	# an ember glow, plus the only light inside the flue
	var ember := _mat(Color("#ff8a3c"), {"glow": 1.1, "bands": 1.0, "outline": false})
	_box(Vector3(0.58, 0.07, 0.34), Vector3(-13.1, y2 + 0.08, z1 - 0.55), ember)
	_fire = OmniLight3D.new()
	_fire.light_color = Color("#ff9d4d")
	_fire.light_energy = 0.8
	_fire.omni_range = 3.6
	_fire.position = Vector3(-13.1, y2 + 0.55, z1 - 0.3)
	add_child(_fire)

	# daylight falling down the open flue, so the climb is never a black screen
	var shaft := SpotLight3D.new()
	shaft.light_color = Color("#cfe0f2")
	shaft.light_energy = 3.2
	shaft.spot_range = 9.0
	shaft.spot_angle = 34.0
	shaft.spot_attenuation = 0.6
	shaft.position = Vector3(-13.1, top - 0.12, (iz0 + iz1) * 0.5)
	shaft.rotation_degrees = Vector3(-90, 0, 0)
	add_child(shaft)

	chimney = {
		"up": Vector3(-13.1, y2 + 0.6, z1 - 0.1),
		"down": Vector3(-13.1, top - 0.25, z1 - 0.05),
		"flue": Vector3(-13.1, y2 + 0.02, (iz0 + iz1) * 0.5),
		"landing": Vector3(-13.1, _roof_y(-13.1) + 0.02, z1 + 0.44),
		"top_y": top,
	}


func _process(delta: float) -> void:
	if _fire != null and is_instance_valid(_fire):
		var t := Time.get_ticks_msec() * 0.001
		_fire.light_energy = 0.76 + sin(t * 9.0) * 0.07 + sin(t * 21.0) * 0.035


func chimney_look(eye: Vector3, dir: Vector3) -> int:
	if chimney.is_empty():
		return 0
	if eye.y < 6.0:
		var pt: Vector3 = chimney["up"]
		var to := pt - eye
		if to.length() < 2.7 and to.normalized().dot(dir) > 0.5:
			return 1
	elif eye.y > 7.4:
		var pt: Vector3 = chimney["down"]
		var to := pt - eye
		if to.length() < 3.4 and to.normalized().dot(dir) > 0.28:
			return -1
	return 0


func chimney_path(dir: int) -> Array:
	var flue: Vector3 = chimney["flue"]
	var landing: Vector3 = chimney["landing"]
	var mouth := Vector3(flue.x, flue.y + 0.05, flue.z + 0.55)
	var lip: float = chimney["top_y"] - 0.62
	var over := Vector3(flue.x, lip, landing.z)
	var throat := Vector3(flue.x, lip, flue.z)
	if dir > 0:
		return [mouth, Vector3(flue.x, flue.y + 0.1, flue.z), throat, over, landing]
	return [Vector3(over.x, over.y + 0.14, over.z), throat, Vector3(flue.x, flue.y + 0.1, flue.z), mouth]


# --- doors -----------------------------------------------------------------

func _make_door(pos: Vector3, door_w: float, door_h: float, label: String, open_a: float, style := "wood") -> HouseDoor:
	var door := HouseDoor.new()
	door.position = pos
	door.label = label
	door.open_angle = open_a
	door.width = door_w
	add_child(door)

	var pivot := Node3D.new()
	door.add_child(pivot)
	door.pivot = pivot

	if style == "gate":
		var slat := _mat(Color("#e6ddc6"))
		var bar := _mat(Color("#dcd2b8"))
		var n := int((door_w - 0.12) / 0.15)
		for i in range(n):
			var z1 := 0.09 + i * 0.15
			Art.box(pivot, Vector3(0.035, door_h - 0.04, 0.08), Vector3(0, door_h * 0.5, z1), slat)
		Art.box(pivot, Vector3(0.05, 0.08, door_w - 0.04), Vector3(0, door_h - 0.12, door_w * 0.5), bar)
		Art.box(pivot, Vector3(0.05, 0.08, door_w - 0.04), Vector3(0, 0.16, door_w * 0.5), bar)
		var brace := Art.box(pivot, Vector3(0.045, 0.06, sqrt(door_w * door_w + door_h * door_h) * 0.94),
			Vector3(0, door_h * 0.5, door_w * 0.5), bar)
		brace.rotation.x = atan2(door_h - 0.28, door_w - 0.06)
		Art.ball(pivot, 0.04, Vector3(0.05, door_h * 0.6, door_w - 0.14), _mat(Color("#8a8f92"), {"rim": 0.5}), Vector3.ONE, 6, 4)
	else:
		var wood := _mat(Color("#8a5a3c"))
		var inset := _mat(Color("#7a4d33"), {"outline": false})
		var panel_size := Vector3(0.07, door_h, door_w)
		Art.box(pivot, panel_size, Vector3(0, door_h * 0.5, door_w * 0.5), wood)
		Art.box(pivot, Vector3(0.09, door_h * 0.34, door_w - 0.3), Vector3(0, door_h * 0.74, door_w * 0.5), inset)
		Art.box(pivot, Vector3(0.09, door_h * 0.34, door_w - 0.3), Vector3(0, door_h * 0.26, door_w * 0.5), inset)
		Art.ball(pivot, 0.05, Vector3(0.08, 1.0, door_w - 0.16), _mat(Color("#d8b25a"), {"rim": 0.6}), Vector3.ONE, 8, 6)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.12, door_h, door_w)
	cs.shape = sh
	cs.position = Vector3(0, door_h * 0.5, door_w * 0.5)
	body.add_child(cs)
	pivot.add_child(body)
	door.body = body
	doors.append(door)
	return door


func door_in_view(eye: Vector3, dir: Vector3, reach := 3.2) -> HouseDoor:
	var best: HouseDoor = null
	var best_d := reach
	for d in doors:
		if not is_instance_valid(d):
			continue
		var p: Vector3 = d.global_transform * Vector3(0, 1.05, d.width * 0.5)
		var to := p - eye
		var dist := to.length()
		if dist > best_d:
			continue
		if to.normalized().dot(dir) < 0.86:
			continue
		best_d = dist
		best = d
	return best


func _place_window(pos: Vector3, rot: Vector3, glass: Material, trim: Material) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot.y
	add_child(g)
	Art.box(g, Vector3(1.25, 1.55, 0.08), Vector3.ZERO, glass)
	Art.box(g, Vector3(1.45, 0.14, 0.14), Vector3(0, 0.85, 0), trim)
	Art.box(g, Vector3(1.45, 0.14, 0.14), Vector3(0, -0.85, 0), trim)
	Art.box(g, Vector3(0.12, 1.75, 0.12), Vector3(-0.66, 0, 0), trim)
	Art.box(g, Vector3(0.12, 1.75, 0.12), Vector3(0.66, 0, 0), trim)
	Art.box(g, Vector3(0.07, 1.55, 0.1), Vector3(0, 0, 0.01), trim)
	Art.box(g, Vector3(1.25, 0.07, 0.1), Vector3(0, 0, 0.01), trim)
	if night:
		var l := OmniLight3D.new()
		l.light_color = Color("#ffc477")
		l.light_energy = 1.6
		l.omni_range = 4.0
		l.position = Vector3(0.6, 0, 0)
		g.add_child(l)
		_lamps.append(l)


func _porch(trim: Material, wood: Material, dark: Material) -> void:
	var p: Dictionary = HOUSE["porch"]
	var px0: float = p["x0"]
	var px1: float = p["x1"]
	var pz0: float = p["z0"]
	var pz1: float = p["z1"]
	var fy: float = HOUSE["floor_y"]
	var cz := (pz0 + pz1) * 0.5
	var cx := (px0 + px1) * 0.5
	var w := px1 - px0
	var d := pz1 - pz0

	_box(Vector3(w, 0.16, d), Vector3(cx, fy - 0.08, cz), wood, Vector3.ZERO, true)
	# steps down to the lawn
	for i in range(3):
		var y := fy - 0.15 - i * 0.15
		_box(Vector3(0.34, 0.16, d * 0.7), Vector3(px1 + 0.17 + i * 0.34, y, cz), wood)
	# ramp collider over the steps
	_ramp(Vector3(1.75, 0.12, d * 0.7), Vector3(px1 + 0.5, 0.23, cz), Vector3(0, 0, -0.303))

	# columns + porch roof
	for sz in [pz0 + 0.25, pz1 - 0.25]:
		_cyl(0.11, 2.45, Vector3(px1 - 0.18, fy + 1.22, sz), trim, Vector3.ZERO, 10, true)
	_box(Vector3(w + 0.5, 0.18, d + 0.5), Vector3(cx + 0.1, fy + 2.5, cz), trim)
	var pr := _box(Vector3(slope_of(w + 0.8, 0.35), 0.16, d + 0.8), Vector3(cx + 0.1, fy + 2.72, cz), _mat(Color("#7a6272")))
	pr.rotation.z = -0.12

	# railing
	for sz in [pz0 + 0.06, pz1 - 0.06]:
		_box(Vector3(w - 0.3, 0.09, 0.09), Vector3(cx, fy + 0.95, sz), trim)
		for i in range(6):
			_box(Vector3(0.06, 0.9, 0.06), Vector3(px0 + 0.15 + i * (w - 0.3) / 5.0, fy + 0.45, sz), trim)

	# porch light
	var lamp := Art.ball(self, 0.1, Vector3(px1 - 0.45, fy + 2.2, cz), _mat(Color("#ffd48a"), {"glow": 1.2, "bands": 1.0}))
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ol := OmniLight3D.new()
	ol.light_color = Color("#ffc879")
	ol.light_energy = 2.4 if night else 0.5
	ol.omni_range = 7.0
	ol.position = Vector3(px1 - 0.45, fy + 2.15, cz)
	add_child(ol)


func slope_of(run: float, rise: float) -> float:
	return sqrt(run * run + rise * rise)


func _deck(trim: Material, wood: Material, dark: Material) -> void:
	# a low deck between the garden door and the pool, with the stair heading
	# west through a gate in the back fence
	var dx0 := -19.9
	var dx1: float = HOUSE["x0"]
	var dz0 := -1.6
	var dz1 := 4.25
	var fy: float = HOUSE["floor_y"]
	var cx := (dx0 + dx1) * 0.5
	var cz := (dz0 + dz1) * 0.5
	var gz := HOUSE["back_door_z"]
	var gw := 1.2

	_box(Vector3(dx1 - dx0, 0.16, dz1 - dz0), Vector3(cx, fy - 0.08, cz), wood, Vector3.ZERO, true)
	# skirt boards
	_box(Vector3(dx1 - dx0, 0.3, 0.09), Vector3(cx, fy - 0.24, dz0 + 0.05), dark)
	_box(Vector3(dx1 - dx0, 0.3, 0.09), Vector3(cx, fy - 0.24, dz1 - 0.05), dark)
	_box(Vector3(0.09, 0.3, dz1 - dz0), Vector3(dx1 - 0.05, fy - 0.24, cz), dark)

	# two steps down to the lawn, with one sloped collider under the visuals
	for i in range(2):
		var top: float = fy - (i + 1) * (fy / 3.0)
		var sx: float = dx0 - 0.32 * (i + 1)
		_box(Vector3(0.34, top, gw + 0.14), Vector3(sx + 0.17, top * 0.5, gz), wood)
	_ramp(Vector3(0.98, 0.12, gw + 0.14), Vector3(dx0 - 0.4, fy * 0.5 - 0.02, gz), Vector3(0, 0, 0.52))

	# railings on the open sides
	for sz in [dz0 + 0.06, dz1 - 0.06]:
		_box(Vector3(dx1 - dx0, 0.09, 0.09), Vector3(cx, fy + 0.92, sz), trim)
		_box(Vector3(dx1 - dx0, 0.07, 0.07), Vector3(cx, fy + 0.42, sz), trim)
		for i in range(6):
			_box(Vector3(0.06, 0.9, 0.06), Vector3(dx0 + 0.12 + i * (dx1 - dx0 - 0.24) / 5.0, fy + 0.45, sz), trim)

	# stepping stones from the stair to the pool coping
	var stones := [
		Vector2(-20.75, 3.15), Vector2(-20.9, 2.7), Vector2(-20.75, 2.25), Vector2(-20.45, 1.95),
	]
	for i in range(stones.size()):
		var p: Vector2 = stones[i]
		var st := _box(Vector3(0.56, 0.05, 0.44), Vector3(p.x, 0.02, p.y), _mat(Color("#b9b2a2")))
		st.rotation.y = 0.3 * i

	# deck chairs looking at the water
	_deck_chair(Vector3(cx - 0.35, fy, cz - 1.5), 1.35)
	_deck_chair(Vector3(cx + 0.25, fy, cz - 0.2), 1.75)

	# drinks table
	_cyl(0.06, 0.46, Vector3(dx1 - 0.35, fy + 0.23, cz - 0.85), dark, Vector3.ZERO, 8)
	_cyl(0.3, 0.06, Vector3(dx1 - 0.35, fy + 0.48, cz - 0.85), _mat(Color("#e8e2cf")), Vector3.ZERO, 12)
	_cyl(0.05, 0.14, Vector3(dx1 - 0.4, fy + 0.58, cz - 0.9), _mat(Color("#7fb2d6"), {"rim": 0.5}), Vector3.ZERO, 8)


func _deck_chair(pos: Vector3, yaw: float) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = yaw
	add_child(g)
	var frame := _mat(Color("#b9a98a"))
	var cushion := _mat(Color("#6f9aa8"))
	# frame + cushion, so it reads as a lounger and not a white board
	Art.box(g, Vector3(0.66, 0.07, 0.66), Vector3(0, 0.41, 0), frame)
	Art.box(g, Vector3(0.58, 0.1, 0.58), Vector3(0, 0.46, 0), cushion)
	var back := Art.box(g, Vector3(0.66, 0.66, 0.08), Vector3(0, 0.73, -0.31), frame, Vector3(0.2, 0, 0))
	Art.box(g, Vector3(0.56, 0.54, 0.09), Vector3(0, 0.74, -0.26), cushion, Vector3(0.2, 0, 0))
	for sx in [-0.27, 0.27]:
		for sz in [-0.27, 0.27]:
			Art.box(g, Vector3(0.06, 0.38, 0.06), Vector3(sx, 0.19, sz), frame)
	# a folded towel over the back
	Art.box(g, Vector3(0.5, 0.14, 0.1), Vector3(0, 0.95, -0.28), _mat(Color("#e8e2cf")), Vector3(0.2, 0, 0))


func _interior(wood: Material, trim: Material) -> void:
	var hx0: float = HOUSE["x0"]
	var hx1: float = HOUSE["x1"]
	var hz0: float = HOUSE["z0"]
	var hz1: float = HOUSE["z1"]
	var fy: float = HOUSE["floor_y"]
	var wt: float = HOUSE["wall"]
	var ix0 := hx0 + wt
	var ix1 := hx1 - wt
	var iz0 := hz0 + wt
	var iz1 := hz1 - wt
	var cx := (ix0 + ix1) * 0.5
	var cz := (iz0 + iz1) * 0.5

	# plank floor (the foundation box is the collider)
	_box(Vector3(ix1 - ix0, 0.06, iz1 - iz0), Vector3(cx, fy + 0.01, cz), _mat(Color("#8a6242")))
	_box(Vector3(3.6, 0.02, 2.6), Vector3(cx + 1.2, fy + 0.06, cz + 1.0), _mat(Color("#8c5a5a")))

	# sofa against the west wall, south of the stairs
	var sofa := _mat(Color("#5e7f6a"))
	var sx := ix0 + 2.5
	_box(Vector3(0.9, 0.42, 2.0), Vector3(sx, fy + 0.28, cz + 1.6), sofa, Vector3.ZERO, true)
	_box(Vector3(0.32, 0.6, 2.0), Vector3(sx - 0.42, fy + 0.66, cz + 1.6), sofa)
	_box(Vector3(0.9, 0.5, 0.22), Vector3(sx, fy + 0.5, cz + 0.64), sofa)
	_box(Vector3(0.9, 0.5, 0.22), Vector3(sx, fy + 0.5, cz + 2.56), sofa)
	for i in range(2):
		_box(Vector3(0.16, 0.34, 0.34), Vector3(sx - 0.05, fy + 0.66, cz + 1.3 + i * 0.7), _mat(Color("#7fa08a")))

	# coffee table
	_box(Vector3(1.4, 0.09, 0.8), Vector3(cx + 1.9, fy + 0.42, cz + 1.6), wood)
	for sx2 in [1.3, 2.5]:
		for sz2 in [1.3, 1.9]:
			_box(Vector3(0.08, 0.42, 0.08), Vector3(cx + sx2, fy + 0.21, cz + sz2), wood)
	_box(Vector3(0.2, 0.05, 0.28), Vector3(cx + 1.9, fy + 0.49, cz + 1.55), _mat(Color("#d9d3c2")))

	# TV on the east wall
	_box(Vector3(0.5, 0.6, 1.7), Vector3(ix1 - 0.25, fy + 0.3, cz + 1.6), _mat(Color("#5a4a3c")), Vector3.ZERO, true)
	_box(Vector3(0.08, 0.9, 1.5), Vector3(ix1 - 0.52, fy + 1.35, cz + 1.6), _mat(Color("#20232a")))
	_box(Vector3(0.03, 0.78, 1.36), Vector3(ix1 - 0.57, fy + 1.35, cz + 1.6), _mat(Color("#4b6f8a"), {"glow": 0.5}))

	# kitchen along the south wall
	var cm := _mat(Color("#d9cdb6"))
	_box(Vector3(3.4, 0.9, 0.66), Vector3(cx + 2.2, fy + 0.45, iz1 - 0.33), cm, Vector3.ZERO, true)
	_box(Vector3(3.5, 0.08, 0.72), Vector3(cx + 2.2, fy + 0.93, iz1 - 0.33), _mat(Color("#4a4a4a")))
	_box(Vector3(3.4, 0.5, 0.02), Vector3(cx + 2.2, fy + 1.5, iz1 - 0.06), _mat(Color("#e8e2d2")))
	_box(Vector3(1.8, 0.9, 0.9), Vector3(cx + 1.4, fy + 0.45, iz0 + 1.8), cm, Vector3.ZERO, true)
	_box(Vector3(1.9, 0.08, 1.0), Vector3(cx + 1.4, fy + 0.93, iz0 + 1.8), _mat(Color("#4a4a4a")))
	for i in range(2):
		_box(Vector3(0.34, 0.06, 0.34), Vector3(cx + 1.0 + i * 0.9, fy + 1.0, iz0 + 1.8), _mat(Color("#7fa8c0"), {"rim": 0.5}))

	# wall art on the north wall (the west wall is taken by the stairs)
	_box(Vector3(1.0, 0.7, 0.06), Vector3(cx + 0.4, fy + 1.8, iz0 + 0.05), _mat(Color("#c98f4e")))
	_box(Vector3(0.8, 0.5, 0.06), Vector3(cx + 0.4, fy + 1.8, iz0 + 0.06), _mat(Color("#7fa8c0")))

	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffe3c2")
	lamp.light_energy = 1.8 if night else 0.55
	lamp.omni_range = 8.0
	lamp.position = Vector3(cx, fy + 2.4, cz + 1.2)
	add_child(lamp)
	var bulb := Art.ball(self, 0.1, Vector3(cx, fy + 2.5, cz + 1.2), _mat(Color("#ffe6b0"), {"glow": 1.4, "bands": 1.0}))
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cyl(0.02, 0.35, Vector3(cx, fy + 2.7, cz + 1.2), _mat(Color("#3a3a3a")), Vector3.ZERO, 6)

	# cool daylight spilling in from the front windows
	var day_win := OmniLight3D.new()
	day_win.light_color = Color("#cfe2f5")
	day_win.light_energy = 0.0 if night else 0.95
	day_win.omni_range = 8.0
	day_win.position = Vector3(ix1 - 1.3, fy + 1.9, cz + 2.7)
	add_child(day_win)


# --- upstairs --------------------------------------------------------------

func _upstairs(wood: Material, trim: Material) -> void:
	var hx0: float = HOUSE["x0"]
	var hx1: float = HOUSE["x1"]
	var hz0: float = HOUSE["z0"]
	var hz1: float = HOUSE["z1"]
	var fy: float = HOUSE["floor_y"]
	var wt: float = HOUSE["wall"]
	var ix0 := hx0 + wt
	var ix1 := hx1 - wt
	var iz0 := hz0 + wt
	var iz1 := hz1 - wt
	var cx := (ix0 + ix1) * 0.5
	var cz := (iz0 + iz1) * 0.5
	var y2 := fy + HOUSE["storey"]
	var plank := _mat(Color("#8f6743"))
	var ceil_mat := _mat(Color("#ded4bd"))
	var rail_mat := _mat(Color("#8a5a3a"))

	# floor slab, with a stairwell opening against the west wall
	var ox0 := ix0
	var ox1 := -15.95
	var oz0 := -2.55
	var oz1 := 2.25
	_box(Vector3(ix1 - ix0, 0.12, oz0 - iz0), Vector3(cx, y2 - 0.06, (iz0 + oz0) * 0.5), plank, Vector3.ZERO, true)
	_box(Vector3(ix1 - ix0, 0.12, iz1 - oz1), Vector3(cx, y2 - 0.06, (oz1 + iz1) * 0.5), plank, Vector3.ZERO, true)
	_box(Vector3(ix1 - ox1, 0.12, oz1 - oz0), Vector3((ox1 + ix1) * 0.5, y2 - 0.06, (oz0 + oz1) * 0.5), plank, Vector3.ZERO, true)
	# ceiling of the upper floor, split round the chimney flue
	var chx0 := -14.0
	var chx1 := -12.2
	var chz1 := -4.72
	var ceil_y := y2 + HOUSE["storey"] - 0.08
	_box(Vector3(chx0 - ix0, 0.1, iz1 - iz0), Vector3((ix0 + chx0) * 0.5, ceil_y, cz), ceil_mat, Vector3.ZERO, true)
	_box(Vector3(ix1 - chx1, 0.1, iz1 - iz0), Vector3((chx1 + ix1) * 0.5, ceil_y, cz), ceil_mat, Vector3.ZERO, true)
	_box(Vector3(chx1 - chx0, 0.1, iz1 - chz1), Vector3((chx0 + chx1) * 0.5, ceil_y, (chz1 + iz1) * 0.5), ceil_mat, Vector3.ZERO, true)

	# --- staircase -----------------------------------------------------
	var steps := 13
	var sx0 := ix0
	var sx1 := ox1
	var sz0 := -2.4
	var sz1 := 2.1
	var rise := (y2 - fy) / steps
	var tread := (sz1 - sz0) / steps
	var scx := (sx0 + sx1) * 0.5
	var sw := sx1 - sx0
	var step_mat := _mat(Color("#9a6b40"))
	var tread_mat := _mat(Color("#c99a63"))
	for i in range(steps):
		var h := rise * (i + 1)
		var z := sz0 + tread * (i + 0.5)
		_box(Vector3(sw, h, tread + 0.02), Vector3(scx, fy + h * 0.5, z), step_mat)
		_box(Vector3(sw + 0.04, 0.045, tread + 0.06), Vector3(scx, fy + h - 0.02, z + 0.01), tread_mat)
	# one sloped collider over the whole flight — rock solid underfoot
	var run := sz1 - sz0
	var rise_total := y2 - fy
	var ang := atan2(rise_total, run)
	var length := sqrt(run * run + rise_total * rise_total) + 0.3
	_collide(Vector3(sw, 0.12, length), Vector3(scx, (fy + y2) * 0.5 - 0.05, (sz0 + sz1) * 0.5), Vector3(-ang, 0, 0))

	# handrail bolted to the wall, so it never fights the upstairs railing
	length = length * 0.92
	for i in range(4):
		var t := i / 3.0
		var z: float = lerp(sz0 + 0.3, sz1 - 0.3, t)
		var y: float = lerp(fy, y2, t) + 0.52
		_box(Vector3(0.06, 1.02, 0.06), Vector3(sx0 + 0.09, y, z), rail_mat)
	var rail := _box(Vector3(0.07, 0.07, length), Vector3(sx0 + 0.09, (fy + y2) * 0.5 + 0.95, (sz0 + sz1) * 0.5), rail_mat)
	rail.rotation.x = -ang

	# railing around the stairwell upstairs
	for i in range(4):
		var z: float = lerp(oz0 + 0.12, oz1 - 0.12, i / 3.0)
		_box(Vector3(0.08, 1.0, 0.08), Vector3(ox1 + 0.06, y2 + 0.5, z), trim)
	_box(Vector3(0.09, 0.09, oz1 - oz0), Vector3(ox1 + 0.06, y2 + 1.0, (oz0 + oz1) * 0.5), trim)

	# --- furniture ------------------------------------------------------
	# bed in the north-west corner
	var bed_x := -15.35
	var bed_z := -4.75
	_box(Vector3(1.45, 0.28, 2.15), Vector3(bed_x, y2 + 0.14, bed_z), wood, Vector3.ZERO, true)
	_box(Vector3(1.32, 0.24, 2.0), Vector3(bed_x, y2 + 0.4, bed_z), _mat(Color("#e8e2cf")))
	_box(Vector3(1.36, 0.16, 1.25), Vector3(bed_x, y2 + 0.52, bed_z + 0.36), _mat(Color("#6f8fa8")))
	_box(Vector3(0.62, 0.14, 0.38), Vector3(bed_x, y2 + 0.55, bed_z - 0.78), _mat(Color("#f6f1e2")))
	_box(Vector3(1.45, 0.7, 0.12), Vector3(bed_x, y2 + 0.35, bed_z - 1.12), wood)
	# nightstand + lamp
	_box(Vector3(0.5, 0.55, 0.5), Vector3(bed_x + 1.0, y2 + 0.27, bed_z - 0.9), wood, Vector3.ZERO, true)
	_cyl(0.03, 0.28, Vector3(bed_x + 1.0, y2 + 0.68, bed_z - 0.9), _mat(Color("#3a3a3a")), Vector3.ZERO, 6)
	Art.ball(self, 0.12, Vector3(bed_x + 1.0, y2 + 0.86, bed_z - 0.9), _mat(Color("#ffe6b0"), {"glow": 1.2, "bands": 1.0}), Vector3(1.0, 0.8, 1.0), 8, 6)

	# desk under the north window
	var desk_x := -11.2
	var desk_z := -5.55
	_box(Vector3(1.7, 0.08, 0.72), Vector3(desk_x, y2 + 0.76, desk_z), wood, Vector3.ZERO, true)
	for sx2 in [-0.76, 0.76]:
		for sz2 in [-0.28, 0.28]:
			_box(Vector3(0.07, 0.76, 0.07), Vector3(desk_x + sx2, y2 + 0.38, desk_z + sz2), wood)
	_box(Vector3(0.05, 0.34, 0.46), Vector3(desk_x + 0.2, y2 + 0.98, desk_z - 0.1), _mat(Color("#2d3138")))
	_box(Vector3(0.32, 0.46, 0.42), Vector3(desk_x - 0.55, y2 + 0.55, desk_z + 0.62), _mat(Color("#5e7f6a")), Vector3.ZERO, true)

	# bookshelf on the east wall
	var bs_x := ix1 - 0.28
	var bs_z := 3.4
	_box(Vector3(0.4, 1.9, 1.7), Vector3(bs_x, y2 + 0.95, bs_z), wood, Vector3.ZERO, true)
	for i in range(4):
		_box(Vector3(0.36, 0.05, 1.6), Vector3(bs_x, y2 + 0.2 + i * 0.55, bs_z), _mat(Color("#8a6644")))
		var cols := [Color("#a84a3c"), Color("#4f7c9c"), Color("#7a9464"), Color("#c9a24e")]
		for j in range(5):
			_box(Vector3(0.26, 0.34, 0.11), Vector3(bs_x + 0.03, y2 + 0.42 + i * 0.55, bs_z - 0.62 + j * 0.28), _mat(cols[(i + j) % 4]))

	# rug
	_box(Vector3(3.2, 0.02, 2.4), Vector3(cx + 1.4, y2 + 0.02, cz + 1.2), _mat(Color("#7d6b8f")))

	# wardrobe against the south wall
	var wd_x := -11.4
	var wd_z := iz1 - 0.34
	_box(Vector3(2.0, 2.1, 0.62), Vector3(wd_x, y2 + 1.05, wd_z), wood, Vector3.ZERO, true)
	for s in [-1, 1]:
		_box(Vector3(0.94, 1.92, 0.05), Vector3(wd_x + s * 0.5, y2 + 1.06, wd_z - 0.33), _mat(Color("#9a7048")))
		Art.ball(self, 0.035, Vector3(wd_x + s * 0.09, y2 + 1.05, wd_z - 0.37), _mat(Color("#d8b25a"), {"rim": 0.6}), Vector3.ONE, 6, 4)
	_box(Vector3(2.1, 0.1, 0.7), Vector3(wd_x, y2 + 2.14, wd_z), wood)

	# bench at the foot of the bed
	var bench := _mat(Color("#5e7f6a"))
	_box(Vector3(1.35, 0.14, 0.48), Vector3(bed_x, y2 + 0.42, bed_z + 1.35), bench, Vector3.ZERO, true)
	for sx3 in [-0.55, 0.55]:
		_box(Vector3(0.08, 0.4, 0.08), Vector3(bed_x + sx3, y2 + 0.2, bed_z + 1.35), wood)

	# pictures on the east wall
	_box(Vector3(0.06, 0.85, 1.2), Vector3(ix1 - 0.04, y2 + 1.85, cz - 2.4), _mat(Color("#c98f4e")))
	_box(Vector3(0.05, 0.66, 1.0), Vector3(ix1 - 0.06, y2 + 1.85, cz - 2.4), _mat(Color("#6f8fa8")))
	_box(Vector3(0.06, 0.6, 0.8), Vector3(ix1 - 0.04, y2 + 1.8, cz + 4.0), _mat(Color("#a84a3c")))

	# floor lamp in the south-east corner of the hall
	_cyl(0.04, 1.7, Vector3(-15.4, y2 + 0.85, 4.2), _mat(Color("#3a3a3a")), Vector3.ZERO, 6)
	_box(Vector3(0.5, 0.34, 0.5), Vector3(-15.4, y2 + 1.78, 4.2), _mat(Color("#f0e6c8"), {"glow": 0.5}))
	var fl := OmniLight3D.new()
	fl.light_color = Color("#ffcf8f")
	fl.light_energy = 1.8 if night else 0.5
	fl.omni_range = 8.0
	fl.position = Vector3(-15.4, y2 + 1.8, 4.2)
	add_child(fl)

	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffe3c2")
	lamp.light_energy = 1.7 if night else 0.5
	lamp.omni_range = 12.0
	lamp.position = Vector3(cx, y2 + 2.35, cz)
	add_child(lamp)

	var day_win := OmniLight3D.new()
	day_win.light_color = Color("#cfe2f5")
	day_win.light_energy = 0.0 if night else 0.9
	day_win.omni_range = 8.5
	day_win.position = Vector3(cx + 0.8, y2 + 1.9, cz + 2.9)
	add_child(day_win)


# --- street ----------------------------------------------------------------

func _street() -> void:
	var walk := _mat(Color("#cfc7b5"))
	var road := _mat(Color("#4c4f55"))
	var curb := _mat(Color("#b7b0a0"))
	var z0 := -30.0
	var z1 := 30.0

	_box(Vector3(STREET["walk1"] - STREET["walk0"], 0.16, z1 - z0),
		Vector3((STREET["walk0"] + STREET["walk1"]) * 0.5, 0.06, 0), walk)
	_box(Vector3(STREET["far1"] - STREET["far0"], 0.16, z1 - z0),
		Vector3((STREET["far0"] + STREET["far1"]) * 0.5, 0.06, 0), walk)
	_box(Vector3(STREET["road1"] - STREET["road0"], 0.12, z1 - z0),
		Vector3((STREET["road0"] + STREET["road1"]) * 0.5, 0.03, 0), road)
	_box(Vector3(0.2, 0.19, z1 - z0), Vector3(STREET["road0"] - 0.02, 0.08, 0), curb)
	_box(Vector3(0.2, 0.19, z1 - z0), Vector3(STREET["road1"] + 0.02, 0.08, 0), curb)

	# dashed centre line
	var line := _mat(Color("#d8c96a"))
	for i in range(16):
		_box(Vector3(0.16, 0.02, 1.5), Vector3((STREET["road0"] + STREET["road1"]) * 0.5, 0.1, -26.0 + i * 3.4), line)

	# driveway from the road to the house side
	_box(Vector3(STREET["walk0"] - 7.2, 0.14, 3.6), Vector3((7.2 + STREET["walk0"]) * 0.5, 0.05, 5.6), walk)

	# flagstone path along the fence, outside the planting grid
	_box(Vector3(6.0, 0.12, 1.0), Vector3(4.0, 0.05, 4.45), walk)


# --- fences ----------------------------------------------------------------

func _fences() -> void:
	var picket := _mat(Color("#e6ddc6"))
	var post := _mat(Color("#e0d7c0"))
	var z_edge := 4.85
	_picket_spots.clear()
	_fence_run(Vector3(-7.2, 0, -z_edge), Vector3(8.4, 0, -z_edge), picket, post)
	_fence_run(Vector3(-7.2, 0, z_edge), Vector3(8.4, 0, z_edge), picket, post)
	_fence_run(Vector3(8.4, 0, -z_edge), Vector3(8.4, 0, z_edge), picket, post)
	# the back fence is broken by a gate at the foot of the deck stair
	_fence_run(Vector3(-19.9, 0, -4.8), Vector3(-19.9, 0, 2.72), picket, post)
	_fence_run(Vector3(-19.9, 0, 3.98), Vector3(-19.9, 0, 4.8), picket, post)
	_fence_run(Vector3(-35.4, 0, -5.6), Vector3(-19.9, 0, -5.6), picket, post)
	_fence_run(Vector3(-35.4, 0, 5.6), Vector3(-19.9, 0, 5.6), picket, post)
	_fence_run(Vector3(-35.4, 0, -5.6), Vector3(-35.4, 0, 5.6), picket, post)
	_build_pickets(picket)
	_back_gate(post)

	# gate posts by the driveway
	for z in [3.7, 7.5]:
		_box(Vector3(0.24, 1.7, 0.24), Vector3(8.4, 0.85, z), post, Vector3.ZERO, true)
		Art.ball(self, 0.12, Vector3(8.4, 1.78, z), _mat(Color("#d8cfb8")), Vector3.ONE, 8, 6)


func _fence_run(a: Vector3, b: Vector3, picket: Material, post: Material) -> void:
	var seg_len := a.distance_to(b)
	var yaw := atan2(b.x - a.x, b.z - a.z)
	var n := int(seg_len / 0.34)
	for i in range(n):
		var t := (i + 0.5) / float(n)
		_picket_spots.append(Transform3D(Basis(Vector3.UP, yaw), a.lerp(b, t) + Vector3(0, 0.62, 0)))
	# rails
	var mid := a.lerp(b, 0.5)
	_box(Vector3(seg_len, 0.09, 0.05), mid + Vector3(0, 0.95, 0), picket, Vector3(0, yaw + PI * 0.5, 0))
	_box(Vector3(seg_len, 0.09, 0.05), mid + Vector3(0, 0.3, 0), picket, Vector3(0, yaw + PI * 0.5, 0))
	_collide(Vector3(seg_len + 0.2, 1.3, 0.14), mid + Vector3(0, 0.65, 0), Vector3(0, yaw + PI * 0.5, 0))
	# posts
	var posts := int(seg_len / 2.4)
	for i in range(posts + 1):
		var p := a.lerp(b, float(i) / max(1, posts))
		_box(Vector3(0.14, 1.35, 0.14), p + Vector3(0, 0.67, 0), post)


func _build_pickets(mat: Material) -> void:
	# one MultiMesh for every picket keeps the draw count sane
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.9, 0.05)
	mm.mesh = bm
	mm.instance_count = _picket_spots.size()
	for i in range(_picket_spots.size()):
		mm.set_instance_transform(i, _picket_spots[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.name = "Pickets"
	add_child(mmi)


func _back_gate(post: Material) -> void:
	var trim := _mat(Color("#efeadb"))
	# taller gate posts, slightly proud of the fence line
	for z in [2.72, 3.98]:
		_box(Vector3(0.18, 2.32, 0.18), Vector3(-19.9, 1.16, z), post, Vector3.ZERO, true)
		_box(Vector3(0.24, 0.1, 0.24), Vector3(-19.9, 2.3, z), trim)
	# an arbour beam across, with a lantern for the night levels
	_box(Vector3(0.12, 0.12, 1.5), Vector3(-19.9, 2.34, 3.35), post)
	_box(Vector3(0.16, 0.08, 1.6), Vector3(-19.9, 2.42, 3.35), trim)
	var lamp := Art.ball(self, 0.08, Vector3(-19.9, 2.14, 3.35), _mat(Color("#ffd48a"), {"glow": 1.1, "bands": 1.0}))
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if night:
		var ol := OmniLight3D.new()
		ol.light_color = Color("#ffc879")
		ol.light_energy = 1.6
		ol.omni_range = 6.0
		ol.position = Vector3(-19.9, 2.05, 3.35)
		add_child(ol)
	# the gate itself: shut by default, so it reads as a gate — [E] swings it
	var gate := _make_door(Vector3(-19.9, 0.06, 2.78), 1.06, 1.02, "后院栅栏门", 1.42, "gate")
	gate.set_open(false, false)


func _clouds() -> void:
	var mat := _mat(Color("#ffffff"), {"bands": 2.0, "rim": 0.5, "outline": false, "glow": 1.5})
	var dark := _mat(Color("#f2f7fb"), {"bands": 2.0, "outline": false, "glow": 1.15})
	for i in range(10):
		var ang := _rng.randf() * TAU
		var rad := _rng.randf_range(72.0, 118.0)
		var base := Vector3(cos(ang) * rad - 14.0, _rng.randf_range(34.0, 52.0), sin(ang) * rad)
		var s := _rng.randf_range(1.2, 2.1)
		for j in range(4):
			var off := Vector3((j - 1.5) * 5.4 * s, _rng.randf_range(-0.6, 0.9), _rng.randf_range(-1.6, 1.6))
			var b := Art.ball(self, 3.2 * s, base + off, mat if j % 2 == 0 else dark, Vector3(1.9, 0.4, 1.1), 8, 6)
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _stars() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#dfe8ff")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.9
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.55)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = 220
	for i in range(220):
		var a := _rrng.randf() * TAU
		var el := _rrng.randf_range(0.12, 1.4)
		var r := 90.0
		var p := Vector3(cos(a) * cos(el) * r, sin(el) * r, sin(a) * cos(el) * r)
		var sc := _rrng.randf_range(0.5, 1.7)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sc, sc, sc)), p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# --- scenery ---------------------------------------------------------------

func _scenery() -> void:
	# trees around the property
	var trees := [
		Vector3(-5.6, 0, 6.4), Vector3(4.4, 0, 7.2), Vector3(-22.5, 0, 7.6),
		Vector3(-30.0, 0, 7.4), Vector3(-37.5, 0, 3.0), Vector3(-22.0, 0, -7.4),
		Vector3(-31.5, 0, -7.8), Vector3(12.5, 0, 9.4), Vector3(12.8, 0, -8.6),
		Vector3(20.0, 0, 4.0), Vector3(21.5, 0, -6.0),
	]
	for t in trees:
		_tree(t, _rng.randf_range(0.85, 1.25))

	# hedges along the fence
	for i in range(14):
		_bush(Vector3(-7.0 + i * 1.15, 0, 4.55), 0.5)
	for i in range(12):
		_bush(Vector3(-34.6 + i * 1.25, 0, -5.25), 0.55)
	for i in range(10):
		_bush(Vector3(-34.9, 0, -4.2 + i * 1.0), 0.55)

	# flower beds by the porch
	var cols := [Color("#e8697d"), Color("#f2c14e"), Color("#c88ce0"), Color("#f5f0e2")]
	for i in range(22):
		var side := -1 if i % 2 == 0 else 1
		var p := Vector3(-7.6 + _rng.randf_range(-0.4, 0.4), 0, side * _rng.randf_range(1.4, 2.9))
		_flower(p, cols[i % cols.size()])

	# lamp posts along the sidewalk
	for z in [-9.0, 9.0]:
		_lamp_post(Vector3(9.3, 0, z))

	# mailbox
	var mb := _mat(Color("#3f4b57"))
	_cyl(0.05, 1.1, Vector3(8.9, 0.55, 3.0), mb, Vector3.ZERO, 8, true)
	_box(Vector3(0.36, 0.3, 0.5), Vector3(8.9, 1.2, 3.0), _mat(Color("#c0563f")))
	_box(Vector3(0.38, 0.04, 0.52), Vector3(8.9, 1.36, 3.0), _mat(Color("#a8482f")))


func _tree(pos: Vector3, s: float) -> void:
	var bark := _mat(Color("#76573b"), {"bands": 3.0, "roughness": 0.95})
	var bark_hi := _mat(Color("#8b6a49"), {"bands": 2.0, "roughness": 0.95})
	_cyl(0.16 * s, 1.7 * s, pos + Vector3(0, 0.85 * s, 0), bark, Vector3.ZERO, 8, true)
	# Two visible limbs break up the lollipop silhouette.
	for side in [-1, 1]:
		_cyl(0.07 * s, 0.85 * s, pos + Vector3(side * 0.28 * s, 1.55 * s, 0.08 * s),
			bark if side < 0 else bark_hi, Vector3(0, 0, side * 0.72), 7)
	var leaf_dark := _mat(Color("#315f35"), {"bands": 3.0, "rim": 0.24})
	var leaf_mid := _mat(Color("#447c3d"), {"bands": 3.0, "rim": 0.28})
	var leaf_hi := _mat(Color("#5b934a"), {"bands": 3.0, "rim": 0.32})
	for i in range(7):
		var a := TAU * float(i) / 7.0 + 0.45
		var r := (0.44 + 0.26 * float(i % 3)) * s
		var y := (1.9 + 0.28 * float(i % 2) + 0.2 * sin(a * 2.0)) * s
		var p := pos + Vector3(cos(a) * r, y, sin(a) * r * 0.82)
		var leaf_mat := leaf_dark if i % 3 == 0 else (leaf_mid if i % 3 == 1 else leaf_hi)
		var radius := (0.7 + 0.12 * float(i % 2)) * s
		var mi := Art.ball(self, radius, p, leaf_mat, Vector3(1.06, 0.78, 1.02), 11, 7)
		mi.rotation.y = a
	# A sunlit cap makes the canopy read as layered foliage rather than one blob.
	Art.ball(self, 0.82 * s, pos + Vector3(-0.12 * s, 2.62 * s, -0.14 * s),
		leaf_hi, Vector3(1.18, 0.72, 1.1), 11, 7)
	for i in range(3):
		var a := 0.8 + float(i) * 2.05
		Art.ball(self, 0.5 * s, pos + Vector3(cos(a) * 0.72 * s, 2.2 * s, sin(a) * 0.56 * s),
			leaf_mid, Vector3(1.15, 0.72, 1.0), 9, 6)


func _bush(pos: Vector3, s: float) -> void:
	var tones := [
		_mat(Color("#3d7136"), {"bands": 3.0, "rim": 0.24}),
		_mat(Color("#4e8842"), {"bands": 3.0, "rim": 0.28}),
		_mat(Color("#60964d"), {"bands": 3.0, "rim": 0.3}),
	]
	for i in range(5):
		var sway := sin(float(i) * 2.1 + pos.x * 0.35)
		var p := pos + Vector3((i - 2.0) * 0.24 * s + sway * 0.045,
			0.27 * s + (i % 2) * 0.11 + sway * 0.025,
			sin(float(i) * 1.7 + pos.z) * 0.12)
		var mi := Art.ball(self, (0.32 + (i % 3) * 0.06) * s, p, tones[i % tones.size()],
			Vector3(1.05, 0.82 + 0.04 * (i % 2), 0.94), 9, 6)
		mi.rotation.y = float(i) * 0.9


func _flower(pos: Vector3, col: Color) -> void:
	var stem := _mat(Color("#4f8a3c"), {"outline": false})
	_cyl(0.012, 0.28, pos + Vector3(0, 0.14, 0), stem, Vector3.ZERO, 4)
	var petal := _mat(col, {"bands": 2.0, "outline": false})
	for i in range(5):
		var a := TAU * float(i) / 5.0 + pos.x * 0.6
		Art.ball(self, 0.032, pos + Vector3(cos(a) * 0.034, 0.315, sin(a) * 0.034),
			petal, Vector3(1.1, 0.42, 0.82), 7, 5)
	Art.ball(self, 0.02, pos + Vector3(0, 0.337, 0), _mat(Color("#e8be5d"), {"outline": false}),
		Vector3(1.0, 0.55, 1.0), 6, 4)


func _lamp_post(pos: Vector3) -> void:
	var metal := _mat(Color("#3e4650"))
	_cyl(0.06, 3.0, pos + Vector3(0, 1.5, 0), metal, Vector3.ZERO, 8, true)
	_cyl(0.16, 0.12, pos + Vector3(0, 0.06, 0), metal, Vector3.ZERO, 8)
	var head := Art.box(self, Vector3(0.3, 0.34, 0.3), pos + Vector3(0, 3.1, 0), _mat(Color("#ffd48a"), {"glow": 1.1 if night else 0.35, "bands": 1.0}))
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(0.4, 0.1, 0.4), pos + Vector3(0, 3.3, 0), metal)
	var l := OmniLight3D.new()
	l.light_color = Color("#ffca8a")
	l.light_energy = 3.0 if night else 0.6
	l.omni_range = 9.0
	l.position = pos + Vector3(0, 3.0, 0)
	add_child(l)


func _props() -> void:
	# garden gnome near the porch — a small reward for looking down
	var gnome := Node3D.new()
	gnome.position = Vector3(-6.9, 0, 2.4)
	gnome.rotation.y = -1.9
	add_child(gnome)
	var red := _mat(Color("#c23b32"))
	var skin := _mat(Color("#e8b48a"))
	Art.ball(gnome, 0.13, Vector3(0, 0.2, 0), red, Vector3(1.0, 1.4, 1.0), 8, 6)
	Art.ball(gnome, 0.09, Vector3(0, 0.36, 0), skin, Vector3.ONE, 8, 6)
	Art.cone(gnome, 0.1, 0.22, Vector3(0, 0.5, 0), red, Vector3.ZERO, 8)
	Art.box(gnome, Vector3(0.1, 0.14, 0.14), Vector3(0.02, 0.3, 0), _mat(Color("#f2f0e6")))

	# hose reel on the house wall
	_cyl(0.26, 0.16, Vector3(-8.1, 0.5, 4.2), _mat(Color("#5d7f5a")), Vector3(0, 0, PI * 0.5), 12, true)

	# pool toys, a bucket and a watering can add scale
	_box(Vector3(0.28, 0.26, 0.28), Vector3(-6.4, 0.13, -2.6), _mat(Color("#7d9bb5")), Vector3(0, 0.4, 0))
