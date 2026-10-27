class_name TabletopDecor
extends Node3D
## Décor « soirée jeu de rôle au salon » : le plateau est posé sur une table en bois
## sous une suspension qui l'éclaire ; autour, chaises, tapis, parquet, bibliothèque
## et fenêtre de nuit, dans la pénombre. La table reste libre : compteurs, dés et
## cartes du jeu viendront s'y poser.
##
## Échelle : 1 unité = une case = environ 2,5 cm (un pouce, comme une grille de
## figurines). Purement visuel : ne lit ni ne modifie le GameState. Construit autour
## des limites du plateau reçues de BoardView (signal board_built).

## Graine fixe : le décor est identique à chaque partie.
const DECOR_SEED := 1984
## Dessus de la table (le plateau en bois est posé dessus, les cases à y = 0).
const TABLE_TOP := -0.55
const TABLE_SIZE := Vector2(46.0, 30.0)
const TABLE_THICKNESS := 1.6
## Hauteur de table d'environ 75 cm.
const FLOOR_Y := TABLE_TOP - 30.0
const ROOM_HALF := Vector2(70.0, 55.0)
const CEILING_Y := FLOOR_Y + 100.0

const WOOD_SHADER := """
shader_type spatial;
uniform vec3 light_wood : source_color;
uniform vec3 dark_wood : source_color;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float grain_scale = 1.0;
uniform float plank_width = 0.0;
uniform float roughness_value = 0.45;
varying vec3 world_pos;
varying vec3 world_normal;

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Fil du bois le long de x ; sur les faces verticales en x, on prend z.
	vec2 p = abs(world_normal.x) > 0.7 ? world_pos.zy : (abs(world_normal.z) > 0.7 ? world_pos.xy : world_pos.xz);
	p /= grain_scale;
	float tint = 0.0;
	float seam = 0.0;
	if (plank_width > 0.0) {
		float row = floor(p.y / plank_width);
		float along = p.x + hash(row) * 40.0;
		float joint = floor(along / 24.0);
		tint = hash(row * 7.0 + joint) - 0.5;
		float edge_y = abs(fract(p.y / plank_width) - 0.5) * 2.0;
		float edge_x = abs(fract(along / 24.0) - 0.5) * 2.0;
		seam = max(smoothstep(0.96, 1.0, edge_y), smoothstep(0.995, 1.0, edge_x));
		p.x = along + row * 13.0;
	}
	float warp = texture(noise_tex, vec2(p.x * 0.004, p.y * 0.05)).r;
	float rings = sin((p.y + warp * 6.0) * 9.0) * 0.5 + 0.5;
	float streak = texture(noise_tex, vec2(p.x * 0.002, p.y * 0.9)).r;
	float g = clamp(rings * 0.55 + streak * 0.6 - 0.1, 0.0, 1.0);
	vec3 c = mix(dark_wood, light_wood, g);
	c *= 1.0 + tint * 0.25;
	c = mix(c, dark_wood * 0.35, seam);
	ALBEDO = c;
	ROUGHNESS = roughness_value + streak * 0.15;
}
"""

## Tapis : fond bordeaux, bordures dorées et motif central.
const RUG_SHADER := """
shader_type spatial;
uniform vec3 field : source_color = vec3(0.32, 0.07, 0.07);
uniform vec3 border : source_color = vec3(0.6, 0.45, 0.2);
uniform vec3 dark : source_color = vec3(0.12, 0.05, 0.05);
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float edge = max(d.x, d.y);
	vec3 c = field;
	c = mix(c, border, step(0.82, edge) * (1.0 - step(0.88, edge)));
	c = mix(c, dark, step(0.88, edge) * (1.0 - step(0.95, edge)));
	c = mix(c, border, step(0.95, edge));
	float diamond = d.x + d.y;
	c = mix(c, border, step(0.55, diamond) * (1.0 - step(0.6, diamond)));
	c = mix(c, dark, (1.0 - step(0.3, diamond)) * 0.6);
	float fibers = fract(sin(dot(floor(UV * 400.0), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = c * (0.9 + fibers * 0.15);
	ROUGHNESS = 1.0;
}
"""

var _rng := RandomNumberGenerator.new()
var _mats: Dictionary = {}
var _noise_tex: NoiseTexture2D


