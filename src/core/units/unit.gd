class_name Unit
extends RefCounted
## Une figurine en jeu : un type, un propriétaire, une case, et ses compteurs du tour.

var id: int
var type: UnitType
var owner: int
var cell_id: StringName
var hp: int
## Points restants pour le tour en cours (remis à max en début de tour).
var move_left: int
var attack_left: int


func _init(p_id: int, p_type: UnitType, p_owner: int, p_cell_id: StringName) -> void:
	id = p_id
	type = p_type
	owner = p_owner
	cell_id = p_cell_id
	hp = p_type.max_hp
	refresh()


func is_alive() -> bool:
	return hp > 0


func refresh() -> void:
	move_left = type.move_points
	attack_left = type.attack_points


func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": String(type.id),
		"owner": owner,
		"cell": String(cell_id),
		"hp": hp,
		"move_left": move_left,
		"attack_left": attack_left,
	}


static func from_dict(d: Dictionary, types: Dictionary) -> Unit:
	var t: UnitType = types[StringName(d["type"])]
	var u := Unit.new(int(d["id"]), t, int(d["owner"]), StringName(d["cell"]))
	u.hp = int(d.get("hp", t.max_hp))
	u.move_left = int(d.get("move_left", t.move_points))
	u.attack_left = int(d.get("attack_left", t.attack_points))
	return u


func _to_string() -> String:
	return "Unit#%d(%s, J%d, %s, %d PV)" % [id, type.id, owner, cell_id, hp]
