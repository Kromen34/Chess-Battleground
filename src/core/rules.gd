class_name Rules
extends RefCounted
## Seule source de vérité sur ce qui est permis. Le serveur appelle apply() ;
## les clients et l'IA appellent validate() / legal_moves() pour anticiper,
## mais seul le résultat du serveur fait foi.
##
## Toutes les fonctions sont statiques et pures vis-à-vis de l'extérieur :
## elles ne touchent qu'au GameState qu'on leur passe.


## Résultat d'une validation : ok=true, ou ok=false + raison lisible.
static func _ok() -> Dictionary:
	return {"ok": true, "reason": ""}


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


## Valide une action sans l'appliquer.
static func validate(state: GameState, player: int, action: Dictionary) -> Dictionary:
	if state.is_over():
		return _fail("partie terminée")
	if player != state.current_player:
		return _fail("ce n'est pas le tour du joueur %d" % player)
	match Actions.type_of(action):
		Actions.MOVE:
			return _validate_move(state, player, action)
		Actions.ATTACK:
			return _validate_attack(state, player, action)
		Actions.END_TURN:
			return _ok()
		_:
			return _fail("type d'action inconnu : %s" % action.get("type", ""))


## Applique une action. Retourne le résultat de validation ; si ok, le state a été modifié
## et les signaux correspondants émis.
static func apply(state: GameState, player: int, action: Dictionary) -> Dictionary:
	var v := validate(state, player, action)
	if not v.ok:
		return v
	match Actions.type_of(action):
		Actions.MOVE:
			_apply_move(state, action)
		Actions.ATTACK:
			_apply_attack(state, action)
		Actions.END_TURN:
			_apply_end_turn(state)
	return v


# --- Déplacement ---------------------------------------------------------------

static func _get_own_unit(state: GameState, player: int, action: Dictionary) -> Unit:
	var u := state.get_unit(int(action.get("unit", -1)))
	if u == null or not u.is_alive() or u.owner != player:
		return null
	return u


static func _validate_move(state: GameState, player: int, action: Dictionary) -> Dictionary:
	var u := _get_own_unit(state, player, action)
	if u == null:
		return _fail("unité invalide")
	var to := StringName(action.get("to", ""))
	if not state.board.has_cell(to):
		return _fail("case inconnue : %s" % to)
	if state.unit_at(to) != null:
		return _fail("case occupée")
	if u.move_left <= 0:
		return _fail("plus de points de mouvement")
	var cost := _move_cost(state, u, to)
	if cost < 0:
		return _fail("case inaccessible")
	if cost > u.move_left:
		return _fail("trop loin (%d > %d PM)" % [cost, u.move_left])
	return _ok()


## Coût en PM pour aller sur [param to], ou -1 si impossible.
static func _move_cost(state: GameState, u: Unit, to: StringName) -> int:
	var blocked := {} if u.type.can_jump else state.occupied_cells()
	blocked.erase(u.cell_id)
	var dirs := u.type.effective_move_directions()
	return state.board.distance(u.cell_id, to, dirs, blocked)


## Toutes les cases où [param u] peut aller ce tour-ci : cell_id -> coût.
static func reachable_cells(state: GameState, u: Unit) -> Dictionary:
	if u.move_left <= 0:
		return {}
	var blocked := {} if u.type.can_jump else state.occupied_cells()
	blocked.erase(u.cell_id)
	var dirs := u.type.effective_move_directions()
	var r := state.board.reachable(u.cell_id, u.move_left, dirs, blocked)
	# Même en sautant, on ne peut pas s'arrêter sur une case occupée.
	for occ in state.occupied_cells().keys():
		r.erase(occ)
	return r


static func _apply_move(state: GameState, action: Dictionary) -> void:
	var u := state.get_unit(int(action["unit"]))
	var to := StringName(action["to"])
	var cost := _move_cost(state, u, to)
	var from := u.cell_id
	u.cell_id = to
	u.move_left -= cost
	state.unit_moved.emit(u, from, to)


# --- Attaque -------------------------------------------------------------------

static func _validate_attack(state: GameState, player: int, action: Dictionary) -> Dictionary:
	var u := _get_own_unit(state, player, action)
	if u == null:
		return _fail("unité invalide")
	var target := state.get_unit(int(action.get("target", -1)))
	if target == null or not target.is_alive():
		return _fail("cible invalide")
	if target.owner == player:
		return _fail("on n'attaque pas ses propres unités")
	if u.attack_left <= 0:
		return _fail("plus de points d'attaque")
	var d := state.board.distance(u.cell_id, target.cell_id, Board.ALL_DIRS)
	if d < 0 or d > u.type.attack_range:
		return _fail("hors de portée")
	return _ok()


## Unités ennemies attaquables par [param u] ce tour-ci.
static func attackable_units(state: GameState, u: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	if u.attack_left <= 0:
		return out
	for other in state.units.values():
		if other.owner == u.owner or not other.is_alive():
			continue
		var d := state.board.distance(u.cell_id, other.cell_id, Board.ALL_DIRS)
		if d >= 0 and d <= u.type.attack_range:
			out.append(other)
	return out


static func _apply_attack(state: GameState, action: Dictionary) -> void:
	var u := state.get_unit(int(action["unit"]))
	var target := state.get_unit(int(action["target"]))
	var dmg := u.type.damage
	target.hp -= dmg
	u.attack_left -= 1
	state.unit_attacked.emit(u, target, dmg)
	if not target.is_alive():
		state.unit_died.emit(target)
		_check_victory(state)


# --- Tour ----------------------------------------------------------------------

static func _apply_end_turn(state: GameState) -> void:
	var start := state.current_player
	var next := (start + 1) % state.player_count
	# Saute les joueurs éliminés.
	while next != start and state.units_of(next).is_empty():
		next = (next + 1) % state.player_count
	if next <= start:
		state.turn_number += 1
	state.current_player = next
	for u in state.units_of(next):
		u.refresh()
	state.turn_started.emit(next, state.turn_number)


## Un joueur a gagné quand il est le seul à avoir encore des unités vivantes.
## En mode N vs 1, les N humains forment une équipe : voir team_of().
static func _check_victory(state: GameState) -> void:
	var alive_teams := {}
	for p in range(state.player_count):
		if not state.units_of(p).is_empty():
			alive_teams[team_of(state, p)] = p
	if alive_teams.size() == 1:
		state.winner = alive_teams.values()[0]
		state.game_over.emit(state.winner)


## Équipe d'un joueur. Pour l'instant : les humains ensemble contre l'IA quand il y a
## une IA et plus de deux joueurs ; sinon chacun pour soi.
static func team_of(state: GameState, player: int) -> int:
	if state.player_count > 2 and state.player_kinds.has("ai"):
		return 1 if state.player_kinds[player] == "ai" else 0
	return player


## Liste toutes les actions légales du joueur courant (utile pour l'IA et les tests).
static func legal_actions(state: GameState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state.is_over():
		return out
	for u in state.units_of(state.current_player):
		for cell in reachable_cells(state, u).keys():
			out.append(Actions.move(u.id, cell))
		for t in attackable_units(state, u):
			out.append(Actions.attack(u.id, t.id))
	out.append(Actions.end_turn())
	return out