## Construit la scène autour de [param bounds] (AABB des cases du plateau).
func build(bounds: AABB) -> void:
	for child in get_children():
		child.queue_free()
	_rng.seed = DECOR_SEED
	var center := bounds.get_center()
	position = Vector3(center.x, 0.0, center.z)
	var half := Vector2(bounds.size.x * 0.5, bounds.size.z * 0.5)

	_build_board_tray(half)
	_build_table()
	_build_lamp()
	_build_room()


# --- Plateau, table et lumière -----------------------------------------------------

## Plateau de jeu en bois foncé sous les dalles, avec un rebord.
func _build_board_tray(half: Vector2) -> void:
	var walnut := _wood("walnut", Color(0.32, 0.19, 0.11), Color(0.16, 0.09, 0.05), 0.4, 0.35)
	var top := -0.05
	var depth := top - TABLE_TOP
	_add(_box(Vector3(half.x * 2 + 1.4, depth, half.y * 2 + 1.4)), walnut, Vector3(0, TABLE_TOP + depth * 0.5, 0))
	var rim_w := 0.4
	var rim_h := 0.22
	var ox := half.x + 0.7 - rim_w * 0.5
	var oz := half.y + 0.7 - rim_w * 0.5
	for s: float in [-1.0, 1.0]:
		_add(_box(Vector3(half.x * 2 + 1.4, rim_h, rim_w)), walnut, Vector3(0, top + rim_h * 0.5, s * oz))
		_add(_box(Vector3(rim_w, rim_h, half.y * 2 + 1.4 - rim_w * 2)), walnut, Vector3(s * ox, top + rim_h * 0.5, 0))


func _build_table() -> void:
	var oak := _wood("oak", Color(0.55, 0.36, 0.2), Color(0.3, 0.17, 0.08), 1.0, 0.35)
	_add(_box(Vector3(TABLE_SIZE.x, TABLE_THICKNESS, TABLE_SIZE.y)), oak, Vector3(0, TABLE_TOP - TABLE_THICKNESS * 0.5, 0))
	# Ceinture sous le plateau et pieds.
	var apron_y := TABLE_TOP - TABLE_THICKNESS - 1.5
	_add(_box(Vector3(TABLE_SIZE.x - 6, 3.0, 0.8)), oak, Vector3(0, apron_y, TABLE_SIZE.y * 0.5 - 2.5))
	_add(_box(Vector3(TABLE_SIZE.x - 6, 3.0, 0.8)), oak, Vector3(0, apron_y, -TABLE_SIZE.y * 0.5 + 2.5))
	var leg_h := TABLE_TOP - TABLE_THICKNESS - FLOOR_Y
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_add(_box(Vector3(2.2, leg_h, 2.2)), oak,
				Vector3(sx * (TABLE_SIZE.x * 0.5 - 3.0), FLOOR_Y + leg_h * 0.5, sz * (TABLE_SIZE.y * 0.5 - 3.0)))


## Suspension au-dessus de la table : la lumière principale de la scène.
func _build_lamp() -> void:
	var metal := _mat("lamp_metal", Color(0.08, 0.08, 0.07), 0.4, 0.8)
	var y := TABLE_TOP + 26.0
	var shade := CylinderMesh.new()
	shade.top_radius = 1.2
	shade.bottom_radius = 6.0
	shade.height = 4.0
	shade.radial_segments = 32
	shade.cap_bottom = false
	var shade_mat := _mat("lamp_shade", Color(0.12, 0.2, 0.16), 0.5, 0.6)
	shade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add(shade, shade_mat, Vector3(0, y, 0))
	var cord := CylinderMesh.new()
	cord.top_radius = 0.08
	cord.bottom_radius = 0.08
	cord.height = CEILING_Y - y
	_add(cord, metal, Vector3(0, y + cord.height * 0.5, 0))
	var bulb := SphereMesh.new()
	bulb.radius = 1.0
	bulb.height = 2.0
	var bulb_mat := _mat("bulb", Color(1, 0.9, 0.7), 0.3)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.8, 0.55)
	bulb_mat.emission_energy_multiplier = 6.0
	_add(bulb, bulb_mat, Vector3(0, y - 1.2, 0))

	var spot := SpotLight3D.new()
	spot.position = Vector3(0, y - 1.5, 0)
	spot.rotation = Vector3(-PI / 2, 0, 0)
	spot.light_color = Color(1.0, 0.84, 0.64)
	spot.light_energy = 9.0
	spot.spot_range = 60.0
	spot.spot_angle = 52.0
	spot.spot_angle_attenuation = 0.6
	spot.spot_attenuation = 0.4
	spot.shadow_enabled = true
	spot.shadow_blur = 1.5
	add_child(spot)
	# Un peu de lumière renvoyée vers le haut et la pièce, pour ne pas être dans le noir.
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, y - 3.0, 0)
	fill.light_color = Color(1.0, 0.8, 0.6)
	fill.light_energy = 0.6
	fill.omni_range = 70.0
	fill.omni_attenuation = 1.5
	add_child(fill)


