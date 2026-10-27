class_name SimpleAI
extends RefCounted
## IA de référence, volontairement bête : attaque si elle peut, sinon rapproche
## chaque unité de l'ennemi le plus proche, puis finit son tour.
## Elle sert à valider la boucle PvE de bout en bout ; une vraie IA viendra la remplacer
## en gardant la même interface : choose_action(state) -> Dictionary.

var player: int


func _init(p_player: int) -> void:
	player = p_player


## Retourne la prochaine action à jouer. Appeler en boucle jusqu'à recevoir END_TURN.
func choose_action(state: GameState) -> Dictionary:
	if state.current_player != player or state.is_over():
		return Actions.end_turn()

	# 1. Une attaque disponible ? On la prend (cible la plus faible).
	for u in state.units_of(player):
		var targets := Rules.attackable_units(state, u)
		if targets.is_empty():
			continue
		var best: Unit = targets[0]
		for t in targets:
			if t.hp < best.hp:
				best = t
		return Actions.attack(u.id, best.id)

	# 2. Sinon, rapprocher une unité qui a encore des PM de l'ennemi le plus proche.
	for u in state.units_of(player):
		var reach := Rules.reachable_cells(state, u)
		if reach.is_empty():
			continue
		var enemy := _nearest_enemy(state, u)
		if enemy == null:
			continue
		var best_cell: StringName = &""
		var best_dist := state.board.distance(u.cell_id, enemy.cell_id, Board.ALL_DIRS)
		for cell in reach.keys():
			var d := state.board.distance(cell, enemy.cell_id, Board.ALL_DIRS)
			if d >= 0 and d < best_dist:
				best_dist = d
				best_cell = cell
		if best_cell != &"":
			return Actions.move(u.id, best_cell)

	return Actions.end_turn()


func _nearest_enemy(state: GameState, u: Unit) -> Unit:
	var best: Unit = null
	var best_d := 1 << 30
	for other in state.units.values():
		if other.owner == player or not other.is_alive():
			continue
		var d := state.board.distance(u.cell_id, other.cell_id, Board.ALL_DIRS)
		if d >= 0 and d < best_d:
			best_d = d
			best = other
	return best


## Joue le tour complet de l'IA sur [param state] (helper pour le solo et les tests).
func play_turn(state: GameState, max_actions: int = 100) -> void:
	for _i in range(max_actions):
		var a := choose_action(state)
		var r := Rules.apply(state, player, a)
		if not r.ok:
			push_warning("IA : action refusée (%s), fin de tour forcée" % r.reason)
			Rules.apply(state, player, Actions.end_turn())
			return
		if Actions.type_of(a) == Actions.END_TURN or state.is_over():
			return
	Rules.apply(state, player, Actions.end_turn())
