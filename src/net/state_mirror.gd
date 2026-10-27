class_name StateMirror
extends RefCounted
## Côté client : applique à la copie locale du GameState les événements envoyés
## par le serveur. Le client ne recalcule rien (il n'a ni la graine ni les dés) :
## il recopie les résultats et émet les mêmes signaux que Rules, pour que la vue
## fonctionne pareil en solo et en ligne.


## Applique [param event]. Retourne false s'il ne correspond pas à l'état local
## (désynchronisation) : il faut alors redemander l'état complet au serveur.
static func apply_event(state: GameState, event: Dictionary) -> bool:
	match String(event.get("e", "")):
		"moved":
			var u := state.get_unit(int(event.get("unit", -1)))
			var to := StringName(String(event.get("to", "")))
			if u == null or not state.board.has_cell(to):
				return false
			var from := u.cell_id
			u.cell_id = to
			u.move_left = int(event.get("move_left", 0))
			state.unit_moved.emit(u, from, to)
		"attacked":
			var attacker := state.get_unit(int(event.get("unit", -1)))
			var target := state.get_unit(int(event.get("target", -1)))
			if attacker == null or target == null:
				return false
			target.hp = int(event.get("target_hp", target.hp))
			attacker.attack_left = int(event.get("attack_left", 0))
			state.unit_attacked.emit(attacker, target, int(event.get("damage", 0)))
		"died":
			var dead := state.get_unit(int(event.get("unit", -1)))
			if dead == null:
				return false
			state.unit_died.emit(dead)
		"turn_started":
			var player := int(event.get("player", -1))
			if player < 0 or player >= state.player_count:
				return false
			state.current_player = player
			state.turn_number = int(event.get("turn", state.turn_number))
			for u in state.units_of(player):
				u.refresh()
			state.turn_started.emit(player, state.turn_number)
		"game_over":
			state.winner = int(event.get("winner", -1))
			state.game_over.emit(state.winner)
		_:
			return false
	return true


## Reconstruit le GameState du client à partir de la vue envoyée par le serveur.
## Retourne null si la forme de plateau est inconnue.
static func state_from_view(view: Dictionary) -> GameState:
	var gen := BoardGenerator.for_player_count(int(view.get("player_count", 0)))
	if gen == null or String(gen.shape_id()) != String(view.get("shape", "")):
		return null
	return GameState.from_dict(view, gen.generate())
