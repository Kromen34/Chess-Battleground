class_name BoardView
extends Node3D
## Rendu 3D du plateau et des figurines. Lit le GameState, ne le modifie jamais :
## toute action passe par le GameController qui appelle Rules.
##
## Placeholder volontaire : des cubes pour les cases, des cylindres colorés pour
## les unités. Quand les GLB seront là, UnitType.model_path remplacera le cylindre.

signal cell_clicked(cell_id: StringName)
signal unit_clicked(unit_id: int)

const CELL_HEIGHT := 0.1
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


func _build_cells() -> void:
	for child in get_children():
		child.queue_free()
	_cell_nodes.clear()
	_base_mats.clear()
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.albedo_color = Color(0.4, 0.9, 0.5)

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.22, 0.2, 0.18)
	var light := StandardMaterial3D.new()
	light.albedo_color = Color(0.85, 0.8, 0.7)

	for cell in state.board.get_cells():
		var body := StaticBody3D.new()
		body.name = "Cell_%s" % cell.id
		body.position = cell.world_position
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.96, CELL_HEIGHT, 0.96)
		mesh.mesh = box
		var mat := dark if cell.has_tag("dark") else light
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
	var body := Area3D.new()
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.3
	cyl.height = 0.6 + 0.1 * u.type.max_hp / 4.0
	mesh.mesh = cyl
	mesh.position.y = cyl.height * 0.5 + CELL_HEIGHT * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLAYER_COLORS[u.owner % PLAYER_COLORS.size()]
	mesh.material_override = mat
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.3
	cs.height = cyl.height
	shape.shape = cs
	shape.position.y = mesh.position.y
	body.add_child(shape)
	body.input_event.connect(_on_unit_input.bind(u.id))
	root.add_child(body)

	var label := Label3D.new()
	label.text = u.type.display_name
	label.font_size = 48
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = cyl.height + 0.35
	root.add_child(label)

	root.position = state.board.get_cell(u.cell_id).world_position
	add_child(root)
	_unit_nodes[u.id] = root


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
