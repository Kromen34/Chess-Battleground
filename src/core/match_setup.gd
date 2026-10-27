class_name MatchSetup
extends RefCounted
## Construit un GameState prêt à jouer : plateau selon le nombre de joueurs,
## catalogue d'unités, armée de départ posée sur les zones de spawn.
## Point d'entrée commun au solo, au serveur et aux tests.

const UNIT_DATA_DIR := "res://src/core/units/data/"

## Armée de départ provisoire (par joueur), dans l'ordre des cases de spawn.
const DEFAULT_ARMY: Array[StringName] = [&"guardian", &"soldier", &"soldier", &"knight", &"archer"]


## Charge tous les UnitType du dossier data. Retourne type_id -> UnitType.
static func load_unit_types() -> Dictionary:
	var out := {}
	var dir := DirAccess.open(UNIT_DATA_DIR)
	if dir == null:
		push_error("Dossier d'unités introuvable : %s" % UNIT_DATA_DIR)
		return out
	for f in dir.get_files():
		if f.ends_with(".tres") or f.ends_with(".tres.remap"):
			var path := UNIT_DATA_DIR + f.trim_suffix(".remap")
			var t := load(path) as UnitType
			if t != null:
				out[t.id] = t
	return out


## Crée une partie. [param kinds] : "human"/"ai" par joueur. Retourne null si aucune
## forme de plateau n'existe encore pour ce nombre de joueurs.
static func new_match(kinds: PackedStringArray, seed_value: int = 0, army: Array[StringName] = DEFAULT_ARMY) -> GameState:
	var gen := BoardGenerator.for_player_count(kinds.size())
	if gen == null:
		push_warning("Pas de plateau défini pour %d joueurs" % kinds.size())
		return null
	var board := gen.generate()
	var state := GameState.new(board, kinds.size(), seed_value)
	state.player_kinds = kinds
	for t in load_unit_types().values():
		state.register_type(t)
	place_armies(state, army)
	return state


## Pose [param army] pour chaque joueur, centrée sur sa zone de spawn.
static func place_armies(state: GameState, army: Array[StringName]) -> void:
	for p in range(state.player_count):
		var zone := state.board.get_spawn_zone(p)
		# Zone = 2 rangs entrelacés (x0r0, x0r1, x1r0, ...) : on prend le rang arrière
		# (index pairs = rang 0 pour J0 ; pour J1 le rang size-1 est aussi en index pair).
		var back_rank: Array[StringName] = []
		for i in range(0, zone.size(), 2):
			back_rank.append(zone[i])
		var start := maxi(0, (back_rank.size() - army.size()) / 2)
		for i in range(army.size()):
			var idx := start + i
			if idx >= back_rank.size():
				break
			state.spawn(army[i], p, back_rank[idx])
