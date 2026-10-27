class_name BoardView
extends Node3D
## Rendu 3D du plateau et des figurines. Lit le GameState, ne le modifie jamais :
## toute action passe par le GameController qui appelle Rules.
##
## Cases en dalles de pierre (basalte / grès) ; le décor autour est construit par
## BattlegroundDecor. Les unités restent des cylindres colorés : quand les GLB seront
## là, UnitType.model_path remplacera le cylindre.

signal cell_clicked(cell_id: StringName)
signal unit_clicked(unit_id: int)
## Émis après construction du plateau, avec l'AABB couvrant toutes les cases
## (le décor se construit autour).
signal board_built(bounds: AABB)

const CELL_HEIGHT := 0.1
const DARK_TILE := Color(0.2, 0.18, 0.17)
const LIGHT_TILE := Color(0.58, 0.54, 0.47)
## Graine fixe : les variations de teinte des dalles sont identiques à chaque partie.
const TILE_SEED := 8
const PLAYER_COLORS: Array[Color] = [
	Color(0.25, 0.55, 0.95),  # J0 bleu
	Color(0.9, 0.3, 0.3),     # J1 rouge
	Color(0.3, 0.8, 0.4),     # J2 vert
	Color(0.9, 0.75, 0.2),    # J3 jaune
	Color(0.7, 0.4, 0.9),     # J4 violet
]

var state: GameState
var _cell_nodes: Dictionary = {}   # cell_id -> StaticBody3D
var _unit_nodes: Dictionary = {}   # unit_id -> Node3D
var _highlight_mat: StandardMaterial3D
var _base_mats: Dictionary = {}    # cell_id -> Material


func bind(p_state: GameState) -> void:
	state = p_state
	_build_cells()
	_build_units()
	state.unit_moved.connect(_on_unit_moved)
	state.unit_died.connect(_on_unit_died)
	state.unit_attacked.connect(_on_unit_attacked)
	board_built.emit(board_bounds())


## AABB couvrant toutes les cases du plateau.
func board_bounds() -> AABB:
	var box := AABB()
	var first := true
	for cell in state.board.get_cells():
		var c := AABB(cell.world_position - Vector3(0.5, CELL_HEIGHT * 0.5, 0.5), Vector3(1.0, CELL_HEIGHT, 1.0))
		box = c if first else box.merge(c)
		first = false
	return box


func _build_cells() -> void:
	for child in get_children():
		child.queue_free()
	_cell_nodes.clear()
	_base_mats.clear()
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.albedo_color = Color(0.3, 0.75, 0.4)
	_highlight_mat.emission_enabled = true
	_highlight_mat.emission = Color(0.25, 0.9, 0.4)
	_highlight_mat.emission_energy_multiplier = 0.8
	_highlight_mat.roughness = 0.6

	# Grain de la pierre : bruit en triplanar, chaque dalle a donc un motif différent.
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	noise.fractal_octaves = 5
	var grain_ramp := Gradient.new()
	grain_ramp.set_color(0, Color(0.72, 0.72, 0.72))
	grain_ramp.set_color(1, Color(1, 1, 1))
	var grain := NoiseTexture2D.new()
	grain.seamless = true
	grain.noise = noise
	grain.color_ramp = grain_ramp
	var rng := RandomNumberGenerator.new()
	rng.seed = TILE_SEED

	for cell in state.board.get_cells():
		var body := StaticBody3D.new()
		body.name = "Cell_%s" % cell.id
		body.position = cell.world_position
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.96, CELL_HEIGHT, 0.96)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		var base := DARK_TILE if cell.has_tag("dark") else LIGHT_TILE
		mat.albedo_color = base.lightened(rng.randf_range(-0.06, 0.06)) if rng.randf() < 0.5 else base.darkened(rng.randf_range(0.0, 0.1))
		mat.albedo_texture = grain
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.6, 0.6, 0.6)
		mat.uv1_offset = Vector3(rng.randf(), rng.randf(), rng.randf())
		mat.roughness = 0.8 if cell.has_tag("dark") else 0.9
		mesh.material_override = mat
		_base_mats[cell.id] = mat
		body.add_child(mesh)
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = box.size
		shape.shape = bs
		body.add_child(shape)
		body.set_meta("cell_id", cell.id)
		body.input_event.connect(_on_cell_input.bind(cell.id))
		add_child(body)
		_cell_nodes[cell.id] = body


