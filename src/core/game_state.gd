class_name GameState
extends RefCounted
## État complet d'une partie. Sérialisable en Dictionary pour le réseau et les replays.
## Ne contient aucune logique de validation : c'est le rôle de Rules.

signal unit_moved(unit: Unit, from_cell: StringName, to_cell: StringName)
signal unit_attacked(attacker: Unit, target: Unit, damage: int)
signal unit_died(unit: Unit)
signal turn_started(player: int, turn_number: int)
signal game_over(winner: int)

var board: Board
## unit_id -> Unit
var units: Dictionary = {}
## type_id -> UnitType (catalogue des types utilisés dans cette partie)
var unit_types: Dictionary = {}
var player_count: int = 2
## Pour chaque joueur : "human" ou "ai". Index = numéro de joueur.
var player_kinds: PackedStringArray = PackedStringArray()
var current_player: int = 0
var turn_number: int = 1
var winner: int = -1
var rng := RandomNumberGenerator.new()
var _next_unit_id: int = 1


func _init(p_board: Board = null, p_player_count: int = 2, seed_value: int = 0) -> void:
	board = p_board
	player_count = p_player_count
	rng.seed = seed_value
	for _i in range(p_player_count):
		player_kinds.append("human")


func register_type(t: UnitType) -> void:
	unit_types[t.id] = t


func spawn(type_id: StringName, owner: int, cell_id: StringName) -> Unit:
	assert(unit_types.has(type_id), "Type d'unité inconnu : %s" % type_id)
	assert(board.has_cell(cell_id), "Case inconnue : %s" % cell_id)
	assert(unit_at(cell_id) == null, "Case déjà occupée : %s" % cell_id)
	var u := Unit.new(_next_unit_id, unit_types[type_id], owner, cell_id)
	_next_unit_id += 1
	units[u.id] = u
	return u


func get_unit(unit_id: int) -> Unit:
	return units.get(unit_id) as Unit


func unit_at(cell_id: StringName) -> Unit:
	for u in units.values():
		if u.cell_id == cell_id and u.is_alive():
			return u
	return null


func units_of(player: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units.values():
		if u.owner == player and u.is_alive():
			out.append(u)
	return out


## Dictionary cell_id -> true pour toutes les cases occupées par une unité vivante.
func occupied_cells() -> Dictionary:
	var out := {}
	for u in units.values():
		if u.is_alive():
			out[u.cell_id] = true
	return out


func is_over() -> bool:
	return winner != -1


func to_dict() -> Dictionary:
	var unit_list: Array = []
	for u in units.values():
		unit_list.append(u.to_dict())
	var types: Array = []
	for t in unit_types.values():
		types.append(t.to_dict())
	return {
		"shape": String(board.shape_id),
		"player_count": player_count,
		"player_kinds": Array(player_kinds),
		"current_player": current_player,
		"turn_number": turn_number,
		"winner": winner,
		"seed": rng.seed,
		"rng_state": rng.state,
		"next_unit_id": _next_unit_id,
		"unit_types": types,
		"units": unit_list,
	}


## Vue de la partie envoyée au client [param player] par le serveur.
## Retire tout ce qu'un client ne doit pas connaître : la graine et l'état du RNG
## (sinon il prédit les dés). C'est ici qu'on cachera aussi la main et le deck adverses.
func to_view_dict(_player: int) -> Dictionary:
	var d := to_dict()
	d.erase("seed")
	d.erase("rng_state")
	return d


static func from_dict(d: Dictionary, p_board: Board) -> GameState:
	var s := GameState.new(p_board, int(d["player_count"]), int(d.get("seed", 0)))
	s.rng.state = int(d.get("rng_state", s.rng.state))
	s.player_kinds = PackedStringArray(d.get("player_kinds", []))
	s.current_player = int(d["current_player"])
	s.turn_number = int(d["turn_number"])
	s.winner = int(d.get("winner", -1))
	s._next_unit_id = int(d.get("next_unit_id", 1))
	for td in d.get("unit_types", []):
		s.register_type(UnitType.from_dict(td))
	for ud in d.get("units", []):
		var u := Unit.from_dict(ud, s.unit_types)
		s.units[u.id] = u
	return s
