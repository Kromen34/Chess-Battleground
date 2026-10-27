class_name BattlegroundDecor
extends Node3D
## Décor du champ de bataille autour du plateau : estrade de pierre, braseros,
## bannières des deux camps, sol, rochers, ruines, armes plantées, arbres morts,
## montagnes au loin et braises dans l'air.
##
## Premier jet entièrement procédural (formes primitives) en attendant les vrais
## modèles. Purement visuel : ne lit ni ne modifie le GameState. Construit autour
## des limites du plateau reçues de BoardView (signal board_built).

const TEAM_COLORS: Array[Color] = [Color(0.2, 0.4, 0.85), Color(0.75, 0.15, 0.15)]
## Graine fixe : le décor est identique à chaque partie.
const DECOR_SEED := 20261027

const GROUND_SHADER := """
shader_type spatial;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 dirt : source_color;
uniform vec3 grass : source_color;
uniform vec3 scorch : source_color;
uniform float arena_radius = 7.0;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float large = texture(noise_tex, world_pos.xz * 0.035).r;
	float detail = texture(noise_tex, world_pos.xz * 0.22 + vec2(0.37, 0.11)).r;
	vec3 c = mix(dirt, grass, smoothstep(0.42, 0.68, large));
	c = mix(c, scorch, smoothstep(0.6, 0.78, detail) * 0.75);
	c *= 0.8 + 0.4 * detail;
	// Terre battue autour de l'arène, piétinée par les combats.
	float d = length(world_pos.xz);
	c = mix(dirt * (0.75 + 0.3 * detail), c, smoothstep(arena_radius * 0.8, arena_radius * 1.5, d));
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
"""

var _rng := RandomNumberGenerator.new()
var _mats: Dictionary = {}
## Feux des braseros : lumière -> phase, pour le scintillement.
var _flames: Dictionary = {}
var _time: float = 0.0
var _banners: Array[Node3D] = []


## Construit tout le décor autour de [param bounds] (AABB des cases du plateau).
func build(bounds: AABB) -> void:
	for child in get_children():
		child.queue_free()
	_flames.clear()
	_banners.clear()
	_rng.seed = DECOR_SEED
	var center := bounds.get_center()
	position = Vector3(center.x, 0.0, center.z)
	var half := Vector2(bounds.size.x * 0.5, bounds.size.z * 0.5)
	var radius := half.length()

	_build_ground(radius)
	_build_dais(half)
	_build_braziers(half)
	_build_banners(half)
	_build_ruins(radius)
	_build_weapons(half, radius)
	_build_rocks(radius)
	_build_dead_trees(radius)
	_build_mountains()
	_build_embers(radius)


func _process(delta: float) -> void:
	_time += delta
	for light: OmniLight3D in _flames.keys():
		var phase: float = _flames[light]
		light.light_energy = 1.6 + 0.4 * sin(_time * 11.0 + phase) + 0.3 * sin(_time * 23.0 + phase * 2.0)
	for i in range(_banners.size()):
		_banners[i].rotation.y = 0.08 * sin(_time * 1.3 + i)


# --- Sol et estrade ----------------------------------------------------------------

