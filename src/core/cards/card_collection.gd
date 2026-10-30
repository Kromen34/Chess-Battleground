class_name CardCollection
extends RefCounted
## Collection de cartes d'un joueur : combien d'exemplaires de chaque carte il possède.
## Fait autorité côté serveur (BDD) ; le client n'en reçoit qu'une copie pour l'affichage.

## Plafond d'exemplaires par carte : borne les données reçues d'une source douteuse.
const MAX_COPIES := 9999

## id de carte (String) -> nombre d'exemplaires (> 0)
var _counts: Dictionary = {}


func count_of(id: StringName) -> int:
	return int(_counts.get(String(id), 0))


func owns(id: StringName) -> bool:
	return count_of(id) > 0


## Ajoute [n] exemplaires (n > 0). Retourne false si la demande est invalide.
func add(id: StringName, n: int = 1) -> bool:
	if id == &"" or n <= 0:
		return false
	_counts[String(id)] = mini(count_of(id) + n, MAX_COPIES)
	return true


## Nombre de cartes différentes possédées.
func distinct_count() -> int:
	return _counts.size()


## Nombre total d'exemplaires.
func total_count() -> int:
	var total := 0
	for n: int in _counts.values():
		total += n
	return total


## { "id": nombre } : la forme qui transite sur le réseau.
func to_dict() -> Dictionary:
	return _counts.duplicate()


## Relit une collection reçue (JSON : les nombres sont des float). Les entrées
## invalides sont ignorées plutôt que de faire échouer toute la lecture.
static func from_dict(v: Variant) -> CardCollection:
	var c := CardCollection.new()
	if typeof(v) != TYPE_DICTIONARY:
		return c
	var d: Dictionary = v
	for key: Variant in d.keys():
		var n: Variant = d[key]
		if typeof(key) != TYPE_STRING or not (typeof(n) == TYPE_INT or typeof(n) == TYPE_FLOAT):
			continue
		c.add(StringName(key), int(n))
	return c