# --- La pièce ----------------------------------------------------------------------

func _build_room() -> void:
	var floor_wood := _wood("floor", Color(0.42, 0.27, 0.15), Color(0.2, 0.11, 0.06), 1.6, 0.55, 5.0)
	var floor := PlaneMesh.new()
	floor.size = ROOM_HALF * 2.0
	_add(floor, floor_wood, Vector3(0, FLOOR_Y, 0))
	var ceiling := PlaneMesh.new()
	ceiling.size = ROOM_HALF * 2.0
	ceiling.flip_faces = true
	_add(ceiling, _mat("ceiling", Color(0.5, 0.47, 0.42), 1.0), Vector3(0, CEILING_Y, 0))

	var rug_shader := Shader.new()
	rug_shader.code = RUG_SHADER
	var rug_mat := ShaderMaterial.new()
	rug_mat.shader = rug_shader
	_add(_box(Vector3(TABLE_SIZE.x + 30, 0.15, TABLE_SIZE.y + 30)), rug_mat, Vector3(0, FLOOR_Y + 0.075, 0))

	# Murs : papier peint vert sombre, plinthes en bois.
	var wall := _mat("wall", Color(0.2, 0.25, 0.21), 0.95)
	var skirting := _wood("skirting", Color(0.3, 0.18, 0.1), Color(0.18, 0.1, 0.05), 0.5, 0.5)
	var h := CEILING_Y - FLOOR_Y
	for s: float in [-1.0, 1.0]:
		_add(_box(Vector3(ROOM_HALF.x * 2, h, 1.0)), wall, Vector3(0, FLOOR_Y + h * 0.5, s * ROOM_HALF.y))
		_add(_box(Vector3(1.0, h, ROOM_HALF.y * 2)), wall, Vector3(s * ROOM_HALF.x, FLOOR_Y + h * 0.5, 0))
		_add(_box(Vector3(ROOM_HALF.x * 2, 4.0, 1.6)), skirting, Vector3(0, FLOOR_Y + 2.0, s * (ROOM_HALF.y - 0.3)))
		_add(_box(Vector3(1.6, 4.0, ROOM_HALF.y * 2)), skirting, Vector3(s * (ROOM_HALF.x - 0.3), FLOOR_Y + 2.0, 0))

	_build_chairs()
	_build_bookshelf(Vector3(0, FLOOR_Y, -ROOM_HALF.y + 7.0))
	_build_window(Vector3(-ROOM_HALF.x + 0.6, FLOOR_Y + 45.0, -10.0))


func _build_chairs() -> void:
	var wood := _wood("chair", Color(0.4, 0.25, 0.13), Color(0.2, 0.11, 0.05), 0.6, 0.45)
	var seat_y := FLOOR_Y + 18.0
	var spots := [
		[Vector3(-10, 0, TABLE_SIZE.y * 0.5 + 5), 0.0], [Vector3(10, 0, TABLE_SIZE.y * 0.5 + 5), 0.0],
		[Vector3(-10, 0, -TABLE_SIZE.y * 0.5 - 5), PI], [Vector3(10, 0, -TABLE_SIZE.y * 0.5 - 5), PI],
		[Vector3(TABLE_SIZE.x * 0.5 + 6, 0, 0), PI / 2],
	]
	for spot: Array in spots:
		var root := _group(Vector3(spot[0].x, seat_y, spot[0].z), Vector3(0, spot[1] + _rng.randf_range(-0.15, 0.15), 0))
		_add(_box(Vector3(16, 1.5, 16)), wood, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, root)
		_add(_box(Vector3(16, 20, 1.5)), wood, Vector3(0, 10.75, 7.25), Vector3.ZERO, Vector3.ONE, root)
		for lx: float in [-7.0, 7.0]:
			for lz: float in [-7.0, 7.0]:
				_add(_box(Vector3(1.4, 18, 1.4)), wood, Vector3(lx, -9.0, lz), Vector3.ZERO, Vector3.ONE, root)


