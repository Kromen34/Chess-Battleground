class_name Cell
extends RefCounted
## Une case du plateau. Ne connaît que son identifiant, sa position 3D (pour la vue
## et le placement des figurines) et ses voisines par direction.
## Elle ne sait pas sur quelle "face" du plateau elle se trouve.

var id: StringName
## Position dans le monde, utilisée par la vue uniquement. Les règles n'y touchent pas.
var world_position: Vector3
## Direction -> id de la case voisine
var _neighbors: Dictionary = {}
## Étiquettes libres (ex. "dark"/"light" pour l'alternance, "spawn", "obstacle")
var tags: PackedStringArray = PackedStringArray()


func _init(p_id: StringName, p_world_position: Vector3 = Vector3.ZERO) -> void:
	id = p_id
	world_position = p_world_position


func set_neighbor(dir: StringName, cell_id: StringName) -> void:
	_neighbors[dir] = cell_id


func get_neighbor(dir: StringName) -> StringName:
	return _neighbors.get(dir, &"")


func has_neighbor(dir: StringName) -> bool:
	return _neighbors.has(dir)


func directions() -> Array[StringName]:
	var out: Array[StringName] = []
	for d in _neighbors.keys():
		out.append(d)
	return out


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func _to_string() -> String:
	return "Cell(%s)" % id