func _build_units() -> void:
	for u in state.units.values():
		if u.is_alive():
			_spawn_unit_node(u)


func _spawn_unit_node(u: Unit) -> void:
	var root := Node3D.new()
	root.name = "Unit_%d" % u.id
	var team_color := PLAYER_COLORS[u.owner % PLAYER_COLORS.size()]
	var model := _load_model(u.type.model_path)
	var height: float
	if model != null:
		# Les modèles regardent vers -Z : le joueur 0 (côté +z) fait face à l'adversaire,
		# le joueur 1 est retourné.
		model.rotation.y = 0.0 if u.owner == 0 else PI
		model.position.y = CELL_HEIGHT * 0.5
		_tint_base(model, team_color)
		root.add_child(model)
		height = _model_height(model)
	else:
		var mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.25
		cyl.bottom_radius = 0.3
		cyl.height = 0.6 + 0.1 * u.type.max_hp / 4.0
		mesh.mesh = cyl
		mesh.position.y = cyl.height * 0.5 + CELL_HEIGHT * 0.5
		var mat := StandardMaterial3D.new()
		mat.albedo_color = team_color
		mesh.material_override = mat
		root.add_child(mesh)
		height = cyl.height

	# Zone cliquable : un cylindre invisible sur la case, quel que soit le visuel.
	var body := Area3D.new()
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.4
	cs.height = minf(height, 1.6)
	shape.shape = cs
	shape.position.y = cs.height * 0.5 + CELL_HEIGHT * 0.5
	body.add_child(shape)
	body.input_event.connect(_on_unit_input.bind(u.id))
	root.add_child(body)

	var label := Label3D.new()
	label.text = u.type.display_name
	label.font_size = 48
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = height + 0.35
	root.add_child(label)

	root.position = state.board.get_cell(u.cell_id).world_position
	add_child(root)
	_unit_nodes[u.id] = root


## Instancie le modèle 3D d'une figurine, ou null s'il n'y en a pas (ou si le fichier
## manque, par exemple des figurines sous licence absentes du dépôt).
func _load_model(path: String) -> Node3D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


## Le socle du modèle (nœud "base") prend la couleur de l'équipe.
func _tint_base(model: Node3D, color: Color) -> void:
	var base := model.find_child("base", true, false) as MeshInstance3D
	if base == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.25)
	mat.roughness = 0.6
	mat.metallic = 0.3
	base.material_override = mat


func _model_height(model: Node3D) -> float:
	var top := 0.0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (mi as MeshInstance3D).get_aabb()
		top = maxf(top, box.end.y)
	return top


func highlight_cells(cell_ids: Array) -> void:
	for id in _cell_nodes.keys():
		var mesh: MeshInstance3D = _cell_nodes[id].get_child(0)
		mesh.material_override = _highlight_mat if cell_ids.has(id) else _base_mats[id]


func _on_cell_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int, cell_id: StringName) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cell_clicked.emit(cell_id)


func _on_unit_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int, unit_id: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		unit_clicked.emit(unit_id)


func _on_unit_moved(u: Unit, _from: StringName, to: StringName) -> void:
	var node: Node3D = _unit_nodes.get(u.id)
	if node == null:
		return
	var target := state.board.get_cell(to).world_position
	var tw := create_tween()
	tw.tween_property(node, "position", target, 0.25).set_trans(Tween.TRANS_SINE)


func _on_unit_attacked(attacker: Unit, target: Unit, _dmg: int) -> void:
	var node: Node3D = _unit_nodes.get(attacker.id)
	if node == null:
		return
	var origin := node.position
	var dir := (state.board.get_cell(target.cell_id).world_position - origin).normalized()
	var tw := create_tween()
	tw.tween_property(node, "position", origin + dir * 0.3, 0.08)
	tw.tween_property(node, "position", origin, 0.12)


func _on_unit_died(u: Unit) -> void:
	var node: Node3D = _unit_nodes.get(u.id)
	if node == null:
		return
	_unit_nodes.erase(u.id)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_callback(node.queue_free)
