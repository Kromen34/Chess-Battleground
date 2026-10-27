class_name GameController
extends Node3D
## Boucle de jeu locale (solo / hot-seat / PvE). Fait le pont entre la vue et Rules.
## En réseau, ce nœud sera remplacé par un client qui envoie les actions au serveur ;
## la vue et le core ne changent pas.

@export var player_kinds: PackedStringArray = PackedStringArray(["human", "ai"])
@export var seed_value: int = 0

@onready var board_view: BoardView = $BoardView
@onready var hud: Label = $HUD/Status

var state: GameState
var selected_unit: Unit
var _ais: Dictionary = {}  # player -> SimpleAI


func _ready() -> void:
	state = MatchSetup.new_match(player_kinds, seed_value)
	if state == null:
		hud.text = "Aucun plateau pour %d joueurs." % player_kinds.size()
		return
	for p in range(state.player_count):
		if state.player_kinds[p] == "ai":
			_ais[p] = SimpleAI.new(p)
	board_view.bind(state)
	board_view.cell_clicked.connect(_on_cell_clicked)
	board_view.unit_clicked.connect(_on_unit_clicked)
	state.turn_started.connect(func(_p: int, _t: int) -> void: _refresh_hud(); _maybe_play_ai())
	state.game_over.connect(func(w: int) -> void: hud.text = "Victoire du joueur %d !" % w)
	_refresh_hud()
	_maybe_play_ai()


func _submit(action: Dictionary) -> void:
	var r := Rules.apply(state, state.current_player, action)
	if not r.ok:
		hud.text = "Refusé : %s" % r.reason
	else:
		_refresh_hud()
	if Actions.type_of(action) != Actions.END_TURN:
		_update_highlights()


func _on_unit_clicked(unit_id: int) -> void:
	if _is_ai_turn() or state.is_over():
		return
	var u := state.get_unit(unit_id)
	if u.owner == state.current_player:
		selected_unit = u
		_update_highlights()
	elif selected_unit != null:
		_submit(Actions.attack(selected_unit.id, u.id))


func _on_cell_clicked(cell_id: StringName) -> void:
	if _is_ai_turn() or state.is_over() or selected_unit == null:
		return
	_submit(Actions.move(selected_unit.id, cell_id))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not _is_ai_turn() and not state.is_over():
		selected_unit = null
		_submit(Actions.end_turn())
		_update_highlights()


func _is_ai_turn() -> bool:
	return _ais.has(state.current_player)


func _maybe_play_ai() -> void:
	if state.is_over() or not _is_ai_turn():
		return
	# Petit délai pour que l'humain voie le tour de l'IA se jouer.
	await get_tree().create_timer(0.4).timeout
	var ai: SimpleAI = _ais[state.current_player]
	while not state.is_over() and _is_ai_turn():
		var a := ai.choose_action(state)
		var r := Rules.apply(state, state.current_player, a)
		if not r.ok or Actions.type_of(a) == Actions.END_TURN:
			break
		await get_tree().create_timer(0.35).timeout
	if not state.is_over() and _is_ai_turn():
		Rules.apply(state, state.current_player, Actions.end_turn())


func _update_highlights() -> void:
	if selected_unit == null or not selected_unit.is_alive():
		board_view.highlight_cells([])
		return
	board_view.highlight_cells(Rules.reachable_cells(state, selected_unit).keys())


func _refresh_hud() -> void:
	if state.is_over():
		return
	var kind: String = state.player_kinds[state.current_player]
	hud.text = "Tour %d — Joueur %d (%s)\nClic figurine : sélectionner · clic case : déplacer · clic ennemi : attaquer · Entrée : fin de tour" % [state.turn_number, state.current_player, kind]