func _build_bookshelf(at: Vector3) -> void:
	var wood := _wood("shelf", Color(0.3, 0.18, 0.1), Color(0.15, 0.08, 0.04), 0.6, 0.5)
	var w := 44.0
	var h := 72.0
	var d := 11.0
	_add(_box(Vector3(w, h, 1.0)), wood, at + Vector3(0, h * 0.5, -d * 0.5))
	for s: float in [-1.0, 1.0]:
		_add(_box(Vector3(1.5, h, d)), wood, at + Vector3(s * w * 0.5, h * 0.5, 0))
	var colors := [Color(0.45, 0.1, 0.08), Color(0.12, 0.2, 0.35), Color(0.18, 0.3, 0.15), Color(0.5, 0.38, 0.15),
		Color(0.25, 0.12, 0.25), Color(0.6, 0.55, 0.45), Color(0.1, 0.1, 0.1)]
	for shelf in range(5):
		var y := shelf * 14.0 + 1.0
		_add(_box(Vector3(w, 1.2, d)), wood, at + Vector3(0, y, 0))
		var x := -w * 0.5 + 1.5
		while x < w * 0.5 - 3.0:
			var bw := _rng.randf_range(1.0, 2.6)
			var bh := _rng.randf_range(8.0, 12.0)
			if _rng.randf() < 0.12:
				x += bw * 2.0
				continue
			var c: Color = colors[_rng.randi() % colors.size()]
			_add(_box(Vector3(bw, bh, d - 2.0)), _mat("spine_%s" % c.to_html(), c, 0.7),
				at + Vector3(x + bw * 0.5, y + 0.6 + bh * 0.5, 0.5), Vector3(0, 0, _rng.randf_range(-0.04, 0.04)))
			x += bw + 0.15
	_add(_box(Vector3(w, 1.5, d)), wood, at + Vector3(0, h, 0))


func _build_window(at: Vector3) -> void:
	var night := _mat("night", Color(0.03, 0.05, 0.12), 1.0)
	night.emission_enabled = true
	night.emission = Color(0.08, 0.12, 0.3)
	night.emission_energy_multiplier = 0.8
	var frame := _wood("window_frame", Color(0.55, 0.5, 0.45), Color(0.4, 0.36, 0.32), 0.5, 0.6)
	_add(_box(Vector3(0.2, 30, 22)), night, at)
	for z: float in [-11.0, 0.0, 11.0]:
		_add(_box(Vector3(1.2, 31, 1.2)), frame, at + Vector3(0.4, 0, z))
	for y: float in [-15.0, 0.0, 15.0]:
		_add(_box(Vector3(1.2, 1.2, 23)), frame, at + Vector3(0.4, y, 0))
	# Clair de lune bleuté qui entre par la fenêtre.
	var moon := SpotLight3D.new()
	moon.position = at + Vector3(3, 6, 0)
	moon.rotation = Vector3(-0.5, -PI / 2, 0)
	moon.light_color = Color(0.5, 0.6, 1.0)
	moon.light_energy = 2.0
	moon.spot_range = 90.0
	moon.spot_angle = 30.0
	add_child(moon)


# --- Utilitaires -------------------------------------------------------------------

func _add(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO,
		scl: Vector3 = Vector3.ONE, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _group(pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation = rot
	add_child(n)
	return n


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _mat(key: String, color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	_mats[key] = m
	return m


## Bois procédural (fil, cernes, et lames de parquet si [param plank_width] > 0).
func _wood(key: String, light: Color, dark: Color, grain_scale: float, roughness: float,
		plank_width: float = 0.0) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key]
	if _noise_tex == null:
		var noise := FastNoiseLite.new()
		noise.seed = DECOR_SEED
		noise.frequency = 0.01
		noise.fractal_octaves = 5
		_noise_tex = NoiseTexture2D.new()
		_noise_tex.width = 1024
		_noise_tex.height = 1024
		_noise_tex.seamless = true
		_noise_tex.noise = noise
	var shader: Shader = _mats.get("_wood_shader")
	if shader == null:
		shader = Shader.new()
		shader.code = WOOD_SHADER
		_mats["_wood_shader"] = shader
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("light_wood", light)
	m.set_shader_parameter("dark_wood", dark)
	m.set_shader_parameter("noise_tex", _noise_tex)
	m.set_shader_parameter("grain_scale", grain_scale)
	m.set_shader_parameter("plank_width", plank_width)
	m.set_shader_parameter("roughness_value", roughness)
	_mats[key] = m
	return m
