class_name ServerMatch
extends RefCounted
## Une partie hébergée par le serveur : le GameState de référence, les clients
## humains qui y jouent et les IA. Les signaux du GameState sont traduits en
## événements sérialisables, envoyés aux clients pour mettre à jour leur copie.

var id: int
var state: GameState
## player -> peer_id des joueurs humains connectés.
var peers: Dictionary = {}
## player -> SimpleAI
var ais: Dictionary = {}
var _events: Array[Dictionary] = []


func _init(p_id: int, p_state: GameState) -> void:
	id = p_id
	state = p_state
	for p in range(state.player_count):
		if state.player_kinds[p] == "ai":
			ais[p] = SimpleAI.new(p)
	state.unit_moved.connect(_on_unit_moved)
	state.unit_attacked.connect(_on_unit_attacked)
	state.unit_died.connect(_on_unit_died)
	state.turn_started.connect(_on_turn_started)
	state.game_over.connect(_on_game_over)


## Fait jouer les IA tant que c'est leur tour.
func play_ai_turns() -> void:
	while not state.is_over() and ais.has(state.current_player):
		(ais[state.current_player] as SimpleAI).play_turn(state)


## Retourne les événements accumulés depuis le dernier appel et vide la file.
func take_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out


func _on_unit_moved(u: Unit, from_cell: StringName, to_cell: StringName) -> void:
	_events.append({"e": "moved", "unit": u.id, "from": String(from_cell), "to": String(to_cell), "move_left": u.move_left})


func _on_unit_attacked(attacker: Unit, target: Unit, damage: int) -> void:
	_events.append({"e": "attacked", "unit": attacker.id, "target": target.id, "damage": damage,
		"target_hp": target.hp, "attack_left": attacker.attack_left})


func _on_unit_died(u: Unit) -> void:
	_events.append({"e": "died", "unit": u.id})


func _on_turn_started(player: int, turn_number: int) -> void:
	_events.append({"e": "turn_started", "player": player, "turn": turn_number})


func _on_game_over(winner: int) -> void:
	_events.append({"e": "game_over", "winner": winner})
