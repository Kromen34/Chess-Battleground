class_name UnitType
extends Resource
## Définition d'un type de figurine. Données pures, éditables en .tres.
## Chaque figurine a ses propres points de mouvement (PM) et d'action/attaque (PA).

## Identifiant stable (sérialisé sur le réseau). Ex : &"knight".
@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Caractéristiques")
@export var max_hp: int = 10
## Points de mouvement par tour : nombre de cases franchissables.
@export var move_points: int = 2
## Points d'attaque par tour : nombre d'attaques possibles.
@export var attack_points: int = 1
@export var damage: int = 3
## Portée d'attaque en cases (1 = corps à corps).
@export var attack_range: int = 1

@export_group("Déplacement")
## Directions autorisées pour le mouvement. Vide = toutes (orthogonales + diagonales).
@export var move_directions: Array[StringName] = []
## Si vrai, l'unité peut passer par-dessus les autres unités (ex. cavalier).
@export var can_jump: bool = false

@export_group("Visuel")
## Chemin du modèle 3D (res://assets/models/xxx.glb). Utilisé par la vue uniquement.
@export_file("*.glb") var model_path: String = ""


func effective_move_directions() -> Array[StringName]:
	if move_directions.is_empty():
		return Board.ALL_DIRS
	return move_directions


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"display_name": display_name,
		"max_hp": max_hp,
		"move_points": move_points,
		"attack_points": attack_points,
		"damage": damage,
		"attack_range": attack_range,
		"move_directions": Array(move_directions).map(func(d: StringName) -> String: return String(d)),
		"can_jump": can_jump,
		"model_path": model_path,
	}


static func from_dict(d: Dictionary) -> UnitType:
	var t := UnitType.new()
	t.id = StringName(d.get("id", ""))
	t.display_name = d.get("display_name", "")
	t.max_hp = int(d.get("max_hp", 10))
	t.move_points = int(d.get("move_points", 2))
	t.attack_points = int(d.get("attack_points", 1))
	t.damage = int(d.get("damage", 3))
	t.attack_range = int(d.get("attack_range", 1))
	for s in d.get("move_directions", []):
		t.move_directions.append(StringName(s))
	t.can_jump = bool(d.get("can_jump", false))
	t.model_path = d.get("model_path", "")
	return t
