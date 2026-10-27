class_name Actions
extends RefCounted
## Fabrique d'actions. Une action est un Dictionary sérialisable : c'est ce qui
## circule sur le réseau et ce que l'IA produit. Pas de classe par action pour
## rester trivial à (dé)sérialiser.

const MOVE := &"move"
const ATTACK := &"attack"
const END_TURN := &"end_turn"


static func move(unit_id: int, to_cell: StringName) -> Dictionary:
	return {"type": String(MOVE), "unit": unit_id, "to": String(to_cell)}


static func attack(unit_id: int, target_unit_id: int) -> Dictionary:
	return {"type": String(ATTACK), "unit": unit_id, "target": target_unit_id}


static func end_turn() -> Dictionary:
	return {"type": String(END_TURN)}


static func type_of(action: Dictionary) -> StringName:
	return StringName(action.get("type", ""))
