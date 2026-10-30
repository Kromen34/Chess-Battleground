class_name CardCatalog
extends RefCounted
## Toutes les cartes du jeu, lues dans les .tres de DATA_DIR. Le client s'en sert pour
## afficher la collection ; le serveur pour reconnaître les identifiants de cartes.

const DATA_DIR := "res://src/core/cards/data/"

## id (String) -> CardDef
var _cards: Dictionary = {}


static func load_dir(dir: String = DATA_DIR) -> CardCatalog:
	var catalog := CardCatalog.new()
	if not DirAccess.dir_exists_absolute(dir):
		push_warning("CardCatalog : dossier %s absent" % dir)
		return catalog
	for f in DirAccess.get_files_at(dir):
		# Dans un jeu exporté, les .tres peuvent devenir des .tres.remap : on charge le chemin d'origine.
		var file := f.trim_suffix(".remap")
		if file.get_extension() != "tres":
			continue
		var card := load(dir.path_join(file)) as CardDef
		if card == null or card.id == &"":
			push_warning("CardCatalog : %s n'est pas une carte valide" % file)
			continue
		catalog.add(card)
	return catalog


func add(card: CardDef) -> void:
	if _cards.has(String(card.id)):
		push_warning("CardCatalog : identifiant de carte en double : %s" % card.id)
		return
	_cards[String(card.id)] = card


func size() -> int:
	return _cards.size()


func has(id: StringName) -> bool:
	return _cards.has(String(id))


## null si la carte n'existe pas.
func get_card(id: StringName) -> CardDef:
	return _cards.get(String(id)) as CardDef


## Familles, triées par nom.
func families() -> PackedStringArray:
	var out: PackedStringArray = []
	for card: CardDef in _cards.values():
		if not out.has(card.family):
			out.append(card.family)
	out.sort()
	return out


## Cartes d'une famille, triées par nom affiché.
func cards_of(family: String) -> Array[CardDef]:
	var out: Array[CardDef] = []
	for card: CardDef in _cards.values():
		if card.family == family:
			out.append(card)
	out.sort_custom(func(a: CardDef, b: CardDef) -> bool:
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	return out