func _build_ground(radius: float) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = DECOR_SEED
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	var shader := Shader.new()
	shader.code = GROUND_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("noise_tex", tex)
	mat.set_shader_parameter("dirt", Color(0.2, 0.17, 0.14))
	mat.set_shader_parameter("grass", Color(0.22, 0.25, 0.15))
	mat.set_shader_parameter("scorch", Color(0.08, 0.07, 0.06))
	mat.set_shader_parameter("arena_radius", radius + 2.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	_add(plane, mat, Vector3(0, -0.9, 0))


## Estrade à deux marches sous le plateau, rebord de pierre et liseré doré.
func _build_dais(half: Vector2) -> void:
	var stone := _mat("dais_stone", Color(0.17, 0.17, 0.18), 0.9)
	var stone_light := _mat("dais_stone_light", Color(0.27, 0.26, 0.26), 0.85)
	var gold := _mat("gold", Color(0.75, 0.55, 0.2), 0.35, 0.9)
	var top := -0.05  # dessous des cases (hauteur 0.1 centrée sur 0)

	_add(_box(Vector3(half.x * 2 + 3.2, 0.45, half.y * 2 + 3.2)), stone, Vector3(0, -0.9 + 0.225, 0))
	_add(_box(Vector3(half.x * 2 + 1.6, top + 0.9 - 0.45, half.y * 2 + 1.6)), stone_light,
		Vector3(0, (-0.45 + top) * 0.5, 0))

	# Rebord autour des cases.
	var rim_w := 0.35
	var rim_h := 0.2
	var y := top + rim_h * 0.5
	var ox := half.x + rim_w * 0.5
	var oz := half.y + rim_w * 0.5
	var long_x := half.x * 2 + rim_w * 2
	for s in [-1.0, 1.0]:
		_add(_box(Vector3(long_x, rim_h, rim_w)), stone, Vector3(0, y, s * oz))
		_add(_box(Vector3(rim_w, rim_h, half.y * 2)), stone, Vector3(s * ox, y, 0))
		_add(_box(Vector3(long_x - 0.1, 0.03, 0.05)), gold, Vector3(0, top + rim_h + 0.015, s * oz))
		_add(_box(Vector3(0.05, 0.03, half.y * 2)), gold, Vector3(s * ox, top + rim_h + 0.015, 0))


## Un pilier surmonté d'un brasero allumé à chaque coin de l'estrade.
func _build_braziers(half: Vector2) -> void:
	var stone := _mat("pillar", Color(0.25, 0.24, 0.24), 0.85)
	var iron := _mat("iron", Color(0.12, 0.11, 0.1), 0.5, 0.8)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var base := Vector3(sx * (half.x + 0.75), -0.05, sz * (half.y + 0.75))
			var pillar := CylinderMesh.new()
			pillar.top_radius = 0.18
			pillar.bottom_radius = 0.24
			pillar.height = 1.1
			pillar.radial_segments = 8
			_add(pillar, stone, base + Vector3(0, 0.55, 0))
			var bowl := CylinderMesh.new()
			bowl.top_radius = 0.32
			bowl.bottom_radius = 0.14
			bowl.height = 0.22
			bowl.radial_segments = 10
			_add(bowl, iron, base + Vector3(0, 1.21, 0))
			_add_fire(base + Vector3(0, 1.32, 0))


func _add_fire(at: Vector3) -> void:
	var fire := GPUParticles3D.new()
	fire.amount = 32
	fire.lifetime = 0.6
	fire.position = at
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.1
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, 0.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	pm.scale_curve = curve_tex
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.75, 0.3, 0.9))
	ramp.set_color(1, Color(0.8, 0.15, 0.02, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	fire.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var qm := StandardMaterial3D.new()
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = _soft_dot()
	quad.material = qm
	fire.draw_pass_1 = quad
	add_child(fire)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = 5.0
	light.position = at + Vector3(0, 0.3, 0)
	add_child(light)
	_flames[light] = _rng.randf() * TAU


# --- Bannières, ruines, armes ------------------------------------------------------

## Deux bannières par camp, sur les côtés, du côté de chaque joueur
## (joueur 0 vers +z, joueur 1 vers -z, comme SquareGenerator).
func _build_banners(half: Vector2) -> void:
	var wood := _mat("wood", Color(0.3, 0.2, 0.12), 0.9)
	var gold := _mat("gold", Color(0.75, 0.55, 0.2), 0.35, 0.9)
	for team in range(2):
		var sz := 1.0 if team == 0 else -1.0
		var cloth := _mat("banner_%d" % team, TEAM_COLORS[team], 0.8)
		for sx in [-1.0, 1.0]:
			var root := Node3D.new()
			root.position = Vector3(sx * (half.x + 2.6), -0.9, sz * (half.y - 1.5))
			add_child(root)
			var pole := CylinderMesh.new()
			pole.top_radius = 0.05
			pole.bottom_radius = 0.06
			pole.height = 4.0
			_add(pole, wood, Vector3(0, 2.0, 0), Vector3.ZERO, Vector3.ONE, root)
			var bar := CylinderMesh.new()
			bar.top_radius = 0.035
			bar.bottom_radius = 0.035
			bar.height = 1.1
			_add(bar, wood, Vector3(0, 3.8, 0), Vector3(0, 0, PI / 2), Vector3.ONE, root)
			_add(_box(Vector3(1.0, 1.6, 0.03)), cloth, Vector3(0, 2.95, 0.05), Vector3.ZERO, Vector3.ONE, root)
			_add(_box(Vector3(1.0, 0.08, 0.035)), gold, Vector3(0, 2.2, 0.05), Vector3.ZERO, Vector3.ONE, root)
			var tip := CylinderMesh.new()
			tip.top_radius = 0.0
			tip.bottom_radius = 0.07
			tip.height = 0.25
			_add(tip, gold, Vector3(0, 4.12, 0), Vector3.ZERO, Vector3.ONE, root)
			_banners.append(root)


## Colonnes brisées et blocs écroulés autour de l'arène.
func _build_ruins(radius: float) -> void:
	var stone := _mat("ruin", Color(0.36, 0.35, 0.33), 0.9)
	var angles := [0.35, 1.25, 2.4, 3.6, 4.4, 5.4]
	for a: float in angles:
		var d := radius + _rng.randf_range(3.5, 6.0)
		var at := Vector3(cos(a) * d, -0.9, sin(a) * d)
		_add(_box(Vector3(1.0, 0.3, 1.0)), stone, at + Vector3(0, 0.15, 0), Vector3(0, _rng.randf() * PI, 0))
		var col := CylinderMesh.new()
		col.top_radius = 0.3
		col.bottom_radius = 0.33
		col.radial_segments = 10
		col.height = _rng.randf_range(0.8, 2.8)
		_add(col, stone, at + Vector3(0, 0.3 + col.height * 0.5, 0), Vector3(_rng.randf_range(-0.06, 0.06), 0, _rng.randf_range(-0.06, 0.06)))
		# Tronçon tombé à côté.
		if _rng.randf() < 0.7:
			var fallen := CylinderMesh.new()
			fallen.top_radius = 0.3
			fallen.bottom_radius = 0.3
			fallen.radial_segments = 10
			fallen.height = _rng.randf_range(0.7, 1.6)
			var off := Vector3(_rng.randf_range(0.8, 1.4), 0, 0).rotated(Vector3.UP, _rng.randf() * TAU)
			_add(fallen, stone, at + off + Vector3(0, 0.3, 0), Vector3(PI / 2, _rng.randf() * PI, 0))


## Épées, lances et boucliers abandonnés sur le champ de bataille.
func _build_weapons(half: Vector2, radius: float) -> void:
	var steel := _mat("steel", Color(0.6, 0.6, 0.62), 0.35, 0.9)
	var wood := _mat("wood", Color(0.3, 0.2, 0.12), 0.9)
	var leather := _mat("leather", Color(0.2, 0.12, 0.08), 0.9)
	var placed := 0
	var tries := 0
	while placed < 22 and tries < 400:
		tries += 1
		var p := _random_ring_point(radius + 1.5, radius + 9.0)
		if _in_camera_foreground(p, half):
			continue
		placed += 1
		var tilt := Vector3(_rng.randf_range(-0.45, 0.45), _rng.randf() * TAU, _rng.randf_range(-0.45, 0.45))
		var root := Node3D.new()
		root.position = Vector3(p.x, -0.9, p.y)
		root.rotation = tilt
		add_child(root)
		match placed % 3:
			0:  # épée plantée
				_add(_box(Vector3(0.07, 0.95, 0.015)), steel, Vector3(0, 0.35, 0), Vector3.ZERO, Vector3.ONE, root)
				_add(_box(Vector3(0.32, 0.04, 0.05)), steel, Vector3(0, 0.83, 0), Vector3.ZERO, Vector3.ONE, root)
				var grip := CylinderMesh.new()
				grip.top_radius = 0.022
				grip.bottom_radius = 0.022
				grip.height = 0.22
				_add(grip, leather, Vector3(0, 0.96, 0), Vector3.ZERO, Vector3.ONE, root)
			1:  # lance
				var shaft := CylinderMesh.new()
				shaft.top_radius = 0.022
				shaft.bottom_radius = 0.025
				shaft.height = 2.2
				_add(shaft, wood, Vector3(0, 0.9, 0), Vector3.ZERO, Vector3.ONE, root)
				var head := CylinderMesh.new()
				head.top_radius = 0.0
				head.bottom_radius = 0.05
				head.height = 0.25
				_add(head, steel, Vector3(0, 2.1, 0), Vector3.ZERO, Vector3.ONE, root)
			_:  # bouclier au sol, aux couleurs d'un camp
				root.rotation = Vector3(_rng.randf_range(1.2, 1.5), _rng.randf() * TAU, 0)
				var shield := CylinderMesh.new()
				shield.top_radius = 0.38
				shield.bottom_radius = 0.38
				shield.height = 0.05
				shield.radial_segments = 16
				var faded := TEAM_COLORS[_rng.randi() % 2].darkened(0.45)
				_add(shield, _mat("shield_%s" % faded.to_html(), faded, 0.8), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3.ONE, root)
				var boss := SphereMesh.new()
				boss.radius = 0.09
				boss.height = 0.09
				_add(boss, steel, Vector3(0, 0.06, 0), Vector3.ZERO, Vector3.ONE, root)


# --- Nature et lointain ------------------------------------------------------------

func _build_rocks(radius: float) -> void:
	var rocks := [_mat("rock_a", Color(0.32, 0.3, 0.28), 0.95), _mat("rock_b", Color(0.24, 0.23, 0.22), 0.95)]
	for i in range(55):
		var p := _random_ring_point(radius + 2.0, 32.0)
		var rock := SphereMesh.new()
		rock.radial_segments = 7
		rock.rings = 4
		var s := _rng.randf_range(0.25, 1.4) * (1.0 + p.length() / 30.0)
		_add(rock, rocks[i % 2], Vector3(p.x, -0.9 + s * 0.15, p.y),
			Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU),
			Vector3(s * _rng.randf_range(0.8, 1.4), s * _rng.randf_range(0.4, 0.8), s * _rng.randf_range(0.8, 1.4)))


func _build_dead_trees(radius: float) -> void:
	var bark := _mat("bark", Color(0.16, 0.12, 0.09), 0.95)
	for i in range(9):
		var p := _random_ring_point(radius + 7.0, 26.0)
		var root := Node3D.new()
		root.position = Vector3(p.x, -0.9, p.y)
		root.rotation.y = _rng.randf() * TAU
		add_child(root)
		var h := _rng.randf_range(2.5, 4.5)
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.06
		trunk.bottom_radius = 0.22
		trunk.height = h
		trunk.radial_segments = 6
		_add(trunk, bark, Vector3(0, h * 0.5, 0), Vector3(0, 0, _rng.randf_range(-0.1, 0.1)), Vector3.ONE, root)
		for b in range(3):
			var branch := CylinderMesh.new()
			branch.top_radius = 0.02
			branch.bottom_radius = 0.07
			branch.height = _rng.randf_range(0.8, 1.6)
			var y := h * _rng.randf_range(0.45, 0.85)
			var ang := b * TAU / 3.0 + _rng.randf_range(-0.4, 0.4)
			var dir := Vector3(cos(ang), 0, sin(ang))
			# Branche inclinée vers l'extérieur, base collée au tronc.
			var tilt := _rng.randf_range(0.6, 1.0)
			var basis := Basis(dir.cross(Vector3.UP).normalized(), -tilt)
			var node := MeshInstance3D.new()
			node.mesh = branch
			node.material_override = bark
			node.transform = Transform3D(basis, Vector3(0, y, 0) + basis * Vector3(0, branch.height * 0.5, 0))
			root.add_child(node)


## Montagnes basses tout autour, estompées par le brouillard.
func _build_mountains() -> void:
	var mat := _mat("mountain", Color(0.17, 0.16, 0.18), 1.0)
	var count := 22
	for i in range(count):
		var a := i * TAU / count + _rng.randf_range(-0.1, 0.1)
		var d := _rng.randf_range(48.0, 62.0)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = _rng.randf_range(9.0, 16.0)
		cone.height = _rng.randf_range(7.0, 16.0)
		cone.radial_segments = 6
		cone.rings = 1
		_add(cone, mat, Vector3(cos(a) * d, -0.9 + cone.height * 0.5, sin(a) * d), Vector3(0, _rng.randf() * TAU, 0))


func _build_embers(radius: float) -> void:
	var embers := GPUParticles3D.new()
	embers.amount = 160
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.visibility_aabb = AABB(Vector3(-radius * 3, -2, -radius * 3), Vector3(radius * 6, 12, radius * 6))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radius * 2.2, 0.5, radius * 2.2)
	pm.direction = Vector3.UP
	pm.spread = 40.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.45
	pm.gravity = Vector3(0.12, 0.05, 0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.6, 0.2, 0.0))
	ramp.add_point(0.2, Color(1.0, 0.55, 0.15, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.8, 0.2, 0.05, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	embers.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var qm := StandardMaterial3D.new()
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = _soft_dot()
	quad.material = qm
	embers.draw_pass_1 = quad
	embers.position = Vector3(0, -0.5, 0)
	add_child(embers)


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


## Petite tache ronde et floue, pour les particules de feu et de braises.
func _soft_dot() -> GradientTexture2D:
	if _mats.has("_soft_dot"):
		return _mats["_soft_dot"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	_mats["_soft_dot"] = tex
	return tex


## Point aléatoire (x, z) dans l'anneau [r_min, r_max] autour du plateau.
func _random_ring_point(r_min: float, r_max: float) -> Vector2:
	var a := _rng.randf() * TAU
	var d := sqrt(_rng.randf_range(r_min * r_min, r_max * r_max))
	return Vector2(cos(a), sin(a)) * d


## Vrai si (x, z) tomberait entre la caméra (côté +z) et le plateau.
func _in_camera_foreground(p: Vector2, half: Vector2) -> bool:
	return p.y > half.y and absf(p.x) < half.x + 3.0
